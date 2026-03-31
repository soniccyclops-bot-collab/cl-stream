;;;; websocket.lisp — WebSocket handler for lobby sync

(defpackage :cl-stream.web.websocket
  (:use :cl)
  (:export #:handle-connection))

(in-package :cl-stream.web.websocket)

(defun handle-connection (ws)
  "Handle a new WebSocket connection."
  (declare (ignore ws))
  ;; Stub — implemented in Phase 4
  nil)
