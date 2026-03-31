VS_CMAKE = C:/Program Files/Microsoft Visual Studio/2022/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe
CMAKE = "$(VS_CMAKE)"
CMAKE_GENERATOR = Visual Studio 17 2022
CMAKE_ARCH = x64
QT_PREFIX = C:/Qt/6.8.3/msvc2022_64_static
QT_DYNAMIC_PREFIX = C:/Qt/6.8.3/msvc2022_64
BUILD_DIR = build
CONFIG = Debug

.PHONY: build clean configure deploy mcp test dynamic msix

build: configure
	$(CMAKE) --build $(BUILD_DIR) --config $(CONFIG)

test: build
	cd $(BUILD_DIR) && "$(VS_CMAKE)" -E env QT_QPA_PLATFORM=windows ctest --output-on-failure -C $(CONFIG)

configure: $(BUILD_DIR)/CMakeCache.txt

$(BUILD_DIR)/CMakeCache.txt: CMakeLists.txt
	$(CMAKE) -B $(BUILD_DIR) -G "$(CMAKE_GENERATOR)" -A $(CMAKE_ARCH) -DCMAKE_PREFIX_PATH=$(QT_PREFIX) -DQT_STATIC=ON

# Dynamic build — uses shared Qt DLLs (run windeployqt after)
dynamic:
	$(CMAKE) -B build-dynamic -G "$(CMAKE_GENERATOR)" -A $(CMAKE_ARCH) -DCMAKE_PREFIX_PATH=$(QT_DYNAMIC_PREFIX) -DQT_STATIC=OFF
	$(CMAKE) --build build-dynamic --config $(CONFIG)

deploy: dynamic
	"$(QT_DYNAMIC_PREFIX)/bin/windeployqt.exe" build-dynamic/$(CONFIG)/copilot-cat.exe --qmldir qml

mcp:
	npx tsc

msix: build
	cmd /c pkg\make_msix.cmd $(BUILD_DIR)\$(CONFIG)

clean:
	$(CMAKE) -E rm -rf $(BUILD_DIR)
	$(CMAKE) -E rm -rf build-dynamic
