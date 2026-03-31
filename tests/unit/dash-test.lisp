;;;; dash-test.lisp — Unit tests for FFmpeg command generation

(defpackage :cl-stream.test.dash
  (:use :cl :fiveam))

(in-package :cl-stream.test.dash)

(def-suite dash-suite :description "DASH transcoder unit tests")
(in-suite dash-suite)

(test ffmpeg-command-includes-required-args
  (let ((args (cl-stream.transcoder::ffmpeg-command
               #P"/tmp/input.mp4"
               #P"/tmp/output/")))
    ;; Must include -f dash
    (is (member "-f" args :test #'string=))
    (is (member "dash" args :test #'string=))
    ;; Must have adaptation sets
    (is (member "-adaptation_sets" args :test #'string=))
    ;; Must have 4 video streams + 1 audio
    (is (= 5 (count "-map" args :test #'string=)))))
