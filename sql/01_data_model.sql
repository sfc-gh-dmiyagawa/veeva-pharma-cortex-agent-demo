-- =====================================================================
-- 01_data_model.sql : 製薬コマーシャル データモデル + ダミーデータ生成
-- すべて決定的（HASH ベース）に生成するため、どのアカウントで実行しても同じデータになる
-- 実行ロール: VEEVA_PHARMA_DEMO_ROLE
-- =====================================================================
USE ROLE VEEVA_PHARMA_DEMO_ROLE;
USE WAREHOUSE VEEVA_PHARMA_DEMO_WH;
USE SCHEMA VEEVA_PHARMA_DEMO_DB.COMMERCIAL;

-- ---------------------------------------------------------------------
-- 1. 営業所（テリトリー）
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE TERRITORY (
  TERRITORY_ID   VARCHAR  COMMENT 'テリトリーID',
  TERRITORY_NAME VARCHAR  COMMENT '営業所名',
  REGION         VARCHAR  COMMENT '支店（エリア）',
  PREFECTURE     VARCHAR  COMMENT '主担当都道府県'
) COMMENT = '営業所（テリトリー）マスタ';

INSERT INTO TERRITORY VALUES
 ('T01','札幌営業所','北海道支店','北海道'),
 ('T02','仙台営業所','東北支店','宮城県'),
 ('T03','東京第一営業所','首都圏支店','東京都'),
 ('T04','東京第二営業所','首都圏支店','東京都'),
 ('T05','横浜営業所','首都圏支店','神奈川県'),
 ('T06','名古屋営業所','中部支店','愛知県'),
 ('T07','大阪営業所','関西支店','大阪府'),
 ('T08','神戸営業所','関西支店','兵庫県'),
 ('T09','広島営業所','中四国支店','広島県'),
 ('T10','福岡営業所','九州支店','福岡県');

-- ---------------------------------------------------------------------
-- 2. MR（営業担当者）  ※Veeva の User に相当
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE MR (
  MR_ID          VARCHAR COMMENT 'MR ID',
  VEEVA_USER_ID  VARCHAR COMMENT 'Veeva CRM ユーザーID',
  MR_NAME        VARCHAR COMMENT 'MR 氏名',
  EMAIL          VARCHAR COMMENT 'メールアドレス',
  TERRITORY_ID   VARCHAR COMMENT '所属テリトリーID',
  JOB_TITLE      VARCHAR COMMENT '役職'
) COMMENT = 'MR（医薬情報担当者）マスタ';

INSERT INTO MR
SELECT
  'MR' || LPAD(n::VARCHAR, 3, '0'),
  '005JP00000MR' || LPAD(n::VARCHAR, 4, '0'),
  ARRAY_CONSTRUCT('佐藤','鈴木','高橋','田中','伊藤','渡辺','山本','中村','小林','加藤',
                  '吉田','山田','佐々木','山口','松本','井上','木村','林','清水','斎藤')[n-1]::VARCHAR
    || ' ' ||
  ARRAY_CONSTRUCT('健太','大輔','翔','拓也','美咲','直樹','彩','誠','優子','亮',
                  '恵','和也','真由美','剛','智子','浩二','麻衣','隆','由紀','聡')[n-1]::VARCHAR,
  'mr' || LPAD(n::VARCHAR, 3, '0') || '@demo-pharma.example.com',
  'T' || LPAD((MOD(n-1, 10) + 1)::VARCHAR, 2, '0'),
  IFF(n <= 10, 'MR', '主任MR')
FROM (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 20)));

-- ---------------------------------------------------------------------
-- 3. 製品（自社品＋主要競合品）
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE PRODUCT (
  PRODUCT_ID        VARCHAR COMMENT '製品ID',
  BRAND_NAME        VARCHAR COMMENT '製品名（ブランド名）',
  GENERIC_NAME      VARCHAR COMMENT '一般名',
  THERAPEUTIC_AREA  VARCHAR COMMENT '領域',
  INDICATION        VARCHAR COMMENT '主な適応',
  IS_OWN_PRODUCT    BOOLEAN COMMENT '自社品フラグ（TRUE=自社品, FALSE=競合品）',
  UNIT_PRICE_JPY    NUMBER(10,1) COMMENT '薬価（円/単位）',
  LAUNCH_DATE       DATE    COMMENT '発売日'
) COMMENT = '製品マスタ（架空の製品）';

