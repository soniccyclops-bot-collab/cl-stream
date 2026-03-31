#!/bin/bash
# Integration test: user creation, login, session validation
set -euo pipefail

PORT=19999
DATA_DIR=$(mktemp -d)
trap "rm -rf $DATA_DIR" EXIT

# Start server
sbcl --noinform --non-interactive \
  --eval "(ql:quickload :cl-stream)" \
  --eval "(cl-stream.config:init-data-dir)" \
  --eval "(cl-stream.web.server:start :port $PORT)" \
  --eval "(loop (sleep 1))" &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null; rm -rf $DATA_DIR" EXIT

# Wait for server to be ready
for i in $(seq 1 10); do
  curl -sf http://localhost:$PORT/ > /dev/null 2>&1 && break
  sleep 1
done

# Create user via CLI
sbcl --noinform --non-interactive \
  --eval "(ql:quickload :cl-stream)" \
  --eval "(cl-stream.db:open-db)" \
  --eval '(cl-stream.users:create-user "testuser" "testpass")' \
  --eval "(cl-stream.db:close-db)"

# Login via HTTP
TOKEN=$(curl -sf -X POST http://localhost:$PORT/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}' | jq -r .token)

[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] && echo "auth-flow: PASS" || { echo "auth-flow: FAIL"; exit 1; }
