# copilot-cat

Desktop pet cat UI plus MCP server for GitHub Copilot.

## Build

```sh
npm install
npm run build
```

## MCP config

Use a direct launcher in your MCP config. Do not use `npm start`, `npx`, or any package-manager wrapper for an MCP server command because MCP requires clean stdio.

Windows example:

```json
{
  "servers": {
    "copilot-cat": {
      "command": "C:\\Software\\copilot-cat\\scripts\\copilot-cat-mcp.cmd"
    }
  }
}
```

Alternative Windows example using Node explicitly:

```json
{
  "servers": {
    "copilot-cat": {
      "command": "C:\\Program Files\\nodejs\\node.exe",
      "args": ["C:\\Software\\copilot-cat\\dist\\server.js"]
    }
  }
}
```

Unix example:

```json
{
  "servers": {
    "copilot-cat": {
      "command": "/path/to/copilot-cat/scripts/copilot-cat-mcp"
    }
  }
}
```

## Troubleshooting

- If Copilot CLI stays on "Loaded 1 MCP server(s)", the server command is usually wrong or wrapped by `npm`/`npx`.
- The MCP process must write only MCP protocol messages to stdout. This server writes logs to stderr only.
- Build output must exist at `dist/server.js` before launching the server.