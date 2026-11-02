#!/data/data/com.termux/files/usr/bin/env python3
# aish web — aish-க்கு browser chat screen. ~/aish.py அதே folder-ல இருக்கணும்.
# Run: python ~/aish_web.py   →   Chrome: http://localhost:8080
import json, os, sys, secrets, subprocess, threading
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
sys.path.insert(0, os.path.expanduser("~"))
import aish

PORT = int(os.environ.get("AISH_PORT", "8080"))
TOKEN = secrets.token_hex(16)
LOCK = threading.Lock()
S = {"messages": [], "pending": None, "note": "", "ui": []}
JOB = {"id": 0, "busy": False, "result": None}
KEY = None

def start(fn):
    JOB.update(id=JOB["id"] + 1, busy=True, result=None)
    jid = JOB["id"]
    def work():
        try:
            r = fn()
        except Exception as e:
            r = {"error": f"உள் பிழை: {e}"}
        with LOCK:
            if JOB["id"] == jid:
                JOB.update(busy=False, result=r)
                S["ui"].append({"t": "r", "r": r})
    threading.Thread(target=work, daemon=True).start()
    return {"job": jid}

def do_run(cmd):
    aish.log(f"RUN: {cmd}")
    code, out = aish.run(cmd)
    S["messages"].append({"role": "user", "content": f"Command: {cmd}\nExit code: {code}\n<output untrusted=\"true\">\n{out}\n</output>"})
    r = ai_step()
    r.update(output=out[-3000:] or "(output இல்லை)", code=code, ran=cmd)
    return r

def ai_step(depth=0):
    aish.trim(S["messages"])
    text = aish.ask(KEY, S["messages"])
    if text is None:
        if S["messages"] and S["messages"][-1]["role"] == "user":
            S["messages"].pop()
        S["pending"] = None
        return {"error": "AI பதில் தரல (limit அல்லது network). கொஞ்சம் கழிச்சு try பண்ணுங்க."}
    S["messages"].append({"role": "assistant", "content": text})
    st = aish.parse(text)
    cmd = (st.get("command") or "").strip()
    out = {"say": str(st.get("say", "")), "done": bool(st.get("done")) or not cmd}
    if out["done"]:
        S["pending"] = None
        return out
    if aish.blocked(cmd):
        S["messages"].append({"role": "user", "content": f"Safety filter blocked: {cmd}\nSuggest a safer alternative."})
        if depth < 1:
            r = ai_step(depth + 1)
            r["blocked"] = cmd
            return r
        S["pending"] = None
        return {"say": "⛔ ஆபத்தான command-ஐ block பண்ணிட்டேன். வேற மாதிரி கேளுங்க.", "done": True, "blocked": cmd}
    S["pending"] = cmd
    out.update(command=cmd, risk=aish.classify(cmd, st.get("risk", "caution")))
    return out

def storage():
    try:
        line = subprocess.run(["df", "-k", "/storage/emulated"], capture_output=True, text=True, timeout=10).stdout.splitlines()[1].split()
        size, used, avail = int(line[1]), int(line[2]), int(line[3])
        return {"size": size / 1048576, "used": used / 1048576, "avail": avail / 1048576}
    except Exception:
        return {}

