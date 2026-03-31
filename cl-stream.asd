(defsystem :cl-stream
  :description "Self-hosted MPEG-DASH video platform with watch-together lobbies"
  :version "0.1.0"
  :license "MIT"
  :depends-on (:woo
               :lparallel
               :bordeaux-threads
               :websocket-driver
               :cl-sqlite
               :ironclad
               :uuid
               :cl-ppcre
               :uiop
               :jonathan   ; JSON
               :spinneret)  ; HTML generation
  :serial t
  :components
  ((:module "src/core"
    :serial t
    :components ((:file "config")
                 (:file "db")
                 (:file "users")
                 (:file "sessions")
                 (:file "invites")
                 (:file "videos")
                 (:file "transcoder")
                 (:file "lobbies")
                 (:file "sync")))
   (:module "src/web"
    :serial t
    :components ((:file "server")
                 (:file "routes")
                 (:file "websocket")
                 (:file "dash-server")
                 (:file "views")))
   (:module "src/cli"
    :serial t
    :components ((:file "cli")))))

(defsystem :cl-stream/tests
  :description "Test suite for cl-stream"
  :depends-on (:cl-stream :fiveam)
  :serial t
  :components
  ((:file "tests/helpers")
   (:module "tests/unit"
    :serial t
    :components ((:file "auth-test")
                 (:file "dash-test")
                 (:file "lobby-test")
                 (:file "sync-test")))
   (:module "tests/integration"
    :serial t
    :components ((:file "upload-flow-test")
                 (:file "watch-party-test")))))
