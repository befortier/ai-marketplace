# Marketplace.json Schema & Management

## Fetching Latest Schema

Before creating or modifying marketplace.json, you MUST use WebFetch to retrieve the latest schema:

- `https://code.claude.com/docs/en/plugin-marketplaces` — Marketplace.json schema, plugin entry fields, plugin source types, validation, and distribution
- `https://code.claude.com/docs/en/discover-plugins` — Installing plugins, adding marketplaces, configuring team marketplaces

When fetching, ask for: "Extract the complete marketplace.json schema with plugin entry fields, source types, and validation rules."

## Repository Location

- `.claude-plugin/marketplace.json` — The marketplace registry (lists all plugins and their sources)

## Adding a Plugin Entry to marketplace.json

When adding a new plugin to the marketplace registry:

- `name` — Must match the plugin's manifest name
- `source` — Relative path like `./plugins/<plugin-name>`
- `description`, `version`, `author`, `keywords` — Match or supplement the manifest

## Validation Rules

- No duplicate plugin names in marketplace.json
- Plugin entries must match their corresponding plugin.json manifests
- Names must be kebab-case with no spaces
- Versions must be valid semver