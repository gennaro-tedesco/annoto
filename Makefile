.PHONY: emulator run build supabase_deploy

APP_VERSION := $(shell tag=$$(git describe --tags --exact-match 2>/dev/null || true); if [ -n "$$tag" ]; then printf '%s' "$$tag"; else git rev-parse --short HEAD; fi)
BUILD_NUMBER := $(shell git rev-list --count HEAD)

emulator:
	emulator -avd pixel_7 -no-snapshot-load -scale 1.5

run:
	flutter run --dart-define-from-file=config.json

build:
	flutter build apk --release --target-platform android-arm64 --build-number=$(BUILD_NUMBER) --dart-define=APP_VERSION=$(APP_VERSION) --dart-define-from-file=config.json

supabase_deploy:
	@if [ ! -f "supabase/.temp/project-ref" ]; then echo "supabase/.temp/project-ref not found"; exit 1; fi
	supabase functions deploy extract-items --project-ref "$$(tr -d '\n' < supabase/.temp/project-ref)" --no-verify-jwt
