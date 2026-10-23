-- =====================================================================
-- 08_oauth_optional.sql : （任意）Snowflake OAuth で MCP に接続する場合
--   Veeva 側の MCP クライアントが OAuth 2.0 Authorization Code フローに対応している場合に使用。
--   ユーザー本人の権限（ロール）で Agent を実行できるため、本番ではこちらを推奨。
-- 実行ロール: ACCOUNTADMIN
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- <VEEVA_REDIRECT_URI> は Veeva（MCP クライアント）側で提示されるコールバック URL に置き換える
CREATE OR REPLACE SECURITY INTEGRATION VEEVA_PHARMA_DEMO_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = '<VEEVA_REDIRECT_URI>'
  OAUTH_ISSUE_REFRESH_TOKENS = TRUE
  OAUTH_REFRESH_TOKEN_VALIDITY = 86400
  PRE_AUTHORIZED_ROLES_LIST = ('VEEVA_PHARMA_DEMO_MCP_ROLE')
  COMMENT = 'Veeva CRM MCP クライアント用 OAuth';

-- Veeva 側に渡す値
--   Client ID / Client Secret
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('VEEVA_PHARMA_DEMO_MCP_OAUTH');
--   Authorization / Token エンドポイント（OAUTH_AUTHORIZATION_ENDPOINT, OAUTH_TOKEN_ENDPOINT）
DESC SECURITY INTEGRATION VEEVA_PHARMA_DEMO_MCP_OAUTH;

-- MR 本人のユーザーで接続させる場合は、各ユーザーに MCP ロールを付与する
-- GRANT ROLE VEEVA_PHARMA_DEMO_MCP_ROLE TO USER <MR_USER>;

-- 社内 IdP（Entra ID / Okta 等）でフェデレーションする場合は External OAuth を使用:
--   https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp
