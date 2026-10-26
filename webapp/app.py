"""Veeva Vault CRM の iFrame に埋め込むチャットウィジェット（デモ用・標準ライブラリのみ）。

起動:
  SNOWFLAKE_ACCOUNT_URL=https://<account>.snowflakecomputing.com \
  SNOWFLAKE_PAT=<PAT> python webapp/app.py
埋め込み URL 例:
  https://<host>/?account_id=001JP00000HCP00010&mr=mr01@example.com&mr_name=佐藤
"""
import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ACCOUNT_URL = os.environ["SNOWFLAKE_ACCOUNT_URL"].rstrip("/")
PAT = os.environ["SNOWFLAKE_PAT"]
ROLE = os.environ.get("SNOWFLAKE_ROLE", "VEEVA_PHARMA_DEMO_MCP_ROLE")
WAREHOUSE = os.environ.get("SNOWFLAKE_WAREHOUSE", "VEEVA_PHARMA_DEMO_WH")
DB, SCHEMA, AGENT = "VEEVA_PHARMA_DEMO_DB", "AGENTS", "PHARMA_MR_ASSISTANT"
# iFrame での表示を許可する親ページ（Veeva のドメイン）。例: "https://*.veevavault.com"
FRAME_ANCESTORS = os.environ.get("FRAME_ANCESTORS", "*")
PORT = int(os.environ.get("PORT", "8080"))