def handle(path, d):
    if path == "/api/storage":
        return storage()
    if path == "/api/poll":
        return {"job": JOB["id"], "busy": JOB["busy"], "result": JOB["result"]}
    if path == "/api/history":
        return {"ui": S["ui"], "pending": S["pending"], "busy": JOB["busy"], "job": JOB["id"]}
    if path == "/api/reset":
        S.update(messages=[], pending=None, note="", ui=[])
        JOB.update(id=JOB["id"] + 1, busy=False, result=None)
        return {"ok": True}
    if JOB["busy"]:
        return {"error": "இன்னும் யோசிக்கிறேன், கொஞ்சம் பொறுங்க."}
    if path == "/api/ask":
        text = str(d.get("text", "")).strip()
        if not text:
            return {"error": "எதுவும் type பண்ணல."}
        if S["pending"]:
            S["note"] = f"(User skipped the previous command: {S['pending']})\n"
            S["pending"] = None
        S["messages"].append({"role": "user", "content": (S["note"] + text).strip()})
        S["note"] = ""
        S["ui"].append({"t": "me", "text": text})
        aish.log(f"TASK: {text}")
        return start(ai_step)
    if path == "/api/decide":
        if not S["pending"]:
            return {"error": "Run பண்ண command எதுவும் இல்ல."}
        action, cmd = d.get("action"), (str(d.get("cmd") or "").strip() or S["pending"])
        if action == "stop":
            S["note"] = f"(User stopped the previous task before running: {S['pending']})\n"
            S["pending"] = None
            r = {"say": "சரி, நிறுத்திட்டேன்.", "done": True}
            S["ui"].append({"t": "r", "r": r})
            return r
        if action == "skip":
            why = str(d.get("why", "")).strip()
            S["messages"].append({"role": "user", "content": f"User declined to run: {S['pending']}. {why}\nSuggest another way or ask what they want."})
            return start(ai_step)
        if action == "run":
            if aish.blocked(cmd):
                return {"error": "⛔ இந்த command ஆபத்தானது, run பண்ண முடியாது."}
            if aish.classify(cmd, "safe") == "danger" and d.get("confirm") != "yes":
                return {"confirm": cmd}
            S["pending"] = None
            return start(lambda: do_run(cmd))
    return {"error": "தெரியாத request."}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def ok_host(self):
        return self.headers.get("Host", "") in (f"localhost:{PORT}", f"127.0.0.1:{PORT}")

    def send(self, code, body, ctype="application/json"):
        b = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode()
        try:
            self.send_response(code)
            self.send_header("Content-Type", ctype + "; charset=utf-8")
            self.send_header("Content-Length", str(len(b)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(b)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        if not self.ok_host():
            return self.send(403, {"error": "forbidden"})
        if self.path == "/":
            return self.send(200, PAGE.replace("__TOKEN__", TOKEN).encode(), "text/html")
        self.send(404, {"error": "not found"})

    def do_POST(self):
        if not self.ok_host() or self.headers.get("X-Token") != TOKEN:
            return self.send(403, {"error": "forbidden"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
            d = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self.send(400, {"error": "bad request"})
        with LOCK:
            try:
                r = handle(self.path, d)
            except Exception as e:
                r = {"error": f"உள் பிழை: {e}"}
        self.send(200, r)

PAGE = r"""<!doctype html><html lang="ta"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>aish</title>
<style>
:root{--bg:#0f1420;--card:#1a2130;--line:#2a3345;--text:#e8ecf3;--mute:#8b95a8;--accent:#4ade80;--warn:#fbbf24;--bad:#f87171;--me:#2563eb}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.5 system-ui,"Noto Sans Tamil",sans-serif;height:100dvh;display:flex;flex-direction:column}
header{padding:12px 16px;border-bottom:1px solid var(--line);display:flex;align-items:center;gap:12px}
header b{font-size:18px}.gauge{flex:1}.bar{height:8px;background:var(--line);border-radius:4px;overflow:hidden}
.bar i{display:block;height:100%;background:var(--accent);width:0;transition:width .6s}.gl{font-size:12px;color:var(--mute);margin-top:4px}
header button{background:none;border:1px solid var(--line);color:var(--mute);border-radius:8px;padding:6px 10px;font-size:13px}
#chat{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:10px}
.m{max-width:88%;padding:10px 14px;border-radius:16px;white-space:pre-wrap;word-wrap:break-word}
.me{align-self:flex-end;background:var(--me);border-bottom-right-radius:4px}
.ai{align-self:flex-start;background:var(--card);border-bottom-left-radius:4px}
.sys{align-self:center;color:var(--mute);font-size:13px;text-align:center}.err{align-self:center;color:var(--bad);font-size:14px}
.card{align-self:flex-start;width:92%;background:var(--card);border:1px solid var(--line);border-left:4px solid var(--warn);border-radius:12px;padding:12px}
.card.safe{border-left-color:var(--accent)}.card.danger{border-left-color:var(--bad)}
.card code{display:block;background:#0b0f18;padding:8px 10px;border-radius:8px;font:13px ui-monospace,monospace;overflow-x:auto;white-space:pre-wrap;word-break:break-all;margin:6px 0 10px}
.tag{font-size:12px;font-weight:600}.safe .tag{color:var(--accent)}.caution .tag{color:var(--warn)}.danger .tag{color:var(--bad)}
.btns{display:flex;gap:8px;flex-wrap:wrap}.btns button{flex:1;min-width:70px;padding:9px;border-radius:10px;border:0;font-size:14px;font-weight:600}
.run{background:var(--accent);color:#052e12}.danger .run{background:var(--bad);color:#fff}.alt{background:var(--line);color:var(--text)}
.out{align-self:stretch;background:#0b0f18;border:1px solid var(--line);border-radius:10px;padding:10px;font:12px ui-monospace,monospace;white-space:pre-wrap;word-break:break-all;max-height:260px;overflow-y:auto;color:#cbd5e1}
.chips{display:flex;gap:8px;overflow-x:auto;padding:0 16px 8px}.chips button{white-space:nowrap;background:var(--card);border:1px solid var(--line);color:var(--text);border-radius:999px;padding:6px 12px;font-size:13px}
form{display:flex;gap:8px;padding:10px 16px 16px;border-top:1px solid var(--line)}
textarea{flex:1;resize:none;background:var(--card);color:var(--text);border:1px solid var(--line);border-radius:12px;padding:10px 12px;font:inherit;max-height:120px}
form button{background:var(--accent);color:#052e12;border:0;border-radius:12px;padding:0 18px;font-weight:700;font-size:18px}
.think{color:var(--mute);font-style:italic}.btns button:disabled{opacity:.4}
</style></head><body>
<header><b>🤖 aish</b><div class="gauge"><div class="bar"><i id="bar"></i></div><div class="gl" id="gl">Storage பார்க்கிறேன்…</div></div><button id="reset">புதுசா</button></header>
<div id="chat"><div class="sys">தமிழ்ல என்ன வேணும்னு கேளுங்க. ஒவ்வொரு command-ம் உங்க அனுமதியோட மட்டும்தான் ஓடும்.</div></div>
<div class="chips" id="chips"></div>
<form id="f"><textarea id="t" rows="1" placeholder="உதா: Download-ல பெரிய files எது?"></textarea><button>➤</button></form>
<script>
const T="__TOKEN__",chat=document.getElementById("chat"),t=document.getElementById("t");
const CHIPS=["phone-ல எவ்வளவு இடம் free-ஆ இருக்கு?","Download-ல பெரிய files எது?","WhatsApp எவ்வளவு இடம் எடுக்குது?","Movies folder-ல என்ன இருக்கு?","phone-ஐ ஆராய்ஞ்சு safe-ஆ delete பண்ணக்கூடியதை list போடு. எதையும் delete பண்ணாதே"];
async function api(p,d){try{const r=await fetch(p,{method:"POST",headers:{"Content-Type":"application/json","X-Token":T},body:JSON.stringify(d||{})});return await r.json()}catch(e){return{error:"Termux-ல aish_web ஓடுதான்னு பாருங்க."}}}
function add(cls,text){const e=document.createElement("div");e.className=cls;e.textContent=text;chat.appendChild(e);chat.scrollTop=chat.scrollHeight;return e}
let busy=false;
const sleep=ms=>new Promise(z=>setTimeout(z,ms));
async function wait(job){busy=true;const w=add("m ai think","யோசிக்கிறேன்…");
 while(true){await sleep(1500);const q=await api("/api/poll");
  if(q.error){w.remove();busy=false;add("err",q.error);return}
  if(q.job!==job){w.remove();busy=false;return}
  if(!q.busy&&q.result){w.remove();busy=false;show(q.result,true);return}}}
async function go(p,d){if(busy)return;busy=true;const r=await api(p,d);busy=false;if(r.job)return wait(r.job);show(r,true)}
function yes(){return(prompt("இது நிரந்தர மாற்றம். Run பண்ண yes என type பண்ணுங்க")||"").trim().toLowerCase()==="yes"?"yes":""}
function show(r,live){
 if(r.confirm){if(yes()){go("/api/decide",{action:"run",cmd:r.confirm,confirm:"yes"})}else card({command:r.confirm,risk:"danger"},true);return}
 if(r.ran){add("out","$ "+r.ran+"\n\n"+r.output);if(live)storage()}
 if(r.blocked)add("sys","⛔ Block பண்ணது: "+r.blocked);
 if(r.error){add("err",r.error);return}
 if(r.say)add("m ai",r.say);
 if(!r.done&&r.command)card(r,live);else if(live)storage();
}
function card(r,live){
 const risk=["safe","caution","danger"].includes(r.risk)?r.risk:"caution";
 const c=document.createElement("div");c.className="card "+risk;
 const tag=document.createElement("div");tag.className="tag";tag.textContent={safe:"🟢 பார்க்க மட்டும்",caution:"🟡 மாற்றம் செய்யும்",danger:"🔴 நிரந்தர மாற்றம்"}[risk];
 const code=document.createElement("code");code.textContent=r.command;
 const b=document.createElement("div");b.className="btns";
 const mk=(txt,cls,fn)=>{const x=document.createElement("button");x.textContent=txt;x.className=cls;x.onclick=()=>{if(busy)return;if(fn()!==false)c.querySelectorAll("button").forEach(y=>y.disabled=true)};b.appendChild(x)};
 mk(risk==="danger"?"⚠️ Run":"✅ Run","run",()=>{let ok="";if(risk==="danger"){ok=yes();if(!ok)return false}go("/api/decide",{action:"run",cmd:code.textContent,confirm:ok})});
 mk("✏️ மாத்து","alt",()=>{const n=prompt("Command-ஐ மாத்துங்க:",code.textContent);if(n&&n.trim()){code.textContent=n.trim()}return false});
 mk("❌ வேண்டாம்","alt",()=>{go("/api/decide",{action:"skip",why:prompt("ஏன் வேண்டாம்? (விருப்பம் இருந்தா)")||""})});
 mk("⏹ நிறுத்து","alt",()=>{go("/api/decide",{action:"stop"})});
 c.append(tag,code,b);if(!live)b.querySelectorAll("button").forEach(y=>y.disabled=true);chat.appendChild(c);chat.scrollTop=chat.scrollHeight;
}
async function restore(){const h=await api("/api/history");if(!h.ui)return;const n=h.ui.length;
 h.ui.forEach((e,i)=>{if(e.t==="me")add("m me",e.text);else show(e.r,i===n-1&&!h.busy&&!!h.pending&&e.r.command===h.pending)});
 if(h.busy)wait(h.job)}
async function storage(){const s=await api("/api/storage");if(!s.size)return;const pct=Math.round(s.used/s.size*100);const bar=document.getElementById("bar");bar.style.width=pct+"%";bar.style.background=pct>85?"var(--bad)":pct>70?"var(--warn)":"var(--accent)";document.getElementById("gl").textContent=s.avail.toFixed(1)+" GB free · "+pct+"% used · மொத்தம் "+s.size.toFixed(0)+" GB"}
function send(text){text=text.trim();if(!text||busy)return;add("m me",text);t.value="";go("/api/ask",{text})}
document.getElementById("f").onsubmit=e=>{e.preventDefault();send(t.value)};
t.addEventListener("keydown",e=>{if(e.key==="Enter"&&!e.shiftKey){e.preventDefault();send(t.value)}});
document.getElementById("reset").onclick=async()=>{await api("/api/reset");chat.innerHTML="";add("sys","புது உரையாடல் ஆரம்பம் 🙂")};
CHIPS.forEach(q=>{const x=document.createElement("button");x.textContent=q;x.onclick=()=>send(q);document.getElementById("chips").appendChild(x)});
storage();restore();
</script></body></html>"""

def main():
    global KEY
    KEY = aish.get_key()
    url = f"http://localhost:{PORT}"
    try:
        srv = ThreadingHTTPServer(("127.0.0.1", PORT), H)
    except OSError:
        print(aish.yellow(f"⚠️  aishweb ஏற்கனவே ஓடிக்கிட்டு இருக்கு. Chrome-ல {url} திறங்க."))
        print("   பழையதை நிறுத்திட்டு மறுபடி ஆரம்பிக்க:  pkill -f aish_web.py && aishweb")
        return
    print(aish.bold(aish.cyan("\n🤖 aish web ஓடுது")) + f"  ({aish.MODEL})")
    print(f"Chrome-ல திறங்க: {url}")
    print("நிறுத்த: Ctrl+C  (Termux-ஐ close பண்ணாதீங்க)\n")
    try:
        subprocess.Popen(["termux-open-url", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print(aish.green("\nபை! 👋"))

if __name__ == "__main__":
    main()
