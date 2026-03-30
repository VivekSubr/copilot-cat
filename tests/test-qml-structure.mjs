/**
 * Structural tests for QML component properties.
 *
 * Parses QML files and verifies required properties/elements are present.
 * No Qt runtime needed — these are static analysis tests.
 *
 * Run: node tests/test-qml-structure.mjs
 */

import { readFileSync } from "fs";

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

function assertContains(content, pattern, name) {
  const found = typeof pattern === "string"
    ? content.includes(pattern)
    : pattern.test(content);
  assert(found, name);
}

function assertNotContains(content, pattern, name) {
  const found = typeof pattern === "string"
    ? content.includes(pattern)
    : pattern.test(content);
  assert(!found, name);
}

// ============================================================
// ReplyBubble.qml — text must be selectable
// ============================================================

console.log("\n=== ReplyBubble: Text Selectability ===\n");

const replyBubble = readFileSync("qml/ReplyBubble.qml", "utf-8");

{
  console.log("Test 1: Uses TextEdit (not Text) for reply content");
  assertContains(replyBubble, "TextEdit {", "TextEdit element present");
  // Must NOT use a plain Text element for the reply content
  // (Text doesn't support selection)
  const textBlocks = replyBubble.match(/^\s+Text\s*\{/gm);
  assert(!textBlocks, "No plain Text elements used for reply content");
}

{
  console.log("\nTest 2: TextEdit has required selectability properties");
  assertContains(replyBubble, "readOnly: true", "readOnly is true");
  assertContains(replyBubble, "selectByMouse: true", "selectByMouse is true");
}

{
  console.log("\nTest 3: TextEdit has selection styling");
  assertContains(replyBubble, /selectedTextColor:\s*"/, "selectedTextColor set");
  assertContains(replyBubble, /selectionColor:\s*"/, "selectionColor set");
}

{
  console.log("\nTest 4: MouseArea does not block text selection");
  // If a MouseArea exists, it must be declared BEFORE the TextEdit
  // (so TextEdit's z-order is higher and gets mouse events first)
  const mouseAreaPos = replyBubble.indexOf("MouseArea {");
  const textEditPos = replyBubble.indexOf("TextEdit {");
  if (mouseAreaPos !== -1 && textEditPos !== -1) {
    assert(mouseAreaPos < textEditPos,
      "MouseArea declared before TextEdit (lower z-order)");
  } else if (mouseAreaPos === -1) {
    assert(true, "No MouseArea present (TextEdit gets all events)");
  } else {
    assert(false, "TextEdit must exist in ReplyBubble");
  }
}

// ============================================================
// Main.qml — bubble text must be selectable
// ============================================================

console.log("\n=== Main.qml: Bubble Text Selectability ===\n");

const mainQml = readFileSync("qml/Main.qml", "utf-8");

{
  console.log("Test 5: Bubble text uses TextEdit (not Text)");
  // Find the bubbleTextEdit element — must be TextEdit, not Text
  const bubbleMatch = mainQml.match(/(\w+)\s*\{\s*\n\s*id:\s*bubbleTextEdit/);
  assert(bubbleMatch && bubbleMatch[1] === "TextEdit",
    "bubbleTextEdit is a TextEdit element");
}

{
  console.log("\nTest 6: Bubble TextEdit has selectability properties");
  // Extract the bubbleTextEdit block
  const startIdx = mainQml.indexOf("id: bubbleTextEdit");
  const blockEnd = mainQml.indexOf("}", startIdx);
  const block = mainQml.substring(startIdx, blockEnd);
  assertContains(block, "readOnly: true", "readOnly is true");
  assertContains(block, "selectByMouse: true", "selectByMouse is true");
}

// ============================================================
// Main.qml — sprite should not flicker
// ============================================================

console.log("\n=== Main.qml: Sprite Properties ===\n");

{
  console.log("Test 7: Main sprite Image is not asynchronous");
  // The primary sprite Image should use synchronous loading
  // to avoid flicker between animation frames (preloaders handle caching)
  assertNotContains(mainQml, "asynchronous: true",
    "No asynchronous: true on sprite Image (prevents flicker)");
}

// ============================================================
// SUMMARY
// ============================================================

console.log("\n" + "=".repeat(50));
console.log(`RESULTS: ${passed} passed, ${failed} failed`);
console.log("=".repeat(50));
process.exit(failed > 0 ? 1 : 0);
