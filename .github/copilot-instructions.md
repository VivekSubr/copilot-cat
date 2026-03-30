# Copilot Instructions

## Build

### Cat UI (QML - for development/testing)
```powershell
# Run with qmlscene (no compilation needed)
$env:PATH = "C:\Qt\6.8.3\msvc2022_64\bin;" + $env:PATH
$env:QT_QUICK_CONTROLS_STYLE = "Basic"
Start-Process qmlscene.exe qml\Debug.qml
```

### MCP Server (Node.js)
```powershell
npm install
npx tsc
node dist/server.js  # runs on stdio, connects to cat via WebSocket
```

### Cat UI (compiled C++ exe)
```powershell
cmake -B build -G "Visual Studio 17 2022" -A x64 -DCMAKE_PREFIX_PATH=C:/Qt/6.8.3/msvc2022_64
cmake --build build --config Release
```

There are no linters or CI/CD workflows in this project.

## Tests

**After every code change, all tests MUST be run and pass before considering the change complete.**

Tests run automatically via CTest as part of the build (`cmake --build build --config Release`). To run them standalone:

```powershell
ctest --test-dir build --output-on-failure -C Release
```

- `test-chat-dedup` — Node.js unit tests for chat dedup guard logic (QML + server)
- `test-qt-quick` — Qt Quick Test suite (component properties, animation A/B variant, SVG assets)

Qt Quick Tests are in `tests/tst_*.qml` using `TestCase` elements. The test executable runs with `QT_QPA_PLATFORM=offscreen` so no display is needed.

## Architecture

Desktop pet cat that serves as a visual interface for GitHub Copilot via MCP. There are two deployment models:

### Development: Debug.qml + MCP Server (two processes)
- `qml/Debug.qml` runs standalone in qmlscene — transparent always-on-top window with SVG sprite animation, speech/thought bubbles, and a WebSocket client connecting to `ws://127.0.0.1:9922`.
- `mcp/server.ts` (compiled to `dist/server.js`) is a Node.js MCP server using `@modelcontextprotocol/sdk`. It exposes tools over stdio to Copilot and runs a WebSocket server on port 9922 to relay commands to the cat UI.
- Both processes must be running together for the full experience.

### Production: Compiled C++ exe (single process)
- `qml/Main.qml` is compiled into the executable via CMake + Qt. Uses `Qt.FramelessWindowHint` (works in compiled builds, unlike qmlscene).
- `src/copilotbridge.cpp` (`CopilotBridge` class) manages a `QProcess` for AI backend communication via Qt signals/slots. Reads the command from `COPILOT_CAT_CMD` env var (with `%MSG%` placeholder); falls back to a built-in cat pun generator.
- Does not connect to the MCP server — these are separate codebases that share some QML components.

### MCP Tools (exposed to Copilot)
| Tool | Parameters | Behavior |
|------|-----------|----------|
| `say_to_cat` | `message: string` | Shows speech bubble (8s auto-dismiss) |
| `ask_via_cat` | `question: string` | Shows input field, waits for user response (60s timeout) |
| `cat_action` | `action: "sit"\|"walk"\|"idle"` | Changes cat animation state |
| `cat_status` | none | Returns whether cat UI is connected |

### WebSocket Protocol (MCP server ↔ Debug.qml)
- JSON messages in WebSocket text frames (RFC 6455) on `ws://127.0.0.1:9922`
- Server → UI: `{ type: "show_bubble", text }`, `{ type: "ask_user", text }`, `{ type: "action", action }`
- UI → Server: `{ type: "chat", text }`, `{ type: "user_response", text }`

### QML Components
- `CatSprite.qml`: Procedural Qt Quick canvas drawing of the cat (currently unused — an alternative to the SVG approach)
- `ThoughtBubble.qml`: Input bubble with TextField (Enter to submit, Esc to close)
- `ReplyBubble.qml`: Speech bubble with auto-dismiss timer, dynamic width

### Cat Animation States (Debug.qml)
`pounce` → `land` → `sit` → `idle` (cycles between walking and sitting via random behavior timer). Walking uses a 4-frame sprite cycle at 180ms/frame, moving 2px/tick at 60 FPS, reversing at screen edges.

## Conventions

- SVG sprites use Catppuccin-inspired palette: body `#7f849c`, outline `#45475a`, light `#cdd6f4`, pink `#f5c2e7`
- Eye heterochromia: blue (`#89b4fa`) when facing right, amber (`#fab387`) when facing left
- Walk SVGs are generated programmatically — edit `assets/gen_walk.py` (not the SVGs directly), then run `python assets/gen_walk.py`. Same for `gen_pounce.py` and `gen_svgs.py`.
- `gen_svgs.py` generates idle/sit poses. `gen_walk.py` generates 4 walk frames + left variants (8 files total). `gen_pounce.py` generates pounce/land frames.
- All SVGs must be pure ASCII (no em-dashes or unicode) — Qt's SVG parser fails silently on non-ASCII characters
- QML Debug.qml uses `Qt.SplashScreen` flag (not `Qt.FramelessWindowHint`) because qmlscene crashes with frameless+transparent on Windows. The compiled Main.qml uses frameless safely.
- MCP tools are registered using `server.tool(name, description, zodSchema, handler)` with Zod for parameter validation
- Debug.qml has hardcoded absolute asset paths (`file:///C:/Software/copilot-cat/assets/...`) — these need updating if the repo moves
