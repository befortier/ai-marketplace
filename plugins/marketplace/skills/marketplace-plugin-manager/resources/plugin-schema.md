# Plugin.json Schema & Management

## Fetching Latest Schema

Before creating or modifying plugin.json, you MUST use WebFetch to retrieve the latest schema:

- `https://code.claude.com/docs/en/plugins-reference` — Complete plugin manifest schema, component schemas (hooks, MCP, LSP, agents, skills, commands), environment variables, path rules, and debugging guidance
- `https://code.claude.com/docs/en/plugins` — Plugin creation tutorials, directory structure, converting standalone configs to plugins

When fetching, ask for: "Extract the complete plugin.json manifest schema with all required and optional fields."

## Additional References (fetch as needed)

- `https://code.claude.com/docs/en/skills` — Skill authoring, SKILL.md frontmatter, progressive disclosure, tool restrictions
- `https://code.claude.com/docs/en/hooks` — Hook event types, matcher patterns, hook types (command, prompt, agent)
- `https://code.claude.com/docs/en/sub-agents` — Agent markdown format, capabilities, frontmatter
- `https://code.claude.com/docs/en/settings` — Plugin settings, scopes, strictKnownMarketplaces

## Repository Structure

Each plugin lives under `plugins/` with this structure:

- `plugins/<name>/.claude-plugin/plugin.json` — The plugin manifest

Review plugins under the `plugins/` directory to better understand common patterns.

## Creating a New Plugin

1. **Read the fetched plugin manifest schema** to know all required and optional fields
2. Create the plugin directory: `plugins/<plugin-name>/`
3. Create the manifest directory: `plugins/<plugin-name>/.claude-plugin/`
4. Create `plugins/<plugin-name>/.claude-plugin/plugin.json` following the schema exactly:
   - **Required**: `name` (kebab-case, no spaces)
   - **Recommended**: `description`, `version` (semver), `owner`, `keywords`
5. Add component directories at the plugin root (NOT inside `.claude-plugin/`):
   - `skills/` — Skill directories each containing `SKILL.md`
   - `commands/` — Command markdown files
   - `agents/` — Agent markdown files
   - `hooks/` — `hooks.json` for event handlers
   - `.mcp.json` — MCP server configurations
   - `.lsp.json` — LSP server configurations
6. **Update `marketplace.json`** — See marketplace-schema.md

## Updating an Existing Plugin

1. Read the current plugin manifest and marketplace entry
2. Fetch latest documentation to verify the schema hasn't changed
3. Make the requested changes while preserving existing valid fields
4. If the version changes, follow semver: MAJOR (breaking), MINOR (new features), PATCH (fixes)
5. Ensure marketplace.json entry stays in sync with the plugin manifest

## Adding Components to a Plugin

When adding skills, agents, hooks, MCP servers, or LSP servers:

1. Fetch the specific component's schema from the documentation
2. Place component directories at the plugin root, never inside `.claude-plugin/`
3. Use `${CLAUDE_PLUGIN_ROOT}` for all paths in hooks and MCP server configs
4. Ensure scripts are executable (`chmod +x`)
5. All paths must be relative and start with `./`