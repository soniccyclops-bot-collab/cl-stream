# cl-stream Design Document

## What Is cl-stream?

A self-hosted MPEG-DASH video streaming platform with synchronized watch-together lobbies. Written in Common Lisp. Single external dependency: FFmpeg.

**Core features:**
- Upload any video → FFmpeg generates multi-bitrate DASH segments
- Adaptive streaming (bitrate adjusts to viewer bandwidth)
- Real-time synchronized watch parties via WebSocket
- Flexible access: registered accounts, admin-created accounts, or anonymous via secure invite links
- Self-hosted: single binary + FFmpeg, runs anywhere

---

## Build Order (Non-Negotiable)

**CI and E2E infrastructure are built first, before any feature code.** Everything else is developed against the test harness. This is the explicit build order:

```
Phase 0 — CI + Test Harness     ← START HERE
Phase 1 — Core Server + Storage
Phase 2 — Auth
Phase 3 — Video Pipeline
Phase 4 — Watch Party
Phase 5 — Web UI
Phase 6 — Packaging
```

**Why Phase 0 first:** Without CI running from day one, every subsequent PR is a gamble. With it, every feature PR must pass unit + integration + E2E before merge. This catches regressions immediately and keeps the codebase shippable at all times.

---

## Phase 0: CI + Test Harness (Issues #13, #15, #16)

The foundation. Nothing else starts until this is in place.

### GitHub Actions CI (`.github/workflows/ci.yml`)

Three jobs, must all pass to merge:

1. **Build** — Install SBCL + Quicklisp + FFmpeg (`apt install ffmpeg`), load system, zero warnings
2. **Unit tests** — `(asdf:test-system :cl-stream)`, fast, in-process
3. **Integration tests** — Shell scripts via the CLI against a running server instance

### No Mock FFmpeg

FFmpeg runs for real in CI. The test video is a 5-10 second, 320x240 synthetic clip checked into `tests/fixtures/test-video.mp4`:

```bash
ffmpeg -f lavfi -i testsrc=duration=5:size=320x240:rate=24 \
       -f lavfi -i "sine=frequency=440:duration=5" \
       -c:v libx264 -c:a aac tests/fixtures/test-video.mp4
```

Transcodes in under 10 seconds on a CI runner. Same code path as production. No lies about what actually works.

### CLI-First E2E Architecture

The server exposes a full CLI for all business operations. This is the primary E2E testing surface — no browser required.

**Why:** Shell scripts + curl + websocat cover 90% of E2E value in <5 seconds total vs 30+ seconds for Playwright. The CLI is also the production admin interface.

```bash
# Start server
cl-stream server --port 9999 --data-dir /tmp/test-data &
SERVER_PID=$!; trap "kill $SERVER_PID" EXIT

# Drive all business logic via CLI
cl-stream users create alice alice-pass
VIDEO_ID=$(cl-stream videos upload tests/fixtures/test-video.mp4 \
           --title "Test" --user alice --json | jq -r .video_id)
cl-stream videos wait $VIDEO_ID --timeout 60
curl -f http://localhost:9999/dash/$VIDEO_ID/manifest.mpd

LOBBY_ID=$(cl-stream lobbies create $VIDEO_ID --name "Party" --json | jq -r .lobby_id)
websocat ws://localhost:9999/ws  # verify sync protocol
```

### Playwright Layer (Optional, Later)

Add Playwright only if visual player behavior needs verification (DASH adaptive bitrate switching, actual sync accuracy in browser). Not needed for core business logic coverage.

### Test File Layout

```
tests/
├── unit/
│   ├── auth-test.lisp          ; bcrypt, sessions, invite tokens
│   ├── dash-test.lisp          ; FFmpeg command args generation
│   ├── lobby-test.lisp         ; lobby state machine
│   └── sync-test.lisp          ; WebSocket protocol, drift calc
├── integration/
│   ├── upload-flow.sh          ; upload → transcode → ready (CLI + curl)
│   ├── auth-flow.sh            ; user create → login → session
│   └── watch-party-flow.sh     ; lobby → invite → join → sync (websocat)
├── fixtures/
│   └── test-video.mp4          ; 5s 320x240 synthetic video
└── helpers.lisp                ; unit test utilities, server setup/teardown
```

---

## Architecture

The architecture has three layers: a **core library** with pure business logic, and two thin **interface adapters** (web API and CLI) that call into it.

