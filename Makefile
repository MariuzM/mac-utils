APP = build/macOS Utility.app
HELPER = $(APP)/Contents/Library/LoginItems/FolderHelper.app
SIGN_ID = macOS Utility Dev

.PHONY: dev build r clean status reset helper-stop

dev:
	swift run MacOSUtility

build:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	mkdir -p "$(HELPER)/Contents/MacOS"
	cp .build/release/MacOSUtility "$(APP)/Contents/MacOS/MacOSUtility"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp .build/release/FolderHelper "$(HELPER)/Contents/MacOS/FolderHelper"
	cp Resources/HelperInfo.plist "$(HELPER)/Contents/Info.plist"
	codesign --force --sign "$(SIGN_ID)" "$(HELPER)"
	codesign --force --sign "$(SIGN_ID)" "$(APP)"
	@echo "Built $(APP) (helper embedded)"

r: build helper-stop
	@pkill -x MacOSUtility 2>/dev/null && sleep 1 || true
	open "$(APP)"

helper-stop:
	@pkill -x FolderHelper 2>/dev/null && sleep 1 || true

clean:
	swift package clean
	rm -rf build

status:
	hidutil property --get UserKeyMapping

reset:
	hidutil property --set '{"UserKeyMapping":[]}'
