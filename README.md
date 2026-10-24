# Veeva CRM × Snowflake Cortex Agent（Managed MCP）製薬コマーシャル デモ

製薬会社の MR（営業）が **Veeva CRM の医師ページから** Snowflake の Cortex Agent を呼び出し、
「この先生の売上は？」「前回の面談で何を懸念していた？」のように **先生の名前を言わずに** 質問できるデモです。
Agent は **Snowflake Managed MCP Server** で公開しているため、MCP クライアント（Veeva Vault CRM の MCP Client など）からそのまま呼び出せます。

> データはすべて架空のダミーデータです（医師・施設・製品・金額は実在しません）。

## アーキテクチャ

```
Veeva Vault CRM（医師ページ）
  │  MCP Client: tools/call "pharma-mr-assistant"
  │  text = "[VEEVA_CONTEXT] veeva_account_id=001JP00000HCP00010 mr_email=...\n<MR の質問>"
  ▼
Snowflake Managed MCP Server  VEEVA_PHARMA_DEMO_DB.AGENTS.PHARMA_MR_MCP_SERVER
  │  （認証: PAT ／ Snowflake OAuth ／ External OAuth）
  ▼
Cortex Agent  VEEVA_PHARMA_DEMO_DB.AGENTS.PHARMA_MR_ASSISTANT
  ├─ hcp_context            : ストアドプロシージャ GET_HCP_CONTEXT（ID→先生特定／名前フォールバック／同名は候補提示）
  ├─ commercial_analyst     : Cortex Analyst（Semantic View PHARMA_COMMERCIAL_SV）
  ├─ call_notes_search      : Cortex Search（面談メモ）
  └─ hcp_directory_search   : Cortex Search（医師名の表記ゆれ・カナ・施設名）
  ▼
COMMERCIAL スキーマ（医師／施設／製品／MR／実消化／医師別推計売上／面談／講演会）
```

Snowflake の推奨構成どおり、外部クライアントには **Agent 1つだけ** を MCP ツールとして公開し、
Analyst / Search / プロシージャは Agent の裏側で実行させています（ガバナンスとオーケストレーションを Snowflake 側に寄せる）。

### 先生コンテキストの渡し方（名前を言わせない仕組み）

Veeva の医師ページは表示中の先生の **Veeva Account ID** を持っているため、MCP 呼び出し時にメッセージ先頭へ付与します。

```
[VEEVA_CONTEXT] veeva_account_id=001JP00000HCP00010 mr_email=mr008@demo-pharma.example.com
この先生の直近12ヶ月の製品別売上と前年比は？
```

- Agent は最初に `hcp_context` を ID で呼び、先生を確定してから回答します（Analyst への問い合わせも ID で絞り込む）。
- ID が無い場合は氏名でフォールバックします。同姓同名（デモでは「田中 誠」を意図的に2名用意）の場合は候補を提示して確認します。
- `mr_email` を渡すと「自分の担当先」などの質問を MR 本人で絞り込みます（任意）。
- 2ターン目以降は MCP ツールの `thread_id` / `parent_message_id` を渡すと会話が継続します。

## データモデル（`VEEVA_PHARMA_DEMO_DB.COMMERCIAL`）

| テーブル / ビュー | 内容 | 件数 |
|---|---|---|
| `TERRITORY` | 営業所・支店 | 10 |
| `MR` | MR（Veeva User ID 付き） | 20 |
| `PRODUCT` | 自社品 8 ＋ 競合品 3（架空） | 11 |
| `HCO` | 施設（大学病院/基幹病院/一般病院/診療所, Veeva Account ID 付き） | 80 |
| `HCP` | 医師（Veeva Account ID, 診療科, セグメント, 処方ステージ等） | 300 |
| `HCP_MR_ASSIGNMENT` | 医師×担当MR | 300 |
| `SALES_FACILITY_MONTHLY` | 施設×製品×月の **実消化**（2024-11〜2026-10, 目標付き） | 約14,500 |
| `HCP_PRODUCT_SHARE` | 施設内の医師別処方シェア（按分係数） | 約2,300 |
| `HCP_SALES_MONTHLY`（View） | **医師別推計売上** = 実消化 × 処方シェア | — |
| `CALL_ACTIVITY` | MR の面談記録（チャネル・反応・メモ・次回アクション） | 6,000 |
| `MEDICAL_EVENT` / `EVENT_ATTENDANCE` | 講演会と参加者（演者/座長/参加者） | 120 / 約1,100 |
| `HCP_PROFILE_V`（View） | 医師・施設・営業所・担当MR の統合ビュー | 300 |