```
                ┌──────────────────────────────────────┐
                │           core library               │
                │                                      │
                │  users · videos · lobbies            │
                │  auth · transcoding · sync state     │
                │                                      │
                │  Zero knowledge of HTTP, sockets,    │
                │  or terminal I/O                     │
                └──────────────┬───────────────────────┘
                               │
               ┌───────────────┴────────────────┐
               │                                │
        ┌──────▼──────┐                  ┌──────▼──────┐
        │   Web API   │                  │     CLI     │
        │             │                  │             │
        │ Woo │                  │ SBCL argv   │
        │ WebSocket   │                  │ thin shell  │
        └─────────────┘                  └─────────────┘
               │                                │
               ▼                                ▼
     Browser / DASH player           Integration tests
     (HTTP + WebSocket)              (shell scripts, direct calls)
```

**Why this matters for testing:** Integration tests call the core library directly (or via CLI) — no HTTP stack, no WebSocket handshake, no browser. This tests the real business logic with maximum coverage and minimum complexity. The web API tests are a thin slice verifying routes map correctly. Playwright covers only what can't be tested any other way (actual browser player behavior).

### Component Map

```
cl-stream/
├── src/
│   ├── core/                    ← all business logic lives here
│   │   ├── config.lisp          ; configuration, data directory
│   │   ├── db.lisp              ; SQLite connection, migrations
│   │   ├── users.lisp           ; create-user, authenticate, roles
│   │   ├── sessions.lisp        ; session token generation/validation
│   │   ├── invites.lisp         ; invite link generation, validation
│   │   ├── videos.lisp          ; video metadata CRUD
│   │   ├── transcoder.lisp      ; FFmpeg invocation, progress, queue
│   │   ├── lobbies.lisp         ; lobby state machine (create/join/close)
│   │   └── sync.lisp            ; playback sync state, drift calc
│   ├── web/                     ← thin HTTP adapter over core
│   │   ├── server.lisp          ; Woo HTTP server setup, route table
│   │   ├── routes.lisp          ; HTTP handlers → core function calls
│   │   ├── websocket.lisp       ; WebSocket handler → core sync functions
│   │   ├── dash-server.lisp     ; DASH segment file serving
│   │   └── views.lisp           ; server-rendered HTML
│   └── cli/                     ← thin CLI adapter over core
│       └── cli.lisp             ; argument parsing → core function calls
├── static/
│   └── lobby.js                 ; WebSocket client, DASH player sync
├── tests/
│   ├── unit/                    ; core library functions in isolation
│   ├── integration/             ; core library functions end-to-end (no HTTP)
│   ├── web/                     ; HTTP route mapping (thin slice)
│   ├── fixtures/
│   │   └── test-video.mp4       ; 5s 320x240 synthetic video
│   └── helpers.lisp
├── docs/
│   └── DESIGN.md
├── cl-stream.asd
├── Dockerfile
├── docker-compose.yml
└── cl-stream.service
```

---

## HTTP API

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | Login → session token |
| POST | `/api/auth/logout` | Invalidate session |
| GET | `/api/auth/me` | Current user |
| POST | `/api/auth/register` | Self-registration (if enabled) |
| POST | `/api/admin/users` | Admin: create user |
| GET | `/api/admin/users` | Admin: list users |
| DELETE | `/api/admin/users/:id` | Admin: delete user |
| POST | `/api/upload` | Upload video (multipart, streaming) |
| GET | `/api/videos` | List videos (paginated) |
| GET | `/api/videos/:id/status` | Transcoding status |
| GET | `/api/videos/:id/info` | Video metadata |
| PATCH | `/api/videos/:id` | Update metadata |
| DELETE | `/api/videos/:id` | Delete video |
| GET | `/dash/:id/manifest.mpd` | DASH manifest |
| GET | `/dash/:id/:segment` | DASH segment |
| POST | `/api/lobbies` | Create lobby |
| GET | `/api/lobbies/:id` | Lobby info |
| DELETE | `/api/lobbies/:id` | Close lobby |
| POST | `/api/lobbies/:id/invite` | Generate invite link |
| WS | `/ws` | WebSocket connection |

---

## WebSocket Sync Protocol

The server holds **authoritative playback state**. Clients reconcile to server state, not each other.

### Client → Server

