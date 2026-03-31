# cl-stream

Self-hosted MPEG-DASH video streaming platform with synchronized watch-together lobbies. Written in Common Lisp.

**Single external dependency:** [FFmpeg](https://ffmpeg.org/) for video transcoding.

## Features

- **Upload & transcode** — upload any video, FFmpeg generates multi-bitrate DASH segments automatically
- **Adaptive streaming** — MPEG-DASH with multiple quality levels (480p, 720p, 1080p), bitrate adapts to viewer bandwidth
- **Watch-together lobbies** — real-time synchronized playback via WebSockets; all viewers stay in sync
- **Flexible access control** — registered accounts, admin-created accounts, or anonymous join via secure invite links
- **Self-hosted** — single binary + FFmpeg, runs on your server

## Quick Start

```bash
# Requirements: SBCL, Quicklisp, FFmpeg
(ql:quickload :cl-stream)
(cl-stream:start :port 8080 :data-dir "/var/cl-stream")
```

## Architecture

```
Browser (upload) ──▶ HTTP Upload ──▶ FFmpeg transcoder ──▶ DASH segments on disk
Browser (watch)  ──▶ DASH player  ──▶ HTTP segment server
Browser (lobby)  ──▶ WebSocket    ──▶ Lobby coordinator (sync, chat)
```

## License

MIT
