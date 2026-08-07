.PHONY: build release bundle dmg clean run

APP_NAME = A-Shot
VERSION = 1.0
DMG_NAME = $(APP_NAME)-$(VERSION).dmg

build:
	swift build

release:
	swift build -c release

bundle: release
	mkdir -p $(APP_NAME).app/Contents/MacOS
	mkdir -p $(APP_NAME).app/Contents/Resources
	cp .build/release/$(APP_NAME) $(APP_NAME).app/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_NAME).app/Contents/Info.plist
	codesign --force --sign - --entitlements Resources/Shot.entitlements $(APP_NAME).app

dmg: bundle
	rm -rf .dmg-staging $(DMG_NAME)
	mkdir -p .dmg-staging
	cp -R $(APP_NAME).app .dmg-staging/
	ln -s /Applications .dmg-staging/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder .dmg-staging -ov -format UDZO $(DMG_NAME)
	rm -rf .dmg-staging

run: build
	swift run $(APP_NAME)

clean:
	swift package clean
	rm -rf $(APP_NAME).app $(APP_NAME)-*.dmg .dmg-staging
