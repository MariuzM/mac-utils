APP = build/Mac Utils.app
HELPER = $(APP)/Contents/Library/LoginItems/FolderHelper.app

VERSION = 0.5.0
BUILD_NUMBER = 5

APP_ID = dev.marius.macutils
HELPER_ID = dev.marius.macutils.folderhelper

PREFERRED_SIGN_ID = mac-utils Dev
SIGN_ID ?= $(shell security find-identity -v -p codesigning 2>/dev/null \
	| grep -qF '$(PREFERRED_SIGN_ID)' && echo '$(PREFERRED_SIGN_ID)' || echo '-')

.PHONY: dev build r test clean status reset helper-stop helper-start tcc

dev:
	swift run MacUtils

test:
	swift test

build:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	mkdir -p "$(HELPER)/Contents/MacOS"
	cp .build/release/MacUtils "$(APP)/Contents/MacOS/MacUtils"
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
	@if [ "$(SIGN_ID)" = "-" ]; then \
		echo ""; \
		echo "  Note: signed ad-hoc. Accessibility and Full Disk Access grants are pinned"; \
		echo "  to the binary hash, so they must be re-granted after every rebuild."; \
		echo "  To keep grants across rebuilds, create a self-signed code-signing"; \
		echo "  certificate named '$(PREFERRED_SIGN_ID)' — see README, Signing."; \
		echo ""; \
	fi

r:
	@$(MAKE) build
	@$(MAKE) helper-stop
	@pkill -x MacUtils 2>/dev/null && sleep 1 || true
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
