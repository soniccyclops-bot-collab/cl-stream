;;;; transcoder.lisp — FFmpeg transcoding worker queue

(defpackage :cl-stream.transcoder
  (:use :cl)
  (:export #:start-workers
           #:stop-workers
           #:enqueue
           #:segments-dir))

(in-package :cl-stream.transcoder)

(defvar *kernel* nil)
(defvar *queue* nil)

(defun segments-dir (video-id)
  (cl-stream.config:data-dir "segments" video-id))

(defun ffmpeg-command (input-path output-dir)
  "Build the FFmpeg argument list for multi-bitrate DASH output."
  (let ((manifest (merge-pathnames "manifest.mpd" output-dir)))
    (list (cl-stream.config:config-ffmpeg-path cl-stream.config:*config*)
          "-i" (namestring input-path)
          "-map" "0:v" "-map" "0:v" "-map" "0:v" "-map" "0:v" "-map" "0:a"
          "-b:v:0" "4000k" "-s:v:0" "1920x1080" "-c:v:0" "libx264"
          "-b:v:1" "2000k" "-s:v:1" "1280x720"  "-c:v:1" "libx264"
          "-b:v:2" "800k"  "-s:v:2" "854x480"   "-c:v:2" "libx264"
          "-b:v:3" "400k"  "-s:v:3" "640x360"   "-c:v:3" "libx264"
          "-b:a:0" "128k"  "-c:a:0" "aac"
          "-use_timeline" "1" "-use_template" "1"
          "-seg_duration" "4"
          "-adaptation_sets" "id=0,streams=v id=1,streams=a"
          "-f" "dash"
          (namestring manifest))))

(defun transcode (video-id input-path)
  "Run FFmpeg and update video status. Blocking."
  (let* ((output-dir (ensure-directories-exist (segments-dir video-id)))
         (args (ffmpeg-command input-path output-dir)))
    (cl-stream.videos:update-video-status video-id "transcoding")
    (handler-case
        (let ((process (uiop:launch-program args :output :stream :error-output :stream)))
          (uiop:wait-process process)
          (let ((code (uiop:process-info-exit-code process)))
            (if (zerop code)
                (cl-stream.videos:update-video-status video-id "ready")
                (progn
                  (cl-stream.videos:update-video-status video-id "failed")
                  (error "FFmpeg exited with code ~A" code)))))
      (error (e)
        (cl-stream.videos:update-video-status video-id "failed")
        (format *error-output* "Transcoding error for ~A: ~A~%" video-id e)))))

(defun start-workers ()
  "Start the lparallel worker kernel for transcoding."
  (let ((n (cl-stream.config:config-transcode-workers cl-stream.config:*config*)))
    (setf *kernel* (lparallel:make-kernel n :name "transcoder"))
    (setf *queue* (lparallel:make-queue))
    (lparallel:submit-task
     (lparallel:make-channel)
     (lambda ()
       (loop
         (let ((task (lparallel:pop-queue *queue*)))
           (when (eq task :stop) (return))
           (destructuring-bind (video-id input-path) task
             (transcode video-id input-path))))))))

(defun stop-workers ()
  (when *queue*
    (lparallel:push-queue :stop *queue*))
  (when *kernel*
    (lparallel:end-kernel :wait t)
    (setf *kernel* nil *queue* nil)))

(defun enqueue (video-id input-path)
  "Queue a video for transcoding."
  (lparallel:push-queue (list video-id input-path) *queue*))
