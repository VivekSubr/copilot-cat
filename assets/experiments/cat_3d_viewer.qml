// cat_3d_viewer.qml — Qt Quick 3D viewer for the generated cat model
//
// HOW TO RUN:
//   1. Generate the model first:
//        cd C:\Software\copilot-cat\assets\experiments
//        python cat_3d_concept.py
//
//   2. View with Qt Quick 3D (requires Qt 6.x with QtQuick3D module):
//        set PATH=C:\Qt\6.8.3\msvc2022_64\bin;%PATH%
//        qml cat_3d_viewer.qml
//
//      Or with qmlscene:
//        qmlscene cat_3d_viewer.qml
//
//   NOTE: QtQuick3D must be installed. It ships with most Qt 6 installers
//   but may need to be selected during installation.

import QtQuick
import QtQuick.Controls
import QtQuick3D

Window {
    id: root
    width: 800
    height: 600
    visible: true
    color: "#1e1e2e"  // Catppuccin base
    title: "Copilot Cat 3D — Proof of Concept"

    // 3D viewport
    View3D {
        id: view3d
        anchors.fill: parent

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Color
            clearColor: "#1e1e2e"
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // Camera orbiting the cat
        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 4, 12)
            eulerRotation.x: -15

            // Smooth orbit animation
            NumberAnimation on eulerRotation.y {
                from: 0
                to: 360
                duration: 20000
                loops: Animation.Infinite
                running: autoRotate.checked
            }
        }

        // Lighting
        DirectionalLight {
            eulerRotation.x: -45
            eulerRotation.y: 30
            brightness: 1.0
            color: "#cdd6f4"
            ambientColor: "#313244"
        }

        DirectionalLight {
            eulerRotation.x: -20
            eulerRotation.y: -120
            brightness: 0.4
            color: "#89b4fa"
        }

        // The cat model
        Model {
            id: catModel
            source: "cat_model.obj"
            // Position the cat centered in the scene
            position: Qt.vector3d(0, -2, 0)
            scale: Qt.vector3d(1, 1, 1)

            // Manual rotation via mouse drag (when auto-rotate is off)
            eulerRotation.y: manualRotationY

            property real manualRotationY: 0
        }

        // Ground plane for visual reference
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, -2.8, 0)
            eulerRotation.x: -90
            scale: Qt.vector3d(0.15, 0.15, 0.15)
            materials: [
                DefaultMaterial {
                    diffuseColor: "#313244"
                }
            ]
        }
    }

    // Mouse interaction for manual rotation
    MouseArea {
        anchors.fill: parent
        property real lastX: 0

        onPressed: function(mouse) {
            lastX = mouse.x
        }
        onPositionChanged: function(mouse) {
            if (pressed && !autoRotate.checked) {
                var dx = mouse.x - lastX
                catModel.manualRotationY += dx * 0.5
                lastX = mouse.x
            }
        }

        // Scroll to zoom
        onWheel: function(wheel) {
            var zoomDelta = wheel.angleDelta.y > 0 ? -0.5 : 0.5
            camera.position.z = Math.max(4, Math.min(25, camera.position.z + zoomDelta))
        }
    }

    // UI overlay
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        spacing: 8

        Label {
            text: "Copilot Cat 3D"
            font.pixelSize: 20
            font.bold: true
            color: "#cdd6f4"
        }

        Label {
            text: "Drag to rotate • Scroll to zoom"
            font.pixelSize: 12
            color: "#a6adc8"
        }

        CheckBox {
            id: autoRotate
            text: "Auto-rotate"
            checked: true
            contentItem: Text {
                text: autoRotate.text
                color: "#cdd6f4"
                font.pixelSize: 13
                leftPadding: autoRotate.indicator.width + 6
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Color palette reference
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 16
        spacing: 4

        Repeater {
            model: [
                { color: "#7f849c", label: "Body" },
                { color: "#45475a", label: "Outline" },
                { color: "#bac2de", label: "Belly" },
                { color: "#cdd6f4", label: "Chest" },
                { color: "#f5c2e7", label: "Pink" },
                { color: "#f38ba8", label: "Nose" },
                { color: "#89b4fa", label: "Blue Eye" },
                { color: "#fab387", label: "Amber Eye" }
            ]
            delegate: Column {
                spacing: 2
                Rectangle {
                    width: 32
                    height: 32
                    radius: 4
                    color: modelData.color
                    border.color: "#585b70"
                    border.width: 1
                }
                Label {
                    text: modelData.label
                    font.pixelSize: 8
                    color: "#a6adc8"
                    horizontalAlignment: Text.AlignHCenter
                    width: 32
                }
            }
        }
    }
}
