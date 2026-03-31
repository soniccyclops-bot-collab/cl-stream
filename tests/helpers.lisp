;;;; helpers.lisp — Test utilities

(defpackage :cl-stream.test.helpers
  (:use :cl :fiveam)
  (:export #:with-test-db
           #:with-test-server))

(in-package :cl-stream.test.helpers)

(defmacro with-test-db (&body body)
  "Run BODY with a fresh in-memory SQLite database."
  `(let ((cl-stream.db:*db* nil))
     (sqlite:with-open-database (cl-stream.db:*db* ":memory:")
       (cl-stream.db:migrate)
       ,@body)))

(defmacro with-test-server ((port) &body body)
  "Run BODY with a test server on PORT."
  `(let* ((cl-stream.config:*config*
           (cl-stream.config:make-config :port ,port
                                         :data-dir (uiop:ensure-temporary-file)))
          (server nil))
     (unwind-protect
         (progn
           (cl-stream.config:init-data-dir)
           (setf server (cl-stream.web.server:start :port ,port))
           ,@body)
       (when server (cl-stream.web.server:stop)))))
