#!/bin/bash
# Verify OpenRouter API connectivity and model availability.
#
# Usage: bash scripts/test-openrouter.sh [config-file]
#
# Reads API key and model from copilot-cat.json (or specified file).
# Tests: DNS, HTTPS, auth, model availability, chat completion.

set -euo pipefail

CONFIG="${1:-copilot-cat.json}"
FAILURES=0

ok()   { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo ""
echo "=== OpenRouter Connection Test ==="
echo ""

# --- Load config ---
if [ ! -f "$CONFIG" ]; then
  fail "Config file not found: $CONFIG"
  exit 1
fi
ok "Config: $CONFIG"

# Parse JSON with python (no jq dependency)
read_json() { python3 -c "import json,sys;d=json.load(open('$CONFIG'));print(d.get('$1','$2'))" 2>/dev/null; }

API_KEY=$(read_json openrouter_api_key "")
MODEL=$(read_json openrouter_model "openai/gpt-4o-mini")
BASE_URL=$(read_json openrouter_base_url "https://openrouter.ai/api/v1")

if [ -z "$API_KEY" ]; then
  API_KEY="${OPENROUTER_API_KEY:-}"
fi
if [ -z "$API_KEY" ]; then
  fail "No API key in config or OPENROUTER_API_KEY env var"
  exit 1
fi

ok "API key: ${API_KEY:0:12}..."
ok "Model:   $MODEL"
ok "URL:     $BASE_URL"

# --- Test 1: DNS ---
echo ""
echo "--- Test 1: DNS Resolution ---"
if ADDR=$(python3 -c "import socket; print(socket.gethostbyname('openrouter.ai'))" 2>/dev/null) && [ -n "$ADDR" ]; then
  ok "openrouter.ai -> $ADDR"
else
  fail "DNS resolution failed"
fi

# --- Test 2: HTTPS ---
echo ""
echo "--- Test 2: HTTPS Connectivity ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${BASE_URL}/models" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
  ok "HTTPS connection successful (HTTP $HTTP_CODE)"
else
  fail "HTTPS connection failed (timeout or network error)"
fi

# --- Test 3: Auth ---
echo ""
echo "--- Test 3: API Key Authentication ---"
AUTH_RESP=$(curl -s --max-time 10 \
  -H "Authorization: Bearer $API_KEY" \
  "${BASE_URL}/auth/key" 2>/dev/null)

AUTH_INFO=$(echo "$AUTH_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if 'data' in d and d['data']:
    label=d['data'].get('label','(none)')
    limit=d['data'].get('limit_remaining')
    lstr='unlimited' if limit is None else '\$'+str(limit)
    print(f'Label: {label}, Remaining: {lstr}')
else:
    sys.exit(1)
" 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$AUTH_INFO" ]; then
  ok "Auth valid. $AUTH_INFO"
else
  fail "Auth failed: $AUTH_RESP"
fi

# --- Test 4: Model ---
echo ""
echo "--- Test 4: Model Availability ---"
MODELS_RESP=$(curl -s --max-time 15 "https://openrouter.ai/api/v1/models" 2>/dev/null)

if echo "$MODELS_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
model='$MODEL'
m=next((x for x in d['data'] if x['id']==model),None)
if m:
    print(f'FOUND|{m[\"context_length\"]}|{m[\"pricing\"][\"prompt\"]}|{m[\"pricing\"][\"completion\"]}')
else:
    free=[x for x in d['data'] if ':free' in x['id']][:8]
    names='|'.join(x['id'] for x in free)
    print(f'NOTFOUND|{names}')
" 2>/dev/null | grep -q "^FOUND"; then
  INFO=$(echo "$MODELS_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
m=next(x for x in d['data'] if x['id']=='$MODEL')
print(f'{m[\"context_length\"]}|{m[\"pricing\"][\"prompt\"]}|{m[\"pricing\"][\"completion\"]}')
" 2>/dev/null)
  CTX=$(echo "$INFO" | cut -d'|' -f1)
  PPROMPT=$(echo "$INFO" | cut -d'|' -f2)
  PCOMPL=$(echo "$INFO" | cut -d'|' -f3)
  ok "Model found: $MODEL"
  ok "Context: $CTX tokens"
  ok "Pricing: \$$PPROMPT/prompt, \$$PCOMPL/completion"
else
  fail "Model not found: $MODEL"
  echo "       Available free models:"
  echo "$MODELS_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for x in d['data']:
    if ':free' in x['id']:
        print(f'         - {x[\"id\"]}')
" 2>/dev/null | head -8
fi

# --- Test 5: Chat ---
echo ""
echo "--- Test 5: Chat Completion ---"
if [ "$FAILURES" -gt 0 ]; then
  echo "  [SKIP] Skipping due to earlier failures"
else
  CHAT_RESP=$(curl -s --max-time 30 \
    -X POST "${BASE_URL}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -H "HTTP-Referer: https://github.com/copilot-cat" \
    -H "X-Title: Copilot Cat Test" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say meow in one word\"}],\"max_tokens\":20}" \
    2>/dev/null)

  RESULT=$(echo "$CHAT_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if 'choices' in d and d['choices']:
    c=d['choices'][0].get('message',{}).get('content','') or ''
    print(f'OK|{c.strip()[:80]}')
elif 'error' in d:
    print(f'ERR|{d[\"error\"][\"message\"]}')
else:
    print(f'ERR|Unexpected: {json.dumps(d)[:200]}')
" 2>/dev/null)

  if echo "$RESULT" | grep -q "^OK"; then
    REPLY=$(echo "$RESULT" | cut -d'|' -f2-)
    ok "Chat works! Response: \"$REPLY\""
  else
    ERR=$(echo "$RESULT" | cut -d'|' -f2-)
    fail "Chat error: $ERR"
  fi
fi

# --- Summary ---
echo ""
echo "============================================="
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed! OpenRouter is ready."
else
  echo "$FAILURES test(s) failed."
fi
echo "============================================="
exit "$FAILURES"
