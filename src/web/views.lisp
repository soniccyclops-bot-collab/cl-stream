;;;; views.lisp — Server-rendered HTML views

(defpackage :cl-stream.web.views
  (:use :cl)
  (:export #:index))

(in-package :cl-stream.web.views)

(defun index (env)
  (declare (ignore env))
  '(200 (:content-type "text/html")
    ("<html><body><h1>cl-stream</h1><p>Coming soon.</p></body></html>")))
