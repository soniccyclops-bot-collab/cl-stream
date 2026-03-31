;;;; cli.lisp — Command-line interface (thin adapter over core)

(defpackage :cl-stream.cli
  (:use :cl)
  (:export #:main))

(in-package :cl-stream.cli)

(defun main ()
  "Entry point for the cl-stream CLI binary."
  (let ((args (uiop:command-line-arguments)))
    (cond
      ((null args)
       (print-usage))
      ((string= (first args) "server")
       (run-server (rest args)))
      ((string= (first args) "users")
       (run-users (rest args)))
      ((string= (first args) "videos")
       (run-videos (rest args)))
      ((string= (first args) "lobbies")
       (run-lobbies (rest args)))
      (t
       (format t "Unknown command: ~A~%" (first args))
       (print-usage)
       (uiop:quit 1)))))

(defun print-usage ()
  (format t "Usage: cl-stream <command> [options]

Commands:
  server   --port N --data-dir PATH   Start the server
  users    create <username> <pass>   User management
  videos   upload <file> --title T    Video management
  lobbies  create <video-id> --name N Lobby management
"))

(defun run-server (args)
  (let ((port 8080)
        (data-dir nil))
    (loop for (flag val) on args by #'cddr do
      (cond ((string= flag "--port") (setf port (parse-integer val)))
            ((string= flag "--data-dir") (setf data-dir val))))
    (when data-dir
      (setf (cl-stream.config:config-data-dir cl-stream.config:*config*)
            (parse-namestring data-dir)))
    (cl-stream.config:init-data-dir)
    (cl-stream.web.server:start :port port)
    ;; Block until killed
    (loop (sleep 3600))))

(defun run-users (args)
  (cl-stream.db:open-db)
  (cond
    ((string= (first args) "create")
     (let ((user (cl-stream.users:create-user (second args) (third args)
                                              :role (or (find-flag "--role" args) "user"))))
       (format t "~A~%" (jonathan:to-json
                         (list :id (cl-stream.users:user-id user)
                               :username (cl-stream.users:user-username user)
                               :role (cl-stream.users:user-role user))))))
    ((string= (first args) "list")
     (dolist (u (cl-stream.users:list-users))
       (format t "~A ~A ~A~%"
               (cl-stream.users:user-id u)
               (cl-stream.users:user-username u)
               (cl-stream.users:user-role u)))))
  (cl-stream.db:close-db))

(defun run-videos (args)
  (cl-stream.db:open-db)
  (cond
    ((string= (first args) "list")
     (dolist (v (cl-stream.videos:list-videos))
       (format t "~A ~A ~A~%"
               (cl-stream.videos:video-id v)
               (cl-stream.videos:video-status v)
               (cl-stream.videos:video-title v))))
    ((string= (first args) "status")
     (let ((v (cl-stream.videos:get-video (second args))))
       (if v
           (format t "~A~%" (cl-stream.videos:video-status v))
           (format t "not found~%")))))
  (cl-stream.db:close-db))

(defun run-lobbies (args)
  (declare (ignore args))
  (format t "Lobby management coming in Phase 4~%"))

(defun find-flag (flag args)
  (let ((pos (position flag args :test #'string=)))
    (when pos (nth (1+ pos) args))))