INSERT INTO PRODUCT VALUES
 ('P001','グルコリア錠','ソラグリプチン','糖尿病','2型糖尿病',TRUE, 180.5,'2019-04-01'),
 ('P002','グルコリアXR','ソラグリフロジン','糖尿病','2型糖尿病/慢性心不全',TRUE, 290.0,'2022-06-01'),
 ('P003','カルディオン錠','アゾサルタン','循環器','高血圧症',TRUE, 95.2,'2016-10-01'),
 ('P004','リピクリア錠','ロスバスタチンX','循環器','脂質異常症',TRUE, 120.8,'2018-02-01'),
 ('P005','オンコリブ点滴静注','ネクスマブ','がん','非小細胞肺がん',TRUE, 185000.0,'2023-09-01'),
 ('P006','イムノセラ皮下注','アダリズマブX','免疫','関節リウマチ/乾癬',TRUE, 62000.0,'2021-03-01'),
 ('P007','ニューロパス錠','ミロガバリンX','疼痛','神経障害性疼痛',TRUE, 75.4,'2020-07-01'),
 ('P008','レスピクリア吸入','フルチカゾンX','呼吸器','喘息/COPD',TRUE, 4200.0,'2017-11-01'),
 ('C001','ジャヌビアン錠','シタグリプチンC','糖尿病','2型糖尿病',FALSE, 170.0,'2010-01-01'),
 ('C002','フォシガルト錠','ダパグリフロジンC','糖尿病','2型糖尿病/慢性心不全',FALSE, 275.0,'2014-05-01'),
 ('C003','キイトルーナ点滴静注','ペムブロマブC','がん','非小細胞肺がん',FALSE, 214000.0,'2017-02-01');

-- ---------------------------------------------------------------------
-- 4. 施設（HCO）  ※Veeva の Account(Business/Institution) に相当
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE HCO (
  HCO_ID            VARCHAR COMMENT '施設ID',
  VEEVA_ACCOUNT_ID  VARCHAR COMMENT 'Veeva CRM 施設 Account ID',
  HCO_NAME          VARCHAR COMMENT '施設名',
  HCO_TYPE          VARCHAR COMMENT '施設区分（大学病院/基幹病院/一般病院/診療所）',
  BED_COUNT         NUMBER  COMMENT '病床数',
  PREFECTURE        VARCHAR COMMENT '都道府県',
  CITY              VARCHAR COMMENT '市区町村',
  TERRITORY_ID      VARCHAR COMMENT '担当テリトリーID',
  DPC_FLAG          BOOLEAN COMMENT 'DPC対象病院フラグ',
  FORMULARY_STATUS  VARCHAR COMMENT '自社主力品の採用状況（採用/仮採用/未採用）'
) COMMENT = '医療機関（施設）マスタ';

INSERT INTO HCO
WITH base AS (
  SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 80))
), t AS (
  SELECT n,
         'T' || LPAD((MOD(n-1, 10) + 1)::VARCHAR, 2, '0') AS territory_id,
         CASE WHEN n <= 10 THEN '大学病院' WHEN n <= 30 THEN '基幹病院'
              WHEN n <= 55 THEN '一般病院' ELSE '診療所' END AS hco_type
  FROM base
)
SELECT
  'HCO' || LPAD(t.n::VARCHAR, 4, '0'),
  '001JP00000HCO' || LPAD(t.n::VARCHAR, 5, '0'),
  CASE t.hco_type
    WHEN '大学病院' THEN REGEXP_REPLACE(tr.prefecture, '[都府県]$', '') || IFF(t.n = 4, '西部', '') || '医科大学病院'
    WHEN '基幹病院' THEN REGEXP_REPLACE(tr.prefecture, '[都府県]$', '')
                       || ARRAY_CONSTRUCT('中央病院','総合病院','市民病院','赤十字病院','済生会病院','労災病院','医療センター','記念病院')[MOD(ABS(HASH(t.n,'h1')),8)]::VARCHAR
    WHEN '一般病院' THEN ARRAY_CONSTRUCT('さくら','あおば','みどり','ひかり','すみれ','つばさ','あさひ','わかば')[MOD(ABS(HASH(t.n,'h2')),8)]::VARCHAR
                       || '病院'
    ELSE ARRAY_CONSTRUCT('山田','森','川口','石井','小川','岡田','前田','藤田','後藤','長谷川')[MOD(ABS(HASH(t.n,'h3')),10)]::VARCHAR
         || ARRAY_CONSTRUCT('内科クリニック','内科医院','循環器クリニック','糖尿病クリニック')[MOD(ABS(HASH(t.n,'h4')),4)]::VARCHAR
  END,
  t.hco_type,
  CASE t.hco_type WHEN '大学病院' THEN 800 + MOD(ABS(HASH(t.n,'b')),400)
                  WHEN '基幹病院' THEN 300 + MOD(ABS(HASH(t.n,'b')),300)
                  WHEN '一般病院' THEN 80 + MOD(ABS(HASH(t.n,'b')),150)
                  ELSE MOD(ABS(HASH(t.n,'b')),19) END,
  tr.prefecture,
  ARRAY_CONSTRUCT('中央区','北区','南区','東区','西区','青葉区','港区','緑区')[MOD(ABS(HASH(t.n,'c')),8)]::VARCHAR,
  t.territory_id,
  t.hco_type IN ('大学病院','基幹病院'),
  ARRAY_CONSTRUCT('採用','採用','採用','仮採用','未採用')[MOD(ABS(HASH(t.n,'f')),5)]::VARCHAR
