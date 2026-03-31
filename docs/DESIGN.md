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

1. **Build** — Install SBCL + Quicklisp + FFmpeg, load system, zero warnings
2. **Unit tests** — `(asdf:test-system :cl-stream)`, fast, in-process
3. **Integration tests** — Spin up real server (in-process), real SQLite (temp dir), mock FFmpeg

### Mock FFmpeg

A shell script `tests/mock-ffmpeg.sh` that:
- Accepts the same arguments as real FFmpeg
- Writes minimal valid DASH output (a few tiny segments + manifest)
- Exits 0 immediately

This makes integration tests fast and deterministic — no actual video encoding.

### E2E Tests (Playwright)

Browser-based tests against a running cl-stream server. Test scenarios built incrementally as features land:

- Auth flows (login, account creation, invite links)
- Upload + transcoding status polling + playback
- Watch party: join, play/pause/seek sync, chat

DASH fixture files (`tests/fixtures/`) are pre-transcoded minimal valid segments checked into the repo. E2E tests use fixtures, not live FFmpeg.

### Test File Layout

```
tests/
├── unit/
│   ├── auth-test.lisp          ; password hashing, sessions, invites
│   ├── dash-test.lisp          ; FFmpeg command generation
│   ├── lobby-test.lisp         ; lobby state machine
│   └── sync-test.lisp          ; WebSocket protocol, drift calc
├── integration/
│   ├── upload-flow-test.lisp   ; upload → transcode → ready
│   └── watch-party-test.lisp   ; lobby → invite → join → sync
├── e2e/
│   ├── auth.spec.ts            ; Playwright: login, registration, invites
│   ├── upload.spec.ts          ; Playwright: upload, playback
│   └── watch-party.spec.ts     ; Playwright: full lobby sync flow
├── fixtures/
│   └── test-video/             ; minimal DASH manifest + segments
├── mock-ffmpeg.sh              ; fake FFmpeg for integration tests
└── helpers.lisp                ; test utilities, server setup/teardown
```

---

## Architecture

```
Browser (upload) ──▶ POST /api/upload   ──▶ FFmpeg worker queue ──▶ DASH segments on disk
Browser (watch)  ──▶ GET /dash/<id>/    ──▶ Segment file server
Browser (lobby)  ──▶ WebSocket /ws      ──▶ Lobby coordinator
Admin browser    ──▶ POST /api/admin/   ──▶ User management
```

### Component Map

```
cl-stream/
├── src/
│   ├── config.lisp              ; config, startup, data dir init
│   ├── server.lisp              ; Hunchentoot setup, route table
│   ├── auth/
│   │   ├── accounts.lisp        ; users, passwords (bcrypt), roles
│   │   ├── sessions.lisp        ; session tokens, expiry
│   │   └── invites.lisp         ; invite link generation, validation
│   ├── storage/
│   │   ├── db.lisp              ; SQLite connection, migrations
│   │   ├── schema.sql           ; DDL
│   │   └── videos.lisp          ; video metadata CRUD
│   ├── dash/
│   │   └── transcoder.lisp      ; FFmpeg invocation, progress, queue
│   ├── web/
│   │   ├── upload.lisp          ; multipart upload handler
│   │   ├── dash-server.lisp     ; segment HTTP server, Range support
│   │   └── views.lisp           ; HTML generation (server-rendered)
│   └── watch-party/
│       ├── lobby.lisp           ; lobby state machine
│       └── websocket.lisp       ; WebSocket server, sync protocol, chat
├── static/
│   └── lobby.js                 ; WebSocket client, DASH player sync
├── tests/                       ; (see above)
├── docs/
│   └── DESIGN.md
├── cl-stream.asd
├── Dockerfile
├── docker-compose.yml
└── cl-stream.service            ; systemd unit
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
| `hunchentoot` | HTTP server |
| `websocket-driver` or `hunchensocket` | WebSocket server |
| `cl-sqlite` | SQLite database |
| `ironclad` | bcrypt password hashing |
| `uuid` | UUID generation |
| `cl-ppcre` | Regex for config parsing |
| `uiop` | Process invocation (FFmpeg), filesystem |

---

## Open Questions

1. **WebSocket library:** `hunchensocket` (Hunchentoot extension) vs `websocket-driver` (lower-level). Hunchensocket is simpler; websocket-driver is more flexible.

2. **HTML generation:** Inline string generation, `cl-who`, or `spinneret`. Spinneret is the modern choice (similar to Hiccup, composable).

3. **DASH player library:** `dash.js` (reference implementation, large) vs `Shaka Player` (Google, full-featured) vs `hls.js` (with DASH mode). All CDN-includable, no build step.

4. **Thumbnail extraction:** FFmpeg at upload time vs on-demand. At upload time is simpler; on-demand saves disk space for videos that are never viewed.