def snowflake_post(path, body, timeout=180):
    req = urllib.request.Request(
        ACCOUNT_URL + path,
        data=json.dumps(body).encode(),
        method="POST",
        headers={
            "Authorization": f"Bearer {PAT}",
            "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
            "X-Snowflake-Role": ROLE,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as res:
        return json.loads(res.read())


def get_hcp(account_id):
    """ヘッダー表示用に先生のプロフィールを取得（SQL API で GET_HCP_CONTEXT を呼ぶ）。"""
    res = snowflake_post("/api/v2/statements", {
        "statement": f"CALL {DB}.{SCHEMA}.GET_HCP_CONTEXT(?, NULL)",
        "bindings": {"1": {"type": "TEXT", "value": account_id}},
        "warehouse": WAREHOUSE,
        "role": ROLE,
    }, timeout=60)
    ctx = json.loads(res["data"][0][0])
    p = ctx.get("profile") or {}
    return {
        "status": ctx.get("status"),
        "hcp_name": p.get("HCP_NAME"),
        "hco_name": p.get("HCO_NAME"),
        "specialty": p.get("SPECIALTY"),
    }


def run_agent(messages, account_id, mr_email):
    """会話履歴を丸ごと送る方式（thread を使わない）。最初のユーザー発言に Veeva コンテキストを付与。"""
    prefix = f"[VEEVA_CONTEXT] veeva_account_id={account_id} mr_email={mr_email}\n"
    payload = []
    for i, m in enumerate(messages):
        text = m["text"]
        if i == 0 and m["role"] == "user":
            text = prefix + text
        payload.append({"role": m["role"], "content": [{"type": "text", "text": text}]})
    res = snowflake_post(f"/api/v2/databases/{DB}/schemas/{SCHEMA}/agents/{AGENT}:run",
                         {"messages": payload, "stream": False})
    return "\n".join(c["text"] for c in res.get("content", []) if c.get("type") == "text").strip()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Security-Policy", f"frame-ancestors {FRAME_ANCESTORS}")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False))

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/":
            self._send(200, PAGE, "text/html; charset=utf-8")
        elif url.path == "/api/hcp":
            account_id = parse_qs(url.query).get("account_id", [""])[0]
            try:
                self._json(200, get_hcp(account_id))
            except Exception as e:  # noqa: BLE001 デモ用
                self._json(502, {"error": str(e)})
        elif url.path == "/healthz":
            self._send(200, "ok", "text/plain")
        else:
            self._send(404, "not found", "text/plain")

    def do_POST(self):
        if urlparse(self.path).path != "/api/chat":
            return self._send(404, "not found", "text/plain")
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            answer = run_agent(body["messages"], body.get("account_id", ""), body.get("mr_email", ""))
            self._json(200, {"answer": answer})
        except urllib.error.HTTPError as e:
            self._json(502, {"error": f"Snowflake {e.code}: {e.read().decode()[:500]}"})
        except Exception as e:  # noqa: BLE001 デモ用
            self._json(500, {"error": str(e)})


PAGE = r"""<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Field AI Assistant</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:-apple-system,"Hiragino Sans","Noto Sans JP",sans-serif;background:#fff;color:#0F172A;height:100vh;display:flex;flex-direction:column}
.top{display:flex;align-items:center;gap:8px;padding:10px 16px;border-bottom:1px solid #E2E8F0}
.logo{color:#29B5E8;font-weight:700;font-size:18px}.badge{background:#29B5E8;color:#fff;font-size:12px;padding:2px 6px;border-radius:4px}
.bar{display:flex;align-items:center;gap:10px;padding:10px 16px;border-bottom:1px solid #E2E8F0}
.icon{width:30px;height:30px;border-radius:8px;background:#0284C7;color:#fff;display:flex;align-items:center;justify-content:center;font-size:15px}
.name{font-weight:600}.chip{background:#F0F9FF;color:#0369A1;border:1px solid #BAE6FD;border-radius:999px;font-size:12px;padding:2px 10px}
.new{margin-left:auto;background:none;border:none;color:#475569;cursor:pointer;font-size:13px}
#log{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:12px}
.msg{max-width:88%;line-height:1.6;font-size:14px;word-wrap:break-word}
.bot{align-self:flex-start}.user{align-self:flex-end;background:#0284C7;color:#fff;padding:8px 14px;border-radius:16px 16px 4px 16px}
.bot table{border-collapse:collapse;margin:6px 0;font-size:13px}.bot td,.bot th{border:1px solid #E2E8F0;padding:4px 8px}.bot th{background:#F8FAFC}
.bot h1,.bot h2,.bot h3{font-size:15px;margin:10px 0 4px}.bot ul{margin:4px 0;padding-left:20px}
.chips{display:flex;flex-wrap:wrap;gap:6px}.chips button{border:1px solid #0284C7;color:#0284C7;background:#fff;border-radius:999px;padding:5px 12px;font-size:13px;cursor:pointer}
.typing{color:#94A3B8;font-size:13px}
form{display:flex;gap:8px;padding:12px 16px;border-top:1px solid #E2E8F0}
input{flex:1;border:1px solid #CBD5E1;border-radius:999px;padding:10px 16px;font-size:14px;outline:none}
.send{width:40px;height:40px;border-radius:50%;border:none;background:#0284C7;color:#fff;font-size:16px;cursor:pointer}.send:disabled{background:#94A3B8}
</style></head><body>
<div class="top"><span class="logo">&#10052; snowflake</span><span class="badge">cortex</span></div>
<div class="bar"><div class="icon">&#9776;</div><span class="name">Field AI Assistant</span><span class="chip" id="chip">読み込み中…</span>
<button class="new" id="new">&#9998; New</button></div>
<div id="log"></div>
<form id="f"><input id="q" placeholder="担当医師・エリア・訪問計画について質問…" autocomplete="off"><button class="send" id="send">&#10148;</button></form>
<script>
const qs = new URLSearchParams(location.search);
const ctx = {account_id: qs.get("account_id") || "", mr_email: qs.get("mr") || "", mr_name: qs.get("mr_name") || ""};
let history = [], hcpName = "先生";
const log = document.getElementById("log");

function esc(s){return s.replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));}
function inline(s){return s.replace(/\*\*(.+?)\*\*/g,"<b>$1</b>").replace(/`(.+?)`/g,"<code>$1</code>");}
function md(src){  // 最小限の Markdown（先に全体をエスケープしてから整形）
  const lines = esc(src).split("\n"); let out = [], i = 0;
  while (i < lines.length) {
    const l = lines[i];
    if (/^\s*\|/.test(l)) {
      const rows = []; while (i < lines.length && /^\s*\|/.test(lines[i])) rows.push(lines[i++]);
      const cells = r => r.trim().replace(/^\||\|$/g,"").split("|").map(c => inline(c.trim()));
      const body = rows.filter(r => !/^\s*\|[\s:\-|]+\|\s*$/.test(r));
      out.push("<table><tr>" + cells(body[0]).map(c=>"<th>"+c+"</th>").join("") + "</tr>" +
        body.slice(1).map(r => "<tr>" + cells(r).map(c=>"<td>"+c+"</td>").join("") + "</tr>").join("") + "</table>");
      continue;
    }
    if (/^\s*[-*] /.test(l)) {
      const items = []; while (i < lines.length && /^\s*[-*] /.test(lines[i])) items.push(inline(lines[i++].replace(/^\s*[-*] /,"")));
      out.push("<ul>" + items.map(x=>"<li>"+x+"</li>").join("") + "</ul>"); continue;
    }
    const h = l.match(/^(#{1,3}) (.*)/);
    if (h) out.push("<h3>" + inline(h[2]) + "</h3>");
    else if (/^-{3,}$/.test(l.trim())) out.push("<hr>");
    else if (l.trim()) out.push("<div>" + inline(l) + "</div>");
    i++;
  }
  return out.join("");
}
function add(role, html){const d=document.createElement("div");d.className="msg "+role;d.innerHTML=html;log.appendChild(d);log.scrollTop=log.scrollHeight;return d;}

function greet(){
  log.innerHTML = ""; history = [];
  const who = ctx.mr_name ? ctx.mr_name + "さん、" : "";
  add("bot", esc(`${who}${hcpName}のページを開いていますね。訪問準備、最近の処方傾向、話題のポイントなど、何をお手伝いしましょうか？`));
  const c = add("bot", ""); c.classList.add("chips");
  [`${hcpName}の訪問準備をして`, "直近12ヶ月の製品別実績は？", "最近の面談で出た懸念点は？"].forEach(t => {
    const b = document.createElement("button"); b.textContent = t; b.addEventListener("click", () => ask(t)); c.appendChild(b);
  });
}

async function ask(text){
  if (!text.trim()) return;
  add("user", esc(text)); history.push({role:"user", text});
  const t = add("bot typing", "回答を作成中…"); document.getElementById("send").disabled = true;
  try {
    const r = await fetch("/api/chat", {method:"POST", headers:{"Content-Type":"application/json"},
      body: JSON.stringify({messages: history, account_id: ctx.account_id, mr_email: ctx.mr_email})});
    const j = await r.json(); t.remove();
    if (j.error) { add("bot", esc("エラー: " + j.error)); history.pop(); }
    else { add("bot", md(j.answer)); history.push({role:"assistant", text:j.answer}); }
  } catch (e) { t.remove(); add("bot", esc("通信エラー: " + e)); history.pop(); }
  document.getElementById("send").disabled = false;
}

document.getElementById("f").addEventListener("submit", e => {e.preventDefault(); const q=document.getElementById("q"); ask(q.value); q.value="";});
document.getElementById("new").addEventListener("click", greet);

(async () => {
  const chip = document.getElementById("chip");
  try {
    const j = await (await fetch("/api/hcp?account_id=" + encodeURIComponent(ctx.account_id))).json();
    if (j.status === "FOUND") { hcpName = j.hcp_name + " 先生"; chip.textContent = j.hcp_name + " 先生"; chip.title = (j.hco_name||"") + " / " + (j.specialty||""); }
    else chip.textContent = "医師未選択";
  } catch (e) { chip.textContent = "医師未選択"; }
  greet();
})();
</script></body></html>"""

if __name__ == "__main__":
    print(f"http://localhost:{PORT}/?account_id=001JP00000HCP00010&mr=mr01@example.com")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
