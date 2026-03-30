#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { WebSocketServer } from "ws";

const WS_PORT = 9922;
const CHAT_TIMEOUT_MS = 30000;

// ==================== OpenRouter Config ====================

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY ?? "";
const OPENROUTER_MODEL = process.env.OPENROUTER_MODEL ?? "openai/gpt-4o-mini";
const OPENROUTER_BASE_URL = process.env.OPENROUTER_BASE_URL ?? "https://openrouter.ai/api/v1";

// ==================== MCP Server ====================

const server = new McpServer({ name: "copilot-cat", version: "1.0.0" });

// WebSocket connection to cat UI
let wsConn: { send: (data: string) => void; close: () => void } | null = null;
let pendingResolve: ((response: string) => void) | null = null;
let chatProcessing = false;

// Chat history for MCP sampling context
const chatHistory: Array<{ role: "user" | "assistant"; content: { type: "text"; text: string } }> = [];

const SYSTEM_PROMPT = "You are Copilot Cat, a helpful and playful desktop pet AI assistant. Keep responses short (1-3 sentences). Be friendly, occasionally use cat puns. You help with coding questions, general knowledge, and chat.";

function fallbackChatReply(reason: string): string {
  if (OPENROUTER_API_KEY) {
    return `Meow! ${reason} But I have OpenRouter configured, so this shouldn't happen...`;
  }
  return `Meow! ${reason} Set OPENROUTER_API_KEY or launch from VS Code for Copilot replies.`;
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number, message: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(message)), timeoutMs);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error) => {
        clearTimeout(timer);
        reject(error);
      }
    );
  });
}

async function callOpenRouterChat(userMessage: string): Promise<string> {
  chatHistory.push({ role: "user", content: { type: "text", text: userMessage } });
  if (chatHistory.length > 20) chatHistory.splice(0, 2);

  const messages = [
    { role: "system" as const, content: SYSTEM_PROMPT },
    ...chatHistory.map((m) => ({ role: m.role, content: m.content.text })),
  ];

  const res = await withTimeout(
    fetch(`${OPENROUTER_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/copilot-cat",
        "X-Title": "Copilot Cat",
      },
      body: JSON.stringify({ model: OPENROUTER_MODEL, messages, max_tokens: 200 }),
    }),
    CHAT_TIMEOUT_MS,
    `Timed out waiting for OpenRouter after ${CHAT_TIMEOUT_MS / 1000}s`
  );

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`OpenRouter ${res.status}: ${body.slice(0, 200)}`);
  }

  const data = (await res.json()) as { choices?: Array<{ message?: { content?: string } }> };
  const reply = data.choices?.[0]?.message?.content?.trim() ?? "Meow? Empty response from OpenRouter...";
  chatHistory.push({ role: "assistant", content: { type: "text", text: reply } });
  return reply;
}

async function callCopilotChat(userMessage: string): Promise<string> {
  const hasSampling = !!server.server.getClientCapabilities()?.sampling;

  // Prefer MCP sampling when available, fall back to OpenRouter
  if (!hasSampling && !OPENROUTER_API_KEY) {
    return fallbackChatReply("No Copilot client or OpenRouter API key configured.");
  }

  if (!hasSampling) {
    // Use OpenRouter
    try {
      return await callOpenRouterChat(userMessage);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`[copilot-cat] OpenRouter error: ${msg}`);
      return fallbackChatReply(`OpenRouter error: ${msg}.`);
    }
  }

  // Use MCP sampling
  chatHistory.push({ role: "user", content: { type: "text", text: userMessage } });
  if (chatHistory.length > 20) chatHistory.splice(0, 2);

  try {
    const result = await withTimeout(
      server.server.createMessage({
        messages: chatHistory,
        systemPrompt: SYSTEM_PROMPT,
        maxTokens: 200,
      }),
      CHAT_TIMEOUT_MS,
      `Timed out waiting for Copilot after ${CHAT_TIMEOUT_MS / 1000}s`
    );

    const reply = result.content.type === "text" ? result.content.text : "Meow? I got a non-text response...";
    chatHistory.push({ role: "assistant", content: { type: "text", text: reply } });
    return reply;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[copilot-cat] Sampling error: ${msg}`);
    // Fall back to OpenRouter if sampling fails and key is available
    if (OPENROUTER_API_KEY) {
      console.error(`[copilot-cat] Falling back to OpenRouter...`);
      // Remove the user message we just added (callOpenRouterChat will re-add it)
      chatHistory.pop();
      try {
        return await callOpenRouterChat(userMessage);
      } catch (orErr: unknown) {
        const orMsg = orErr instanceof Error ? orErr.message : String(orErr);
        console.error(`[copilot-cat] OpenRouter fallback also failed: ${orMsg}`);
      }
    }
    return fallbackChatReply(`Couldn't reach Copilot: ${msg}.`);
  }
}

// ==================== WebSocket Server ====================

function sendToCat(msg: object): boolean {
  if (wsConn) {
    wsConn.send(JSON.stringify(msg));
    return true;
  }
  return false;
}

