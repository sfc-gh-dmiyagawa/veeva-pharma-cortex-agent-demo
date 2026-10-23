-- =====================================================================
-- 02_semantic_view.sql : Cortex Analyst 用 Semantic View
-- 実行ロール: VEEVA_PHARMA_DEMO_ROLE
-- =====================================================================
USE ROLE VEEVA_PHARMA_DEMO_ROLE;
USE WAREHOUSE VEEVA_PHARMA_DEMO_WH;
USE SCHEMA VEEVA_PHARMA_DEMO_DB.AGENTS;

CREATE OR REPLACE SEMANTIC VIEW PHARMA_COMMERCIAL_SV
  TABLES (
    hcp AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP PRIMARY KEY (HCP_ID) UNIQUE (VEEVA_ACCOUNT_ID)
      WITH SYNONYMS = ('医師','先生','ドクター') COMMENT = '医師マスタ',
    hco AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCO PRIMARY KEY (HCO_ID)
      WITH SYNONYMS = ('施設','病院','医療機関') COMMENT = '医療機関マスタ',
    territory AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.TERRITORY PRIMARY KEY (TERRITORY_ID)
      WITH SYNONYMS = ('営業所','テリトリー','エリア') COMMENT = '営業所マスタ',
    product AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.PRODUCT PRIMARY KEY (PRODUCT_ID)
      WITH SYNONYMS = ('製品','薬剤','品目') COMMENT = '製品マスタ（自社品・競合品）',
    mr AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.MR PRIMARY KEY (MR_ID)
      WITH SYNONYMS = ('営業担当','担当者') COMMENT = 'MR マスタ',
    assignment AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP_MR_ASSIGNMENT PRIMARY KEY (HCP_ID, MR_ID)
      COMMENT = '医師の担当MR',
    hcp_sales AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.HCP_SALES_MONTHLY
      WITH SYNONYMS = ('医師別売上','先生の売上','医師別実績','推計処方') COMMENT = '医師別・製品別 月次推計売上（施設実消化を処方シェアで按分）',
    facility_sales AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.SALES_FACILITY_MONTHLY
      WITH SYNONYMS = ('実消化','施設別売上','納入実績') COMMENT = '施設別・製品別 月次実消化',
    calls AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.CALL_ACTIVITY PRIMARY KEY (CALL_ID)
      WITH SYNONYMS = ('訪問','面談','コール','ディテール') COMMENT = 'MR の訪問・面談記録',
    events AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.MEDICAL_EVENT PRIMARY KEY (EVENT_ID)
      WITH SYNONYMS = ('講演会','イベント','セミナー') COMMENT = '講演会・イベント',
    attendance AS VEEVA_PHARMA_DEMO_DB.COMMERCIAL.EVENT_ATTENDANCE PRIMARY KEY (EVENT_ID, HCP_ID)
      COMMENT = '講演会参加者'
  )
  RELATIONSHIPS (
    hcp_to_hco          AS hcp (HCO_ID) REFERENCES hco,
    hco_to_territory    AS hco (TERRITORY_ID) REFERENCES territory,
    assignment_to_hcp   AS assignment (HCP_ID) REFERENCES hcp,
    assignment_to_mr    AS assignment (MR_ID) REFERENCES mr,
    hcp_sales_to_hcp    AS hcp_sales (HCP_ID) REFERENCES hcp,
    hcp_sales_to_prod   AS hcp_sales (PRODUCT_ID) REFERENCES product,
    fac_sales_to_hco    AS facility_sales (HCO_ID) REFERENCES hco,
    fac_sales_to_prod   AS facility_sales (PRODUCT_ID) REFERENCES product,
    calls_to_hcp        AS calls (HCP_ID) REFERENCES hcp,
    calls_to_mr         AS calls (MR_ID) REFERENCES mr,
    calls_to_prod       AS calls (DETAILED_PRODUCT_ID) REFERENCES product,
    events_to_prod      AS events (PRODUCT_ID) REFERENCES product,
    attendance_to_event AS attendance (EVENT_ID) REFERENCES events,
    attendance_to_hcp   AS attendance (HCP_ID) REFERENCES hcp
  )
  FACTS (
    hcp_sales.est_sales_amount  AS EST_SALES_AMOUNT  COMMENT = '医師別推計売上（円）',
    hcp_sales.est_target_amount AS EST_TARGET_AMOUNT COMMENT = '医師別推計目標（円）',
    hcp_sales.est_units         AS EST_UNITS         COMMENT = '医師別推計数量',
    facility_sales.sales_amount  AS SALES_AMOUNT  COMMENT = '施設実消化金額（円）',
    facility_sales.target_amount AS TARGET_AMOUNT COMMENT = '施設目標金額（円）',
    facility_sales.units         AS UNITS         COMMENT = '施設実消化数量',
    calls.call_record AS 1 COMMENT = '訪問1件',
    attendance.attendance_record AS 1 COMMENT = '参加1件',
    hco.bed_count AS BED_COUNT COMMENT = '病床数',
    hcp.years_of_practice AS YEARS_OF_PRACTICE COMMENT = '医師経験年数'
  )
  DIMENSIONS (
    -- 医師
    hcp.hcp_id           AS HCP_ID           COMMENT = '医師ID（内部ID, 例 HCP00010）',
    hcp.veeva_account_id AS VEEVA_ACCOUNT_ID WITH SYNONYMS = ('Veeva ID','アカウントID') COMMENT = 'Veeva CRM の医師 Account ID（例 001JP00000HCP00010）。Veeva画面から渡される医師の識別子',
    hcp.hcp_name         AS HCP_NAME         WITH SYNONYMS = ('医師名','先生の名前','ドクター名') COMMENT = '医師氏名（姓と名の間に半角スペース。例: 田中 誠）',
    hcp.hcp_name_kana    AS HCP_NAME_KANA    COMMENT = '医師氏名カナ',
    hcp.specialty        AS SPECIALTY        WITH SYNONYMS = ('診療科','専門') COMMENT = '診療科',
    hcp.title            AS TITLE            WITH SYNONYMS = ('役職') COMMENT = '役職（教授/准教授/部長/医長/医員/院長/副院長）',
    hcp.segment          AS SEGMENT          WITH SYNONYMS = ('セグメント','ランク','ターゲットランク') COMMENT = 'ターゲットセグメント S/A/B/C（Sが最重要）',
    hcp.kol_flag         AS KOL_FLAG         WITH SYNONYMS = ('KOL') COMMENT = 'KOLフラグ',
    hcp.adoption_stage   AS ADOPTION_STAGE   WITH SYNONYMS = ('処方ステージ','アドプションステージ') COMMENT = '自社品処方ステージ（未処方/トライアル/リピート/ロイヤル）',
    hcp.preferred_channel AS PREFERRED_CHANNEL COMMENT = '希望コミュニケーションチャネル',
    -- 施設
    hco.hco_id           AS HCO_ID           COMMENT = '施設ID',
    hco.hco_name         AS HCO_NAME         WITH SYNONYMS = ('施設名','病院名') COMMENT = '施設名',
    hco.hco_type         AS HCO_TYPE         WITH SYNONYMS = ('施設区分') COMMENT = '施設区分（大学病院/基幹病院/一般病院/診療所）',
    hco.prefecture       AS PREFECTURE       WITH SYNONYMS = ('都道府県') COMMENT = '都道府県',
    hco.city             AS CITY             COMMENT = '市区町村',
    hco.dpc_flag         AS DPC_FLAG         COMMENT = 'DPC対象病院',
    hco.formulary_status AS FORMULARY_STATUS WITH SYNONYMS = ('採用状況') COMMENT = '自社主力品の採用状況（採用/仮採用/未採用）',
    -- 営業所
    territory.territory_name AS TERRITORY_NAME WITH SYNONYMS = ('営業所名') COMMENT = '営業所名',
    territory.region         AS REGION         WITH SYNONYMS = ('支店') COMMENT = '支店',
    -- 製品
    product.product_id       AS PRODUCT_ID     COMMENT = '製品ID',
    product.brand_name       AS BRAND_NAME     WITH SYNONYMS = ('製品名','ブランド') COMMENT = '製品名（例: グルコリア錠, カルディオン錠）',
    product.generic_name     AS GENERIC_NAME   WITH SYNONYMS = ('一般名') COMMENT = '一般名',
    product.therapeutic_area AS THERAPEUTIC_AREA WITH SYNONYMS = ('領域','疾患領域') COMMENT = '領域（糖尿病/循環器/がん/免疫/疼痛/呼吸器）',
    product.is_own_product   AS IS_OWN_PRODUCT WITH SYNONYMS = ('自社品') COMMENT = 'TRUE=自社品, FALSE=競合品',
    -- MR
    mr.mr_name  AS MR_NAME  WITH SYNONYMS = ('MR名','担当者名') COMMENT = 'MR氏名',
    mr.mr_email AS EMAIL COMMENT = 'MRのメールアドレス',
    assignment.is_primary_mr AS IS_PRIMARY COMMENT = '主担当MRフラグ',
    -- 期間
    hcp_sales.hcp_sales_month AS SALES_MONTH COMMENT = '医師別売上の年月（月初日）',
    facility_sales.facility_sales_month AS SALES_MONTH COMMENT = '実消化年月（月初日）',
    -- 訪問
    calls.call_date      AS CALL_DATE      WITH SYNONYMS = ('訪問日','面談日') COMMENT = '面談日',
    calls.channel        AS CHANNEL        COMMENT = '面談チャネル（対面面談/Web面談/電話/メール）',
    calls.key_message    AS KEY_MESSAGE    COMMENT = '伝達したキーメッセージ',
    calls.hcp_reaction   AS HCP_REACTION   WITH SYNONYMS = ('反応') COMMENT = '医師の反応（ポジティブ/ニュートラル/ネガティブ）',
    calls.call_note      AS CALL_NOTE      COMMENT = '面談メモ',
    calls.next_action    AS NEXT_ACTION    COMMENT = '次回アクション',
    -- 講演会
    events.event_name    AS EVENT_NAME     COMMENT = '講演会名',
    events.event_date    AS EVENT_DATE     COMMENT = '開催日',
    events.event_type    AS EVENT_TYPE     COMMENT = '形式',
    attendance.attendance_role AS ROLE     WITH SYNONYMS = ('参加区分') COMMENT = '参加区分（演者/座長/参加者）'
  )
  METRICS (
    hcp_sales.total_hcp_sales  AS SUM(hcp_sales.est_sales_amount)  WITH SYNONYMS = ('先生の売上','医師売上','処方金額') COMMENT = '医師別推計売上合計（円）',
    hcp_sales.total_hcp_target AS SUM(hcp_sales.est_target_amount) COMMENT = '医師別推計目標合計（円）',
    hcp_sales.total_hcp_units  AS SUM(hcp_sales.est_units)         COMMENT = '医師別推計数量合計',
    hcp_sales.hcp_achievement_rate AS DIV0(SUM(hcp_sales.est_sales_amount), SUM(hcp_sales.est_target_amount)) WITH SYNONYMS = ('達成率') COMMENT = '医師別目標達成率（売上/目標）',
    facility_sales.total_sales  AS SUM(facility_sales.sales_amount)  WITH SYNONYMS = ('実消化金額','施設売上') COMMENT = '施設実消化金額合計（円）',
    facility_sales.total_target AS SUM(facility_sales.target_amount) COMMENT = '施設目標金額合計（円）',
    facility_sales.total_units  AS SUM(facility_sales.units)         COMMENT = '施設実消化数量合計',
    facility_sales.facility_achievement_rate AS DIV0(SUM(facility_sales.sales_amount), SUM(facility_sales.target_amount)) COMMENT = '施設目標達成率',
    calls.call_count AS COUNT(calls.call_record) WITH SYNONYMS = ('訪問回数','面談回数','コール数') COMMENT = '訪問・面談件数',
    attendance.event_attendance_count AS COUNT(attendance.attendance_record) WITH SYNONYMS = ('講演会参加回数') COMMENT = '講演会参加件数',
    hcp.hcp_count AS COUNT(DISTINCT hcp.hcp_id) WITH SYNONYMS = ('医師数') COMMENT = '医師数'
  )
  COMMENT = '製薬コマーシャル分析（医師・施設・実消化・医師別推計売上・訪問・講演会）'
  AI_SQL_GENERATION '日本語で回答する。金額は円。期間指定が無い場合は直近12ヶ月（2025-11〜2026-10）を対象とする。データの最新月は2026年10月。医師を特定する場合は VEEVA_ACCOUNT_ID が与えられていればそれで絞り込み、なければ HCP_NAME で絞り込む。「先生の売上」は医師別推計売上（hcp_sales）を使う。施設全体の売上は facility_sales（実消化）を使う。特に指定が無ければ自社品（IS_OWN_PRODUCT = TRUE）のみを集計する。';