FROM t JOIN TERRITORY tr ON tr.territory_id = t.territory_id;

-- 施設名の重複を解消（同名には地区名を付与）
UPDATE HCO h SET HCO_NAME = h.HCO_NAME || '（' || h.CITY || '）'
WHERE h.HCO_NAME IN (SELECT HCO_NAME FROM HCO GROUP BY 1 HAVING COUNT(*) > 1);
UPDATE HCO h SET HCO_NAME = h.HCO_NAME || ' ' || RIGHT(h.HCO_ID, 2)
WHERE h.HCO_NAME IN (SELECT HCO_NAME FROM HCO GROUP BY 1 HAVING COUNT(*) > 1);

-- ---------------------------------------------------------------------
-- 5. 医師（HCP）  ※Veeva の Account(Person) に相当
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE HCP (
  HCP_ID             VARCHAR COMMENT '医師ID',
  VEEVA_ACCOUNT_ID   VARCHAR COMMENT 'Veeva CRM 医師 Account ID（Veeva 画面から渡されるID）',
  HCP_NAME           VARCHAR COMMENT '医師氏名（漢字）',
  HCP_NAME_KANA      VARCHAR COMMENT '医師氏名（カナ）',
  SPECIALTY          VARCHAR COMMENT '診療科',
  TITLE              VARCHAR COMMENT '役職',
  HCO_ID             VARCHAR COMMENT '主所属施設ID',
  SEGMENT            VARCHAR COMMENT 'ターゲットセグメント（S/A/B/C）',
  KOL_FLAG           BOOLEAN COMMENT 'KOL（キーオピニオンリーダー）フラグ',
  ADOPTION_STAGE     VARCHAR COMMENT '自社品処方ステージ（未処方/トライアル/リピート/ロイヤル）',
  PREFERRED_CHANNEL  VARCHAR COMMENT '希望コミュニケーションチャネル',
  YEARS_OF_PRACTICE  NUMBER  COMMENT '医師経験年数',
  BIRTH_YEAR         NUMBER  COMMENT '生年'
) COMMENT = '医師（HCP）マスタ';

INSERT INTO HCP
WITH base AS (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 300))),
fam AS (
  SELECT ARRAY_CONSTRUCT('佐藤','鈴木','高橋','田中','伊藤','渡辺','山本','中村','小林','加藤','吉田','山田','佐々木','山口','松本','井上','木村','林','清水','山崎','森','池田','橋本','阿部','石川','山下','中島','石井','小川','前田') AS k,
         ARRAY_CONSTRUCT('サトウ','スズキ','タカハシ','タナカ','イトウ','ワタナベ','ヤマモト','ナカムラ','コバヤシ','カトウ','ヨシダ','ヤマダ','ササキ','ヤマグチ','マツモト','イノウエ','キムラ','ハヤシ','シミズ','ヤマザキ','モリ','イケダ','ハシモト','アベ','イシカワ','ヤマシタ','ナカジマ','イシイ','オガワ','マエダ') AS kk,
         ARRAY_CONSTRUCT('一郎','健一','誠','浩','隆','修','大輔','直樹','裕子','恵子','真理','智也','雅人','拓海','美穂','亮介','聡子','剛','和彦','典子') AS g,
         ARRAY_CONSTRUCT('イチロウ','ケンイチ','マコト','ヒロシ','タカシ','オサム','ダイスケ','ナオキ','ユウコ','ケイコ','マリ','トモヤ','マサト','タクミ','ミホ','リョウスケ','サトコ','ツヨシ','カズヒコ','ノリコ') AS gk
)
SELECT
  'HCP' || LPAD(b.n::VARCHAR, 5, '0'),
  '001JP00000HCP' || LPAD(b.n::VARCHAR, 5, '0'),
  f.k[MOD(b.n-1,30)]::VARCHAR || ' ' || f.g[MOD(FLOOR((b.n-1)/30) + 3*MOD(b.n-1,30), 20)]::VARCHAR,
  f.kk[MOD(b.n-1,30)]::VARCHAR || ' ' || f.gk[MOD(FLOOR((b.n-1)/30) + 3*MOD(b.n-1,30), 20)]::VARCHAR,
  ARRAY_CONSTRUCT('糖尿病・内分泌内科','糖尿病・内分泌内科','循環器内科','循環器内科','一般内科','一般内科',
                  '呼吸器内科','腫瘍内科','膠原病・リウマチ内科','腎臓内科','整形外科','皮膚科')[MOD(ABS(HASH(b.n,'s')),12)]::VARCHAR,
  ARRAY_CONSTRUCT('教授','准教授','部長','医長','医員','院長','副院長','医員','医員','医長')[MOD(ABS(HASH(b.n,'t')),10)]::VARCHAR,
  'HCO' || LPAD((MOD(ABS(HASH(b.n,'hco')), 80) + 1)::VARCHAR, 4, '0'),
  ARRAY_CONSTRUCT('S','A','A','B','B','B','C','C','C','C')[MOD(ABS(HASH(b.n,'seg')),10)]::VARCHAR,
  MOD(ABS(HASH(b.n,'kol')),12) = 0,
  ARRAY_CONSTRUCT('未処方','トライアル','リピート','リピート','ロイヤル')[MOD(ABS(HASH(b.n,'ad')),5)]::VARCHAR,
  ARRAY_CONSTRUCT('対面面談','対面面談','Web面談','メール','講演会')[MOD(ABS(HASH(b.n,'ch')),5)]::VARCHAR,
  5 + MOD(ABS(HASH(b.n,'y')),35),
  0
FROM base b CROSS JOIN fam f;

UPDATE HCP SET BIRTH_YEAR = 2026 - 26 - YEARS_OF_PRACTICE;
-- 大学病院の医師は教授/准教授などが付きやすいよう、診療所の医師は院長に寄せる
UPDATE HCP SET TITLE = '院長'
WHERE HCO_ID IN (SELECT HCO_ID FROM HCO WHERE HCO_TYPE = '診療所') AND TITLE IN ('教授','准教授','部長');
UPDATE HCP SET TITLE = '部長'
WHERE HCO_ID IN (SELECT HCO_ID FROM HCO WHERE HCO_TYPE <> '大学病院') AND TITLE IN ('教授','准教授');

-- 診療所の医師の診療科はクリニック名に合わせる
UPDATE HCP p SET SPECIALTY = CASE WHEN h.HCO_NAME LIKE '%循環器%' THEN '循環器内科'
                                  WHEN h.HCO_NAME LIKE '%糖尿病%' THEN '糖尿病・内分泌内科'
                                  ELSE '一般内科' END
FROM HCO h WHERE h.HCO_ID = p.HCO_ID AND h.HCO_TYPE = '診療所';

-- 同姓同名を意図的に1組残す（名前フォールバック時の曖昧性デモ用）
UPDATE HCP SET HCP_NAME = '田中 誠', HCP_NAME_KANA = 'タナカ マコト' WHERE HCP_ID IN ('HCP00001','HCP00002');

-- ---------------------------------------------------------------------
-- 6. MR 担当（MR × 医師）
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE HCP_MR_ASSIGNMENT (
  HCP_ID      VARCHAR COMMENT '医師ID',
  MR_ID       VARCHAR COMMENT '担当MR ID',
  IS_PRIMARY  BOOLEAN COMMENT '主担当フラグ',
  START_DATE  DATE    COMMENT '担当開始日'
) COMMENT = '医師×担当MR';

INSERT INTO HCP_MR_ASSIGNMENT
SELECT p.HCP_ID, m.MR_ID, TRUE, '2024-04-01'
FROM HCP p JOIN HCO h ON h.HCO_ID = p.HCO_ID
JOIN (SELECT MR_ID, TERRITORY_ID, ROW_NUMBER() OVER (PARTITION BY TERRITORY_ID ORDER BY MR_ID) - 1 AS rn FROM MR) m
  ON m.TERRITORY_ID = h.TERRITORY_ID
 AND m.rn = MOD(ABS(HASH(p.HCP_ID,'mr')), 2);

