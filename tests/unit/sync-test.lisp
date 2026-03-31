;;;; sync-test.lisp — Unit tests for playback sync

(defpackage :cl-stream.test.sync
  (:use :cl :fiveam))

(in-package :cl-stream.test.sync)

(def-suite sync-suite :description "Playback sync tests")
(in-suite sync-suite)

(test initial-state-is-paused-at-zero
  (let ((s (cl-stream.sync:make-sync-state)))
    (is (string= "paused" (cl-stream.sync::sync-state-action s)))
    (is (= 0.0 (cl-stream.sync:current-position s)))))

(test play-command-changes-action
  (let* ((s (cl-stream.sync:make-sync-state))
         (cmd (let ((h (make-hash-table :test 'equal)))
                (setf (gethash "type" h) "play")
                (setf (gethash "position" h) 10.0)
                h))
         (new-s (cl-stream.sync:apply-command s cmd)))
    (is (string= "playing" (cl-stream.sync::sync-state-action new-s)))
    (is (= 10.0 (cl-stream.sync::sync-state-position new-s)))))
