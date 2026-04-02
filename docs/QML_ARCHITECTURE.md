# QML Architecture — Copilot Cat

This document provides a comprehensive technical reference for how QML is used in the Copilot Cat desktop pet application. It covers engine setup, component design, state machines, animation systems, C++/QML interop, and testing.

---

## Table of Contents

1. [QML Engine Setup](#1-qml-engine-setup)
2. [Main.qml Deep Dive](#2-mainqml-deep-dive)
3. [SetupWizard.qml](#3-setupwizardqml)
4. [ReplyBubble.qml](#4-replybubbleqml)
5. [ThoughtBubble.qml](#5-thoughtbubbleqml)
6. [CatSprite.qml](#6-catspriteqml)
7. [C++ ↔ QML Interface](#7-c--qml-interface)
8. [QML Patterns Used](#8-qml-patterns-used)
9. [Testing QML](#9-testing-qml)

---

## 1. QML Engine Setup

### How `main.cpp` Creates the QML Engine

The application entry point (`src/main.cpp`) bootstraps Qt and the QML engine in a specific sequence:

```cpp
// Enable transparent windows (must be called before QGuiApplication)
QQuickWindow::setDefaultAlphaBuffer(true);

QGuiApplication app(argc, argv);
QQuickStyle::setStyle("Basic");

CatConfig config;
CopilotBridge bridge(&config);

QQmlApplicationEngine engine;
engine.rootContext()->setContextProperty("catConfig", &config);
engine.rootContext()->setContextProperty("copilotBridge", &bridge);

const QUrl url(u"qrc:/CopilotCat/qml/Main.qml"_qs);
engine.load(url);
```

Key steps:

1. **Alpha buffer** — `QQuickWindow::setDefaultAlphaBuffer(true)` is called *before* `QGuiApplication` construction, enabling per-pixel transparency on Windows.
2. **Style** — `QQuickStyle::setStyle("Basic")` forces the Basic style for `QtQuick.Controls`, avoiding platform-native styling that would clash with the custom dark theme.
3. **Context properties** — Two C++ objects are injected into the QML root context as global properties:
   - `catConfig` (`CatConfig*`) — configuration, auth, model fetching
   - `copilotBridge` (`CopilotBridge*`) — chat message sending, response handling
4. **QML loading** — The engine loads `Main.qml` via a `qrc:/` URL, meaning the file is compiled into the binary via Qt's resource system.

### QML Module Registration (CMake)

The `CMakeLists.txt` registers the QML module using `qt_add_qml_module`:

```cmake
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
```

This does several things:
- Assigns the module URI `CopilotCat`, so the main QML file is addressable as `qrc:/CopilotCat/qml/Main.qml`.
- Compiles all listed QML files into the Qt Resource System (`.qrc`), bundling them into the executable.
- Generates a `qmldir` file for the module, making `CatSprite`, `ThoughtBubble`, `ReplyBubble`, and `SetupWizard` available as types within `Main.qml` without explicit imports.

### Resource Compilation (`qrc:/` URLs)

In the compiled (production) build, all QML files are accessed via `qrc:/CopilotCat/qml/...` URLs. This means:
- No external QML files are needed at runtime.
- The `qrc:/` scheme is resolved by Qt's resource system, which reads from data embedded in the binary.
- SVG assets are **not** compiled into resources — they are loaded from disk via `file:///` URLs (see [Section 2: SVG Sprite Loading](#svg-sprite-loading)).

### Error Handling

```cpp
QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
    &app, []() { QCoreApplication::exit(-1); },
    Qt::QueuedConnection);
```

If the QML engine fails to instantiate the root component (e.g., due to syntax errors), the application exits with code `-1`.

---

## 2. Main.qml Deep Dive

`qml/Main.qml` is the primary QML file for the compiled application. It contains all cat behavior logic, animations, WebSocket communication, bubble UI, drag-and-drop, and setup wizard integration in a single ~690-line file.

### Window Configuration

```qml
Window {
    id: win
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WA_TranslucentBackground
    color: "transparent"
    // ...
}
```

| Flag | Purpose |
|------|---------|
| `Qt.FramelessWindowHint` | Removes the title bar and window borders |
| `Qt.WindowStaysOnTopHint` | Keeps the cat above all other windows |
| `Qt.WA_TranslucentBackground` | Enables per-pixel transparency so the cat appears to float on the desktop |
| `color: "transparent"` | Makes the window background fully transparent |

### Properties

The `Window` element declares numerous properties that form the application state:

#### Layout / Sizing

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `compactWidth` | `int` | `200` | Window width when bubble is hidden |
| `compactHeight` | `int` | `180` | Window height when bubble is hidden |
| `bubbleWidth` | `int` | `260` | Width allocated for the speech bubble |
| `catSpriteWidth` | `int` | `120` | Width of the cat sprite area when bubble is visible |
| `bubblePadding` | `int` | `10` | Gap between bubble and sprite |
| `screenW` / `screenH` | `int` | `Screen.width/height` | Cached screen dimensions |
| `catBottom` | `int` | `screenH - 48` | Y-coordinate of the cat's feet (above the taskbar) |
| `restY` | `int` | `catBottom - height` | Default Y-position of the window |

#### Animation State

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `catState` | `string` | `"pounce"` | Current animation state (see state machine below) |
| `facingRight` | `bool` | `true` | Horizontal flip direction |
| `walkFrame` | `int` | `0` | Current walk animation frame index (0–7) |
| `walkFrameCounter` | `int` | `0` | Raw tick counter (increments every 33ms during walk) |
| `tailSwishFrame` | `int` | `0` | Current tail swish frame index (0–7) |
| `walkFrameCount` | `int` | `8` | Total walk animation frames |
| `walkStepPx` | `int` | `3` | Pixels moved per walk tick |
| `walkFrameMod` | `int` | `3` | Ticks per animation frame change |
| `tailSwishFrameCount` | `int` | `8` | Total tail swish frames |
| `tailSwishMs` | `int` | `150` | Milliseconds between tail swish frames |

#### Bubble / Chat State

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `bubbleIsInput` | `bool` | `false` | Whether the bubble shows an input field |
| `bubbleText` | `string` | `""` | Current bubble display text |
| `chatMode` | `bool` | `false` | Whether the user initiated a chat (vs. responding to `ask_user`) |
| `chatReplyPending` | `bool` | `false` | Waiting for the first real reply from the backend |
| `chatReplyReceived` | `bool` | `false` | First reply has been accepted; dedup lock is active |

#### Drag State

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `dragArmed` | `bool` | `false` | Hold timer fired; drag begins on next mouse move |
| `dragging` | `bool` | `false` | Currently in a drag operation |
| `dragOffsetX` / `dragOffsetY` | `real` | `0` | Offset from window origin to grab point |
| `dragArmX` / `dragArmY` | `real` | `0` | Global position when drag was armed |
| `resumeBehaviorAfterDrag` | `bool` | `false` | Whether behaviorTimer was running before drag |
| `restoreBubbleAfterDrag` | `bool` | `false` | Whether to re-show the bubble after drag ends |
| `savedBubbleText` / `savedBubbleIsInput` | various | — | Saved bubble state for restoration |
| `suppressClick` | `bool` | `false` | Prevents click handler from firing after a drag release |
| `dragHoldDelayMs` | `int` | `50` | Milliseconds before a press becomes a drag-arm |

#### Misc

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `exitingCat` | `bool` | `false` | Exit animation in progress; blocks all interaction |
| `introPlayed` | `bool` | `false` | Prevents intro animation from replaying |
| `wsConnected` | `bool` | `false` | WebSocket connection status |
| `reconnectDelay` | `int` | `1000` | Current reconnect delay (exponential backoff) |
| `reconnectMax` | `int` | `30000` | Maximum reconnect delay |

### The Complete State Machine

The cat has the following animation states, managed by the `catState` string property:

```
                    ┌──────────────────────────────────────────┐
                    │              Application Start           │
                    └────────────────┬─────────────────────────┘
                                     │
                                     ▼
                               ┌──────────┐
                               │  pounce  │ (intro animation: slide in from left)
                               └────┬─────┘
                                    │ 700ms
                                    ▼
                               ┌──────────┐
                               │   land   │ (landing pose)
                               └────┬─────┘
                                    │ 400ms
                                    ▼
                               ┌──────────┐
                               │   sit    │ (greeting bubble shown, 800ms)
                               └────┬─────┘
                                    │ 4s bubble + dismiss
                                    ▼
                    ┌──────────────────────────────────────────┐
                    │               idle                       │◄──────────────────┐
                    │  (default resting state)                 │                   │
                    └────────┬────────┬────────┬────────┬──────┘                   │
                  50%        │  20%   │  15%   │  15%   │                          │
                    ▼        ▼        ▼        ▼        │                          │
              ┌─────────┐ ┌────────────┐ ┌─────────┐ ┌──────┐                     │
              │ walking │ │ tail_swish │ │ stretch │ │ jump │                     │
              │ (3-7s)  │ │  (3.6s)    │ │  (3s)   │ │      │                     │
              └────┬────┘ └─────┬──────┘ └────┬────┘ └──┬───┘                     │
                   │            │              │         │                          │
                   │            │              │         ▼                          │
                   │            │              │    ┌──────────┐                    │
                   │            │              │    │   land   │ (300ms)            │
                   │            │              │    └────┬─────┘                    │
                   │            │              │         │                          │
                   └────────────┴──────────────┴─────────┴──────────────────────────┘
                            (all return to idle)

              Special transitions:
              ─────────────────────
              • Any state → "sit" (user click, drag, bubble shown)
              • "sit" + user click → showBubble (chat mode)
              • Right-click → Context menu → beginExit()
              • Exit: sit → farewell bubble → jump → pounce → off-screen → Qt.quit()
```

### State Transitions (behaviorTimer)

The `behaviorTimer` is a repeating `Timer` that drives the idle behavior loop. Its interval is randomized on each tick:

```qml
Timer {
    id: behaviorTimer
    interval: 4000
    repeat: true
    onTriggered: {
        if (bubble.visible) return;  // Don't change state while bubble is shown
        if (win.catState === "walking") {
            win.catState = "idle";
            win.y = win.restY;       // Reset Y after walk bobbing
            interval = 2000 + Math.random() * 2000;  // 2-4s pause
        }
        else if (win.catState === "idle") {
            var roll = Math.random();
            if (roll < 0.5) {         // 50% — walk
                win.catState = "walking";
                if (Math.random() > 0.5) win.facingRight = !win.facingRight;
                interval = 3000 + Math.random() * 4000;  // walk for 3-7s
            } else if (roll < 0.7) {  // 20% — tail swish
                win.catState = "tail_swish";
                tailSwishDuration.restart();
                interval = 4000 + Math.random() * 3000;
            } else if (roll < 0.85) { // 15% — stretch
                win.catState = "stretch";
                stretchDuration.restart();
                interval = 5000 + Math.random() * 3000;
            } else {                  // 15% — jump
                win.catState = "jump";
                jumpAnimation.start();
                interval = 3000 + Math.random() * 3000;
            }
        }
    }
}
```

**Probability distribution when idle:**

| Behavior | Probability | Duration |
|----------|-------------|----------|
| Walk | 50% | 3–7 seconds |
| Tail swish | 20% | 3.6 seconds (fixed) |
| Stretch | 15% | 3 seconds (fixed) |
| Jump | 15% | ~850ms animation |

### Walk Animation System

Walking uses a high-frequency timer (33ms ≈ 30 FPS) that moves the window and advances sprite frames:

```qml
Timer {
    interval: 33
    running: win.catState === "walking"
    repeat: true
    onTriggered: {
        // Move horizontally
        var nx = win.x + (win.facingRight ? win.walkStepPx : -win.walkStepPx);

        // Bounce at screen edges
        if (nx > win.screenW - win.width - 10) win.facingRight = false;
        else if (nx < 10) win.facingRight = true;
        win.x = nx;

        // Y-axis bobbing (sinusoidal)
        win.y = win.restY - Math.abs(Math.sin(win.walkFrameCounter * 0.15)) * 3;

        // Advance sprite frame every walkFrameMod ticks
        win.walkFrameCounter++;
        if (win.walkFrameCounter % win.walkFrameMod === 0)
            win.walkFrame = (win.walkFrame + 1) % win.walkFrameCount;
    }
}
```

- **Speed**: 3px per tick × 30 ticks/sec ≈ 90 px/sec
- **Frame cycling**: Every 3rd tick (`walkFrameMod`), `walkFrame` advances through 8 frames (`walkFrameCount`)
- **Bobbing**: `Math.abs(Math.sin(counter * 0.15)) * 3` creates a subtle 3px vertical bounce
- **Edge bouncing**: Reverses `facingRight` at screen edges (10px margin)

### Tail Swish System

```qml
Timer {
    interval: win.tailSwishMs   // 150ms
    running: win.catState === "tail_swish"
    repeat: true
    onTriggered: win.tailSwishFrame = (win.tailSwishFrame + 1) % win.tailSwishFrameCount
}
Timer {
    id: tailSwishDuration
    interval: 3600
    onTriggered: win.catState = "idle"
}
```

- Cycles through 8 tail swish frames at 150ms each (1.2s per full cycle, 3 cycles in 3.6s)
- The `tailSwishDuration` timer ends the animation and returns to idle

### The Bubble System

#### `showBubble(text, isInput)`

```qml
function showBubble(text, isInput) {
    behaviorTimer.stop();
    autoDismiss.stop();
    win.catState = "sit";
    win.bubbleText = text;
    win.bubbleIsInput = isInput;
    bubble.visible = true;
    resizeDelay.start();              // 10ms delay for text layout
    if (isInput) {
        inputField.text = "";
        focusDelay.start();           // 100ms delay for focus
    } else if (!win.chatReplyPending) {
        autoDismiss.restart();        // 6s auto-dismiss (only for non-pending replies)
    }
}
```

#### `hideBubble()`

```qml
function hideBubble() {
    bubble.visible = false;
    win.bubbleIsInput = false;
    resizeForBubble(false);           // Shrinks window back to compact size
}
```

#### `resizeForBubble(expanded)`

When the bubble appears, the window expands from `compactWidth × compactHeight` to accommodate both the bubble and the cat sprite side by side:

```qml
function resizeForBubble(expanded) {
    if (expanded) {
        var bubbleH = bubble.height > 0 ? bubble.height : 100;
        targetWidth = bubbleWidth + bubblePadding + catSpriteWidth;  // 260 + 10 + 120 = 390
        targetHeight = Math.max(bubbleH + 20, compactHeight);
        targetHeight = Math.min(targetHeight, screenH - 100);
    } else {
        targetWidth = compactWidth;   // 200
        targetHeight = compactHeight; // 180
    }
    // Anchor the cat's right edge and bottom edge
    var oldRight = x + width;
    var catBottomY = y + height;
    width = targetWidth;
    height = targetHeight;
    x = clampX(oldRight - width);
    y = clampY(catBottomY - height);
}
```

The window grows leftward (keeping the cat's right edge in place) and upward (keeping the cat's bottom edge at the same position).

#### Auto-Dismiss Timer

```qml
Timer { id: autoDismiss; interval: 6000; onTriggered: hideBubble() }
```

Fires 6 seconds after showing a speech bubble (not an input bubble, and not while waiting for a chat reply).

### Chat Flow — `sendChat(msg)`

This function routes messages based on the configured backend:

```qml
function sendChat(msg) {
    var b = catConfig.backend;
    if (b === "mcp" || (b === "auto" && win.wsConnected)) {
        // Route via WebSocket to MCP server
        if (!win.wsConnected) {
            showBubble("Meow! MCP server not connected...", false);
            return;
        }
        if (win.chatMode) {
            win.chatReplyPending = true;
            win.chatReplyReceived = false;
            sendToMcp({ type: "chat", text: msg });
        } else {
            sendToMcp({ type: "user_response", text: msg });
        }
        chatTimeout.restart();
    } else {
        // Route via C++ CopilotBridge (OpenRouter, command, or fallback)
        copilotBridge.sendMessage(msg);
    }
}
```

**Routing logic:**

```
Backend = "mcp"  ───────────────────────────────────► WebSocket (always)
Backend = "auto" + wsConnected ─────────────────────► WebSocket
Backend = "auto" + !wsConnected ────────────────────► CopilotBridge (C++)
Backend = "openrouter" / "command" / anything else ─► CopilotBridge (C++)
```

### The Dedup Guard

When the user sends a chat message via the MCP WebSocket, the AI backend often sends multiple duplicate `show_bubble` messages (e.g., the same response echoed multiple times due to tool-call routing). The dedup guard prevents this:

```
┌─────────────┐     User sends chat     ┌─────────────────────────────────┐
│  chatMode   │ ──────────────────────►  │  chatReplyPending = true        │
│  = true     │                          │  chatReplyReceived = false      │
└─────────────┘                          └────────────┬────────────────────┘
                                                      │
                           ┌──────────────────────────┼──────────────────────┐
                           ▼                          ▼                      ▼
                    "Thinking..." msg          First real reply       Duplicate replies
                    ┌────────────┐           ┌──────────────┐       ┌──────────────────┐
                    │ SHOWN      │           │ SHOWN        │       │ BLOCKED          │
                    │ (pending   │           │ pending=false│       │ chatReplyReceived │
                    │  stays on) │           │ received=true│       │ = true            │
                    └────────────┘           └──────────────┘       └──────────────────┘
                                                      │
                                                      ▼
                                              chatReplyLock timer (10s)
                                              ┌────────────────────────┐
                                              │ chatReplyReceived=false│
                                              │ (unlock for future)    │
                                              └────────────────────────┘
```

**Key rules:**
1. Messages starting with `"Thinking..."` do NOT engage the lock — they pass through while `chatReplyPending` is true.
2. The first non-"Thinking..." message flips `chatReplyPending → false` and `chatReplyReceived → true`.
3. While `chatReplyReceived` is true, all `show_bubble` messages are blocked.
4. The `chatReplyLock` timer (10 seconds) resets `chatReplyReceived` to false, re-enabling future messages.
5. Starting a new chat (`qmlStartChat()`) also resets both flags.

### WebSocket Connection

```qml
WebSocket {
    id: ws
    url: "ws://127.0.0.1:9922"
    active: catConfig.backend === "auto" || catConfig.backend === "mcp"
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
```

**Reconnection strategy:**
- Exponential backoff: 1s → 2s → 4s → 8s → ... → 30s (capped)
- Resets to 1s on successful connection
- Reconnection requires toggling `ws.active` off then on (via two chained single-shot timers with a 100ms gap):

```qml
Timer { id: reconnectTimer; onTriggered: { ws.active = false; reactivateTimer.start(); } }
Timer { id: reactivateTimer; interval: 100; onTriggered: { ws.active = true; } }
```

The WebSocket is only active when the backend is `"auto"` or `"mcp"`. Other backends (OpenRouter, command) don't use WebSocket at all.

#### `handleMcpMessage(data)`

Processes three message types from the MCP server:

| `data.type` | Action |
|-------------|--------|
| `"show_bubble"` | Shows speech bubble with dedup guard logic |
| `"ask_user"` | Shows input bubble (disables `chatMode` so response goes as `user_response`) |
| `"action"` | Changes cat state: `"sit"` (stop behavior), `"walk"` (start walking), anything else → `"idle"` |

### Drag and Drop Implementation

The drag system uses a three-phase approach: arm → drag → release.

**Phase 1: Arm (mouse press + hold)**

```qml
onPressed: function(mouse) {
    if (win.exitingCat) return;
    if (mouse.button === Qt.RightButton) return;
    win.dragArmed = false;
    win.dragging = false;
    win.suppressClick = false;
    dragHoldTimer.restart();  // 50ms delay before arming
}
```

**Phase 2: Drag (mouse move after arm)**

```qml
onPositionChanged: function(mouse) {
    var globalPos = catHitbox.mapToGlobal(mouse.x, mouse.y);
    if (win.dragArmed && !win.dragging) {
        var deltaX = globalPos.x - win.dragArmX;
        var deltaY = globalPos.y - win.dragArmY;
        if (Math.abs(deltaX) >= 2 || Math.abs(deltaY) >= 2)
            win.beginDrag(globalPos);  // 2px dead zone before drag starts
    }
    if (!win.dragging) return;
    win.x = win.clampX(globalPos.x - win.dragOffsetX);
    win.y = win.clampY(globalPos.y - win.dragOffsetY);
}
```

**Phase 3: Release**

```qml
onReleased: {
    dragHoldTimer.stop();
    win.dragArmed = false;
    if (!win.dragging) return;
    win.dragging = false;
    if (win.restoreBubbleAfterDrag) {
        win.restoreBubbleAfterDrag = false;
        showBubble(win.savedBubbleText, win.savedBubbleIsInput);
    } else {
        win.catState = "sit";
    }
    suppressClickReset.restart();  // 1ms timer to clear suppressClick
}
```

**`beginDrag(globalPos)`** saves the current bubble state (if visible), hides the bubble, sets `dragging = true`, and records the grab offset. The `suppressClick` flag prevents the click handler from firing when the user releases after a drag.

### Right-Click Context Menu

```qml
Menu {
    id: contextMenu
    MenuItem {
        text: "Close"
        onTriggered: win.beginExit()
    }
}
```

Opened via `contextMenu.popup()` when right-clicking the cat hitbox.

### Exit Animation Sequence

```
1. beginExit()
   ├─ Stop all timers
   ├─ Show random farewell bubble ("See ya later, hu-meow-n! 😽")
   └─ Start exitSequenceTimer (2s)

2. exitSequenceTimer fires (2s later)
   ├─ Hide bubble
   ├─ catState = "jump"
   └─ Start exitJumpAnimation

3. exitJumpAnimation (SequentialAnimation)
   ├─ Rise: y -= 120 over 300ms (OutQuad)
   ├─ catState = "pounce"
   ├─ Fall + slide: y → screenH + 100, x += ±200 over 500ms (InQuad)
   └─ Qt.quit()
```

### Intro Animation

```qml
SequentialAnimation {
    id: introAnimation
    running: !catConfig.needsSetup && !win.introPlayed
    onRunningChanged: if (running) win.introPlayed = true
    // ...
}
```

The intro only plays once (`introPlayed` guard) and only if setup is not needed:

1. **Pounce in**: Slide from `x = -width` to `screenW / 4` over 700ms with `OutCubic` easing
2. **Arc**: Simultaneously, y goes up 100px (250ms OutQuad) then bounces down (450ms OutBounce)
3. **Land**: `catState = "land"`, hold 400ms
4. **Sit**: `catState = "sit"`, hold 800ms
5. **Greet**: Show greeting bubble (content depends on WebSocket status), hold 4s
6. **Start**: Hide bubble, `catState = "idle"`, start `behaviorTimer`

### Setup Wizard Integration

```qml
SetupWizard {
    id: setupWizard
    onSetupComplete: {
        setupWizard.visible = false;
        win.catState = "idle";
        win.width = win.compactWidth;
        win.height = win.compactHeight;
        win.y = win.restY;
        behaviorTimer.start();
        showBubble("Purrfect! I'm all set up! Click me to chat!", false);
    }
}

Component.onCompleted: {
    if (catConfig.needsSetup) {
        win.catState = "sit";
        win.x = win.screenW / 2 - win.compactWidth / 2;
        win.y = win.restY;
        bubble.visible = false;
        setupWizard.start();
    }
}
```

If `catConfig.needsSetup` is `true` (no config file found), `Component.onCompleted` centers the cat, skips the intro animation, and opens the setup wizard. The intro animation's `running` binding (`!catConfig.needsSetup && !win.introPlayed`) ensures it doesn't play during setup.

### SVG Sprite Loading

All SVG sprites are loaded via `file:///` URLs with absolute paths:

```qml
Image {
    source: {
        if (win.catState === "pounce") return "file:///C:/Software/copilot-cat/assets/cat_pounce.svg";
        if (win.catState === "walking") {
            var dir = win.facingRight ? "" : "_left";
            return "file:///C:/Software/copilot-cat/assets/cat_walk_b" + (win.walkFrame+1) + dir + ".svg";
        }
        return "file:///C:/Software/copilot-cat/assets/cat_idle.svg";
    }
    sourceSize.width: 210; sourceSize.height: 225
    fillMode: Image.PreserveAspectFit
    cache: true
    asynchronous: false
}
```

**The Image source binding expression** is a computed property that maps `catState` + `facingRight` + frame indices to SVG file paths:

| catState | File pattern |
|----------|-------------|
| `pounce` | `cat_pounce.svg` |
| `land` | `cat_land.svg` |
| `sit` | `cat_sit.svg` |
| `peek` | `cat_peek.svg` |
| `stretch` | `cat_stretch.svg` |
| `jump` | `cat_jump.svg` |
| `tail_swish` | `cat_tail_swish_b{1-8}.svg` |
| `walking` | `cat_walk_b{1-8}[_left].svg` |
| `idle` (default) | `cat_idle.svg` |

**Preloading** uses invisible `Repeater` elements to force Qt to decode and cache all SVG frames at startup, preventing hitches during animation:

```qml
Repeater { model: 8; Image { visible: false; source: "file:///.../cat_walk_b" + (index+1) + ".svg"; cache: true } }
Repeater { model: 8; Image { visible: false; source: "file:///.../cat_walk_b" + (index+1) + "_left.svg"; cache: true } }
Repeater { model: 8; Image { visible: false; source: "file:///.../cat_tail_swish_b" + (index+1) + ".svg"; cache: true } }
```

> **Note:** The hardcoded `file:///C:/Software/copilot-cat/assets/...` paths must be updated if the repository is moved.

---

## 3. SetupWizard.qml

### Window vs Item

`SetupWizard` is a separate `Window`, not an `Item` inside the main window. This is intentional:
- It has its own title bar, close button, and can be independently moved
- It is centered on screen via `x: (Screen.width - width) / 2; y: (Screen.height - height) / 2`
- It starts invisible (`visible: false`) and is shown via `start()`
- Being a separate window avoids the transparent/frameless styling of the main cat window

```qml
Window {
    id: wizard
    visible: false
    title: "Copilot Cat Setup"
    width: 360; height: 320
    color: "#1e1e2e"  // Catppuccin Mocha base
    // ...
}
```

### Multi-Step Flow

The wizard uses a `currentStep` integer property with conditional visibility to implement a step-by-step flow:

```
Step 0: Backend Selection
    ├─ "GitHub Copilot" → Step 1
    └─ "OpenRouter" → Step 2

Step 1: Copilot Sign-in
    ├─ "Sign in with GitHub" → calls catConfig.startCopilotAuth()
    │   └─ onCopilotDeviceCode signal → Step 4
    └─ "< Back" → Step 0

Step 2: OpenRouter API Key
    ├─ Enter key + "Fetch free models" → calls catConfig.fetchModels(key)
    │   └─ onModelsReceived signal → Step 3
    └─ "< Back" → Step 0

Step 3: Model Selection
    ├─ Click model → calls catConfig.saveConfig({...})
    │   └─ onConfigSaved signal → wizard closes, setupComplete() emitted
    └─ "< Back" → Step 2

Step 4: Device Code Display
    ├─ Shows code for user to enter in browser
    ├─ onCopilotAuthSuccess → onConfigSaved → wizard closes
    └─ "< Cancel" → calls catConfig.cancelCopilotAuth(), → Step 0
```

### Step 0: Backend Selection

Uses a `Repeater` with an inline model of objects to create two styled buttons:

```qml
Repeater {
    model: [
        { label: "GitHub Copilot", value: "copilot" },
        { label: "OpenRouter", value: "openrouter" }
    ]
    delegate: Rectangle {
        // Hover effect via containsMouse
        color: ma0.containsMouse ? "#45475a" : "#313244"
        MouseArea {
            id: ma0
            hoverEnabled: true
            onClicked: {
                wizard.selectedBackend = modelData.value;
                if (modelData.value === "copilot") wizard.currentStep = 1;
                else wizard.currentStep = 2;
            }
        }
    }
}
```

### Step 2: OpenRouter API Key Input

The `TextField` calls `catConfig.fetchModels(apiKey)` when the user presses Enter or clicks the fetch button. The `fetchingModels` boolean disables the button and shows "Fetching..." text.

### Step 3: Model List

A `ListView` displays free models filtered from the `onModelsReceived` signal:

```qml
Connections {
    target: catConfig
    function onModelsReceived(models) {
        var free = [];
        for (var i = 0; i < models.length; i++) {
            if (models[i].isFree) free.push(models[i]);
        }
        wizard.modelList = free;
        wizard.currentStep = 3;
    }
}
```

Clicking a model calls `catConfig.saveConfig(...)` with the backend, API key (retrieved via `catConfig.lastApiKey()`), and model ID.

### Step 4: Device Code Display

Shows the code in a selectable `TextEdit` (read-only, `selectByMouse: true`) so the user can copy it. A status message toggles between "Waiting for authorization..." and "Authorized!" based on `copilotAuthPending`.

### Signal Connections

The `Connections` element to `catConfig` handles all asynchronous events:

| Signal | Handler Action |
|--------|---------------|
| `onModelsReceived(models)` | Filter free models, populate list, go to step 3 |
| `onModelsFetchFailed(error)` | Show error in status text |
| `onConfigSaved()` | Hide wizard, emit `setupComplete()` |
| `onCopilotDeviceCode(userCode, verificationUri)` | Store code, go to step 4 |
| `onCopilotAuthSuccess()` | Clear pending flag (configSaved follows) |
| `onCopilotAuthFailed(error)` | Show error, return to step 0 |

---

## 4. ReplyBubble.qml

> **Note:** `ReplyBubble.qml` is a standalone component. In `Main.qml`, the bubble is implemented inline within the main window.

### Component Structure

```qml
Item {
    id: root
    property string message: ""
    property int displayDuration: 8000

    width: Math.min(Math.max(replyText.implicitWidth + 36, 140), 300)
    height: replyText.implicitHeight + 50
    visible: false
    opacity: 0
    // ...
}
```

### TextEdit for Selectable Text

The bubble uses `TextEdit` instead of `Text` so users can select and copy the response text:

```qml
TextEdit {
    id: replyText
    text: root.message
    wrapMode: Text.WordWrap
    readOnly: true
    selectByMouse: true
    selectedTextColor: "#1e1e2e"
    selectionColor: "#89b4fa"
}
```

Using `TextEdit` with `readOnly: true` gives text selection behavior without allowing editing.

### MouseArea Z-Ordering

The `MouseArea` (for click-to-dismiss) is declared *before* the `TextEdit` in the source, which places it lower in the z-order. This means `TextEdit` gets mouse events first for text selection, while clicks that aren't on text fall through to the `MouseArea` for dismissal:

```qml
// Declared first = lower z-order
MouseArea {
    anchors.fill: parent
    onClicked: root.hide()
}
// Declared second = higher z-order, gets events first
TextEdit { /* ... */ }
```

### Show/Hide with Opacity Animation

```qml
Behavior on opacity { NumberAnimation { duration: 250 } }

function show(text) {
    message = text;
    visible = true;
    opacity = 1;        // Animated from 0 → 1 over 250ms
    autoDismiss.restart();
}

function hide() {
    opacity = 0;         // Animated from 1 → 0 over 250ms
    hideTimer.start();   // After 250ms, set visible = false
}
```

The `visible` property is toggled *after* the opacity animation completes, using a timer that matches the animation duration. This ensures the item isn't removed from the scene graph mid-animation.

### Auto-Dismiss Timer

```qml
Timer {
    id: autoDismiss
    interval: root.displayDuration  // 8000ms (8 seconds)
    onTriggered: root.hide()
}
```

### Speech Tail

The tail pointing down from the bubble is drawn with `Shape` and `ShapePath`:

```qml
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
```

This draws a triangle pointing down, filled with the same color as the bubble body.

### Dynamic Width/Height

The bubble width is computed reactively:

```qml
width: Math.min(Math.max(replyText.implicitWidth + 36, 140), 300)
```

- Minimum: 140px
- Maximum: 300px
- Content-dependent: `implicitWidth + 36` (18px padding on each side)

---

## 5. ThoughtBubble.qml

### Component Structure

```qml
Item {
    id: root
    property alias text: inputField.text
    signal submitted(string message)
    width: 280; height: 130
    visible: false; opacity: 0
    // ...
}
```

### How It Differs from ReplyBubble

| Feature | ReplyBubble | ThoughtBubble |
|---------|------------|---------------|
| **Purpose** | Display read-only text | Accept user input |
| **Main widget** | `TextEdit` (readOnly) | `TextField` (editable) |
| **Tail shape** | Triangle (speech) | Three descending circles (thought dots) |
| **Border color** | `#89b4fa` (blue) | `#585b70` (gray) |
| **Auto-dismiss** | Yes (8s) | No |
| **Size** | Dynamic (140–300px wide) | Fixed (280×130px) |
| **Signal** | None | `submitted(string message)` |

### TextField for Input

```qml
TextField {
    id: inputField
    placeholderText: "Ask me anything..."
    onAccepted: {
        if (text.trim().length > 0)
            root.submitted(text.trim());
    }
    Keys.onEscapePressed: root.hide()
}
```

- **Enter** submits the text via the `submitted` signal
- **Escape** hides the bubble

### Thought Dots

Three progressively smaller circles create the classic thought-bubble tail:

```qml
Rectangle { x: ...; width: 16; height: 12; radius: 6;  /* largest */ }
Rectangle { x: ...; width: 10; height: 8;  radius: 4;  /* medium */ }
Rectangle { x: ...; width: 6;  height: 5;  radius: 2.5; /* smallest */ }
```

### Show/Hide Animation

Identical pattern to ReplyBubble — `Behavior on opacity` with a `hideTimer`:

```qml
Behavior on opacity { NumberAnimation { duration: 200 } }
```

---

## 6. CatSprite.qml

### Canvas-Based Procedural Drawing

`CatSprite.qml` is an alternative to the SVG sprite approach. Instead of loading pre-rendered SVG files, it draws the cat entirely using Qt Quick primitives (`Rectangle`, `Shape`, `ShapePath`):

```qml
Item {
    id: root
    property string state_name: "idle"
    property bool facingRight: true
    property int frame: 0
    width: 180; height: 210
    // ...
}
```

### How It Draws the Cat

The cat is composed of layered Qt Quick elements:

1. **Tail** — `Shape` with `ShapePath` using `PathQuad` curves, animated by `tailWag` property
2. **Body** — `Rectangle` with rounded corners
3. **Belly/Chest** — Lighter `Rectangle` overlays
4. **Legs** — Four `Item` groups, each containing a leg rectangle, paw, and toe beans (tiny pink circles)
5. **Ears** — `Shape` triangles with inner fill
6. **Head** — Large rounded `Rectangle` with cheek puffs
7. **Heart marking** — `Shape` with quadratic curves on the forehead
8. **Eyes** — Heterochromatic: left eye amber (`#fab387`), right eye blue (`#89b4fa`), with pupils, highlights, and blink animation
9. **Nose** — `Shape` triangle
10. **Mouth** — W-shaped `Shape` paths
11. **Whiskers** — Curved `ShapePath` lines (3 per side)

### Animation System

```qml
Timer {
    interval: 120; running: true; repeat: true
    onTriggered: {
        root.frame++;
        if (root.state_name === "walking") {
            root.legOffset1 = Math.sin(root.frame * 0.9) * 7;
            root.legOffset2 = Math.sin(root.frame * 0.9 + Math.PI) * 7;
        } else {
            root.legOffset1 *= 0.7;  // Smooth deceleration
            root.legOffset2 *= 0.7;
        }
    }
}
```

- **Walking**: Legs oscillate via sinusoidal functions (opposite phase for front/back pairs)
- **Blinking**: `blinkPhase: frame % 55` — eyes close for 2 frames every 55 frames (~6.6s at 120ms/frame)
- **Tail wag**: `tailWag: Math.sin(frame * 0.2) * 8` — continuous sinusoidal tail motion
- **Idle bounce**: `SequentialAnimation on y` — subtle up/down oscillation (1.8s per half-cycle)
- **Horizontal flip**: `transform: Scale { xScale: root.facingRight ? 1 : -1 }` — mirrors the entire item

### Eye Blink Details

```qml
property int blinkPhase: frame % 55
property real eyeScaleY: blinkPhase < 2 ? 0.06 : 1.0
```

When `eyeScaleY` drops to `0.06`, the eye `Rectangle` heights collapse to nearly zero, and a curved `Shape` (drawn as an arc) appears instead:

```qml
// Normal eye (visible when not blinking)
Item { visible: root.eyeScaleY > 0.1; /* full eye */ }
// Blink line (visible only when blinking)
Shape { visible: root.eyeScaleY <= 0.1; /* curved line */ }
```

### Why It Exists as an Alternative

The SVG approach uses pre-generated image files (created by `gen_walk.py`, `gen_svgs.py`, etc.) that are loaded and displayed by `Image` elements. CatSprite offers:

- **No external files** — everything is self-contained in QML
- **Smooth procedural animation** — leg motion, tail wag, and blink are continuously interpolated rather than frame-stepped
- **Resolution independence** — vector shapes scale perfectly at any size

However, the SVG approach is used in production because:
- SVGs offer more artistic detail and are easier to design
- Procedural drawing requires manually positioning every shape
- CatSprite doesn't implement all pose variants (pounce, land, stretch, jump, tail swish)

---

## 7. C++ ↔ QML Interface

### Context Properties

Two C++ objects are exposed to QML as root context properties:

```cpp
engine.rootContext()->setContextProperty("catConfig", &config);
engine.rootContext()->setContextProperty("copilotBridge", &bridge);
```

These are accessible as global variables in all QML files loaded by the engine.

### CatConfig — Q_PROPERTY Bindings

```cpp
class CatConfig : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString backend READ backend NOTIFY backendChanged)
    Q_PROPERTY(bool needsSetup READ needsSetup NOTIFY needsSetupChanged)
    // ...
};
```

| Property | Type | QML Usage |
|----------|------|-----------|
| `backend` | `QString` | `catConfig.backend` — determines WebSocket activation and chat routing |
| `needsSetup` | `bool` | `catConfig.needsSetup` — triggers setup wizard in `Component.onCompleted` |

QML accesses these reactively — when C++ emits `backendChanged()`, any QML binding referencing `catConfig.backend` is automatically re-evaluated.

### CatConfig — Q_INVOKABLE Methods

```cpp
Q_INVOKABLE void saveConfig(const QVariantMap &config);
Q_INVOKABLE void fetchModels(const QString &apiKey);
Q_INVOKABLE QString lastApiKey() const;
Q_INVOKABLE void startCopilotAuth();
Q_INVOKABLE void cancelCopilotAuth();
```

| Method | QML Call Site | Purpose |
|--------|--------------|---------|
| `saveConfig(config)` | `SetupWizard.qml` step 3 | Writes config JSON to disk |
| `fetchModels(apiKey)` | `SetupWizard.qml` step 2 | Fetches model list from OpenRouter API |
| `lastApiKey()` | `SetupWizard.qml` step 3 | Retrieves the API key used in the last `fetchModels` call |
| `startCopilotAuth()` | `SetupWizard.qml` step 1 | Initiates GitHub device flow authentication |
| `cancelCopilotAuth()` | `SetupWizard.qml` step 4 | Cancels pending device flow |

### CatConfig — Signals

```cpp
signals:
    void backendChanged();
    void needsSetupChanged();
    void modelsReceived(const QVariantList &models);
    void modelsFetchFailed(const QString &error);
    void configSaved();
    void copilotDeviceCode(const QString &userCode, const QString &verificationUri);
    void copilotAuthSuccess();
    void copilotAuthFailed(const QString &error);
```

These signals are connected in QML using the `Connections` element:

```qml
Connections {
    target: catConfig
    function onModelsReceived(models) { /* ... */ }
    function onConfigSaved() { /* ... */ }
    function onCopilotDeviceCode(userCode, verificationUri) { /* ... */ }
    // ...
}
```

### CopilotBridge — Q_PROPERTY Bindings

```cpp
class CopilotBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    // ...
};
```

| Property | Type | QML Usage |
|----------|------|-----------|
| `busy` | `bool` | `copilotBridge.busy` — indicates a request is in-flight (not currently used in QML UI) |

### CopilotBridge — Q_INVOKABLE Methods

```cpp
Q_INVOKABLE void sendMessage(const QString &message);
```

Called from `Main.qml`'s `sendChat()` function when the backend is not MCP:

```qml
copilotBridge.sendMessage(msg);
```

This triggers the C++ backend to route the message to OpenRouter, a custom command, or the fallback pun generator.

### CopilotBridge — Signals

```cpp
signals:
    void responseReceived(const QString &response);
    void errorOccurred(const QString &error);
    void busyChanged();
```

Connected in `Main.qml`:

```qml
Connections {
    target: copilotBridge
    function onResponseReceived(response) {
        if (!setupWizard.visible) showBubble(response, win.chatMode);
    }
    function onErrorOccurred(error) {
        if (!setupWizard.visible) showBubble("Meow! " + error, win.chatMode);
    }
}
```

Both handlers check `!setupWizard.visible` to avoid showing bubbles while the setup wizard is active.

### Data Flow Diagram

```
User clicks cat          User types message          MCP server sends command
      │                        │                            │
      ▼                        ▼                            ▼
  MouseArea.onClicked    TextField.onAccepted        WebSocket.onTextMessageReceived
      │                        │                            │
      ▼                        ▼                            ▼
  showBubble(             sendChat(msg)               handleMcpMessage(data)
   "What's on your           │                            │
    mind?", true)        ┌────┴────┐                 ┌────┴────┐
      │                  │         │                 │         │
      ▼                  ▼         ▼                 ▼         ▼
  [Input bubble]    MCP route   C++ route       show_bubble  ask_user
                       │         │                  │         │
                       ▼         ▼                  ▼         ▼
                  sendToMcp   copilotBridge     showBubble  showBubble
                  (WebSocket)  .sendMessage()   (text,false) (text,true)
                       │         │
                       ▼         ▼
                  MCP Server   CopilotBridge::sendMessage
                       │         │
                       ▼         ▼
                  AI backend   OpenRouter / Command / Fallback
                       │         │
                       ▼         ▼
                  WebSocket   signal responseReceived(response)
                  message        │
                       │         ▼
                       ▼    Connections { function onResponseReceived }
                  handleMcpMessage        │
                       │                  ▼
                       ▼            showBubble(response)
                  showBubble(text)
```

---

## 8. QML Patterns Used

### Property Bindings (Reactive UI Updates)

QML's declarative bindings automatically re-evaluate when dependencies change:

```qml
// WebSocket active state reacts to backend changes
active: catConfig.backend === "auto" || catConfig.backend === "mcp"

// Sprite size reacts to bubble visibility
width: bubble.visible ? win.catSpriteWidth : 200
height: bubble.visible ? 140 : 180

// Bubble border color reacts to input mode
border.color: win.bubbleIsInput ? "#585b70" : "#89b4fa"

// Bubble height reacts to text content
height: {
    var textH = bubbleTextEdit.implicitHeight;
    var inputH = win.bubbleIsInput ? win.inputAreaHeight : 0;
    var natural = textH + inputH + 30;
    return Math.min(natural, win.maxBubbleHeight);
}
```

### Timer-Based Animation (vs QML Animation Types)

The project uses both approaches:

**Timer-based** (for frame-stepped sprite animation):
```qml
Timer {
    interval: 33; running: win.catState === "walking"; repeat: true
    onTriggered: { /* update position, frame counter */ }
}
```

**QML Animation types** (for smooth property transitions):
```qml
SequentialAnimation {
    id: introAnimation
    ParallelAnimation {
        NumberAnimation { target: win; property: "x"; from: -win.width; to: win.screenW / 4; duration: 700 }
        NumberAnimation { target: win; property: "y"; /* bounce */ }
    }
    ScriptAction { script: win.catState = "land" }
    PauseAnimation { duration: 400 }
}
```

Timer-based is used where discrete frame indices are needed (walk frame cycling). QML Animations are used for smooth position/opacity interpolation.

### Conditional Visibility

The setup wizard uses `visible` bindings tied to step indices:

```qml
Column { visible: currentStep === 0; /* Backend selection */ }
Column { visible: currentStep === 1; /* Copilot sign-in */ }
Column { visible: currentStep === 2; /* API key input */ }
Column { visible: currentStep === 3; /* Model selection */ }
Column { visible: currentStep === 4; /* Device code */ }
```

Only one step is visible at a time. All steps are always instantiated (no `Loader` — the wizard is small enough that this is acceptable).

### Anchoring and Layout Strategies

The project uses several layout approaches:

1. **Absolute positioning** — Cat legs in CatSprite use explicit `x`, `y` coordinates for pixel-perfect placement
2. **Anchoring** — Bubble components use `anchors.bottom`, `anchors.right`, `anchors.verticalCenter` for responsive layout within the window
3. **Column layout** — Setup wizard steps use `Column` with `spacing` for vertical stacking
4. **`anchors.fill: parent`** — MouseAreas and backgrounds fill their parent completely

### Image Preloading with Invisible Repeaters

```qml
Repeater {
    model: 8
    Image {
        visible: false
        source: "file:///.../cat_walk_b" + (index+1) + ".svg"
        sourceSize.width: 210; sourceSize.height: 225
        cache: true
    }
}
```

This pattern creates 8 invisible `Image` elements. Qt decodes each SVG at creation time and stores the rasterized result in its image cache (keyed by URL + sourceSize). When the visible `Image` later requests the same URL, it gets a cache hit — no decode latency.

### Dynamic Width/Height Calculation for Bubbles

Bubbles compute their size from content:

```qml
// ReplyBubble — width based on text
width: Math.min(Math.max(replyText.implicitWidth + 36, 140), 300)

// Main.qml inline bubble — height based on text + input
height: {
    var textH = bubbleTextEdit.implicitHeight;
    var inputH = win.bubbleIsInput ? win.inputAreaHeight : 0;
    return Math.min(textH + inputH + 30, win.maxBubbleHeight);
}
```

`implicitWidth` and `implicitHeight` are Qt Quick properties that report the "natural" size of a text element based on its content.

---

## 9. Testing QML

### Qt Quick Test Framework

The project uses Qt's built-in `QtQuickTest` module for QML testing. Test files follow the naming convention `tst_*.qml` and are located in the `tests/` directory.

### QUICK_TEST_MAIN_WITH_SETUP

The C++ test runner (`tests/tst_main.cpp`) provides the entry point:

```cpp
#include <QtQuickTest>
#include <QQmlEngine>
#include <QQmlContext>

class Setup : public QObject {
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        engine->rootContext()->setContextProperty("assetPath", QString(ASSETS_DIR));
        engine->rootContext()->setContextProperty("qmlPath", QString(QML_DIR));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(copilot_cat_tests, Setup)
```

`QUICK_TEST_MAIN_WITH_SETUP` does the following:
1. Creates a `QGuiApplication`
2. Calls the `Setup::qmlEngineAvailable` slot to inject context properties before QML loads
3. Scans `QUICK_TEST_SOURCE_DIR` for `tst_*.qml` files
4. Runs all `TestCase` elements found in those files

The `Setup` class injects two context properties:
- `assetPath` — absolute path to the `assets/` directory
- `qmlPath` — absolute path to the `qml/` directory

These are defined by CMake compile definitions:

```cmake
target_compile_definitions(copilot-cat-tests PRIVATE
    ASSETS_DIR="${CMAKE_SOURCE_DIR}/assets"
    QML_DIR="${CMAKE_SOURCE_DIR}/qml"
    QUICK_TEST_SOURCE_DIR="${CMAKE_SOURCE_DIR}/tests"
)
```

### How TestCase Elements Work

Each `tst_*.qml` file contains a `TestCase` element with test functions:

```qml
import QtQuick
import QtTest

TestCase {
    id: tc
    name: "AnimationParams"
    when: windowShown           // Wait for the test window to appear

    function test_walkFrameCount() {
        compare(walkFrameCount, 8, "8 walk frames")
    }
}
```

- **`name`** — Identifies the test case in output
- **`when: windowShown`** — Delays test execution until the Qt Quick window is visible (required for rendering-dependent tests)
- **Test functions** — Any function named `test_*` is automatically discovered and executed
- **`init()`** — Called before each test function (equivalent to setUp)
- **Assertions** — `compare(actual, expected, msg)`, `verify(condition, msg)`, `wait(ms)`

### Component Loading in Tests

Tests load QML components using `Loader` with `file://` paths:

```qml
Component {
    id: bubbleComp
    Item {
        Loader {
            id: loader
            source: "file:///" + qmlPath + "/ReplyBubble.qml"
            onLoaded: {
                item.parent = root;
                item.show("Test selectable text");
            }
        }
    }
}

function test_textEditExists() {
    var wrapper = createTemporaryObject(bubbleComp, tc)
    wait(200)
    var bubble = wrapper.children[0].item
    verify(bubble, "ReplyBubble loaded")
}
```

`createTemporaryObject` instantiates the component and automatically cleans it up after the test.

### Testing Without a Display

The CMake configuration sets the platform plugin for headless testing:

```cmake
set_tests_properties(test-qt-quick PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=windows;QML2_IMPORT_PATH=${CMAKE_SOURCE_DIR}/qml"
)
```

On CI systems without a display, `QT_QPA_PLATFORM` can be set to `offscreen` to run tests without a visible window. The `windows` platform is used here since the project targets Windows.

### Test Files Overview

| File | Tests | What It Covers |
|------|-------|---------------|
| `tst_animation.qml` | 5 | Walk frame count, step size, frame modulo, tail swish frame count, tail swish timing |
| `tst_assets.qml` | 7 | Verifies all SVG asset files exist and load (variant A walk 4 frames, variant B walk 8 frames, tail swish, static poses) |
| `tst_replybubble.qml` | 4 | TextEdit exists, is readOnly, has selectByMouse, has selection colors |
| `tst_chatdedup.qml` | 11 | Dedup guard logic: single reply, duplicates blocked, lock reset, passthrough, server guard, combined flow |
| `tst_catconfig.cpp` | — | C++ unit tests for CatConfig (separate from QML tests) |
| `tst_copilotbridge.cpp` | — | C++ unit tests for CopilotBridge (separate from QML tests) |

### Running Tests

```powershell
cmake -B build -G "Visual Studio 17 2022" -A x64 -DCMAKE_PREFIX_PATH=C:/Qt/6.8.3/msvc2022_64
cmake --build build --config Release
ctest --test-dir build --output-on-failure -C Release
```

Tests are also run automatically after every build via the `run-tests` custom target:

```cmake
add_custom_target(run-tests ALL
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure -C $<CONFIG>
    DEPENDS copilot-cat copilot-cat-tests copilot-cat-config-tests copilot-cat-bridge-tests
)
```
