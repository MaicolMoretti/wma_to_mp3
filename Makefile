APP_NAME = WMA2MP3
BUNDLE_ID = com.example.wma2mp3
EXECUTABLE_NAME = WMA2MP3
BUILD_DIR = .build
APP_BUNDLE = build/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES_DIR = $(CONTENTS)/Resources
# Use a static build from evermeet.cx which distributes FFmpeg binaries for macOS
FFMPEG_URL = https://evermeet.cx/ffmpeg/getrelease/zip
FFMPEG_ZIP = $(BUILD_DIR)/ffmpeg.zip
FFMPEG_BIN = Sources/WMA2MP3/Resources/ffmpeg

all: init_ffmpeg build app_bundle

clean:
	rm -rf $(BUILD_DIR) build
	swift package clean

init_ffmpeg:
	@if [ ! -f "$(FFMPEG_BIN)" ]; then \
		echo "Downloading ffmpeg..."; \
		mkdir -p $(BUILD_DIR); \
		curl -sL $(FFMPEG_URL) -o $(FFMPEG_ZIP); \
		unzip -q -o $(FFMPEG_ZIP) -d $(BUILD_DIR); \
		mkdir -p Sources/WMA2MP3/Resources; \
		mv $(BUILD_DIR)/ffmpeg $(FFMPEG_BIN); \
		chmod +x $(FFMPEG_BIN); \
		rm $(FFMPEG_ZIP); \
		echo "ffmpeg downloaded and placed in Resources."; \
	fi

build:
	swift build -c release

app_bundle:
	@echo "Creating .app bundle..."
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	
	# Copy Info.plist
	cp Sources/WMA2MP3/Info.plist $(CONTENTS)/Info.plist
	
	# Copy Executable (Universal binary if possible, or host binary)
	cp $(BUILD_DIR)/apple/Products/Release/$(EXECUTABLE_NAME) $(MACOS_DIR)/$(EXECUTABLE_NAME) || cp $(BUILD_DIR)/release/$(EXECUTABLE_NAME) $(MACOS_DIR)/$(EXECUTABLE_NAME)
	
	# Copy Resources (ffmpeg and Any other bundles)
	# SPM packages up the resources into a bundle inside the build folder
	cp -R $(BUILD_DIR)/release/$(EXECUTABLE_NAME)_$(EXECUTABLE_NAME).bundle $(RESOURCES_DIR)/ 2>/dev/null || true
	# Alternatively just copy the raw resources just in case SPM doesn't bundle them directly like xcodebuild does
	cp $(FFMPEG_BIN) $(RESOURCES_DIR)/ffmpeg
	cp Sources/WMA2MP3/Resources/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	
	# Create empty PkgInfo
	echo "APPL????" > $(CONTENTS)/PkgInfo

	@echo "Build successful: $(APP_BUNDLE)"

run: all
	open $(APP_BUNDLE)

test:
	swift test
