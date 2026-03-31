;;;; routes.lisp — HTTP route table (thin adapter over core)

(defpackage :cl-stream.web.routes
  (:use :cl)
  (:export #:route))

(in-package :cl-stream.web.routes)

(defun route (method path env)
  "Dispatch METHOD + PATH to handler. Returns CLACK response list."
  (handler-case
      (cond
        ;; Auth
        ((and (equal method "POST") (equal path "/api/auth/login"))
         (cl-stream.web.routes/auth:login env))
        ((and (equal method "POST") (equal path "/api/auth/logout"))
         (cl-stream.web.routes/auth:logout env))
        ((and (equal method "GET") (equal path "/api/auth/me"))
         (cl-stream.web.routes/auth:me env))

        ;; Videos
        ((and (equal method "POST") (equal path "/api/upload"))
         (cl-stream.web.routes/videos:upload env))
        ((and (equal method "GET") (cl-ppcre:scan "^/api/videos$" path))
         (cl-stream.web.routes/videos:list-videos env))

        ;; DASH segments
        ((cl-ppcre:scan "^/dash/" path)
         (cl-stream.web.dash-server:serve env path))

        ;; Web UI
        ((equal path "/")
         (cl-stream.web.views:index env))

        (t '(404 (:content-type "text/plain") ("Not Found"))))
    (error (e)
      `(500 (:content-type "text/plain") (,(format nil "Internal error: ~A" e))))))
