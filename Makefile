APP = build/Copipe Storage.app
SWIFT_BUILD = swift build --build-system swiftbuild

.PHONY: build test app app-debug run run-debug stop clean sign-check

build:
	$(SWIFT_BUILD)

test:
	swift test --build-system swiftbuild

app:
	Scripts/build-app.sh

app-debug:
	CONFIG=debug Scripts/build-app.sh

run: app
	open "$(APP)"

run-debug: app-debug
	open "$(APP)"

stop:
	pkill -x CopipeStorage || true

clean:
	rm -rf .build build

sign-check:
	codesign -dvvv "$(APP)"
	codesign -d -r - "$(APP)"
