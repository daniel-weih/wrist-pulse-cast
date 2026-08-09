.PHONY: generate open clean

generate:
	@command -v xcodegen >/dev/null || { echo "xcodegen not found. Install it with: brew install xcodegen"; exit 1; }
	xcodegen generate

open:
	open PulseCast.xcodeproj

clean:
	rm -rf PulseCast.xcodeproj
