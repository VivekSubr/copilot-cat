import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string message: ""
    property int displayDuration: 8000

    width: Math.min(Math.max(replyText.implicitWidth + 36, 140), 300)
    height: replyText.implicitHeight + 50
    visible: false
    opacity: 0

    Behavior on opacity { NumberAnimation { duration: 250 } }

    function show(text) {
        message = text;
        visible = true;
        opacity = 1;
        autoDismiss.restart();
    }

    function hide() {
        opacity = 0;
        hideTimer.start();
    }

    Timer {
        id: hideTimer
        interval: 250
        onTriggered: root.visible = false
    }

    Timer {
        id: autoDismiss
        interval: root.displayDuration
        onTriggered: root.hide()
    }

    // Bubble body
    Rectangle {
        x: 4; y: 4
        width: parent.width - 8
        height: parent.height - 24
        radius: 14
        color: "#313244"
        border.color: "#89b4fa"
        border.width: 2
    }

    // Speech tail
    Shape {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 20; height: 20
        ShapePath {
            fillColor: "#313244"
            strokeColor: "#89b4fa"
            strokeWidth: 2
            startX: 0; startY: 0
            PathLine { x: 10; y: 18 }
            PathLine { x: 20; y: 0 }
        }
    }

    Text {
        id: replyText
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 18
            topMargin: 14
        }
        text: root.message
        wrapMode: Text.WordWrap
        font.pixelSize: 13
        color: "#cdd6f4"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
        cursorShape: Qt.PointingHandCursor
    }
}
