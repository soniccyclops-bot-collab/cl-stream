;;;; auth-test.lisp — Unit tests for auth subsystem

(defpackage :cl-stream.test.auth
  (:use :cl :fiveam :cl-stream.test.helpers))

(in-package :cl-stream.test.auth)

(def-suite auth-suite :description "Auth unit tests")
(in-suite auth-suite)

(test create-and-authenticate-user
  (with-test-db
    (let ((user (cl-stream.users:create-user "alice" "s3cr3t")))
      (is (string= "alice" (cl-stream.users:user-username user)))
      (is (string= "user" (cl-stream.users:user-role user)))
      (let ((auth (cl-stream.users:authenticate "alice" "s3cr3t")))
        (is (not (null auth)))
        (is (string= "alice" (cl-stream.users:user-username auth))))
      (is (null (cl-stream.users:authenticate "alice" "wrongpass"))))))

(test duplicate-username-signals-error
  (with-test-db
    (cl-stream.users:create-user "bob" "pass")
    (signals error
      (cl-stream.users:create-user "bob" "otherpass"))))

(test session-create-and-validate
  (with-test-db
    (let* ((user (cl-stream.users:create-user "carol" "pass"))
           (token (cl-stream.sessions:create-session (cl-stream.users:user-id user))))
      (is (not (null token)))
      (is (string= (cl-stream.users:user-id user)
                   (cl-stream.sessions:validate-session token))))))

(test expired-session-returns-nil
  (with-test-db
    (let* ((user (cl-stream.users:create-user "dave" "pass"))
           (token (cl-stream.sessions:create-session (cl-stream.users:user-id user))))
      ;; Manually expire the session
      (cl-stream.db:execute "UPDATE sessions SET expires_at = 1 WHERE token = ?" token)
      (is (null (cl-stream.sessions:validate-session token))))))

(test invite-create-and-validate
  (with-test-db
    (let* ((user (cl-stream.users:create-user "eve" "pass"))
           (token (cl-stream.invites:create-invite "lobby-1"
                                                    (cl-stream.users:user-id user))))
      (is (string= "lobby-1" (cl-stream.invites:validate-invite token))))))

(test invite-max-uses
  (with-test-db
    (let* ((user (cl-stream.users:create-user "frank" "pass"))
           (token (cl-stream.invites:create-invite "lobby-2"
                                                    (cl-stream.users:user-id user)
                                                    :max-uses 2)))
      (cl-stream.invites:use-invite token)
      (cl-stream.invites:use-invite token)
      (is (null (cl-stream.invites:validate-invite token))))))
