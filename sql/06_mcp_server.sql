-- =====================================================================
-- 06_mcp_server.sql : Snowflake Managed MCP Server（Cortex Agent を1ツールとして公開）
--   Snowflake 推奨構成：外部クライアント（Veeva）には Agent 1つだけを公開し、
--   Analyst / Search / プロシージャは Agent の裏側でガバナンスを効かせて実行させる。
-- 実行ロール: VEEVA_PHARMA_DEMO_ROLE
-- =====================================================================
USE ROLE VEEVA_PHARMA_DEMO_ROLE;
USE SCHEMA VEEVA_PHARMA_DEMO_DB.AGENTS;

CREATE OR REPLACE MCP SERVER PHARMA_MR_MCP_SERVER
  FROM SPECIFICATION $$
    tools:
      - name: "pharma-mr-assistant"
        type: "CORTEX_AGENT_RUN"
        identifier: "VEEVA_PHARMA_DEMO_DB.AGENTS.PHARMA_MR_ASSISTANT"
        title: "MR Assistant (Pharma Commercial)"
        description: >-
          製薬コマーシャル領域の MR アシスタント。医師（先生）のプロファイル、医師別推計売上（実消化の按分）、
          施設の実消化、目標達成率、MR の面談記録、講演会参加を回答する。
          Veeva CRM の医師ページから呼ぶ場合は、メッセージ先頭に
          "[VEEVA_CONTEXT] veeva_account_id=<Veeva Account ID> mr_email=<MRのメール>" を付与すると、
          ユーザーが先生の名前を言わなくても「この先生」として回答する。
        annotations:
          readOnlyHint: true
          destructiveHint: false
          idempotentHint: false
          openWorldHint: false
  $$;

SHOW MCP SERVERS IN SCHEMA VEEVA_PHARMA_DEMO_DB.AGENTS;
