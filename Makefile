APP_NAME    := LED Banner
BIN_NAME    := LEDBanner
BUILD_DIR   := build
APP_DIR     := $(BUILD_DIR)/$(APP_NAME).app
BIN         := $(BUILD_DIR)/$(BIN_NAME)

ICON        := resources/AppIcon.icns
ICONSET     := $(BUILD_DIR)/AppIcon.iconset
ICON_TOOL   := $(BUILD_DIR)/make-icon

SDK         := $(shell xcrun --show-sdk-path)
MIN_OS      := 10.13
CC          := clang
CFLAGS      := -fobjc-arc -fmodules -isysroot "$(SDK)" -mmacosx-version-min=$(MIN_OS) \
               -Isrc/app -Isrc/engine -Isrc/export \
               -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -O2
LDFLAGS     := -isysroot "$(SDK)" -mmacosx-version-min=$(MIN_OS)
FRAMEWORKS  := -framework Cocoa -framework QuartzCore -framework ImageIO \
               -framework AVFoundation -framework CoreMedia -framework CoreVideo \
               -framework CoreGraphics

SOURCES     := $(wildcard src/*.m src/app/*.m src/engine/*.m src/export/*.m)
HEADERS     := $(wildcard src/app/*.h src/engine/*.h src/export/*.h)
TEST_SRC    := tests/test_engine.m
SNAPSHOT_SRC := tests/snapshot_ui.m
UI_SOURCES  := $(filter-out src/main.m src/app/AppDelegate.m,$(SOURCES))

.PHONY: all run app test snapshot icon clean

all: $(BIN)

$(BIN): $(SOURCES) $(HEADERS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SOURCES) $(LDFLAGS) $(FRAMEWORKS) -o $@

run: $(BIN)
	./$(BIN)

app: $(BIN) $(ICON)
	@mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	@cp $(BIN) "$(APP_DIR)/Contents/MacOS/$(BIN_NAME)"
	@cp resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	@cp $(ICON) "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	@echo "Built $(APP_DIR)"

# Regenerates the app icon from tools/make_icon.m.
icon: $(ICON)

$(ICON): tools/make_icon.m src/engine/LEBGlyphFont.m src/engine/LEBGlyphFont.h
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -Isrc/engine tools/make_icon.m src/engine/LEBGlyphFont.m \
		$(LDFLAGS) $(FRAMEWORKS) -o $(ICON_TOOL)
	@rm -rf "$(ICONSET)"
	$(ICON_TOOL) "$(ICONSET)"
	iconutil -c icns "$(ICONSET)" -o "$@"
	@echo "Built $(ICON)"

test: $(TEST_SRC) $(filter-out src/main.m,$(SOURCES)) $(HEADERS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -Isrc/engine -Isrc/export $(TEST_SRC) \
		$(filter-out src/main.m src/app/AppDelegate.m src/app/MainWindowController.m,$(SOURCES)) \
		$(LDFLAGS) $(FRAMEWORKS) -o $(BUILD_DIR)/led-banner-tests
	./$(BUILD_DIR)/led-banner-tests

snapshot: $(SNAPSHOT_SRC) $(UI_SOURCES) $(HEADERS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SNAPSHOT_SRC) $(UI_SOURCES) \
		$(LDFLAGS) $(FRAMEWORKS) -o $(BUILD_DIR)/snapshot
	./$(BUILD_DIR)/snapshot

clean:
	rm -rf $(BUILD_DIR)
