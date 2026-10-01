#!/usr/bin/env python3
"""
9Router local proxy — Realme 9i optimized.
- Runs in NEW Termux session:  python hermes-9i-router.py (listens 127.0.0.1:4000)
- Hermes points to it:  base_url http://127.0.0.1:4000/v1  provider: custom
- Auto-routes across OpenRouter :free models with fallback + 429 rotation.
- Stdlib only (no fastapi/litellm) = ~30MB RAM. Critical for 4GB phone.
Env:
  OPENROUTER_API_KEY  required (sk-or-v1-...)
  ROUTER_PORT         default 4000
  ROUTER_MODELS       comma list override, else models.txt
"""
import json, os, sys, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("ROUTER_PORT", "4000"))
API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
UPSTREAM = "https://openrouter.ai/api/v1/chat/completions"

def load_models():
    env = os.environ.get("ROUTER_MODELS", "").strip()
    if env:
        return [m.strip() for m in env.split(",") if m.strip()]
    p = os.path.join(os.path.dirname(__file__), "models.txt")
    models = []
    if os.path.exists(p):
        for line in open(p):
            line = line.strip()
            if line and not line.startswith("#"):
                models.append(line.split()[0])
    if not models:
        models = [
            "qwen/qwen3-235b-a22b:free",
            "deepseek/deepseek-chat-v3.1:free",
            "google/gemini-2.0-flash-exp:free",
            "meta-llama/llama-3.3-70b-instruct:free",
        ]
    return models

MODELS = load_models()

def forward(payload, model):
    payload = dict(payload)
    payload["model"] = model
    data = json.dumps(payload).encode()
    req = urllib.request.Request(UPSTREAM, data=data, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
        "HTTP-Referer": "http://localhost/hermes-9i",
        "X-Title": "hermes-9i-router",
    }, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return 502, json.dumps({"error": str(e)}).encode()

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):  # quiet, save CPU
        pass
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
    def do_OPTIONS(self):
        self.send_response(200); self._cors(); self.end_headers()
    def do_GET(self):
        if self.path in ("/", "/health", "/v1/models"):
            body = json.dumps({"status": "ok", "models": MODELS}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self._cors(); self.end_headers(); self.wfile.write(body)
        else:
            self.send_response(404); self.end_headers()
    def do_POST(self):
        if self.path not in ("/v1/chat/completions", "/chat/completions"):
            self.send_response(404); self.end_headers(); return
        if not API_KEY:
            self.send_response(500)
            self.send_header("Content-Type", "application/json"); self.end_headers()
            self.wfile.write(json.dumps({"error": "Set OPENROUTER_API_KEY first. export OPENROUTER_API_KEY=sk-or-..."}).encode())
            return
        n = int(self.headers.get("Content-Length", 0))
        try:
            payload = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            payload = {}
        last_code, last_body = 500, b"{}"
        # auto-route: try requested model first if :free, else chain
        req_model = payload.get("model", "")
        chain = ([req_model] if req_model and req_model in MODELS else []) + [m for m in MODELS if m != req_model]
        for m in chain:
            code, body = forward(payload, m)
            if code == 200:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self._cors(); self.end_headers(); self.wfile.write(body)
                return
            # rotate only on rate-limit / overload / bad gateway
            if code in (429, 502, 503, 529):
                last_code, last_body = code, body
                continue
            else:  # hard error (401/400) — return immediately
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self._cors(); self.end_headers(); self.wfile.write(body)
                return
        self.send_response(last_code if isinstance(last_code, int) else 502)
        self.send_header("Content-Type", "application/json")
        self._cors(); self.end_headers(); self.wfile.write(last_body)

if __name__ == "__main__":
    print(f"[9router] {len(MODELS)} free models, port {PORT}", flush=True)
    for m in MODELS: print(f"  - {m}", flush=True)
    if not API_KEY: print("[9router] WARNING: OPENROUTER_API_KEY not set", flush=True)
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()
