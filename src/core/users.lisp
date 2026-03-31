;;;; users.lisp — User account management

(defpackage :cl-stream.users
  (:use :cl)
  (:export #:create-user
           #:authenticate
           #:get-user
           #:get-user-by-username
           #:list-users
           #:delete-user
           #:user-id
           #:user-username
           #:user-role))

(in-package :cl-stream.users)

(defstruct user id username role)

(defun hash-password (password)
  (ironclad:pbkdf2-hash-password-to-combined-string
   (ironclad:ascii-string-to-byte-array password)
   :digest :sha256 :iterations 100000))

(defun verify-password (password hash)
  (ironclad:pbkdf2-check-password
   (ironclad:ascii-string-to-byte-array password) hash))

(defun create-user (username password &key (role "user"))
  "Create a new user. Returns the user struct or signals an error."
  (let ((id (format nil "~A" (uuid:make-v4-uuid)))
        (hash (hash-password password))
        (now (get-universal-time)))
    (handler-case
        (progn
          (cl-stream.db:execute
           "INSERT INTO users (id, username, password_hash, role, created_at) VALUES (?,?,?,?,?)"
           id username hash role now)
          (make-user :id id :username username :role role))
      (sqlite:sqlite-error (e)
        (error "Username '~A' already taken: ~A" username e)))))

(defun get-user (id)
  (let ((row (car (cl-stream.db:query
                   "SELECT id, username, role FROM users WHERE id = ?" id))))
    (when row (apply #'make-user :id (first row) :username (second row) :role (third row) nil))))

(defun get-user-by-username (username)
  (let ((row (car (cl-stream.db:query
                   "SELECT id, username, role FROM users WHERE username = ?" username))))
    (when row (make-user :id (first row) :username (second row) :role (third row)))))

(defun authenticate (username password)
  "Verify credentials. Returns user struct or NIL."
  (let ((row (car (cl-stream.db:query
                   "SELECT id, username, role, password_hash FROM users WHERE username = ?"
                   username))))
    (when (and row (verify-password password (fourth row)))
      (make-user :id (first row) :username (second row) :role (third row)))))

(defun list-users ()
  (mapcar (lambda (row)
            (make-user :id (first row) :username (second row) :role (third row)))
          (cl-stream.db:query "SELECT id, username, role FROM users ORDER BY username")))

(defun delete-user (id)
  (cl-stream.db:execute "DELETE FROM users WHERE id = ?" id))
