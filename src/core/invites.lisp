;;;; invites.lisp — Invite link management

(defpackage :cl-stream.invites
  (:use :cl)
  (:export #:create-invite
           #:validate-invite
           #:use-invite
           #:revoke-invite
           #:list-invites))

(in-package :cl-stream.invites)

(defun generate-token ()
  (ironclad:byte-array-to-hex-string (ironclad:random-data 24)))

(defun create-invite (lobby-id created-by &key expires-in-seconds max-uses)
  "Create an invite link for LOBBY-ID. Returns the token."
  (let ((token (generate-token))
        (expires (when expires-in-seconds
                   (+ (get-universal-time) expires-in-seconds))))
    (cl-stream.db:execute
     "INSERT INTO invites (token, lobby_id, created_by, expires_at, max_uses) VALUES (?,?,?,?,?)"
     token lobby-id created-by expires max-uses)
    token))

(defun validate-invite (token)
  "Returns lobby-id if invite is valid, NIL if expired/exhausted/not found."
  (let ((row (car (cl-stream.db:query
                   "SELECT lobby_id, expires_at, max_uses, use_count FROM invites WHERE token = ?"
                   token))))
    (when row
      (destructuring-bind (lobby-id expires-at max-uses use-count) row
        (when (and (or (null expires-at) (> expires-at (get-universal-time)))
                   (or (null max-uses) (< use-count max-uses)))
          lobby-id)))))

(defun use-invite (token)
  "Increment use count. Call after successful join."
  (cl-stream.db:execute
   "UPDATE invites SET use_count = use_count + 1 WHERE token = ?" token))

(defun revoke-invite (token)
  (cl-stream.db:execute "DELETE FROM invites WHERE token = ?" token))

(defun list-invites (lobby-id)
  (cl-stream.db:query
   "SELECT token, expires_at, max_uses, use_count FROM invites WHERE lobby_id = ?"
   lobby-id))
