;;;; dash-server.lisp — Serve DASH manifest and segment files

(defpackage :cl-stream.web.dash-server
  (:use :cl)
  (:export #:serve))

(in-package :cl-stream.web.dash-server)

(defun serve (env path)
  "Serve a DASH file. PATH is like /dash/<video-id>/<file>"
  (declare (ignore env))
  (cl-ppcre:register-groups-bind (video-id file)
      ("^/dash/([^/]+)/(.+)$" path)
    (let* ((segments-dir (cl-stream.transcoder:segments-dir video-id))
           (file-path (merge-pathnames file segments-dir)))
      (if (probe-file file-path)
          (let ((mime (cond
                        ((cl-ppcre:scan "\\.mpd$" file) "application/dash+xml")
                        (t "video/mp4"))))
            `(200 (:content-type ,mime)
                  ,(uiop:read-file-string (namestring file-path))))
          '(404 (:content-type "text/plain") ("Segment not found"))))))
