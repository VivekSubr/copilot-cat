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

add_test(NAME test-chat-dedup
    COMMAND ${NODE_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/test-chat-dedup.mjs
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

add_test(NAME test-qml-structure
    COMMAND ${NODE_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/test-qml-structure.mjs
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# Run tests automatically after build
add_custom_target(run-tests ALL
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure -C $<CONFIG>
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    DEPENDS copilot-cat
    COMMENT "Running tests..."
)
