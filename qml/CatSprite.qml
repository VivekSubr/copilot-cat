import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string state_name: "idle"
    property bool facingRight: true
    property int frame: 0
    property real legOffset1: 0
    property real legOffset2: 0

    width: 180
    height: 210

    transform: Scale {
        origin.x: root.width / 2
        xScale: root.facingRight ? 1 : -1
    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            root.frame++;
            if (root.state_name === "walking") {
                root.legOffset1 = Math.sin(root.frame * 0.9) * 7;
                root.legOffset2 = Math.sin(root.frame * 0.9 + Math.PI) * 7;
            } else {
                root.legOffset1 *= 0.7;
                root.legOffset2 *= 0.7;
            }
        }
    }

    property int blinkPhase: frame % 55
    property real eyeScaleY: blinkPhase < 2 ? 0.06 : 1.0
    property real tailWag: Math.sin(frame * 0.2) * 8

    readonly property color cBody: "#9399b2"
    readonly property color cDark: "#7f849c"
    readonly property color cDarker: "#6c7086"
    readonly property color cLight: "#cdd6f4"
    readonly property color cOutline: "#45475a"
    readonly property color cPink: "#f5c2e7"
    readonly property color cNose: "#f38ba8"

    // ==================== TAIL (thick fluffy S-curve) ====================
    Shape {
        x: 5; y: 5
        // Main tail body (thick)
        ShapePath {
            strokeColor: root.cOutline; strokeWidth: 2
            fillColor: root.cBody
            startX: 32; startY: 155
            PathQuad { x: 18 + root.tailWag * 0.3; y: 115; controlX: 12 + root.tailWag * 0.3; controlY: 140 }
            PathQuad { x: 32 + root.tailWag * 0.8; y: 55; controlX: 8 + root.tailWag * 0.7; controlY: 80 }
            PathQuad { x: 18 + root.tailWag; y: 15; controlX: 42 + root.tailWag; controlY: 30 }
            // Tip round
            PathQuad { x: 8 + root.tailWag * 0.8; y: 20; controlX: 5 + root.tailWag * 0.8; controlY: 10 }
            // Return (inner edge)
            PathQuad { x: 20 + root.tailWag * 0.6; y: 60; controlX: 28 + root.tailWag * 0.8; controlY: 35 }
            PathQuad { x: 24 + root.tailWag * 0.2; y: 118; controlX: 18 + root.tailWag * 0.5; controlY: 85 }
            PathQuad { x: 42; y: 152; controlX: 22 + root.tailWag * 0.2; controlY: 140 }
        }
    }

    // ==================== BODY ====================
    Rectangle {
        x: 42; y: 130; width: 100; height: 52; radius: 26
        color: root.cBody; border.color: root.cOutline; border.width: 2
    }
    // Belly
    Rectangle { x: 55; y: 138; width: 74; height: 34; radius: 17; color: root.cLight }
    // Neck bridge (connect head to body smoothly)
    Rectangle { x: 55; y: 115; width: 75; height: 30; radius: 15; color: root.cBody }
    // Chest fluff
    Rectangle { x: 62; y: 118; width: 60; height: 26; radius: 13; color: root.cLight }
    Rectangle { x: 72; y: 114; width: 42; height: 20; radius: 10; color: "#d9e0ee" }

    // ==================== LEGS ====================
    // Back left
    Item {
        x: 46 + root.legOffset2; y: 165
        Rectangle { width: 22; height: 28; radius: 8; color: root.cBody; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: -2; y: 20; width: 26; height: 16; radius: 8; color: root.cDark; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: 3; y: 26; width: 6; height: 5; radius: 2.5; color: root.cPink }
        Rectangle { x: 10; y: 27; width: 5; height: 4; radius: 2; color: root.cPink }
        Rectangle { x: 16; y: 26; width: 6; height: 5; radius: 2.5; color: root.cPink }
    }
    // Back right
    Item {
        x: 68 + root.legOffset1; y: 165
        Rectangle { width: 22; height: 28; radius: 8; color: root.cBody; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: -2; y: 20; width: 26; height: 16; radius: 8; color: root.cDark; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: 3; y: 26; width: 6; height: 5; radius: 2.5; color: root.cPink }
        Rectangle { x: 10; y: 27; width: 5; height: 4; radius: 2; color: root.cPink }
        Rectangle { x: 16; y: 26; width: 6; height: 5; radius: 2.5; color: root.cPink }
    }
    // Front left
    Item {
        x: 96 + root.legOffset1; y: 162
        Rectangle { width: 22; height: 30; radius: 8; color: root.cBody; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: -2; y: 22; width: 26; height: 16; radius: 8; color: root.cDark; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: 3; y: 28; width: 6; height: 5; radius: 2.5; color: root.cPink }
        Rectangle { x: 10; y: 29; width: 5; height: 4; radius: 2; color: root.cPink }
        Rectangle { x: 16; y: 28; width: 6; height: 5; radius: 2.5; color: root.cPink }
    }
    // Front right
    Item {
        x: 118 + root.legOffset2; y: 162
        Rectangle { width: 22; height: 30; radius: 8; color: root.cBody; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: -2; y: 22; width: 26; height: 16; radius: 8; color: root.cDark; border.color: root.cOutline; border.width: 1.5 }
        Rectangle { x: 3; y: 28; width: 6; height: 5; radius: 2.5; color: root.cPink }
        Rectangle { x: 10; y: 29; width: 5; height: 4; radius: 2; color: root.cPink }
        Rectangle { x: 16; y: 28; width: 6; height: 5; radius: 2.5; color: root.cPink }
    }

    // ==================== EARS (drawn before head so bases are hidden) ====================
    // Left ear outer
    Shape {
        x: 20; y: -2
        width: 60; height: 60
        ShapePath {
            fillColor: root.cBody; strokeColor: root.cOutline; strokeWidth: 2.5
            startX: 10; startY: 58
            PathLine { x: 18; y: 2 }
            PathLine { x: 55; y: 52 }
            PathLine { x: 10; y: 58 }
        }
    }
    // Left ear inner
    Shape {
        x: 27; y: 6
        width: 40; height: 42
        ShapePath {
            fillColor: "white"; strokeColor: "transparent"
            startX: 5; startY: 40
            PathLine { x: 11; y: 4 }
            PathLine { x: 36; y: 36 }
            PathLine { x: 5; y: 40 }
        }
    }
    // Right ear outer (mirror of left)
    Shape {
        x: 102; y: -2
        width: 60; height: 60
        ShapePath {
            fillColor: root.cBody; strokeColor: root.cOutline; strokeWidth: 2.5
            startX: 5; startY: 52
            PathLine { x: 42; y: 2 }
            PathLine { x: 50; y: 58 }
            PathLine { x: 5; y: 52 }
        }
    }
    // Right ear inner
    Shape {
        x: 115; y: 6
        width: 40; height: 42
        ShapePath {
            fillColor: "white"; strokeColor: "transparent"
            startX: 4; startY: 36
            PathLine { x: 29; y: 4 }
            PathLine { x: 35; y: 40 }
            PathLine { x: 4; y: 36 }
        }
    }

    // ==================== HEAD ====================
    Rectangle {
        x: 32; y: 35; width: 120; height: 100; radius: 50
        color: root.cBody; border.color: root.cOutline; border.width: 2.5
    }
    // Cheek puffs
    Rectangle { x: 25; y: 78; width: 36; height: 34; radius: 17; color: root.cBody; border.color: root.cOutline; border.width: 1.5 }
    Rectangle { x: 123; y: 78; width: 36; height: 34; radius: 17; color: root.cBody; border.color: root.cOutline; border.width: 1.5 }
    // Hide cheek-head seam
    Rectangle { x: 38; y: 80; width: 32; height: 30; color: root.cBody }
    Rectangle { x: 114; y: 80; width: 32; height: 30; color: root.cBody }
    // Muzzle
    Rectangle { x: 62; y: 86; width: 60; height: 38; radius: 19; color: root.cLight }

    // ==================== HEART MARKING ====================
    Shape {
        x: 78; y: 52
        ShapePath {
            fillColor: root.cLight; strokeColor: "transparent"
            startX: 13; startY: 22
            PathQuad { x: 0; y: 9; controlX: 2; controlY: 20 }
            PathQuad { x: 13; y: 0; controlX: -3; controlY: 0 }
            PathQuad { x: 26; y: 9; controlX: 29; controlY: 0 }
            PathQuad { x: 13; y: 22; controlX: 24; controlY: 20 }
        }
    }

    // ==================== EYES ====================
    // Left eye - amber
    Item {
        x: 45; y: 66
        visible: root.eyeScaleY > 0.1
        Rectangle {
            width: 36; height: 40 * root.eyeScaleY; radius: 18
            color: "white"; border.color: root.cOutline; border.width: 2.5
        }
        Rectangle {
            x: 3; y: Math.max(2, 40 * root.eyeScaleY - 36)
            width: 30; height: Math.min(34, 40 * root.eyeScaleY - 4); radius: 15
            color: "#fab387"; visible: root.eyeScaleY > 0.2
            Rectangle {
                x: 2; y: 0; width: parent.width - 4; height: parent.height * 0.3; radius: 12
                color: "#e8956a"; opacity: 0.6; visible: root.eyeScaleY > 0.4
            }
            Rectangle {
                anchors.centerIn: parent; anchors.verticalCenterOffset: 2
                width: 14; height: Math.min(22, parent.height - 6); radius: 7
                color: "#1e1e2e"; visible: root.eyeScaleY > 0.4
            }
        }
        Rectangle { x: 21; y: 5; width: 11; height: 11; radius: 5.5; color: "white"; visible: root.eyeScaleY > 0.5 }
        Rectangle { x: 6; y: 40 * root.eyeScaleY - 15; width: 7; height: 7; radius: 3.5; color: "white"; opacity: 0.85; visible: root.eyeScaleY > 0.5 }
        Rectangle { x: 24; y: 40 * root.eyeScaleY - 20; width: 4; height: 4; radius: 2; color: "white"; opacity: 0.6; visible: root.eyeScaleY > 0.5 }
    }
    // Left blink
    Shape {
        x: 45; y: 85; visible: root.eyeScaleY <= 0.1
        ShapePath {
            strokeColor: root.cOutline; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 2; startY: 4
            PathQuad { x: 18; y: 0; controlX: 10; controlY: 6 }
            PathQuad { x: 34; y: 4; controlX: 26; controlY: 6 }
        }
    }

    // Right eye - blue
    Item {
        x: 103; y: 66
        visible: root.eyeScaleY > 0.1
        Rectangle {
            width: 36; height: 40 * root.eyeScaleY; radius: 18
            color: "white"; border.color: root.cOutline; border.width: 2.5
        }
        Rectangle {
            x: 3; y: Math.max(2, 40 * root.eyeScaleY - 36)
            width: 30; height: Math.min(34, 40 * root.eyeScaleY - 4); radius: 15
            color: "#89b4fa"; visible: root.eyeScaleY > 0.2
            Rectangle {
                x: 2; y: 0; width: parent.width - 4; height: parent.height * 0.3; radius: 12
                color: "#5e8ad4"; opacity: 0.6; visible: root.eyeScaleY > 0.4
            }
            Rectangle {
                anchors.centerIn: parent; anchors.verticalCenterOffset: 2
                width: 14; height: Math.min(22, parent.height - 6); radius: 7
                color: "#1e1e2e"; visible: root.eyeScaleY > 0.4
            }
        }
        Rectangle { x: 21; y: 5; width: 11; height: 11; radius: 5.5; color: "white"; visible: root.eyeScaleY > 0.5 }
        Rectangle { x: 6; y: 40 * root.eyeScaleY - 15; width: 7; height: 7; radius: 3.5; color: "white"; opacity: 0.85; visible: root.eyeScaleY > 0.5 }
        Rectangle { x: 24; y: 40 * root.eyeScaleY - 20; width: 4; height: 4; radius: 2; color: "white"; opacity: 0.6; visible: root.eyeScaleY > 0.5 }
    }
    // Right blink
    Shape {
        x: 103; y: 85; visible: root.eyeScaleY <= 0.1
        ShapePath {
            strokeColor: root.cOutline; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 2; startY: 4
            PathQuad { x: 18; y: 0; controlX: 10; controlY: 6 }
            PathQuad { x: 34; y: 4; controlX: 26; controlY: 6 }
        }
    }

    // ==================== NOSE ====================
    Shape {
        x: 83; y: 96
        ShapePath {
            fillColor: root.cNose; strokeColor: "#d4637a"; strokeWidth: 1
            startX: 8; startY: 0
            PathQuad { x: 0; y: 9; controlX: 1; controlY: 5 }
            PathQuad { x: 16; y: 9; controlX: 8; controlY: 12 }
            PathQuad { x: 8; y: 0; controlX: 15; controlY: 5 }
        }
    }

    // ==================== MOUTH (W-shape) ====================
    Shape {
        x: 77; y: 104
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap; startX: 14; startY: 0; PathLine { x: 14; y: 5 } }
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap; startX: 3; startY: 3; PathQuad { x: 14; y: 5; controlX: 8; controlY: 11 } }
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap; startX: 14; startY: 5; PathQuad { x: 25; y: 3; controlX: 20; controlY: 11 } }
    }

    // ==================== WHISKERS (curved, 3 per side) ====================
    Shape {
        x: 15; y: 90
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.2; fillColor: "transparent"; startX: 35; startY: 4; PathQuad { x: 0; y: 0; controlX: 18; controlY: -2 } }
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.2; fillColor: "transparent"; startX: 35; startY: 10; PathQuad { x: 0; y: 10; controlX: 18; controlY: 8 } }
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.2; fillColor: "transparent"; startX: 35; startY: 16; PathQuad { x: 2; y: 24; controlX: 18; controlY: 22 } }
    }
    Shape {
        x: 132; y: 90
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.2; fillColor: "transparent"; startX: 0; startY: 4; PathQuad { x: 35; y: 0; controlX: 17; controlY: -2 } }
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.2; fillColor: "transparent"; startX: 0; startY: 10; PathQuad { x: 35; y: 10; controlX: 17; controlY: 8 } }
        ShapePath { strokeColor: root.cOutline; strokeWidth: 1.2; fillColor: "transparent"; startX: 0; startY: 16; PathQuad { x: 33; y: 24; controlX: 17; controlY: 22 } }
    }

    // ==================== IDLE BOUNCE ====================
    SequentialAnimation on y {
        running: root.state_name === "idle"
        loops: Animation.Infinite
        NumberAnimation { to: -4; duration: 1800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 1800; easing.type: Easing.InOutSine }
    }
}
