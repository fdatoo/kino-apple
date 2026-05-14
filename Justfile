set shell := ["sh", "-cu"]

default:
	just --list

setup:
	git config core.hooksPath .githooks
	xcode_path="$(xcode-select -p 2>/dev/null)" || { echo "setup: xcode-select -p failed; install or select Xcode" >&2; exit 1; }; \
	echo "setup: xcode-select $xcode_path"
	swift_version="$(swift --version 2>/dev/null | sed -n '1p')" || { echo "setup: swift --version failed; install Swift 6.x" >&2; exit 1; }; \
	case "$swift_version" in \
		*"Swift version 6."*) ;; \
		*) echo "setup: Swift 6.x required; found $swift_version" >&2; exit 1 ;; \
	esac; \
	echo "setup: $swift_version"

build:
	if [ -f Packages/KinoKit/Package.swift ]; then \
		echo "build: KinoKit"; \
		swift build --package-path Packages/KinoKit; \
	else \
		echo "build: skipping KinoKit (no KinoKit yet)"; \
	fi
	build_app() { \
		name="$1"; \
		destination="$2"; \
		project="Apps/$name/$name.xcodeproj"; \
		if [ -d "$project" ]; then \
			echo "build: $name"; \
			xcodebuild build -project "$project" -scheme "$name" -destination "$destination" -quiet CODE_SIGNING_ALLOWED=NO; \
		else \
			echo "build: skipping $name (no Xcode project yet)"; \
		fi; \
	}; \
	build_app Kino-iOS "generic/platform=iOS Simulator"; \
	build_app Kino-tvOS "generic/platform=tvOS Simulator"; \
	build_app Kino-macOS "platform=macOS"

test:
	if [ -f Packages/KinoKit/Package.swift ]; then \
		echo "test: KinoKit"; \
		swift test --package-path Packages/KinoKit; \
	else \
		echo "test: skipping KinoKit (no KinoKit yet)"; \
	fi
	has_scheme() { \
		xcodebuild -list -project "$1" 2>/dev/null | awk -v scheme="$2" '{$1=$1} $0 == scheme { found=1 } END { exit found ? 0 : 1 }'; \
	}; \
	test_app() { \
		name="$1"; \
		destination="$2"; \
		project="Apps/$name/$name.xcodeproj"; \
		if [ ! -d "$project" ]; then \
			echo "test: skipping $name (no Xcode project yet)"; \
		elif has_scheme "$project" "$name"; then \
			echo "test: $name"; \
			xcodebuild test -project "$project" -scheme "$name" -destination "$destination" -quiet CODE_SIGNING_ALLOWED=NO; \
		else \
			echo "test: skipping $name (no test scheme yet)"; \
		fi; \
	}; \
	test_app Kino-iOS "platform=iOS Simulator,name=iPhone 17,OS=latest"; \
	test_app Kino-tvOS "platform=tvOS Simulator,name=Apple TV,OS=latest"; \
	if [ -d Apps/Kino-macOS/Kino-macOS.xcodeproj ]; then \
		echo "test: Kino-macOS (build-for-testing only — unsigned mac UI test runners are Gatekeeper-blocked on launch)"; \
		xcodebuild build-for-testing -project Apps/Kino-macOS/Kino-macOS.xcodeproj -scheme Kino-macOS -destination "platform=macOS" -quiet CODE_SIGNING_ALLOWED=NO; \
	else \
		echo "test: skipping Kino-macOS (no Xcode project yet)"; \
	fi

fmt:
	dirs=""; \
	for dir in Packages Apps; do \
		if [ -d "$dir" ]; then dirs="$dirs $dir"; fi; \
	done; \
	if [ -z "$dirs" ]; then \
		echo "fmt: skipping (no Swift source directories yet)"; \
	elif [ -z "$(find $dirs -type f -name '*.swift' -print -quit)" ]; then \
		echo "fmt: skipping (no Swift files yet)"; \
	else \
		swift format --in-place --recursive $dirs; \
	fi

fmt-check:
	dirs=""; \
	for dir in Packages Apps; do \
		if [ -d "$dir" ]; then dirs="$dirs $dir"; fi; \
	done; \
	if [ -z "$dirs" ]; then \
		echo "fmt-check: skipping (no Swift source directories yet)"; \
	elif [ -z "$(find $dirs -type f -name '*.swift' -print -quit)" ]; then \
		echo "fmt-check: skipping (no Swift files yet)"; \
	else \
		swift format lint --strict --recursive $dirs; \
	fi

lint:
	dirs=""; \
	for dir in Packages Apps; do \
		if [ -d "$dir" ]; then dirs="$dirs $dir"; fi; \
	done; \
	if [ -z "$dirs" ]; then \
		echo "lint: skipping (no Swift source directories yet)"; \
	elif [ -z "$(find $dirs -type f -name '*.swift' -print -quit)" ]; then \
		echo "lint: skipping (no Swift files yet)"; \
	else \
		swift format lint --strict --recursive $dirs; \
	fi
