/**
 * Standalone unit tests for the chat dedup logic.
 *
 * Tests the EXACT guard logic from Main.qml's handleMcpMessage and
 * server.ts's handleCatMessage — extracted and run in isolation.
 *
 * Run: node tests/test-chat-dedup.mjs
 * No running app, no WebSocket, no Qt required.
 */

let passed = 0;
let failed = 0;

function assert(condition, name) {
  if (condition) {
    passed++;
    console.log(`  ✅ ${name}`);
  } else {
    failed++;
    console.log(`  ❌ ${name}`);
  }
}

function assertEqual(actual, expected, name) {
  assert(actual === expected, `${name} — expected: ${JSON.stringify(expected)}, got: ${JSON.stringify(actual)}`);
}

// ============================================================
// QML-SIDE GUARD LOGIC (extracted from Main.qml handleMcpMessage)
// ============================================================

function createQmlState() {
  return {
    chatMode: false,
    chatReplyPending: false,
    chatReplyReceived: false,
    bubbleText: "",
    bubbleCount: 0, // counts how many times showBubble was called
  };
}

/** Replicates Main.qml handleMcpMessage for show_bubble */
function qmlHandleShowBubble(state, text) {
  if (state.chatReplyReceived) return false; // blocked

  if (state.chatReplyPending) {
    if (text.indexOf("Thinking...") !== 0) {
      state.chatReplyPending = false;
      state.chatReplyReceived = true;
    }
    state.bubbleText = text;
    state.bubbleCount++;
    return true; // shown
  }

  // Not in chat flow — passthrough
  state.bubbleText = text;
  state.bubbleCount++;
  return true;
}

/** Replicates the flag-setting in sendChat when user sends a chat message */
function qmlSendChat(state) {
  state.chatReplyPending = true;
  state.chatReplyReceived = false;
}

/** Replicates clicking the cat to start chat mode */
function qmlStartChat(state) {
  state.chatMode = true;
  state.chatReplyPending = false;
  state.chatReplyReceived = false;
}

// ============================================================
// SERVER-SIDE GUARD LOGIC (extracted from server.ts handleCatMessage)
// ============================================================

function createServerState() {
  return {
    chatProcessing: false,
    sentMessages: [],
  };
}

/** Replicates server handleCatMessage for chat messages */
function serverHandleChat(state, text, replyCallback) {
  if (state.chatProcessing) return false; // blocked
  state.chatProcessing = true;
  state.sentMessages.push({ type: "show_bubble", text: "Thinking... 🐱" });

  // Simulate async reply
  const reply = replyCallback(text);
  state.sentMessages.push({ type: "show_bubble", text: reply });
  state.chatProcessing = false;
  return true;
}

// ============================================================
// QML GUARD TESTS
// ============================================================

console.log("\n=== QML Guard: handleMcpMessage ===\n");

{
  console.log("Test 1: Single reply accepted");
  const s = createQmlState();
  qmlStartChat(s);
  qmlSendChat(s);

  qmlHandleShowBubble(s, "Thinking... 🐱");
  assertEqual(s.bubbleText, "Thinking... 🐱", "Thinking shown");
  assertEqual(s.chatReplyReceived, false, "Not locked yet");

  qmlHandleShowBubble(s, "Hey there!");
  assertEqual(s.bubbleText, "Hey there!", "Reply shown");
  assertEqual(s.chatReplyReceived, true, "Locked after reply");
  assertEqual(s.bubbleCount, 2, "Two bubbles total (Thinking + reply)");
}

{
  console.log("\nTest 2: Duplicates blocked after first reply");
  const s = createQmlState();
  qmlStartChat(s);
  qmlSendChat(s);

  qmlHandleShowBubble(s, "Thinking... 🐱");
  qmlHandleShowBubble(s, "Hey there!");
  assertEqual(s.chatReplyReceived, true, "Locked");

  // Simulate 5 more duplicate replies
  const blocked = [];
  for (let i = 0; i < 5; i++) {
    const shown = qmlHandleShowBubble(s, `Duplicate ${i}`);
    blocked.push(shown);
  }
  assert(blocked.every((b) => b === false), "All 5 duplicates blocked");
  assertEqual(s.bubbleText, "Hey there!", "Bubble text unchanged");
  assertEqual(s.bubbleCount, 2, "Still only 2 bubbles");
}

{
  console.log("\nTest 3: Lock resets when user starts new chat");
  const s = createQmlState();
  qmlStartChat(s);
  qmlSendChat(s);

  qmlHandleShowBubble(s, "Reply 1");
  assertEqual(s.chatReplyReceived, true, "Locked");

  // User clicks cat again, starts new chat
  qmlStartChat(s);
  qmlSendChat(s);
  assertEqual(s.chatReplyReceived, false, "Lock reset");

  qmlHandleShowBubble(s, "Reply 2");
  assertEqual(s.bubbleText, "Reply 2", "New reply accepted");
  assertEqual(s.chatReplyReceived, true, "Re-locked");
}

{
  console.log("\nTest 4: Non-chat messages pass through when not in chat flow");
  const s = createQmlState();
  // No chat started, chatReplyPending = false

  const shown = qmlHandleShowBubble(s, "say_to_cat message");
  assert(shown, "Passthrough allowed");
  assertEqual(s.bubbleText, "say_to_cat message", "Message shown");
}

