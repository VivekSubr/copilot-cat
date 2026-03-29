// Test harness: acts as a minimal MCP client to verify the server works.
// Usage: node dist/test-mcp.js
//
// Sends initialize, lists tools, calls cat_status, then exits.

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { fileURLToPath } from "url";
import * as path from "path";

const serverPath = path.join(path.dirname(fileURLToPath(import.meta.url)), "server.js");

async function main() {
  console.log("Starting MCP server as child process...");

  const transport = new StdioClientTransport({
    command: "node",
    args: [serverPath],
  });

  const client = new Client({ name: "test-client", version: "1.0.0" });
  await client.connect(transport);
  console.log("✓ Connected to MCP server");

  // List tools
  const { tools } = await client.listTools();
  console.log(`✓ ${tools.length} tools available:`);
  for (const tool of tools) {
    console.log(`  - ${tool.name}: ${tool.description}`);
  }

  // Call cat_status
  const result = await client.callTool({ name: "cat_status", arguments: {} });
  const text = (result.content as Array<{ type: string; text: string }>)[0]?.text;
  console.log(`✓ cat_status: "${text}"`);

  // Call say_to_cat (cat UI won't be connected, but tests the tool path)
  const sayResult = await client.callTool({ name: "say_to_cat", arguments: { message: "Test meow!" } });
  const sayText = (sayResult.content as Array<{ type: string; text: string }>)[0]?.text;
  console.log(`✓ say_to_cat: "${sayText}"`);

  console.log("\n✓ All tests passed! MCP server is working.");
  await client.close();
  process.exit(0);
}

main().catch((err) => {
  console.error("✗ Test failed:", err.message || err);
  process.exit(1);
});
