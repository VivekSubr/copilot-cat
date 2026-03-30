/**
 * Test: Duplicate Reply Reproduction
 *
 * Connects to the copilot-cat WebSocket server on port 9922 and
 * simulates what the cat UI does when the user types "hi":
 *   1. Sends { type: "chat", text: "hi" }
 *   2. Counts all { type: "show_bubble" } responses
 *
 * Expected: 1-2 show_bubble messages (Thinking + reply)
 * Bug: 6+ show_bubble messages
 *
 * Usage: node tests/test-dedup.mjs
 */

import { WebSocket } from "ws";

const WS_URL = "ws://127.0.0.1:9922";
const WAIT_MS = 30000; // wait 30s for all replies

console.log(`Connecting to ${WS_URL}...`);
const ws = new WebSocket(WS_URL);

let messages = [];
let connected = false;

ws.on("open", () => {
  connected = true;
  console.log("Connected. Sending chat message: 'hi'");
  ws.send(JSON.stringify({ type: "chat", text: "hi" }));
  console.log(`Waiting ${WAIT_MS / 1000}s for responses...\n`);
});

ws.on("message", (data) => {
  const msg = JSON.parse(data.toString());
  messages.push({ time: Date.now(), ...msg });
  const i = messages.length;
  console.log(`  [${i}] ${msg.type}: "${(msg.text || msg.action || "").substring(0, 60)}"`);
});

ws.on("error", (err) => {
  console.error(`WebSocket error: ${err.message}`);
  process.exit(1);
});

ws.on("close", () => {
  if (!connected) {
    console.error("Could not connect. Is the MCP server running on port 9922?");
    process.exit(1);
  }
  printResults();
});

setTimeout(() => {
  ws.close();
  printResults();
}, WAIT_MS);

function printResults() {
  console.log("\n" + "=".repeat(60));
  console.log("RESULTS");
  console.log("=".repeat(60));

  const bubbles = messages.filter((m) => m.type === "show_bubble");
  const thinkings = bubbles.filter((m) => m.text && m.text.startsWith("Thinking..."));
  const replies = bubbles.filter((m) => m.text && !m.text.startsWith("Thinking..."));
  const uniqueReplies = [...new Set(replies.map((m) => m.text))];

  console.log(`Total WebSocket messages received: ${messages.length}`);
  console.log(`  show_bubble messages: ${bubbles.length}`);
  console.log(`    "Thinking..." messages: ${thinkings.length}`);
  console.log(`    Reply messages: ${replies.length}`);
  console.log(`    Unique reply texts: ${uniqueReplies.length}`);
  console.log();

  if (replies.length > 1) {
    console.log("❌ FAIL: Got multiple replies for a single chat message!");
    console.log();
    console.log("Timeline:");
    const t0 = messages[0]?.time || 0;
    for (const m of messages) {
      const dt = m.time - t0;
      console.log(`  +${dt}ms  ${m.type}: "${(m.text || "").substring(0, 70)}"`);
    }
  } else if (replies.length === 1) {
    console.log("✅ PASS: Got exactly 1 reply for 1 chat message.");
  } else {
    console.log("⚠️  No replies received (only Thinking or nothing).");
  }

  console.log();
  process.exit(replies.length <= 1 ? 0 : 1);
}
