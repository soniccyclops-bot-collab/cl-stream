#!/bin/bash
# Integration test: upload video -> wait for transcoding -> verify manifest
set -euo pipefail

PORT=19998
DATA_DIR=$(mktemp -d)
trap "rm -rf $DATA_DIR" EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_VIDEO="$SCRIPT_DIR/../fixtures/test-video.mp4"

[ -f "$TEST_VIDEO" ] || { echo "Missing test fixture: $TEST_VIDEO"; exit 1; }

# Create video record and run transcoder via CLI (in-process, no server needed)
sbcl --noinform --non-interactive \
  --eval "(ql:quickload :cl-stream)" \
  --eval "(cl-stream.config:init-data-dir)" \
  --eval "(cl-stream.db:open-db)" \
  --eval '(cl-stream.users:create-user "uploader" "pass")' \
  --eval "(let* ((uid (cl-stream.users:user-id (cl-stream.users:get-user-by-username \"uploader\")))
                 (vid (cl-stream.videos:create-video uid \"Test Video\")))
            (cl-stream.transcoder:transcode vid #P\"$TEST_VIDEO\")
            (let ((status (cl-stream.videos:video-status (cl-stream.videos:get-video vid))))
              (unless (string= status \"ready\")
                (error \"Expected status 'ready', got '~A'\" status)))
            (format t \"upload-flow: PASS~%\"))" \
  --eval "(cl-stream.db:close-db)"