> 実消化は卸経由で施設単位でしか取れないため、「先生の売上」は処方シェアで按分した **推計値** として扱っています（Agent も回答で明示）。
> データは HASH ベースで決定的に生成するので、どのアカウントで実行しても同じ内容になります。

## 作成されるオブジェクト（すべてデモ専用）

| 種別 | 名前 |
|---|---|
| Role | `VEEVA_PHARMA_DEMO_ROLE`（管理用）, `VEEVA_PHARMA_DEMO_MCP_ROLE`（MCP 実行用・読み取りのみ） |
| Warehouse | `VEEVA_PHARMA_DEMO_WH`（XSMALL, 60秒で自動停止） |
| Database | `VEEVA_PHARMA_DEMO_DB`（スキーマ `COMMERCIAL`, `AGENTS`, `SECURITY`） |
| Semantic View | `AGENTS.PHARMA_COMMERCIAL_SV` |
| Cortex Search | `AGENTS.CALL_NOTES_SEARCH`, `AGENTS.HCP_DIRECTORY_SEARCH` |
| Procedure | `AGENTS.GET_HCP_CONTEXT(VARCHAR, VARCHAR)` |
| Agent | `AGENTS.PHARMA_MR_ASSISTANT` |
| MCP Server | `AGENTS.PHARMA_MR_MCP_SERVER`（ツール名 `pharma-mr-assistant`） |
| User | `VEEVA_PHARMA_DEMO_MCP_USER`（TYPE=SERVICE, PAT 用） |
| Auth Policy | `SECURITY.MCP_PAT_AUTH_POLICY`（デモ用にネットワークポリシー無しで PAT を許可） |

## セットアップ手順（トライアルアカウント可）

Snowsight のワークシート、または Snowflake CLI で `sql/` を番号順に実行します。

| # | ファイル | 実行ロール | 内容 |
|---|---|---|---|
| 00 | `00_setup.sql` | ACCOUNTADMIN | ロール・WH・DB・スキーマ、クロスリージョン推論の有効化 |
| 01 | `01_data_model.sql` | DEMO_ROLE | テーブル作成とダミーデータ生成 |
| 02 | `02_semantic_view.sql` | DEMO_ROLE | Semantic View |
| 03 | `03_cortex_search.sql` | DEMO_ROLE | Cortex Search ×2 |
| 04 | `04_hcp_context_procedure.sql` | DEMO_ROLE | 先生コンテキスト解決プロシージャ |
| 05 | `05_agent.sql` | DEMO_ROLE | Cortex Agent |
| 06 | `06_mcp_server.sql` | DEMO_ROLE | Managed MCP Server |
| 07 | `07_access.sql` | ACCOUNTADMIN | MCP ロールへの権限付与・サービスユーザー・認証ポリシー |
| 08 | `08_pat.sql` | ACCOUNTADMIN | PAT 発行（**token_secret は一度しか表示されない**） |
| 09 | `09_oauth_optional.sql` | ACCOUNTADMIN | （任意）Snowflake OAuth 用 Security Integration |
| 99 | `99_teardown.sql` | ACCOUNTADMIN | 全削除 |

```bash
# Snowflake CLI の例（<conn> は接続名）
for f in 00_setup 01_data_model 02_semantic_view 03_cortex_search 04_hcp_context_procedure 05_agent 06_mcp_server 07_access 08_pat; do
  snow sql -c <conn> -f sql/$f.sql
done
```

