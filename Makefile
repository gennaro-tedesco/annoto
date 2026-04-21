.PHONY: emulator run build supabase_deploy

APP_VERSION := $(shell tag=$$(git describe --tags --exact-match 2>/dev/null || true); if [ -n "$$tag" ]; then printf '%s' "$$tag"; else git rev-parse --short HEAD; fi)
BUILD_NUMBER := $(shell git rev-list --count HEAD)

emulator:
	emulator -avd pixel_7_large -partition-size 4096 -no-snapshot-load -scale 1.5

run:
	flutter run --dart-define-from-file=config.json

build:
	flutter build apk --release --split-per-abi --target-platform android-arm64 --build-number=$(BUILD_NUMBER) --dart-define=APP_VERSION=$(APP_VERSION) --dart-define-from-file=config.json

SUPABASE_PROJECT_REF := $(shell jq -r '.SUPABASE_PROJECT_REF' config.json)

supabase_deploy:
	supabase functions deploy extract-pgn --no-verify-jwt --project-ref $(SUPABASE_PROJECT_REF)