-- ---------------------------------------------------------------------
-- 7. 実消化（施設×製品×月）  ※卸からの実消化データ（納入実績）
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE SALES_FACILITY_MONTHLY (
  SALES_MONTH    DATE   COMMENT '実消化年月（月初日）',
  HCO_ID         VARCHAR COMMENT '施設ID',
  PRODUCT_ID     VARCHAR COMMENT '製品ID',
  UNITS          NUMBER  COMMENT '実消化数量（単位）',
  SALES_AMOUNT   NUMBER(18,0) COMMENT '実消化金額（円, 薬価ベース）',
  TARGET_AMOUNT  NUMBER(18,0) COMMENT '目標金額（円）'
) COMMENT = '施設別・製品別 月次実消化（卸実消化）';

INSERT INTO SALES_FACILITY_MONTHLY
WITH months AS (
  SELECT DATEADD(month, SEQ4(), '2024-11-01'::DATE) AS m, SEQ4() AS idx
  FROM TABLE(GENERATOR(ROWCOUNT => 24))
), hp AS (
  -- 施設×製品の組合せ：施設区分と製品領域で取り扱い有無を決める
  SELECT h.HCO_ID, h.HCO_TYPE, h.FORMULARY_STATUS, p.PRODUCT_ID, p.UNIT_PRICE_JPY, p.THERAPEUTIC_AREA, p.IS_OWN_PRODUCT,
         CASE h.HCO_TYPE WHEN '大学病院' THEN 4.0 WHEN '基幹病院' THEN 2.5 WHEN '一般病院' THEN 1.2 ELSE 0.6 END AS size_factor
  FROM HCO h CROSS JOIN PRODUCT p
  WHERE NOT (p.THERAPEUTIC_AREA IN ('がん','免疫') AND h.HCO_TYPE IN ('一般病院','診療所'))
    AND MOD(ABS(HASH(h.HCO_ID, p.PRODUCT_ID)), 10) < 8
), u AS (
  SELECT mo.m, hp.HCO_ID, hp.PRODUCT_ID, hp.UNIT_PRICE_JPY,
  GREATEST(0, ROUND(
      (CASE WHEN hp.UNIT_PRICE_JPY > 10000 THEN 6 ELSE 2500 END)
      * hp.size_factor
      * (0.6 + MOD(ABS(HASH(hp.HCO_ID, hp.PRODUCT_ID, 'base')), 80) / 100)            -- 施設固有の規模
      * (1 + mo.idx * (MOD(ABS(HASH(hp.HCO_ID, hp.PRODUCT_ID, 'tr')), 7) - 2) / 100)  -- トレンド（-2%〜+4%/月）
      * (0.9 + MOD(ABS(HASH(hp.HCO_ID, hp.PRODUCT_ID, mo.m)), 21) / 100)            -- 月次ノイズ
      * IFF(hp.FORMULARY_STATUS = '未採用' AND hp.IS_OWN_PRODUCT, 0.15, 1)
      * IFF(MONTH(mo.m) IN (3, 12), 1.08, 1)                                       -- 季節性
  )) AS units
  FROM hp CROSS JOIN months mo
)
SELECT m, HCO_ID, PRODUCT_ID, units,
       ROUND(units * UNIT_PRICE_JPY),
       ROUND(units * UNIT_PRICE_JPY * (0.85 + MOD(ABS(HASH(HCO_ID, PRODUCT_ID, 'tgt')), 36) / 100))
FROM u;

-- ---------------------------------------------------------------------
-- 8. 医師別 推計処方実績（施設実消化を医師へ按分）
--    実消化は施設単位でしか取れないため、処方シェア（MR の把握情報）で医師に按分した推計値
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE HCP_PRODUCT_SHARE (
  HCP_ID      VARCHAR COMMENT '医師ID',
  HCO_ID      VARCHAR COMMENT '施設ID',
  PRODUCT_ID  VARCHAR COMMENT '製品ID',
  RX_SHARE    NUMBER(6,4) COMMENT '施設内での当該医師の処方シェア（0-1）'
) COMMENT = '医師の施設内処方シェア（按分係数）';

