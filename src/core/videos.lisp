;;;; videos.lisp — Video metadata CRUD

(defpackage :cl-stream.videos
  (:use :cl)
  (:export #:create-video
           #:get-video
           #:list-videos
           #:update-video-status
           #:update-video-metadata
           #:delete-video
           #:video-id
           #:video-status
           #:video-title))

(in-package :cl-stream.videos)

(defstruct video id user-id title description visibility status duration-seconds created-at)

(defun row->video (row)
  (make-video :id (first row)
              :user-id (second row)
              :title (third row)
              :description (fourth row)
              :visibility (fifth row)
              :status (sixth row)
              :duration-seconds (seventh row)
              :created-at (eighth row)))

(defun create-video (user-id title &key (visibility "private") description)
  (let ((id (format nil "~A" (uuid:make-v4-uuid)))
        (now (get-universal-time)))
    (cl-stream.db:execute
     "INSERT INTO videos (id, user_id, title, description, visibility, status, created_at)
      VALUES (?,?,?,?,?,'queued',?)"
     id user-id title description visibility now)
    id))

(defun get-video (id)
  (let ((row (car (cl-stream.db:query
                   "SELECT id,user_id,title,description,visibility,status,duration_seconds,created_at
                    FROM videos WHERE id=?" id))))
    (when row (row->video row))))

(defun list-videos (&key user-id visibility status)
  (let* ((conditions '("1=1"))
         (params '()))
    (when user-id
      (push "user_id=?" conditions)
      (push user-id params))
    (when visibility
      (push "visibility=?" conditions)
      (push visibility params))
    (when status
      (push "status=?" conditions)
      (push status params))
    (let ((sql (format nil
                       "SELECT id,user_id,title,description,visibility,status,duration_seconds,created_at
                        FROM videos WHERE ~A ORDER BY created_at DESC"
                       (format nil "~{~A~^ AND ~}" (reverse conditions)))))
      (mapcar #'row->video (apply #'cl-stream.db:query sql (reverse params))))))

(defun update-video-status (id status &optional duration-seconds)
  (if duration-seconds
      (cl-stream.db:execute
       "UPDATE videos SET status=?, duration_seconds=? WHERE id=?"
       status duration-seconds id)
      (cl-stream.db:execute "UPDATE videos SET status=? WHERE id=?" status id)))

(defun update-video-metadata (id &key title description visibility)
  (when title
    (cl-stream.db:execute "UPDATE videos SET title=? WHERE id=?" title id))
  (when description
    (cl-stream.db:execute "UPDATE videos SET description=? WHERE id=?" description id))
  (when visibility
    (cl-stream.db:execute "UPDATE videos SET visibility=? WHERE id=?" visibility id)))

(defun delete-video (id)
  (cl-stream.db:execute "DELETE FROM videos WHERE id=?" id))
