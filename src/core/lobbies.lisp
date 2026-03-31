;;;; lobbies.lisp — Lobby (watch party room) state machine

(defpackage :cl-stream.lobbies
  (:use :cl)
  (:export #:create-lobby
           #:get-lobby
           #:close-lobby
           #:list-lobbies
           #:add-participant
           #:remove-participant
           #:lobby-participants
           #:lobby-id
           #:lobby-video-id
           #:lobby-state))

(in-package :cl-stream.lobbies)

;; In-memory store (lobbies are ephemeral — no persistence needed)
(defvar *lobbies* (make-hash-table :test 'equal))
(defvar *lobbies-lock* (bordeaux-threads:make-lock "lobbies"))

(defstruct lobby
  id name video-id host-id
  (state "waiting" :type string)   ; waiting / playing / paused / ended
  (position 0.0 :type float)       ; current playback position in seconds
  (state-updated-at 0 :type integer) ; universal-time when state last changed
  (participants (list)))

(defun create-lobby (video-id host-id name)
  (let ((id (format nil "~A" (uuid:make-v4-uuid))))
    (let ((lobby (make-lobby :id id :name name :video-id video-id :host-id host-id)))
      (bordeaux-threads:with-lock-held (*lobbies-lock*)
        (setf (gethash id *lobbies*) lobby)))
    id))

(defun get-lobby (id)
  (bordeaux-threads:with-lock-held (*lobbies-lock*)
    (gethash id *lobbies*)))

(defun close-lobby (id)
  (bordeaux-threads:with-lock-held (*lobbies-lock*)
    (remhash id *lobbies*)))

(defun list-lobbies ()
  (bordeaux-threads:with-lock-held (*lobbies-lock*)
    (loop for v being the hash-values of *lobbies* collect v)))

(defun add-participant (lobby-id participant)
  (bordeaux-threads:with-lock-held (*lobbies-lock*)
    (let ((lobby (gethash lobby-id *lobbies*)))
      (when lobby
        (pushnew participant (lobby-participants lobby) :test #'equal)))))

(defun remove-participant (lobby-id participant)
  (bordeaux-threads:with-lock-held (*lobbies-lock*)
    (let ((lobby (gethash lobby-id *lobbies*)))
      (when lobby
        (setf (lobby-participants lobby)
              (remove participant (lobby-participants lobby) :test #'equal))))))
