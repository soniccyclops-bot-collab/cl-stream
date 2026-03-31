;;;; sync.lisp — Playback sync state and protocol

(defpackage :cl-stream.sync
  (:use :cl)
  (:export #:apply-command
           #:current-position
           #:encode-state
           #:make-sync-state))

(in-package :cl-stream.sync)

(defstruct sync-state
  (action "paused" :type string)  ; "playing" or "paused"
  (position 0.0 :type float)
  (updated-at 0 :type integer))

(defun make-sync-state ()
  (make-sync-state%))

(defun current-position (state)
  "Compute current position accounting for elapsed time if playing."
  (if (string= (sync-state-action state) "playing")
      (+ (sync-state-position state)
         (- (get-universal-time) (sync-state-updated-at state)))
      (sync-state-position state)))

(defun apply-command (state command)
  "Apply a sync command (play/pause/seek) to the state. Returns new state."
  (let ((action (gethash "type" command))
        (position (gethash "position" command)))
    (cond
      ((string= action "play")
       (make-sync-state% :action "playing"
                         :position (or position (current-position state))
                         :updated-at (get-universal-time)))
      ((string= action "pause")
       (make-sync-state% :action "paused"
                         :position (or position (current-position state))
                         :updated-at (get-universal-time)))
      ((string= action "seek")
       (make-sync-state% :action (sync-state-action state)
                         :position (or position 0.0)
                         :updated-at (get-universal-time)))
      (t state))))

(defun encode-state (state)
  "Encode sync state as a plist for JSON serialization."
  (list :type "state"
        :action (sync-state-action state)
        :position (current-position state)
        :server-time (get-universal-time)))
