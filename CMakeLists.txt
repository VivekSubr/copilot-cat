cmake_minimum_required(VERSION 3.16)
project(copilot-cat VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml QuickControls2 Network WebSockets)

qt_add_executable(copilot-cat
    src/main.cpp
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
)

target_link_libraries(copilot-cat PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Network
    Qt6::WebSockets
)

# Windows: hide console window in release builds
if(WIN32)
    set_target_properties(copilot-cat PROPERTIES
        WIN32_EXECUTABLE $<NOT:$<CONFIG:Debug>>
    )
endif()

# === Tests ===
enable_testing()

find_program(NODE_EXECUTABLE node REQUIRED)

# Node.js logic tests
add_test(NAME test-chat-dedup
    COMMAND ${NODE_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/test-chat-dedup.mjs
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# Qt Quick Tests
find_package(Qt6 REQUIRED COMPONENTS QuickTest)

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

# Run tests automatically after build
add_custom_target(run-tests ALL
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure -C $<CONFIG>
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    DEPENDS copilot-cat copilot-cat-tests
    COMMENT "Running tests..."
)
