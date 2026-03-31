;;;; lobby-test.lisp — Unit tests for lobby state machine

(defpackage :cl-stream.test.lobby
  (:use :cl :fiveam))

(in-package :cl-stream.test.lobby)

(def-suite lobby-suite :description "Lobby state machine tests")
(in-suite lobby-suite)

(test create-and-get-lobby
  (let* ((id (cl-stream.lobbies:create-lobby "video-1" "user-1" "Test Lobby"))
         (lobby (cl-stream.lobbies:get-lobby id)))
    (is (not (null lobby)))
    (is (string= "video-1" (cl-stream.lobbies:lobby-video-id lobby)))
    (is (string= "waiting" (cl-stream.lobbies:lobby-state lobby)))))

(test add-and-remove-participants
  (let ((id (cl-stream.lobbies:create-lobby "video-2" "user-2" "Party")))
    (cl-stream.lobbies:add-participant id "user-a")
    (cl-stream.lobbies:add-participant id "user-b")
    (is (= 2 (length (cl-stream.lobbies:lobby-participants (cl-stream.lobbies:get-lobby id)))))
    (cl-stream.lobbies:remove-participant id "user-a")
    (is (= 1 (length (cl-stream.lobbies:lobby-participants (cl-stream.lobbies:get-lobby id)))))))
