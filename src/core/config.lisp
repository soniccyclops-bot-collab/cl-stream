;;;; config.lisp — Configuration and startup

(defpackage :cl-stream.config
  (:use :cl)
  (:export #:*config*
           #:config
           #:data-dir
           #:port
           #:allow-registration
           #:max-upload-bytes
           #:ffmpeg-path
           #:transcode-workers
           #:session-ttl-seconds
           #:init-data-dir))

(in-package :cl-stream.config)

(defstruct config
  (port 8080 :type integer)
  (data-dir (merge-pathnames ".cl-stream/" (user-homedir-pathname)) :type pathname)
  (allow-registration nil :type boolean)
  (max-upload-bytes (* 10 1024 1024 1024) :type integer)  ; 10GB
  (ffmpeg-path "ffmpeg" :type string)
  (transcode-workers 2 :type integer)
  (session-ttl-seconds (* 7 24 3600) :type integer))  ; 7 days

(defvar *config* (make-config))

(defun data-dir (&rest subdirs)
  "Return a pathname under the configured data directory."
  (reduce (lambda (path dir)
            (merge-pathnames (concatenate 'string dir "/") path))
          subdirs
          :initial-value (config-data-dir *config*)))

(defun init-data-dir ()
  "Create data directory structure if it does not exist."
  (dolist (subdir '("uploads" "segments" "db"))
    (ensure-directories-exist (data-dir subdir))))