INSERT INTO HCP_PRODUCT_SHARE
WITH w AS (
  SELECT p.HCP_ID, p.HCO_ID, s.PRODUCT_ID,
         (1 + MOD(ABS(HASH(p.HCP_ID, s.PRODUCT_ID)), 10))
         * CASE
             WHEN pr.THERAPEUTIC_AREA = '糖尿病' AND p.SPECIALTY LIKE '糖尿病%' THEN 5
             WHEN pr.THERAPEUTIC_AREA = '循環器' AND p.SPECIALTY = '循環器内科' THEN 5
             WHEN pr.THERAPEUTIC_AREA = 'がん'   AND p.SPECIALTY IN ('腫瘍内科','呼吸器内科') THEN 6
             WHEN pr.THERAPEUTIC_AREA = '免疫'   AND p.SPECIALTY IN ('膠原病・リウマチ内科','皮膚科','整形外科') THEN 6
             WHEN pr.THERAPEUTIC_AREA = '疼痛'   AND p.SPECIALTY IN ('整形外科','一般内科') THEN 5
             WHEN pr.THERAPEUTIC_AREA = '呼吸器' AND p.SPECIALTY = '呼吸器内科' THEN 6
             WHEN p.SPECIALTY = '一般内科' THEN 1
             ELSE 0.2 END
         * CASE p.ADOPTION_STAGE WHEN '未処方' THEN IFF(pr.IS_OWN_PRODUCT, 0.05, 1.5) WHEN 'トライアル' THEN 0.5
                                 WHEN 'リピート' THEN 1 ELSE 1.6 END AS wgt
  FROM HCP p
  JOIN (SELECT DISTINCT HCO_ID, PRODUCT_ID FROM SALES_FACILITY_MONTHLY) s ON s.HCO_ID = p.HCO_ID
  JOIN PRODUCT pr ON pr.PRODUCT_ID = s.PRODUCT_ID
)
SELECT HCP_ID, HCO_ID, PRODUCT_ID, ROUND(wgt / SUM(wgt) OVER (PARTITION BY HCO_ID, PRODUCT_ID), 4)
FROM w;

CREATE OR REPLACE VIEW HCP_SALES_MONTHLY
  COMMENT = '医師別・製品別 月次推計売上（施設実消化 × 医師処方シェア）'
AS
SELECT s.SALES_MONTH, sh.HCP_ID, s.HCO_ID, s.PRODUCT_ID,
       ROUND(s.UNITS * sh.RX_SHARE)          AS EST_UNITS,
       ROUND(s.SALES_AMOUNT * sh.RX_SHARE)   AS EST_SALES_AMOUNT,
       ROUND(s.TARGET_AMOUNT * sh.RX_SHARE)  AS EST_TARGET_AMOUNT
FROM SALES_FACILITY_MONTHLY s
JOIN HCP_PRODUCT_SHARE sh ON sh.HCO_ID = s.HCO_ID AND sh.PRODUCT_ID = s.PRODUCT_ID;

-- ---------------------------------------------------------------------
-- 9. 訪問・面談記録（Call）  ※Veeva の Call2 に相当
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE CALL_ACTIVITY (
  CALL_ID            VARCHAR COMMENT 'コールID',
  CALL_DATE          DATE    COMMENT '面談日',
  HCP_ID             VARCHAR COMMENT '医師ID',
  MR_ID              VARCHAR COMMENT 'MR ID',
  CHANNEL            VARCHAR COMMENT 'チャネル（対面面談/Web面談/電話/メール）',
  DETAILED_PRODUCT_ID VARCHAR COMMENT 'ディテーリング製品ID',
  KEY_MESSAGE        VARCHAR COMMENT '伝達したキーメッセージ',
  HCP_REACTION       VARCHAR COMMENT '医師の反応（ポジティブ/ニュートラル/ネガティブ）',
  CALL_NOTE          VARCHAR COMMENT '面談メモ（自由記述）',
  NEXT_ACTION        VARCHAR COMMENT '次回アクション'
) COMMENT = 'MR の訪問・面談記録';