function handleCatMessage(msg: { type: string; text?: string }) {
  if (msg.type === "user_response" && pendingResolve && msg.text) {
    pendingResolve(msg.text);
    pendingResolve = null;
  }
  // Direct chat from cat UI (user typed in the bubble)
  if (msg.type === "chat" && msg.text) {
    if (chatProcessing) {
      console.error(`[copilot-cat] Ignoring duplicate chat while processing: "${msg.text}"`);
      return;
    }
    chatProcessing = true;
    console.error(`[copilot-cat] Chat: "${msg.text}"`);
    sendToCat({ type: "show_bubble", text: "Thinking... 🐱" });
    callCopilotChat(msg.text).then((reply) => {
      console.error(`[copilot-cat] Reply: "${reply.slice(0, 50)}..."`);
      // Only send the reply bubble if NOT using MCP sampling.
      // When sampling is active, the Copilot client already calls say_to_cat.
      const hasSampling = !!server.server.getClientCapabilities()?.sampling;
      if (!hasSampling) {
        sendToCat({ type: "show_bubble", text: reply });
      }
    }).catch((err) => {
      console.error(`[copilot-cat] Chat error:`, err);
      sendToCat({ type: "show_bubble", text: "Meow! Something went wrong..." });
    }).finally(() => {
      chatProcessing = false;
    });
  }
}

function startWebSocketServer(retries = 30, delay = 3000) {
  const wss = new WebSocketServer({ port: WS_PORT, host: "127.0.0.1" });

  wss.on("listening", () => {
    console.error(`[copilot-cat] WebSocket on ws://127.0.0.1:${WS_PORT}`);
  });

  wss.on("error", (err: NodeJS.ErrnoException) => {
    if (err.code === "EADDRINUSE" && retries > 0) {
      console.error(`[copilot-cat] Port ${WS_PORT} in use, retrying in ${delay / 1000}s... (${retries} left)`);
      wss.close();
      setTimeout(() => startWebSocketServer(retries - 1, delay), delay);
    } else {
      console.error(`[copilot-cat] WebSocket server error: ${err.message}`);
    }
  });

  wss.on("connection", (socket) => {
    // Only allow one cat UI connection — close previous
    if (wsConn) {
      console.error("[copilot-cat] Replacing old cat UI connection");
      try { wsConn.close(); } catch {}
    }
    const conn = { send(data: string) { socket.send(data); }, close() { socket.close(); } };
    wsConn = conn;
    console.error("[copilot-cat] Cat UI connected via WebSocket");

    socket.on("message", (data) => {
      if (wsConn !== conn) return;
      try { handleCatMessage(JSON.parse(data.toString("utf8"))); }
      catch { console.error("[copilot-cat] Bad JSON from cat"); }
    });
    socket.on("close", () => {
      if (wsConn === conn) { console.error("[copilot-cat] Cat UI disconnected"); wsConn = null; }
    });
    socket.on("error", () => {
      if (wsConn === conn) wsConn = null;
    });
  });
}

startWebSocketServer();

// ==================== MCP Tools ====================

server.tool(
  "say_to_cat",
  "Send a message to the desktop cat. Shows as a speech bubble above the cat.",
  { message: z.string().describe("The message to display") },
  async ({ message }) => {
    console.error(`[DEDUP] say_to_cat TOOL called: "${message.substring(0, 60)}"`);
    const sent = sendToCat({ type: "show_bubble", text: message });
    return { content: [{ type: "text", text: sent ? `Cat says: "${message}"` : "Cat UI not connected." }] };
  }
);

server.tool(
  "ask_via_cat",
  "Ask the user a question through the cat. Shows thought bubble with input field, waits for reply.",
  { question: z.string().describe("Question to ask the user") },
  async ({ question }) => {
    if (!sendToCat({ type: "ask_user", text: question }))
      return { content: [{ type: "text", text: "Cat UI not connected." }] };

    const response = await new Promise<string>((resolve) => {
      pendingResolve = resolve;
      setTimeout(() => { if (pendingResolve === resolve) { pendingResolve = null; resolve("[No response - timeout]"); } }, 60000);
    });
    return { content: [{ type: "text", text: response }] };
  }
);

server.tool(
  "cat_action",
  "Make the cat sit, walk, or idle.",
  { action: z.enum(["sit", "walk", "idle"]).describe("Action") },
  async ({ action }) => {
    const sent = sendToCat({ type: "action", action });
    return { content: [{ type: "text", text: sent ? `Cat: ${action}` : "Cat UI not connected." }] };
  }
);

server.tool(
  "cat_status",
  "Check if the desktop cat is running.",
  {},
  async () => ({
    content: [{ type: "text", text: wsConn ? "Cat is alive and connected!" : "Cat is not connected." }]
  })
);

// ==================== Start ====================

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[copilot-cat] MCP server running on stdio");
  if (OPENROUTER_API_KEY) {
    console.error(`[copilot-cat] OpenRouter enabled (model: ${OPENROUTER_MODEL})`);
  } else {
    console.error("[copilot-cat] OpenRouter not configured (set OPENROUTER_API_KEY to enable)");
  }
}

main().catch((err) => { console.error("[copilot-cat] Fatal:", err); process.exit(1); });
