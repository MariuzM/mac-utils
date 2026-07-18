APP = build/macOS Utility.app
HELPER = $(APP)/Contents/Library/LoginItems/FolderHelper.app

VERSION = 0.4.0
BUILD_NUMBER = 4

APP_ID = dev.marius.macosutility
HELPER_ID = dev.marius.macosutility.folderhelper

SIGN_ID ?= macOS Utility Dev

.PHONY: dev build r test clean status reset helper-stop helper-start tcc

dev:
	swift run MacOSUtility

test:
	swift test

build:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	mkdir -p "$(HELPER)/Contents/MacOS"
	cp .build/release/MacOSUtility "$(APP)/Contents/MacOS/MacOSUtility"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp .build/release/FolderHelper "$(HELPER)/Contents/MacOS/FolderHelper"
	cp Resources/HelperInfo.plist "$(HELPER)/Contents/Info.plist"
	@for plist in "$(APP)/Contents/Info.plist" "$(HELPER)/Contents/Info.plist"; do \
		/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$$plist"; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$$plist"; \
	done
	codesign --force --sign "$(SIGN_ID)" "$(HELPER)"
	codesign --force --sign "$(SIGN_ID)" "$(APP)"
	@echo "Built $(APP) $(VERSION) ($(BUILD_NUMBER)) signed as $(SIGN_ID)"

r:
	@$(MAKE) build
	@$(MAKE) helper-stop
	@pkill -x MacOSUtility 2>/dev/null && sleep 1 || true
	open "$(APP)"
	@$(MAKE) helper-start

helper-stop:
	@pkill -x FolderHelper 2>/dev/null && sleep 1 || true

helper-start:
	@open "$(HELPER)" 2>/dev/null || true
	@echo "Helper started"

tcc:
	@tccutil reset Accessibility $(APP_ID) || true
	@tccutil reset Accessibility $(HELPER_ID) || true
	@echo "Accessibility grants reset — approve again on next launch"

clean:
	swift package clean
	rm -rf build

status:
	/usr/bin/hidutil property --get UserKeyMapping

reset:
	/usr/bin/hidutil property --set '{"UserKeyMapping":[]}'