{
  console.log("\nTest 5: Non-chat messages blocked during lock");
  const s = createQmlState();
  qmlStartChat(s);
  qmlSendChat(s);
  qmlHandleShowBubble(s, "Reply");
  assertEqual(s.chatReplyReceived, true, "Locked");

  // say_to_cat tool call arrives during lock period
  const shown = qmlHandleShowBubble(s, "Tool call message");
  assert(!shown, "Tool call blocked during lock");
}

{
  console.log("\nTest 6: Exactly reproduces the 6-reply bug scenario");
  const s = createQmlState();
  qmlStartChat(s);
  qmlSendChat(s);

  const replies = [
    "Thinking... 🐱",
    "Hey there! 😺 I'm paws-itively thrilled!",
    "Hey there! 😺 I'm paws-itively thrilled!",
    "Hey again! 😸 Looks like we're on a re-purr-t",
    "Hey there! 😺 I'm paws-itively thrilled!",
    "Hey there! 😺 I'm paws-itively thrilled!",
    "Hey again! 😸 Looks like we're on a re-purr-t",
  ];

  const results = replies.map((text) => ({
    text: text.substring(0, 40),
    shown: qmlHandleShowBubble(s, text),
  }));

  const shownCount = results.filter((r) => r.shown).length;
  assertEqual(shownCount, 2, "Only 2 of 7 messages shown (Thinking + first reply)");
  assertEqual(s.bubbleText, "Hey there! 😺 I'm paws-itively thrilled!", "Final text is first real reply");

  console.log("  Detail:");
  results.forEach((r, i) => {
    console.log(`    [${i}] ${r.shown ? "SHOWN" : "BLOCKED"}: ${r.text}`);
  });
}

{
  console.log("\nTest 7: Multiple Thinking messages are allowed");
  const s = createQmlState();
  qmlStartChat(s);
  qmlSendChat(s);

  qmlHandleShowBubble(s, "Thinking... 🐱");
  qmlHandleShowBubble(s, "Thinking... still working");
  assertEqual(s.chatReplyReceived, false, "Not locked — both were Thinking");
  assertEqual(s.bubbleCount, 2, "Both Thinking messages shown");

  qmlHandleShowBubble(s, "Here is the answer");
  assertEqual(s.chatReplyReceived, true, "Locked after real reply");
  assertEqual(s.bubbleCount, 3, "3 total (2 Thinking + 1 reply)");
}

{
  console.log("\nTest 8: chatReplyPending=false means no guard (passthrough)");
  const s = createQmlState();
  s.chatMode = true;
  // User did NOT call sendChat, so chatReplyPending is false

  const results = [];
  for (let i = 0; i < 6; i++) {
    results.push(qmlHandleShowBubble(s, `Msg ${i}`));
  }
  assert(results.every((r) => r === true), "All 6 pass through — no guard active");
  assertEqual(s.bubbleCount, 6, "All 6 shown");
}

// ============================================================
// SERVER GUARD TESTS
// ============================================================

console.log("\n=== Server Guard: handleCatMessage ===\n");

{
  console.log("Test 9: chatProcessing blocks concurrent calls");
  const s = createServerState();
  const reply = () => "Reply 1";

  const first = serverHandleChat(s, "hi", reply);
  assert(first, "First call accepted");
  assertEqual(s.sentMessages.length, 2, "Thinking + reply sent");
}

{
  console.log("\nTest 10: Concurrent calls blocked");
  const s = createServerState();
  s.chatProcessing = true; // simulate in-flight request

  const blocked = serverHandleChat(s, "hi again", () => "Reply 2");
  assert(!blocked, "Concurrent call blocked");
}

{
  console.log("\nTest 11: After completion, new calls allowed");
  const s = createServerState();

  serverHandleChat(s, "first", () => "Reply 1");
  assertEqual(s.chatProcessing, false, "Processing flag reset after completion");

  const second = serverHandleChat(s, "second", () => "Reply 2");
  assert(second, "Second call accepted after first completes");
  assertEqual(s.sentMessages.length, 4, "4 messages total (2 per call)");
}

// ============================================================
// COMBINED FLOW TEST
// ============================================================

console.log("\n=== Combined Flow: Server + QML ===\n");

{
  console.log("Test 12: Full flow — server sends, QML guards");
  const server = createServerState();
  const qml = createQmlState();
  qmlStartChat(qml);
  qmlSendChat(qml);

  // Server handles the chat message
  serverHandleChat(server, "hi", () => "Hey there!");

  // Server's sent messages arrive at QML
  let shownCount = 0;
  for (const msg of server.sentMessages) {
    if (msg.type === "show_bubble") {
      if (qmlHandleShowBubble(qml, msg.text)) shownCount++;
    }
  }
  assertEqual(shownCount, 2, "QML shows 2 (Thinking + reply)");

  // Now simulate say_to_cat tool calls (from Copilot CLI)
  const toolCalls = [
    "Hey there!",
    "Hey there!",
    "Hey again!",
    "Hey there!",
  ];
  let blockedCount = 0;
  for (const text of toolCalls) {
    if (!qmlHandleShowBubble(qml, text)) blockedCount++;
  }
  assertEqual(blockedCount, 4, "All 4 say_to_cat tool calls blocked by QML guard");
  assertEqual(qml.bubbleText, "Hey there!", "Bubble text is still the first reply");
}

// ============================================================
// SUMMARY
// ============================================================

console.log("\n" + "=".repeat(50));
console.log(`RESULTS: ${passed} passed, ${failed} failed`);
console.log("=".repeat(50));
process.exit(failed > 0 ? 1 : 0);
