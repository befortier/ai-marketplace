---
name: marketplace-plugin-manager
description: Create, update, and validate Claude Code marketplace plugins and marketplace.json entries. Use when creating new plugins, updating existing plugin configurations, modifying marketplace.json, or troubleshooting plugin schema issues.
---

# Marketplace Plugin Manager

You help create, update, and validate Claude Code marketplace plugins in this repository.

## Step 1: Read All Resource Files

Before doing any work, you MUST read ALL resource files in the `resources/` directory within this skill's folder. These files contain the schemas and management instructions for each configuration type.

1. Use the Glob tool to list all files matching `resources/*.md` relative to this skill's directory.
2. Use the Read tool to read ALL matched files in parallel.

Do NOT hardcode file names — always discover them dynamically via Glob. The resource files contain the authoritative instructions for each schema type, including which URLs to fetch for the latest documentation.

## Step 2: Fetch Latest Documentation

After reading the resource files, follow the documentation fetch instructions specified in each resource file relevant to your task. Always use WebFetch to retrieve the latest schemas — do NOT rely on cached or memorized schemas.

## Step 3: Understand This Repository's Structure

This repository is the **befortier-marketplace** — a personal Claude Code plugin marketplace. Before making changes, read these files to understand the current state:

- `.claude-plugin/marketplace.json` — The marketplace registry
- `plugins/` — Directory containing all plugin subdirectories
- Each plugin has: `plugins/<name>/.claude-plugin/plugin.json`

## Step 4: Perform the Requested Task

Follow the instructions from the relevant resource files based on what is being requested (creating plugins, updating marketplace entries, configuring MCP servers, etc.).

## Step 5: Validate

After any changes:

1. Verify JSON syntax is valid in all modified files
2. Cross-check that marketplace.json plugin entries match their plugin.json manifests
3. Verify directory structure matches the schema (components at plugin root, only plugin.json in `.claude-plugin/`)
4. Check for common issues:
   - No absolute paths (all must be relative with `./`)
   - No path traversal (`../`)
   - No duplicate plugin names in marketplace.json
   - kebab-case names with no spaces
   - Valid semver versions
5. If the user requests it, suggest running `claude plugin validate .` or `/plugin validate .`
