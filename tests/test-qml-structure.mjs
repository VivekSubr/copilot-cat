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
  assertNotContains(mainQml, "asynchronous: true",
    "No asynchronous: true on sprite Image (prevents flicker)");
}

// ============================================================
// Main.qml — A/B animation variant toggle
// ============================================================

console.log("\n=== Main.qml: A/B Animation Variant ===\n");

{
  console.log("Test 8: animVariantB property exists");
  assertContains(mainQml, "property bool animVariantB", "animVariantB property declared");
}

{
  console.log("\nTest 9: F2 keyboard shortcut toggles variant");
  assertContains(mainQml, /Shortcut\s*\{/, "Shortcut element exists");
  assertContains(mainQml, '"F2"', "F2 key sequence configured");
  assertContains(mainQml, "animVariantB = !win.animVariantB", "Shortcut toggles animVariantB");
}

{
  console.log("\nTest 10: Variant B walk uses 8 frames");
  assertContains(mainQml, "cat_walk_b", "Variant B walk SVG prefix referenced");
  assertContains(mainQml, /walkFrameCount.*8/, "walkFrameCount is 8 for variant B");
}

{
  console.log("\nTest 11: Variant B tail swish uses 8 frames");
  assertContains(mainQml, "cat_tail_swish_b", "Variant B tail swish SVG prefix referenced");
  assertContains(mainQml, /tailSwishFrameCount.*8/, "tailSwishFrameCount is 8 for variant B");
}

{
  console.log("\nTest 12: Variant B preloaders exist");
  assertContains(mainQml, /Repeater.*model:\s*8.*cat_walk_b/, "8-frame walk_b preloader");
  assertContains(mainQml, /Repeater.*model:\s*8.*cat_tail_swish_b/, "8-frame tail_swish_b preloader");
}

// ============================================================
// SVG files — variant B assets exist
// ============================================================

import { existsSync } from "fs";

console.log("\n=== SVG Assets: Variant B Files ===\n");

{
  console.log("Test 13: Variant B walk SVGs exist (8 right + 8 left)");
  let walkOk = true;
  for (let i = 1; i <= 8; i++) {
    if (!existsSync(`assets/cat_walk_b${i}.svg`)) { walkOk = false; break; }
    if (!existsSync(`assets/cat_walk_b${i}_left.svg`)) { walkOk = false; break; }
  }
  assert(walkOk, "All 16 variant B walk SVGs present");
}

{
  console.log("\nTest 14: Variant B tail swish SVGs exist (8 frames)");
  let tailOk = true;
  for (let i = 1; i <= 8; i++) {
    if (!existsSync(`assets/cat_tail_swish_b${i}.svg`)) { tailOk = false; break; }
  }
  assert(tailOk, "All 8 variant B tail swish SVGs present");
}

// ============================================================
// SUMMARY
// ============================================================

console.log("\n" + "=".repeat(50));
console.log(`RESULTS: ${passed} passed, ${failed} failed`);
console.log("=".repeat(50));
process.exit(failed > 0 ? 1 : 0);