INSERT INTO CALL_ACTIVITY
WITH c AS (
  SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 6000))
), x0 AS (
  SELECT c.n,
         'HCP' || LPAD((MOD(ABS(HASH(c.n,'hcp')), 300) + 1)::VARCHAR, 5, '0') AS hcp_id,
         DATEADD(day, -MOD(ABS(HASH(c.n,'d')), 540), '2026-10-20'::DATE) AS call_date,
         'P00' || (MOD(ABS(HASH(c.n,'p')),8) + 1)::VARCHAR AS pid_fallback,
         IFF(MOD(ABS(HASH(c.n,'pr')), 10) < 7, 1, 2) AS want_rank,
         MOD(ABS(HASH(c.n,'r')), 10) AS r,
         MOD(ABS(HASH(c.n,'tpl')), 6) AS tpl
  FROM c
), hp_rank AS (
  -- 医師ごとに処方シェアの高い自社品を順位付け（面談は主にその先生が処方する自社品について行う）
  SELECT s.HCP_ID, s.PRODUCT_ID,
         ROW_NUMBER() OVER (PARTITION BY s.HCP_ID ORDER BY s.RX_SHARE DESC, s.PRODUCT_ID) AS rk,
         COUNT(*) OVER (PARTITION BY s.HCP_ID) AS cnt
  FROM HCP_PRODUCT_SHARE s JOIN PRODUCT p ON p.PRODUCT_ID = s.PRODUCT_ID AND p.IS_OWN_PRODUCT
), x AS (
  SELECT x0.*, COALESCE(r.PRODUCT_ID, x0.pid_fallback) AS pid
  FROM x0
  LEFT JOIN hp_rank r ON r.HCP_ID = x0.hcp_id AND r.rk = LEAST(x0.want_rank, r.cnt)
)
SELECT
  'CALL' || LPAD(x.n::VARCHAR, 7, '0'),
  x.call_date, x.hcp_id, a.MR_ID,
  ARRAY_CONSTRUCT('対面面談','対面面談','対面面談','Web面談','電話','メール')[MOD(ABS(HASH(x.n,'ch')),6)]::VARCHAR,
  x.pid,
  CASE pr.THERAPEUTIC_AREA
    WHEN '糖尿病' THEN ARRAY_CONSTRUCT('低血糖リスクの低さ','心腎保護エビデンス','1日1回投与による服薬アドヒアランス')[MOD(x.n,3)]::VARCHAR
    WHEN '循環器' THEN ARRAY_CONSTRUCT('24時間の安定した降圧効果','配合剤への切替提案','LDL-C 目標達成率')[MOD(x.n,3)]::VARCHAR
    WHEN 'がん'   THEN ARRAY_CONSTRUCT('PD-L1 発現別の全生存期間データ','irAE マネジメント','併用療法の最新データ')[MOD(x.n,3)]::VARCHAR
    WHEN '免疫'   THEN ARRAY_CONSTRUCT('自己注射デバイスの使いやすさ','長期寛解維持データ','感染症リスク管理')[MOD(x.n,3)]::VARCHAR
    WHEN '疼痛'   THEN ARRAY_CONSTRUCT('ふらつき・眠気の少なさ','腎機能別の用量調整','高齢者での安全性')[MOD(x.n,3)]::VARCHAR
    ELSE ARRAY_CONSTRUCT('吸入手技の簡便さ','増悪抑制エビデンス','1日1回吸入')[MOD(x.n,3)]::VARCHAR
  END,
  CASE WHEN x.r < 5 THEN 'ポジティブ' WHEN x.r < 8 THEN 'ニュートラル' ELSE 'ネガティブ' END,
  CASE x.tpl
    WHEN 0 THEN pr.BRAND_NAME || 'について説明。' || IFF(x.r < 5, '先生は効果に満足しており、新規患者への処方を検討するとのこと。', '既存薬からの切替には慎重な姿勢。')
    WHEN 1 THEN pr.BRAND_NAME || 'の最新データを紹介。' || IFF(x.r < 5, '高齢患者での使用経験を共有いただいた。症例検討会での紹介に関心あり。', '競合品' || IFF(pr.THERAPEUTIC_AREA='糖尿病','フォシガルト','') || 'との比較データを求められた。')
    WHEN 2 THEN '外来後に面談。' || pr.BRAND_NAME || 'の副作用プロファイルについて質問あり。' || IFF(x.r >= 8, '過去に患者で消化器症状が出たため懸念を示された。', '安全性情報を追加でお届けする約束をした。')
    WHEN 3 THEN '薬剤部と同席で' || pr.BRAND_NAME || 'の採用状況を確認。' || IFF(x.r < 5, '次回薬事委員会で正式採用の見込み。', '院内の後発品切替方針があり、採用は保留。')
    WHEN 4 THEN 'Web面談で' || pr.BRAND_NAME || 'の講演会案内。' || IFF(x.r < 5, '先生ご自身も座長を検討いただけるとのこと。', '多忙のため参加は未定。')
    ELSE pr.BRAND_NAME || 'の処方状況をヒアリング。' || IFF(x.r < 5, '月10名程度の患者に処方中で、リピート率は高い。', '処方は限定的で、効果実感がまだ弱いとのコメント。')
  END,
  CASE WHEN x.r < 5 THEN '症例データ・文献を持参しフォロー' WHEN x.r < 8 THEN '比較データを準備して再訪' ELSE 'MSL 同行で安全性情報を説明' END
