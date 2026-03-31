;;;; server.lisp — Woo HTTP server setup and route dispatch

(defpackage :cl-stream.web.server
  (:use :cl)
  (:export #:start
           #:stop))

(in-package :cl-stream.web.server)

(defvar *server* nil)

(defun start (&key (port (cl-stream.config:config-port cl-stream.config:*config*)))
  "Start the Woo HTTP server."
  (cl-stream.db:open-db)
  (cl-stream.transcoder:start-workers)
  (setf *server*
        (woo:run #'dispatch :port port :use-thread t))
  (format t "cl-stream listening on port ~A~%" port))

(defun stop ()
  (when *server*
    (woo:stop *server*)
    (setf *server* nil))
  (cl-stream.transcoder:stop-workers)
  (cl-stream.db:close-db))

(defun dispatch (env)
  "Route an incoming request to the appropriate handler."
  (let ((path (getf env :path-info))
        (method (getf env :request-method)))
    (cl-stream.web.routes:route method path env)))
