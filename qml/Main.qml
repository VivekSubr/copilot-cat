import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtWebSockets

Window {
    id: win
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WA_TranslucentBackground
    color: "transparent"

    property int compactWidth: 200
    property int compactHeight: 180
    property int bubbleWidth: 260
    property int catSpriteWidth: 120
    property int bubblePadding: 10

    width: compactWidth
    height: compactHeight

    property int screenW: Screen.width
    property int screenH: Screen.height
    property int catBottom: screenH - 48
    property int restY: catBottom - height

    property string catState: "pounce"
    property bool facingRight: true
    property int walkFrame: 0
    property int tailSwishFrame: 0
    property bool bubbleIsInput: false
    property string bubbleText: ""
    property bool chatMode: false
    property bool dragArmed: false
    property bool dragging: false
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragArmX: 0
    property real dragArmY: 0
    property bool resumeBehaviorAfterDrag: false
    property bool restoreBubbleAfterDrag: false
    property string savedBubbleText: ""
    property bool savedBubbleIsInput: false
    property bool suppressClick: false
    property int dragHoldDelayMs: 50

    x: 0
    y: restY

    // === WEBSOCKET (MCP server) ===
    property bool wsConnected: false
    property int reconnectDelay: 1000
    property int reconnectMax: 30000

    WebSocket {
        id: ws
        url: "ws://127.0.0.1:9922"
        active: copilotBridge.backend === "auto" || copilotBridge.backend === "mcp"
        onStatusChanged: function(status) {
            if (status === WebSocket.Open) {
                win.wsConnected = true;
                win.reconnectDelay = 1000;
            } else if (status === WebSocket.Error || status === WebSocket.Closed) {
                win.wsConnected = false;
                reconnectTimer.interval = win.reconnectDelay;
                win.reconnectDelay = Math.min(win.reconnectDelay * 2, win.reconnectMax);
                reconnectTimer.start();
            }
        }
        onTextMessageReceived: function(msg) {
            chatTimeout.stop();
            try { handleMcpMessage(JSON.parse(msg)); } catch(e) {}
        }
    }
    Timer { id: reconnectTimer; onTriggered: { ws.active = false; reactivateTimer.interval = 100; reactivateTimer.start(); } }
    Timer { id: reactivateTimer; onTriggered: { ws.active = true; } }
    Timer { id: chatTimeout; interval: 15000; onTriggered: showBubble("Meow! No response from server.", false) }

    function handleMcpMessage(data) {
        if (data.type === "show_bubble") showBubble(data.text, win.chatMode);
        else if (data.type === "ask_user") {
            win.chatMode = false;
            showBubble(data.text, true);
        }
        else if (data.type === "action") {
            if (data.action === "sit") { behaviorTimer.stop(); win.catState = "sit"; }
            else if (data.action === "walk") { win.catState = "walking"; behaviorTimer.start(); }
            else { win.catState = "idle"; behaviorTimer.start(); }
        }
    }
    function sendToMcp(msg) { if (ws.status === WebSocket.Open) ws.sendTextMessage(JSON.stringify(msg)); }

    // === COPILOT BRIDGE (fallback when MCP not connected) ===
    Connections {
        target: copilotBridge
        function onResponseReceived(response) { showBubble(response, win.chatMode); }
        function onErrorOccurred(error) { showBubble("Meow! " + error, win.chatMode); }
    }

    function sendChat(msg) {
        var b = copilotBridge.backend;
        // "mcp" forces WebSocket; "auto" prefers WebSocket when connected
        if (b === "mcp" || (b === "auto" && win.wsConnected)) {
            if (!win.wsConnected) {
                showBubble("Meow! MCP server not connected on ws://127.0.0.1:9922", false);
                return;
            }
            if (win.chatMode) sendToMcp({ type: "chat", text: msg });
            else sendToMcp({ type: "user_response", text: msg });
            chatTimeout.restart();
        } else {
            copilotBridge.sendMessage(msg);
        }
    }

    function showBubble(text, isInput) {
        behaviorTimer.stop();
        autoDismiss.stop();
        win.catState = "sit";
        win.bubbleText = text;
        win.bubbleIsInput = isInput;
        bubble.visible = true;
        resizeDelay.start();
        if (isInput) {
            inputField.text = "";
            focusDelay.start();
        } else {
            autoDismiss.restart();
        }
    }
    Timer { id: resizeDelay; interval: 10; onTriggered: resizeForBubble(true) }
    Timer { id: focusDelay; interval: 100; onTriggered: { win.requestActivate(); inputField.forceActiveFocus(); } }
    Timer { id: suppressClickReset; interval: 1; onTriggered: win.suppressClick = false }

    function hideBubble() {
        bubble.visible = false;
        win.bubbleIsInput = false;
        resizeForBubble(false);
    }

    function beginDrag(globalPos) {
        introAnimation.stop();
        autoDismiss.stop();
        focusDelay.stop();
        if (bubble.visible) {
            win.restoreBubbleAfterDrag = true;
            win.savedBubbleText = win.bubbleText;
            win.savedBubbleIsInput = win.bubbleIsInput;
            hideBubble();
        } else {
            win.restoreBubbleAfterDrag = false;
        }

        win.dragArmed = false;
        win.dragging = true;
        win.suppressClick = true;
        win.dragOffsetX = globalPos.x - win.x;
        win.dragOffsetY = globalPos.y - win.y;
        win.resumeBehaviorAfterDrag = behaviorTimer.running;
        behaviorTimer.stop();
        win.catState = "sit";
    }

    function resizeForBubble(expanded) {
        var targetWidth, targetHeight;
        if (expanded) {
            var bubbleH = bubble.height > 0 ? bubble.height : 100;
            targetWidth = bubbleWidth + bubblePadding + catSpriteWidth;
            targetHeight = Math.max(bubbleH + 20, compactHeight);
            targetHeight = Math.min(targetHeight, screenH - 100);
        } else {
            targetWidth = compactWidth;
            targetHeight = compactHeight;
        }

        var catBottomY = y + height;
        var oldRight = x + width;

        width = targetWidth;
        height = targetHeight;
        x = clampX(oldRight - width);
        y = clampY(catBottomY - height);
    }

    function clampX(value) {
        return Math.max(0, Math.min(value, screenW - width));
    }

    function clampY(value) {
        return Math.max(0, Math.min(value, screenH - height));
    }

    property int maxBubbleHeight: screenH - 200
    property int inputAreaHeight: 56

    // === BUBBLE (left side when visible) ===
    Item {
        id: bubble
        visible: false
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: win.bubbleWidth - 20
        height: {
            var textH = bubbleTextEdit.implicitHeight;
            var inputH = win.bubbleIsInput ? win.inputAreaHeight : 0;
            var natural = textH + inputH + 30;
            return Math.min(natural, win.maxBubbleHeight);
        }

        Rectangle {
            anchors.fill: parent
            anchors.rightMargin: 4
            radius: 14
            color: "#313244"
            border.color: win.bubbleIsInput ? "#585b70" : "#89b4fa"
            border.width: 2
        }
        // Triangle tail (points right toward cat)
        Canvas {
            anchors.right: parent.right
            anchors.rightMargin: -14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            width: 20; height: 30
            onPaint: {
                var ctx = getContext("2d");
                ctx.fillStyle = "#313244";
                ctx.strokeStyle = win.bubbleIsInput ? "#585b70" : "#89b4fa";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(0, 2); ctx.lineTo(18, 15); ctx.lineTo(0, 28);
                ctx.fill(); ctx.stroke();
                ctx.fillStyle = "#313244";
                ctx.fillRect(0, 4, 3, 22);
            }
        }

        // Scrollable text area
        Flickable {
            id: textFlickable
            x: 12; y: 12
            width: parent.width - 28
            height: parent.height - 24 - (inputArea.visible ? win.inputAreaHeight : 0)
            contentHeight: bubbleTextEdit.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: bubbleTextEdit
                width: parent.width
                text: win.bubbleText
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                color: "#cdd6f4"
                readOnly: true
                selectByMouse: true
                selectionColor: "#89b4fa"
                selectedTextColor: "#1e1e2e"
            }
        }

        // Input area pinned at bottom
        Column {
            id: inputArea
            visible: win.bubbleIsInput
            x: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: parent.width - 28
            spacing: 4

            TextField {
                id: inputField
                width: parent.width
                height: 34
                placeholderText: "Type here..."
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
                    if (text.trim().length > 0) {
                        var msg = text.trim();
                        sendChat(msg);
                        focus = false;
                        win.bubbleText = "Thinking... \uD83D\uDC31";
                        win.bubbleIsInput = false;
                        bubble.visible = true;
                    }
                }
                Keys.onEscapePressed: {
                    if (!win.chatMode && win.wsConnected)
                        sendToMcp({ type: "user_response", text: "[dismissed]" });
                    win.chatMode = false;
                    hideBubble();
                    win.catState = "idle";
                    behaviorTimer.start();
                }
            }

            Text {
                text: "Enter to send | Esc to close"
                font.pixelSize: 9
                color: "#6c7086"
            }
        }
    }

    Timer { id: autoDismiss; interval: 6000; onTriggered: hideBubble() }

    // === CAT SPRITE (right side when bubble visible, centered otherwise) ===
    Item {
        id: sprite
        width: bubble.visible ? win.catSpriteWidth : 200
        height: bubble.visible ? 140 : 180
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        transform: Scale {
            origin.x: sprite.width / 2
            xScale: win.facingRight ? 1 : -1
        }

        Image {
            anchors.fill: parent
            source: {
                if (win.catState === "pounce") return "file:///C:/Software/copilot-cat/assets/cat_pounce.svg";
                if (win.catState === "land") return "file:///C:/Software/copilot-cat/assets/cat_land.svg";
                if (win.catState === "sit") return "file:///C:/Software/copilot-cat/assets/cat_sit.svg";
                if (win.catState === "stretch") return "file:///C:/Software/copilot-cat/assets/cat_stretch.svg";
                if (win.catState === "jump") return "file:///C:/Software/copilot-cat/assets/cat_jump.svg";
                if (win.catState === "tail_swish") return "file:///C:/Software/copilot-cat/assets/cat_tail_swish" + (win.tailSwishFrame + 1) + ".svg";
                if (win.catState === "walking") {
                    var dir = win.facingRight ? "" : "_left";
                    return "file:///C:/Software/copilot-cat/assets/cat_walk" + (win.walkFrame+1) + dir + ".svg";
                }
                return "file:///C:/Software/copilot-cat/assets/cat_idle.svg";
            }
            sourceSize.width: 480; sourceSize.height: 480
            fillMode: Image.PreserveAspectFit; smooth: true
        }

        Item {
            id: catHitbox
            width: 122
            height: 116
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10

            MouseArea {
                id: catMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                Timer {
                    id: dragHoldTimer
                    interval: win.dragHoldDelayMs
                    repeat: false
                    onTriggered: {
                        if (!catMouseArea.pressed) return;

                        var globalPos = catHitbox.mapToGlobal(catMouseArea.mouseX, catMouseArea.mouseY);
                        win.dragArmed = true;
                        win.dragArmX = globalPos.x;
                        win.dragArmY = globalPos.y;
                        win.resumeBehaviorAfterDrag = behaviorTimer.running;
                        behaviorTimer.stop();
                        win.catState = "sit";
                    }
                }

                onPressed: {
                    win.dragArmed = false;
                    win.dragging = false;
                    win.suppressClick = false;
                    dragHoldTimer.restart();
                }
                onPositionChanged: function(mouse) {
                    var globalPos = catHitbox.mapToGlobal(mouse.x, mouse.y);

                    if (win.dragArmed && !win.dragging) {
                        var deltaX = globalPos.x - win.dragArmX;
                        var deltaY = globalPos.y - win.dragArmY;
                        if (Math.abs(deltaX) >= 2 || Math.abs(deltaY) >= 2)
                            win.beginDrag(globalPos);
                    }

                    if (!win.dragging) return;
                    win.x = win.clampX(globalPos.x - win.dragOffsetX);
                    win.y = win.clampY(globalPos.y - win.dragOffsetY);
                }
                onReleased: {
                    dragHoldTimer.stop();
                    win.dragArmed = false;
                    if (!win.dragging) return;
                    win.dragging = false;
                    behaviorTimer.stop();
                    if (win.restoreBubbleAfterDrag) {
                        win.restoreBubbleAfterDrag = false;
                        showBubble(win.savedBubbleText, win.savedBubbleIsInput);
                    } else {
                        win.catState = "sit";
                    }
                    win.resumeBehaviorAfterDrag = false;
                    suppressClickReset.restart();
                }
                onCanceled: {
                    dragHoldTimer.stop();
                    win.dragArmed = false;
                    win.dragging = false;
                    behaviorTimer.stop();
                    if (!bubble.visible)
                        win.catState = "sit";
                    win.resumeBehaviorAfterDrag = false;
                    suppressClickReset.restart();
                }
                onClicked: {
                    if (win.suppressClick) {
                        win.suppressClick = false;
                        return;
                    }
                    if (win.catState === "pounce" || win.catState === "land") return;
                    if (bubble.visible) {
                        if (!win.bubbleIsInput) {
                            win.chatMode = false;
                            hideBubble();
                            win.catState = "idle";
                            behaviorTimer.start();
                        }
                        return;
                    }
                    if (win.catState === "sit") {
                        win.chatMode = true;
                        showBubble("What's on your mind?", true);
                    } else {
                        behaviorTimer.stop();
                        win.catState = "sit";
                    }
                }
            }
        }
    }

    // === POUNCE ===
    SequentialAnimation {
        id: introAnimation
        running: true
        ParallelAnimation {
            NumberAnimation { target: win; property: "x"; from: -win.width; to: win.screenW / 4; duration: 700; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: win; property: "y"; from: win.restY; to: win.restY - 100; duration: 250; easing.type: Easing.OutQuad }
                NumberAnimation { target: win; property: "y"; from: win.restY - 100; to: win.restY; duration: 450; easing.type: Easing.OutBounce }
            }
        }
        ScriptAction { script: win.catState = "land" }
        PauseAnimation { duration: 400 }
        ScriptAction { script: win.catState = "sit" }
        PauseAnimation { duration: 800 }
        ScriptAction { script: showBubble(win.wsConnected ? "Hi! I'm Copilot Cat! Click me to chat!" : "Hi! Click me to chat! (MCP server not connected)", false) }
        PauseAnimation { duration: 4000 }
        ScriptAction { script: { hideBubble(); win.catState = "idle"; behaviorTimer.start(); } }
    }

    // === WALK ===
    Timer { interval: 180; running: win.catState === "walking"; repeat: true; onTriggered: win.walkFrame = (win.walkFrame + 1) % 4 }
    Timer {
        interval: 16; running: win.catState === "walking"; repeat: true
        onTriggered: {
            var nx = win.x + (win.facingRight ? 2 : -2);
            if (nx > win.screenW - win.width - 10) win.facingRight = false;
            else if (nx < 10) win.facingRight = true;
            win.x = nx;
        }
    }

    // === TAIL SWISH ===
    Timer { interval: 300; running: win.catState === "tail_swish"; repeat: true; onTriggered: win.tailSwishFrame = (win.tailSwishFrame + 1) % 4 }
    Timer { id: tailSwishDuration; interval: 3600; onTriggered: { win.catState = "idle"; } }

    // === STRETCH ===
    Timer { id: stretchDuration; interval: 3000; onTriggered: { win.catState = "idle"; } }

    // === BEHAVIOR ===
    Timer {
        id: behaviorTimer
        interval: 3000 + Math.random() * 3000
        repeat: true
        onTriggered: {
            if (bubble.visible) return;
            if (win.catState === "walking") { win.catState = "idle"; interval = 2000 + Math.random() * 2000; }
            else if (win.catState === "idle") {
                var roll = Math.random();
                if (roll < 0.5) {
                    win.catState = "walking";
                    if (Math.random() > 0.5) win.facingRight = !win.facingRight;
                    interval = 3000 + Math.random() * 4000;
                } else if (roll < 0.7) {
                    win.catState = "tail_swish";
                    tailSwishDuration.restart();
                    interval = 4000 + Math.random() * 3000;
                } else if (roll < 0.85) {
                    win.catState = "stretch";
                    stretchDuration.restart();
                    interval = 5000 + Math.random() * 3000;
                } else {
                    win.catState = "jump";
                    jumpAnimation.start();
                    interval = 3000 + Math.random() * 3000;
                }
            }
        }
    }

    // === JUMP ANIMATION ===
    SequentialAnimation {
        id: jumpAnimation
        NumberAnimation { target: win; property: "y"; to: win.y - 60; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: win; property: "y"; to: win.restY; duration: 350; easing.type: Easing.OutBounce }
        ScriptAction { script: { win.catState = "land"; } }
        PauseAnimation { duration: 300 }
        ScriptAction { script: { win.catState = "idle"; } }
    }
}