FROM x
JOIN HCP_MR_ASSIGNMENT a ON a.HCP_ID = x.hcp_id
JOIN PRODUCT pr ON pr.PRODUCT_ID = x.pid;

-- ---------------------------------------------------------------------
-- 10. 講演会・イベント参加
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE MEDICAL_EVENT (
  EVENT_ID     VARCHAR COMMENT 'イベントID',
  EVENT_NAME   VARCHAR COMMENT 'イベント名',
  EVENT_DATE   DATE    COMMENT '開催日',
  EVENT_TYPE   VARCHAR COMMENT '形式（講演会/Web講演会/勉強会/学会共催セミナー）',
  PRODUCT_ID   VARCHAR COMMENT '関連製品ID',
  TERRITORY_ID VARCHAR COMMENT '開催テリトリーID'
) COMMENT = '講演会・イベントマスタ';

INSERT INTO MEDICAL_EVENT
SELECT 'EV' || LPAD(n::VARCHAR, 4, '0'),
       pr.BRAND_NAME || ' ' || ARRAY_CONSTRUCT('地域連携講演会','Webセミナー','エキスパートミーティング','学会共催セミナー')[MOD(n,4)]::VARCHAR,
       DATEADD(day, -MOD(ABS(HASH(n,'d')), 540), '2026-10-15'::DATE),
       ARRAY_CONSTRUCT('講演会','Web講演会','勉強会','学会共催セミナー')[MOD(n,4)]::VARCHAR,
       pr.PRODUCT_ID,
       'T' || LPAD((MOD(n-1, 10) + 1)::VARCHAR, 2, '0')
FROM (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 120))) g
JOIN PRODUCT pr ON pr.PRODUCT_ID = 'P00' || (MOD(ABS(HASH(g.n,'p')), 8) + 1)::VARCHAR;

CREATE OR REPLACE TABLE EVENT_ATTENDANCE (
  EVENT_ID  VARCHAR COMMENT 'イベントID',
  HCP_ID    VARCHAR COMMENT '医師ID',
  ROLE      VARCHAR COMMENT '参加区分（演者/座長/参加者）'
) COMMENT = '講演会・イベント参加者';

INSERT INTO EVENT_ATTENDANCE
SELECT e.EVENT_ID, p.HCP_ID,
       CASE WHEN p.KOL_FLAG AND MOD(ABS(HASH(e.EVENT_ID, p.HCP_ID)), 4) = 0 THEN '演者'
            WHEN p.SEGMENT = 'S' AND MOD(ABS(HASH(e.EVENT_ID, p.HCP_ID)), 5) = 0 THEN '座長'
            ELSE '参加者' END
FROM MEDICAL_EVENT e
JOIN HCO h ON h.TERRITORY_ID = e.TERRITORY_ID
JOIN HCP p ON p.HCO_ID = h.HCO_ID
WHERE MOD(ABS(HASH(e.EVENT_ID, p.HCP_ID, 'att')), 100) < 30;

-- ---------------------------------------------------------------------
-- 11. 医師プロファイル統合ビュー（Agent の「先生サマリー」用）
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW HCP_PROFILE_V COMMENT = '医師・施設・担当MRの統合プロファイル' AS
SELECT p.HCP_ID, p.VEEVA_ACCOUNT_ID, p.HCP_NAME, p.HCP_NAME_KANA, p.SPECIALTY, p.TITLE,
       p.SEGMENT, p.KOL_FLAG, p.ADOPTION_STAGE, p.PREFERRED_CHANNEL, p.YEARS_OF_PRACTICE,
       h.HCO_ID, h.VEEVA_ACCOUNT_ID AS HCO_VEEVA_ACCOUNT_ID, h.HCO_NAME, h.HCO_TYPE, h.BED_COUNT,
       h.PREFECTURE, h.CITY, h.FORMULARY_STATUS,
       t.TERRITORY_ID, t.TERRITORY_NAME, t.REGION,
       m.MR_ID, m.MR_NAME, m.EMAIL AS MR_EMAIL
FROM HCP p
JOIN HCO h ON h.HCO_ID = p.HCO_ID
JOIN TERRITORY t ON t.TERRITORY_ID = h.TERRITORY_ID
LEFT JOIN HCP_MR_ASSIGNMENT a ON a.HCP_ID = p.HCP_ID AND a.IS_PRIMARY
LEFT JOIN MR m ON m.MR_ID = a.MR_ID;
