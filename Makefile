APP = build/macOS Utility.app

.PHONY: dev build r clean status reset

dev:
	swift run

build:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp .build/release/MacOSUtility "$(APP)/Contents/MacOS/MacOSUtility"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"
	@echo "Built $(APP)"

r: build
	@pkill -x MacOSUtility 2>/dev/null && sleep 1 || true
	open "$(APP)"

clean:
	swift package clean
	rm -rf build

status:
	hidutil property --get UserKeyMapping

reset:
	hidutil property --set '{"UserKeyMapping":[]}'
