# Test Plan: Duplicate Chat Reply Bug

## Bug Description

When user clicks the cat, types "hi" and presses Enter, the cat shows **6 replies** instead of 1. The bubble text grows longer as if replies are appended.

## Hypothesis Tree

The duplicate replies can originate from **4 possible layers**:

```
User types "hi" in cat bubble
         │
         ▼
┌─────────────────────┐
│ 1. QML sends multiple│  Does onAccepted fire more than once?
│    WebSocket messages │  Does sendChat() get called multiple times?
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ 2. MCP server calls  │  Does handleCatMessage fire multiple times?
│    LLM multiple times │  Does callCopilotChat run concurrently?
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ 3. Copilot CLI calls  │  Does MCP sampling trigger say_to_cat tool?
│    say_to_cat tool    │  How many say_to_cat calls per sampling request?
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ 4. QML shows multiple │  Does handleMcpMessage show multiple bubbles?
│    bubbles per message│  Does the guard logic actually block?
└─────────────────────┘
```

## Test Approach

### Layer 1: QML → WebSocket (how many chat messages are sent?)

**Test 1.1: Count WebSocket sends**

Add a counter to `sendToMcp` in Main.qml:

```qml
property int wsSendCount: 0
function sendToMcp(msg) {
    if (ws.status === WebSocket.Open) {
        win.wsSendCount++;
        console.log("[TEST] sendToMcp #" + win.wsSendCount + ": " + JSON.stringify(msg));
        ws.sendTextMessage(JSON.stringify(msg));
    }
}
```

After typing "hi" + Enter, check: `wsSendCount` should be **1**. If > 1, the bug is in QML sending duplicates.

**Test 1.2: Count onAccepted fires**

```qml
property int acceptedCount: 0
onAccepted: {
    win.acceptedCount++;
    console.log("[TEST] onAccepted #" + win.acceptedCount);
    // ... rest of handler
}
```

**Test 1.3: Verify chatReplyPending is set**

```qml
// In sendChat, after setting the flag:
console.log("[TEST] sendChat: chatMode=" + win.chatMode
    + " chatReplyPending=" + win.chatReplyPending
    + " wsConnected=" + win.wsConnected
    + " backend=" + copilotBridge.backend);
```

**Expected**: chatMode=true, chatReplyPending=true, wsConnected=true, backend=auto

---

### Layer 2: MCP Server → LLM (how many times is the LLM called?)

**Test 2.1: Count handleCatMessage calls**

Add logging to `mcp/server.ts`:

```typescript
let chatMsgCount = 0;
function handleCatMessage(msg: { type: string; text?: string }) {
    if (msg.type === "chat") {
        chatMsgCount++;
        console.error(`[TEST] handleCatMessage chat #${chatMsgCount}: "${msg.text}"`);
    }
    // ...
}
```

After "hi", check stderr: `chatMsgCount` should be **1**.

**Test 2.2: Count sendToCat calls**

```typescript
let sendCount = 0;
function sendToCat(msg: object): boolean {
    sendCount++;
    console.error(`[TEST] sendToCat #${sendCount}: ${JSON.stringify(msg).substring(0, 80)}`);
    // ...
}
```

After "hi", count all `show_bubble` sends. If > 2 (Thinking + reply), the server is sending duplicates.

**Test 2.3: Count say_to_cat tool invocations**

```typescript
server.tool("say_to_cat", ..., async ({ message }) => {
    console.error(`[TEST] say_to_cat tool called: "${message.substring(0, 50)}"`);
    // ...
});
```

This reveals if the Copilot CLI is calling `say_to_cat` independently of the chat handler.

---

### Layer 3: Copilot CLI → MCP tools (does sampling trigger tool calls?)

**Test 3.1: Disable MCP sampling, use only OpenRouter**

Set `OPENROUTER_API_KEY` env var and modify `callCopilotChat` to skip sampling:

```typescript
async function callCopilotChat(userMessage: string): Promise<string> {
    // Force OpenRouter only — bypass MCP sampling
    if (OPENROUTER_API_KEY) {
        return await callOpenRouterChat(userMessage);
    }
    return fallbackChatReply("No backend.");
}
```

If duplicates STOP with OpenRouter-only, the bug is in MCP sampling triggering extra `say_to_cat` calls.

**Test 3.2: Disable say_to_cat tool response during chat**

```typescript
let chatInProgress = false;

// In handleCatMessage:
chatInProgress = true;
// ... after reply sent:
chatInProgress = false;

