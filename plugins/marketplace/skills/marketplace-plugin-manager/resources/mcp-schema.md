# MCP.json Schema & Management

## Fetching Latest Schema

Before creating or modifying .mcp.json, you MUST use WebFetch to retrieve the latest schema:

- `https://code.claude.com/docs/en/mcp` — MCP server configuration
- `https://code.claude.com/docs/en/plugins-reference` — MCP component schema within plugins

When fetching, ask for: "Extract the complete MCP server configuration schema with all required and optional fields."

## Location Within a Plugin

MCP configuration lives at the plugin root (NOT inside `.claude-plugin/`):

```
plugins/<plugin-name>/.mcp.json
```

## Key Rules

- Use `${CLAUDE_PLUGIN_ROOT}` for all paths in MCP server configs
- All paths must be relative and start with `./`
- No absolute paths
- No path traversal (`../`)
