;;;; db.lisp — SQLite connection and schema migrations

(defpackage :cl-stream.db
  (:use :cl)
  (:export #:*db*
           #:open-db
           #:close-db
           #:with-db
           #:migrate
           #:query
           #:execute))

(in-package :cl-stream.db)

(defvar *db* nil)

(defun open-db (&optional (path (cl-stream.config:data-dir "db" "cl-stream.sqlite3")))
  "Open or create the SQLite database."
  (ensure-directories-exist path)
  (setf *db* (sqlite:connect (namestring path)))
  (migrate)
  *db*)

(defun close-db ()
  (when *db*
    (sqlite:disconnect *db*)
    (setf *db* nil)))

(defmacro with-db ((db &optional path) &body body)
  `(let ((,db (open-db ,@(when path (list path)))))
     (unwind-protect (progn ,@body)
       (sqlite:disconnect ,db))))

(defun execute (sql &rest params)
  (apply #'sqlite:execute-non-query *db* sql params))

(defun query (sql &rest params)
  (apply #'sqlite:execute-to-list *db* sql params))

(defun migrate ()
  "Run schema migrations."
  (execute "PRAGMA journal_mode=WAL")
  (execute "PRAGMA foreign_keys=ON")
  (execute "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY)")
  (run-migration 1 "
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user',
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS videos (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      description TEXT,
      visibility TEXT NOT NULL DEFAULT 'private',
      status TEXT NOT NULL DEFAULT 'queued',
      duration_seconds REAL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS invites (
      token TEXT PRIMARY KEY,
      lobby_id TEXT NOT NULL,
      created_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER,
      max_uses INTEGER,
      use_count INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
    CREATE INDEX IF NOT EXISTS idx_videos_user ON videos(user_id);
    CREATE INDEX IF NOT EXISTS idx_invites_lobby ON invites(lobby_id);
  "))

(defun migration-applied-p (version)
  (not (null (query "SELECT 1 FROM schema_migrations WHERE version = ?" version))))

(defun run-migration (version sql)
  (unless (migration-applied-p version)
    ;; Execute each statement separately
    (dolist (stmt (split-sql sql))
      (let ((trimmed (string-trim '(#\Space #\Newline #\Return #\Tab) stmt)))
        (unless (string= trimmed "")
          (execute trimmed))))
    (execute "INSERT INTO schema_migrations VALUES (?)" version)))

(defun split-sql (sql)
  "Split SQL string on semicolons into individual statements."
  (cl-ppcre:split ";" sql))
