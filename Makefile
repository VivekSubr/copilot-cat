VS_CMAKE = C:/Program Files/Microsoft Visual Studio/2022/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe
CMAKE = "$(VS_CMAKE)"
CMAKE_GENERATOR = Visual Studio 17 2022
CMAKE_ARCH = x64
QT_PREFIX = C:/Qt/6.8.3/msvc2022_64
BUILD_DIR = build
CONFIG = Debug

.PHONY: build clean configure deploy mcp

build: configure
	$(CMAKE) --build $(BUILD_DIR) --config $(CONFIG)

configure: $(BUILD_DIR)/CMakeCache.txt

$(BUILD_DIR)/CMakeCache.txt: CMakeLists.txt
	$(CMAKE) -B $(BUILD_DIR) -G "$(CMAKE_GENERATOR)" -A $(CMAKE_ARCH) -DCMAKE_PREFIX_PATH=$(QT_PREFIX)

deploy: build
	"$(QT_PREFIX)/bin/windeployqt.exe" $(BUILD_DIR)/$(CONFIG)/copilot-cat.exe --qmldir qml

mcp:
	npx tsc

clean:
	$(CMAKE) -E rm -rf $(BUILD_DIR)