- 01〜06 は `CREATE OR REPLACE` なので何度でも再実行できます。再実行した場合は **07 も再実行**して権限を付け直してください（08 の PAT はそのまま使えます）。
- Tokyo などで Agent のモデルが使えない場合に備え、00 で `CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'` を設定しています。
- **トライアルアカウントで動作確認済み**（Enterprise / AWS US East 2）：00〜08 をそのまま実行し、Managed MCP 経由（PAT）で Agent が回答することを確認しています。SPCS やコンテナは使わないため、トライアルの制限には該当しません。
- トライアルに SSO が無い場合、CLI の `externalbrowser` 認証は使えません。キーペア認証（`ALTER USER ... SET RSA_PUBLIC_KEY`）で接続してください。

## MCP 接続情報（Veeva 側に案内する内容）

| 項目 | 値 |
|---|---|
| MCP エンドポイント | `https://<orgname>-<account_name>.snowflakecomputing.com/api/v2/databases/VEEVA_PHARMA_DEMO_DB/schemas/AGENTS/mcp-servers/PHARMA_MR_MCP_SERVER` |
| トランスポート | Streamable HTTP（JSON-RPC 2.0, `POST`） |
| 認証ヘッダ（PAT） | `Authorization: Bearer <08_pat.sql の token_secret>` |
| ツール名 | `pharma-mr-assistant` |
| 入力 | `text`（必須）, `thread_id` / `parent_message_id`（会話継続時）, `background`（非同期実行時） |

- ホスト名の **アンダースコアはハイフン** にしてください（`my_org-my_account` → `my-org-my-account`）。MCP はアンダースコアを含むホスト名で接続できないことがあります。
- アカウント URL は `SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();` で確認できます。

### 疎通確認

```bash
export SNOWFLAKE_ACCOUNT_URL=https://<orgname>-<account_name>.snowflakecomputing.com
export SNOWFLAKE_PAT=<token_secret>
python3 tests/mcp_smoke_test.py "この先生の概要と訪問前のポイントを教えて" --veeva-account-id 001JP00000HCP00010
```

curl の場合:

```bash
curl -X POST "$SNOWFLAKE_ACCOUNT_URL/api/v2/databases/VEEVA_PHARMA_DEMO_DB/schemas/AGENTS/mcp-servers/PHARMA_MR_MCP_SERVER" \
  -H "Authorization: Bearer $SNOWFLAKE_PAT" -H "Content-Type: application/json" -H "Accept: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"pharma-mr-assistant","arguments":{"text":"[VEEVA_CONTEXT] veeva_account_id=001JP00000HCP00010\n先生の直近12ヶ月の製品別売上は？"}}}'
```

## 認証方式の選び方

| 方式 | 用途 | 備考 |
|---|---|---|
| **PAT（本デモの既定）** | まず繋げる・PoC | サービスユーザー1つで全 MR 共通。デモ用に認証ポリシーでネットワークポリシー必須を緩和している。本番では Veeva の送信元 IP を許可するネットワークポリシーを設定する |
| Snowflake OAuth（`09_oauth_optional.sql`） | MR 本人の権限で実行 | Veeva の MCP クライアントが Authorization Code フローに対応している場合 |
| External OAuth | 社内 IdP（Entra ID / Okta）連携 | 本番推奨。MCP サーバーには `OAUTH_AUTHORIZATION_SERVER` / `OAUTH_SCOPES_SUPPORTED` パラメータで設定 |

## デモシナリオ（質問例）

すべて `[VEEVA_CONTEXT] veeva_account_id=001JP00000HCP00010` を先頭に付けた状態を想定。

1. この先生の概要と、訪問前に押さえるポイントを教えて
2. 先生の直近12ヶ月の製品別売上と前年比は？
3. 先生の自社品の月次売上推移を直近6ヶ月で見せて
4. 先生が過去の面談で懸念していたことは？
5. 同じ施設の他の先生と比べて、この先生の売上はどう？
6. 次回訪問で何を話すべき？3行で
7. （コンテキスト無しで）田中誠先生の売上を教えて → 同姓同名の候補を提示して確認

## ディレクトリ構成

```
sql/       構築スクリプト（番号順に実行）
tests/     MCP 疎通テスト（mcp_smoke_test.py）
```

## 参考

- [Snowflake-managed MCP server](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [CREATE MCP SERVER](https://docs.snowflake.com/en/sql-reference/sql/create-mcp-server)
- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
