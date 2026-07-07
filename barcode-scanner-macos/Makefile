APP_NAME := BarcodeScanner
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
APP_EXECUTABLE := $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
ARCH := $(shell uname -m)
MACOSX_DEPLOYMENT_TARGET ?= 14.0
SWIFTC := xcrun swiftc
SOURCES := $(shell find Sources -name '*.swift' | sort)

.PHONY: app run clean

app: $(APP_EXECUTABLE)

$(APP_EXECUTABLE): $(SOURCES) Resources/Info.plist Makefile
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	$(SWIFTC) \
		-swift-version 5 \
		-target $(ARCH)-apple-macosx$(MACOSX_DEPLOYMENT_TARGET) \
		-O \
		-framework SwiftUI \
		-framework AVFoundation \
		-framework AppKit \
		-framework QuartzCore \
		-framework Vision \
		-o "$(APP_EXECUTABLE)" \
		$(SOURCES)
	codesign --force --deep --sign - "$(APP_BUNDLE)"

run: app
	open "$(APP_BUNDLE)"

clean:
	rm -rf "$(BUILD_DIR)"
