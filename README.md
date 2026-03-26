# ai-marketplace

Personal Claude Code plugin marketplace.

## Structure

```
.claude-plugin/
  marketplace.json    # Marketplace registry
plugins/
  <plugin-name>/
    .claude-plugin/
      plugin.json     # Plugin manifest
    skills/           # Skills (SKILL.md files)
    agents/           # Agents (markdown files)
    commands/         # Commands (markdown files)
    hooks/            # Hooks (hooks.json)
    .mcp.json         # MCP servers
```

## Usage

```bash
# Add this marketplace
/plugin marketplace add befortier/ai-marketplace

# Install a plugin
/plugin install <plugin-name>@befortier-marketplace

# Update marketplace
/plugin marketplace update befortier-marketplace
```
