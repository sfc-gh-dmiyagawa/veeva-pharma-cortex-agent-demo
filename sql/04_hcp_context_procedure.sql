-- =====================================================================
-- 04_hcp_context_procedure.sql : 先生コンテキスト解決ツール
--   Veeva の医師ページから渡される VEEVA_ACCOUNT_ID（優先）または医師名（フォールバック）で
--   先生を一意に特定し、プロファイル・直近売上・直近面談をまとめて返す。
--   名前が複数ヒットした場合は候補一覧を返し、Agent がユーザーに確認する。
-- 実行ロール: VEEVA_PHARMA_DEMO_ROLE
-- =====================================================================
USE ROLE VEEVA_PHARMA_DEMO_ROLE;
USE WAREHOUSE VEEVA_PHARMA_DEMO_WH;
USE SCHEMA VEEVA_PHARMA_DEMO_DB.AGENTS;

CREATE OR REPLACE PROCEDURE GET_HCP_CONTEXT(VEEVA_ACCOUNT_ID VARCHAR, HCP_NAME VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Veeva Account ID または医師名から先生を特定し、プロファイル・売上サマリー・直近面談を返す'
EXECUTE AS OWNER
AS
$$
DECLARE
  v_id      VARCHAR DEFAULT NULL;
  v_cnt     INTEGER DEFAULT 0;
  v_name    VARCHAR;
  v_profile VARIANT;
  v_sales   VARIANT;
  v_calls   VARIANT;
  v_events  VARIANT;
  v_cands   VARIANT;
BEGIN
  -- 1) Veeva Account ID（または内部 HCP_ID）で特定
  IF (VEEVA_ACCOUNT_ID IS NOT NULL AND TRIM(VEEVA_ACCOUNT_ID) <> '') THEN
    SELECT MAX(HCP_ID), COUNT(*) INTO :v_id, :v_cnt
    FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP
    WHERE VEEVA_ACCOUNT_ID = TRIM(:VEEVA_ACCOUNT_ID) OR HCP_ID = TRIM(:VEEVA_ACCOUNT_ID);
  END IF;

  -- 2) 名前フォールバック（スペース有無・カナ両対応）
  IF (v_cnt = 0 AND HCP_NAME IS NOT NULL AND TRIM(HCP_NAME) <> '') THEN
    v_name := REGEXP_REPLACE(REPLACE(REPLACE(TRIM(HCP_NAME), '先生', ''), '医師', ''), '[ 　]', '');
    SELECT MAX(HCP_ID), COUNT(*) INTO :v_id, :v_cnt
    FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP
    WHERE REPLACE(HCP_NAME, ' ', '') = :v_name OR REPLACE(HCP_NAME_KANA, ' ', '') = :v_name;

    IF (v_cnt = 0) THEN
      SELECT MAX(HCP_ID), COUNT(*) INTO :v_id, :v_cnt
      FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP
      WHERE REPLACE(HCP_NAME, ' ', '') LIKE '%' || :v_name || '%'
         OR REPLACE(HCP_NAME_KANA, ' ', '') LIKE '%' || :v_name || '%';
    END IF;

    IF (v_cnt > 1) THEN
      SELECT ARRAY_AGG(OBJECT_CONSTRUCT('veeva_account_id', VEEVA_ACCOUNT_ID, 'hcp_name', HCP_NAME,
                                        'hco_name', HCO_NAME, 'specialty', SPECIALTY, 'title', TITLE, 'mr_name', MR_NAME))
             WITHIN GROUP (ORDER BY HCP_ID)
        INTO :v_cands
      FROM (SELECT * FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP_PROFILE_V
            WHERE REPLACE(HCP_NAME, ' ', '') LIKE '%' || :v_name || '%'
               OR REPLACE(HCP_NAME_KANA, ' ', '') LIKE '%' || :v_name || '%'
            LIMIT 10);
      RETURN OBJECT_CONSTRUCT('status', 'AMBIGUOUS',
        'message', '同名または類似名の医師が複数います。どの先生か確認してください。',
        'candidates', :v_cands);
    END IF;
  END IF;

  IF (v_cnt = 0 OR v_id IS NULL) THEN
    RETURN OBJECT_CONSTRUCT('status', 'NOT_FOUND',
      'message', '該当する医師が見つかりませんでした。Veeva Account ID または氏名を確認してください。');
  END IF;

  -- プロファイル
  SELECT OBJECT_CONSTRUCT(*) INTO :v_profile
  FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP_PROFILE_V WHERE HCP_ID = :v_id;

  -- 直近12ヶ月（2025-11〜2026-10）の製品別推計売上・前年同期比・達成率
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT('brand_name', BRAND_NAME, 'is_own_product', IS_OWN_PRODUCT,
           'sales_last_12m_jpy', CUR, 'sales_prev_12m_jpy', PREV,
           'yoy_growth', IFF(PREV = 0, NULL, ROUND(CUR / PREV - 1, 3)),
           'achievement_rate', IFF(TGT = 0, NULL, ROUND(CUR / TGT, 3))))
         WITHIN GROUP (ORDER BY CUR DESC)
    INTO :v_sales
  FROM (
    SELECT pr.BRAND_NAME, pr.IS_OWN_PRODUCT,
           SUM(IFF(s.SALES_MONTH >= '2025-11-01', s.EST_SALES_AMOUNT, 0)) AS CUR,
           SUM(IFF(s.SALES_MONTH <  '2025-11-01', s.EST_SALES_AMOUNT, 0)) AS PREV,
           SUM(IFF(s.SALES_MONTH >= '2025-11-01', s.EST_TARGET_AMOUNT, 0)) AS TGT
    FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP_SALES_MONTHLY s
    JOIN VEEVA_PHARMA_DEMO_DB.COMMERCIAL.PRODUCT pr ON pr.PRODUCT_ID = s.PRODUCT_ID
    WHERE s.HCP_ID = :v_id
    GROUP BY 1, 2);

  -- 直近の面談5件
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT('call_date', CALL_DATE, 'mr_name', MR_NAME, 'channel', CHANNEL,
           'product', BRAND_NAME, 'reaction', HCP_REACTION, 'note', CALL_NOTE, 'next_action', NEXT_ACTION))
         WITHIN GROUP (ORDER BY CALL_DATE DESC)
    INTO :v_calls
  FROM (SELECT c.CALL_DATE, m.MR_NAME, c.CHANNEL, pr.BRAND_NAME, c.HCP_REACTION, c.CALL_NOTE, c.NEXT_ACTION
        FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.CALL_ACTIVITY c
        JOIN VEEVA_PHARMA_DEMO_DB.COMMERCIAL.MR m ON m.MR_ID = c.MR_ID
        JOIN VEEVA_PHARMA_DEMO_DB.COMMERCIAL.PRODUCT pr ON pr.PRODUCT_ID = c.DETAILED_PRODUCT_ID
        WHERE c.HCP_ID = :v_id ORDER BY c.CALL_DATE DESC LIMIT 5);

  -- 直近の講演会参加3件
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT('event_date', EVENT_DATE, 'event_name', EVENT_NAME, 'role', ROLE))
         WITHIN GROUP (ORDER BY EVENT_DATE DESC)
    INTO :v_events
  FROM (SELECT e.EVENT_DATE, e.EVENT_NAME, a.ROLE
        FROM VEEVA_PHARMA_DEMO_DB.COMMERCIAL.EVENT_ATTENDANCE a
        JOIN VEEVA_PHARMA_DEMO_DB.COMMERCIAL.MEDICAL_EVENT e ON e.EVENT_ID = a.EVENT_ID
        WHERE a.HCP_ID = :v_id ORDER BY e.EVENT_DATE DESC LIMIT 3);

  RETURN OBJECT_CONSTRUCT(
    'status', 'FOUND',
    'data_as_of', '2026-10',
    'profile', :v_profile,
    'sales_by_product_last_12m', :v_sales,
    'recent_calls', :v_calls,
    'recent_events', :v_events);
END;
$$;
