-- =====================================================================
-- 08_pat.sql : Veeva 接続用 PAT（Programmatic Access Token）の発行
--   出力の token_secret は一度しか表示されない。Veeva 側の MCP 接続設定で
--   Authorization: Bearer <token_secret> として使用する。
-- 実行ロール: ACCOUNTADMIN
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- 4) PAT 発行（token_secret は一度しか表示されないので控えること）
ALTER USER VEEVA_PHARMA_DEMO_MCP_USER ADD PROGRAMMATIC ACCESS TOKEN VEEVA_MCP_PAT
  ROLE_RESTRICTION = 'VEEVA_PHARMA_DEMO_MCP_ROLE'
  DAYS_TO_EXPIRY = 30
  COMMENT = 'Veeva MCP 接続デモ用';

-- 再発行する場合:
-- ALTER USER VEEVA_PHARMA_DEMO_MCP_USER ROTATE PROGRAMMATIC ACCESS TOKEN VEEVA_MCP_PAT;
