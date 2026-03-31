cmake_minimum_required(VERSION 3.16)
project(copilot-cat VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

option(QT_STATIC "Link Qt statically (requires static Qt build)" ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml QuickControls2 Network WebSockets)

qt_add_executable(copilot-cat
    src/main.cpp
    src/catconfig.cpp
    src/catconfig.h
    src/copilotbridge.cpp
    src/copilotbridge.h
)

qt_add_qml_module(copilot-cat
    URI CopilotCat
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/CatSprite.qml
        qml/ThoughtBubble.qml
        qml/ReplyBubble.qml
        qml/SetupWizard.qml
)

target_link_libraries(copilot-cat PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Network
    Qt6::WebSockets
)

# Static Qt: import plugins that would normally be loaded dynamically
if(QT_STATIC)
    find_package(Qt6 REQUIRED COMPONENTS Svg)
    target_link_libraries(copilot-cat PRIVATE Qt6::Svg)
    target_compile_definitions(copilot-cat PRIVATE QT_STATIC_BUILD)

    # Import required plugins for static builds
    qt_import_plugins(copilot-cat
        INCLUDE
            Qt6::QWindowsIntegrationPlugin
            Qt6::QSvgPlugin
            Qt6::QSvgIconPlugin
            Qt6::QJpegPlugin
            Qt6::QICOPlugin
    )
endif()

# Windows: hide console window in release builds
if(WIN32)
    set_target_properties(copilot-cat PROPERTIES
        WIN32_EXECUTABLE $<NOT:$<CONFIG:Debug>>
    )
endif()

# === Tests ===
enable_testing()

# Qt Quick Tests (QML)
find_package(Qt6 REQUIRED COMPONENTS QuickTest Test)

qt_add_executable(copilot-cat-tests tests/tst_main.cpp)
target_link_libraries(copilot-cat-tests PRIVATE
    Qt6::QuickTest
    Qt6::Quick
    Qt6::Qml
)
target_compile_definitions(copilot-cat-tests PRIVATE
    ASSETS_DIR="${CMAKE_SOURCE_DIR}/assets"
    QML_DIR="${CMAKE_SOURCE_DIR}/qml"
    QUICK_TEST_SOURCE_DIR="${CMAKE_SOURCE_DIR}/tests"
)

add_test(NAME test-qt-quick
    COMMAND copilot-cat-tests
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)
set_tests_properties(test-qt-quick PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=windows;QML2_IMPORT_PATH=${CMAKE_SOURCE_DIR}/qml"
)

# C++ unit tests (CatConfig)
qt_add_executable(copilot-cat-config-tests
    tests/tst_catconfig.cpp
    src/catconfig.cpp
    src/catconfig.h
)
target_link_libraries(copilot-cat-config-tests PRIVATE
    Qt6::Test
    Qt6::Network
    Qt6::Core
)
target_compile_definitions(copilot-cat-config-tests PRIVATE
    SOURCE_DIR="${CMAKE_SOURCE_DIR}"
)

add_test(NAME test-config
    COMMAND copilot-cat-config-tests
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# C++ unit tests (CopilotBridge)
qt_add_executable(copilot-cat-bridge-tests
    tests/tst_copilotbridge.cpp
    src/catconfig.cpp
    src/catconfig.h
    src/copilotbridge.cpp
    src/copilotbridge.h
)
target_link_libraries(copilot-cat-bridge-tests PRIVATE
    Qt6::Test
    Qt6::Network
    Qt6::Core
)
target_compile_definitions(copilot-cat-bridge-tests PRIVATE
    SOURCE_DIR="${CMAKE_SOURCE_DIR}"
)

add_test(NAME test-bridge
    COMMAND copilot-cat-bridge-tests
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# Run tests automatically after build
add_custom_target(run-tests ALL
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure -C $<CONFIG>
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    DEPENDS copilot-cat copilot-cat-tests copilot-cat-config-tests copilot-cat-bridge-tests
    COMMENT "Running tests..."
)