```json
{"type": "join", "lobby_id": "...", "token": "..."}
{"type": "play", "position": 42.5}
{"type": "pause", "position": 42.5}
{"type": "seek", "position": 120.0}
{"type": "chat", "message": "lol"}
{"type": "ping", "client_time": 1234567890.123}
```

### Server → Client

```json
{"type": "state", "action": "play|pause", "position": 42.5, "server_time": 1234567890.456}
{"type": "seek", "position": 120.0}
{"type": "chat", "from": "Alice", "message": "lol", "time": 1234567890}
{"type": "participant_joined", "name": "Bob"}
{"type": "participant_left", "name": "Bob"}
{"type": "pong", "server_time": 1234567890.456, "client_time": 1234567890.123}
{"type": "error", "code": "unauthorized", "message": "..."}
```

### Drift Compensation

Clients use `pong` latency measurements to estimate `server_now`. If player position drifts more than 2 seconds from expected, seek to correct position. For smaller drifts, adjust playback rate slightly (0.95x or 1.05x) to converge smoothly.

---

## FFmpeg Transcoding

### Multi-bitrate DASH output

```bash
ffmpeg -i <input> \
  -map 0:v -map 0:v -map 0:v -map 0:v -map 0:a \
  -b:v:0 4000k -s:v:0 1920x1080 -c:v:0 libx264 \
  -b:v:1 2000k -s:v:1 1280x720  -c:v:1 libx264 \
  -b:v:2 800k  -s:v:2 854x480   -c:v:2 libx264 \
  -b:v:3 400k  -s:v:3 640x360   -c:v:3 libx264 \
  -b:a:0 128k  -c:a:0 aac \
  -use_timeline 1 -use_template 1 \
  -seg_duration 4 \
  -adaptation_sets "id=0,streams=v id=1,streams=a" \
  -f dash data/segments/<video-id>/manifest.mpd
```

4-second segments, H.264/AAC, 4 video quality levels + audio.

### Worker Queue

- Configurable concurrency (default 2 workers)
- FIFO queue, status tracked per video in SQLite
- Progress parsing from FFmpeg stderr (`time=` field)
- On failure: status → `failed`, error message stored

---

## Database Schema (SQLite)

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  created_at INTEGER NOT NULL
);

CREATE TABLE sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at INTEGER NOT NULL
);

CREATE TABLE videos (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  visibility TEXT NOT NULL DEFAULT 'private',
  status TEXT NOT NULL DEFAULT 'queued',
  duration_seconds REAL,
  created_at INTEGER NOT NULL
);

CREATE TABLE invites (
  token TEXT PRIMARY KEY,
  lobby_id TEXT NOT NULL,
  created_by TEXT NOT NULL REFERENCES users(id),
  expires_at INTEGER,
  max_uses INTEGER,
  use_count INTEGER NOT NULL DEFAULT 0
);
```

---

## Configuration

```lisp
;; Library mode
(cl-stream:start
  :port 8080
  :data-dir "/var/cl-stream"
  :allow-registration nil          ; admin creates accounts by default
  :max-upload-bytes (* 10 1024 1024 1024)  ; 10GB
  :ffmpeg-path "/usr/bin/ffmpeg"
  :transcode-workers 2
  :session-ttl (* 7 24 3600))      ; 7 days
```

Environment variables override config (for Docker deployments).

---

## Dependencies

| Library | Purpose |
|---------|---------|
| `woo` | HTTP server |
| `websocket-driver` or `websocket-driver + woo` | WebSocket server |
| `cl-sqlite` | SQLite database |
| `ironclad` | bcrypt password hashing |
| `uuid` | UUID generation |
| `cl-ppcre` | Regex for config parsing |
| `uiop` | Process invocation (FFmpeg), filesystem |

---

## Open Questions

1. **WebSocket library:** `websocket-driver + woo` (Woo extension) vs `websocket-driver` (lower-level). Hunchensocket is simpler; websocket-driver is more flexible.

2. **HTML generation:** Inline string generation, `cl-who`, or `spinneret`. Spinneret is the modern choice (similar to Hiccup, composable).

3. **DASH player library:** `dash.js` (reference implementation, large) vs `Shaka Player` (Google, full-featured) vs `hls.js` (with DASH mode). All CDN-includable, no build step.

4. **Thumbnail extraction:** FFmpeg at upload time vs on-demand. At upload time is simpler; on-demand saves disk space for videos that are never viewed.
