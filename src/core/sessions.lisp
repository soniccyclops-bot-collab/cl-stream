;;;; sessions.lisp — Session token management

(defpackage :cl-stream.sessions
  (:use :cl)
  (:export #:create-session
           #:validate-session
           #:delete-session
           #:cleanup-expired))

(in-package :cl-stream.sessions)

(defun generate-token ()
  "Generate a cryptographically random URL-safe token."
  (ironclad:byte-array-to-hex-string
   (ironclad:random-data 32)))

(defun create-session (user-id)
  "Create a session for USER-ID. Returns the token string."
  (let ((token (generate-token))
        (expires (+ (get-universal-time)
                    (cl-stream.config:config-session-ttl-seconds
                     cl-stream.config:*config*))))
    (cl-stream.db:execute
     "INSERT INTO sessions (token, user_id, expires_at) VALUES (?,?,?)"
     token user-id expires)
    token))

(defun validate-session (token)
  "Returns user-id if valid and not expired, NIL otherwise."
  (let ((row (car (cl-stream.db:query
                   "SELECT user_id, expires_at FROM sessions WHERE token = ?"
                   token))))
    (when (and row (> (second row) (get-universal-time)))
      (first row))))

(defun delete-session (token)
  (cl-stream.db:execute "DELETE FROM sessions WHERE token = ?" token))

(defun cleanup-expired ()
  (cl-stream.db:execute
   "DELETE FROM sessions WHERE expires_at < ?" (get-universal-time)))
