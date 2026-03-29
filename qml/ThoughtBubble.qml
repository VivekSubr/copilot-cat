import QtQuick
import QtQuick.Controls

Item {
    id: root

    property alias text: inputField.text
    signal submitted(string message)

    width: 280
    height: 130
    visible: false
    opacity: 0

    Behavior on opacity { NumberAnimation { duration: 200 } }

    function show() {
        visible = true;
        opacity = 1;
        inputField.text = "";
        inputField.forceActiveFocus();
    }

    function hide() {
        opacity = 0;
        hideTimer.start();
    }

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: root.visible = false
    }

    // Bubble body
    Rectangle {
        x: 4; y: 4
        width: parent.width - 8
        height: parent.height - 35
        radius: 16
        color: "#313244"
        border.color: "#585b70"
        border.width: 2
    }

    // Thought dots
    Rectangle { x: parent.width/2 - 8; y: parent.height - 28; width: 16; height: 12; radius: 6; color: "#313244"; border.color: "#585b70"; border.width: 1.5 }
    Rectangle { x: parent.width/2 + 5; y: parent.height - 16; width: 10; height: 8; radius: 4; color: "#313244"; border.color: "#585b70"; border.width: 1.5 }
    Rectangle { x: parent.width/2 + 14; y: parent.height - 8; width: 6; height: 5; radius: 2.5; color: "#313244"; border.color: "#585b70"; border.width: 1.5 }

    TextField {
        id: inputField
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 16
            topMargin: 14
        }
        height: 36
        placeholderText: "Ask me anything..."
        placeholderTextColor: "#6c7086"
        color: "#cdd6f4"
        font.pixelSize: 13
        background: Rectangle {
            radius: 8
            color: "#1e1e2e"
            border.color: inputField.activeFocus ? "#89b4fa" : "#45475a"
            border.width: 1
        }

        onAccepted: {
            if (text.trim().length > 0)
                root.submitted(text.trim());
        }

        Keys.onEscapePressed: root.hide()
    }

    Text {
        anchors.top: inputField.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: inputField.horizontalCenter
        text: "Enter to send · Esc to close"
        font.pixelSize: 10
        color: "#6c7086"
    }
}
