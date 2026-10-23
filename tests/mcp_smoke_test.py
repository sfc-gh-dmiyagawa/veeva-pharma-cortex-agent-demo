"""Managed MCP Server の疎通テスト（Veeva の MCP クライアントの動きを模擬）.

使い方:
  export SNOWFLAKE_ACCOUNT_URL=https://<orgname>-<account_name>.snowflakecomputing.com
  export SNOWFLAKE_PAT=<07_access_pat.sql で発行した token_secret>
  python3 tests/mcp_smoke_test.py "この先生の概要を教えて" --veeva-account-id 001JP00000HCP00010

標準ライブラリのみで動作します。
"""
import argparse
import json
import os
import urllib.request

MCP_PATH = "/api/v2/databases/VEEVA_PHARMA_DEMO_DB/schemas/AGENTS/mcp-servers/PHARMA_MR_MCP_SERVER"
TOOL_NAME = "pharma-mr-assistant"


def rpc(url: str, token: str, method: str, params: dict, req_id: int) -> dict:
    body = {"jsonrpc": "2.0", "id": req_id, "method": method, "params": params}
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.load(resp)


def final_text(result: dict) -> str:
    """tools/call の結果から Agent の最終回答テキストを取り出す."""
    texts = []
    for item in result.get("content", []):
        if item.get("type") != "text":
            continue
        raw = item.get("text", "")
        try:
            inner = json.loads(raw)
        except json.JSONDecodeError:
            texts.append(raw)
            continue
        for c in inner.get("content", []):
            if c.get("type") == "text":
                texts.append(c.get("text", ""))
    return "\n".join(t for t in texts if t)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("question")
    p.add_argument("--veeva-account-id", default="")
    p.add_argument("--mr-email", default="")
    args = p.parse_args()

    url = os.environ["SNOWFLAKE_ACCOUNT_URL"].rstrip("/") + MCP_PATH
    token = os.environ["SNOWFLAKE_PAT"]

    tools = rpc(url, token, "tools/list", {}, 1)["result"]["tools"]
    print("tools:", [t["name"] for t in tools])

    # Veeva の医師ページから渡される想定のコンテキスト
    ctx = []
    if args.veeva_account_id:
        ctx.append(f"veeva_account_id={args.veeva_account_id}")
    if args.mr_email:
        ctx.append(f"mr_email={args.mr_email}")
    text = (f"[VEEVA_CONTEXT] {' '.join(ctx)}\n" if ctx else "") + args.question

    res = rpc(url, token, "tools/call", {"name": TOOL_NAME, "arguments": {"text": text}}, 2)
    result = res.get("result", res)
    print("isError:", result.get("isError"))
    print(final_text(result) or json.dumps(result, ensure_ascii=False)[:3000])


if __name__ == "__main__":
    main()