// In say_to_cat tool:
server.tool("say_to_cat", ..., async ({ message }) => {
    if (chatInProgress) {
        console.error(`[TEST] BLOCKED say_to_cat during chat: "${message.substring(0, 50)}"`);
        return { content: [{ type: "text", text: "Blocked during chat" }] };
    }
    // ... normal handler
});
```

---

### Layer 4: QML message reception (does the guard work?)

**Test 4.1: Count handleMcpMessage calls**

```qml
property int handleMsgCount: 0
function handleMcpMessage(data) {
    if (data.type === "show_bubble") {
        win.handleMsgCount++;
        console.log("[TEST] handleMcpMessage #" + win.handleMsgCount
            + " chatReplyPending=" + win.chatReplyPending
            + " chatReplyReceived=" + win.chatReplyReceived
            + " text=" + data.text.substring(0, 40));
    }
    // ... rest of handler
}
```

After "hi", check how many times `handleMcpMessage` fires and what the flag values are for each call.

**Test 4.2: Nuclear block confirms code path**

```qml
function handleMcpMessage(data) {
    if (data.type === "show_bubble") {
        return;  // Block EVERYTHING
    }
    // ...
}
```

If user still sees replies → messages bypass handleMcpMessage. If stuck on "Thinking..." → handleMcpMessage IS the only path. **(Already confirmed: stuck on Thinking)**

**Test 4.3: Unit test the guard logic directly**

```qml
// Qt Quick Test
TestCase {
    name: "ChatDedup"

    function test_guard_blocks_after_first_reply() {
        win.chatMode = true;
        win.chatReplyPending = true;
        win.chatReplyReceived = false;

        // Simulate 6 show_bubble messages
        for (var i = 0; i < 6; i++) {
            win.handleMcpMessage({ type: "show_bubble", text: "Reply " + i });
        }

        // Only first should have been accepted
        compare(win.bubbleText, "Reply 0", "Only first reply shown");
        compare(win.chatReplyReceived, true, "Lock engaged after first reply");
    }
}
```

---

## Execution Order

Run these in order — each narrows the root cause:

| Step | Test | Expected Result | If Fails |
|------|------|----------------|----------|
| 1 | 4.2 Nuclear block | Stuck on Thinking | Messages bypass QML (check C++ layer) |
| 2 | 4.1 Count handleMcpMessage | See how many calls + flag values | Reveals why guard doesn't catch |
| 3 | 1.1 Count WS sends | 1 send | QML sends duplicates → fix onAccepted |
| 4 | 2.2 Count sendToCat | 2 (Thinking + reply) | Server sends extras → fix server |
| 5 | 2.3 Count say_to_cat tool | 0 during chat | Copilot CLI calls tool → fix server |
| 6 | 3.1 OpenRouter-only | No duplicates | Confirms sampling causes extras |

## Implementation: Instrumented Build

Create an instrumented version that runs ALL logging at once:

### `mcp/server.ts` additions:

```typescript
// Add at top
let debugChatMsgCount = 0;
let debugSendCount = 0;

// Wrap sendToCat
function sendToCat(msg: object): boolean {
    debugSendCount++;
    const summary = JSON.stringify(msg).substring(0, 100);
    console.error(`[DEDUP-DEBUG] sendToCat #${debugSendCount}: ${summary}`);
    if (wsConn) { wsConn.send(JSON.stringify(msg)); return true; }
    return false;
}

// In handleCatMessage, before "chat" check:
if (msg.type === "chat") {
    debugChatMsgCount++;
    console.error(`[DEDUP-DEBUG] chat msg #${debugChatMsgCount}: "${msg.text}"`);
}

// In say_to_cat tool:
console.error(`[DEDUP-DEBUG] say_to_cat tool invoked: "${message.substring(0, 60)}"`);
```

### `qml/Main.qml` additions:

```qml
property int debugSendCount: 0
property int debugRecvCount: 0

function sendToMcp(msg) {
    if (ws.status === WebSocket.Open) {
        win.debugSendCount++;
        console.log("[DEDUP-DEBUG] QML send #" + win.debugSendCount + ": " + JSON.stringify(msg));
        ws.sendTextMessage(JSON.stringify(msg));
    }
}

function handleMcpMessage(data) {
    if (data.type === "show_bubble") {
        win.debugRecvCount++;
        console.log("[DEDUP-DEBUG] QML recv #" + win.debugRecvCount
            + " pending=" + win.chatReplyPending
            + " received=" + win.chatReplyReceived
            + " chatMode=" + win.chatMode
            + " text=" + data.text.substring(0, 50));
        // ... existing guard logic
    }
}
```

### Reading the logs:

```powershell
# MCP server logs go to stderr of the node process
# Cat UI logs go to Qt debug output (stdout or debugger)
# On Windows, use DebugView (Sysinternals) to see qml console.log output
# Or run the binary from terminal to see stdout:
.\build\Release\copilot-cat.exe 2>&1 | Tee-Object -FilePath cat-debug.log
```

## Expected Diagnostic Output (single "hi")

```
[DEDUP-DEBUG] QML send #1: {"type":"chat","text":"hi"}
[DEDUP-DEBUG] chat msg #1: "hi"
[DEDUP-DEBUG] sendToCat #1: {"type":"show_bubble","text":"Thinking... 🐱"}
[DEDUP-DEBUG] QML recv #1 pending=true received=false chatMode=true text=Thinking...
[DEDUP-DEBUG] sendToCat #2: {"type":"show_bubble","text":"Hey there! ..."}
[DEDUP-DEBUG] QML recv #2 pending=true received=false chatMode=true text=Hey there!
[DEDUP-DEBUG] say_to_cat tool invoked: "Hey there! ..."    ← IF THIS APPEARS, Copilot CLI is the source
[DEDUP-DEBUG] sendToCat #3: {"type":"show_bubble","text":"Hey there! ..."}
[DEDUP-DEBUG] QML recv #3 pending=false received=true chatMode=true text=Hey there!  ← SHOULD BE BLOCKED
```

## Fix Validation

After applying any fix, run this checklist:

- [ ] Type "hi" → exactly 1 reply shown
- [ ] Type "hi" again → exactly 1 new reply (lock resets)
- [ ] Use `say_to_cat` MCP tool → message shows (not blocked by chat lock)
- [ ] Use `ask_via_cat` MCP tool → input shows (not blocked)
- [ ] Click cat while reply showing → dismisses reply, can chat again
- [ ] Disconnect/reconnect WebSocket → chat still works
- [ ] Close via right-click menu → farewell + exit animation plays
