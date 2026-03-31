.PHONY: build test test-unit test-integration fixture clean

build:
	sbcl --noinform --non-interactive --eval '(ql:quickload :cl-stream)'

test: test-unit test-integration

test-unit:
	sbcl --noinform --non-interactive \
	  --eval '(ql:quickload :cl-stream/tests)' \
	  --eval '(fiveam:run! :auth-suite)' \
	  --eval '(fiveam:run! :dash-suite)' \
	  --eval '(fiveam:run! :lobby-suite)' \
	  --eval '(fiveam:run! :sync-suite)'

test-integration: fixture
	tests/integration/auth-flow.sh
	tests/integration/upload-flow.sh

fixture:
	@[ -f tests/fixtures/test-video.mp4 ] || \
	  ffmpeg -f lavfi -i testsrc=duration=5:size=320x240:rate=24 \
	         -f lavfi -i "sine=frequency=440:duration=5" \
	         -c:v libx264 -c:a aac tests/fixtures/test-video.mp4

clean:
	find . -name "*.fasl" -delete
	rm -f tests/fixtures/test-video.mp4
