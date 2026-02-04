# Claude Code + AWS Bedrock Setup

Automated setup script for Claude Code CLI with AWS Bedrock integration.

**Supported Platforms:** Linux and macOS

## Quick Start

```bash
./setup_claude_bedrock.sh
```

## What It Does

1. Validates AWS Bedrock credentials
2. Installs Claude Code CLI
3. Installs Node.js/npm (via nvm if needed)
4. Installs MCP servers (optional)
5. Installs VSCode extension
6. Configures shell auto-load

## Files

- `.env` - Your AWS credentials (DO NOT COMMIT)
- `.env.example` - Template for sharing
- `.gitignore` - Excludes .env from git
- `setup_claude_bedrock.sh` - Setup script
- `README_SETUP.md` - This file

## Requirements

- Internet connection
- `.env` file with valid AWS credentials
- Bash, Zsh, or Fish shell

## Usage

```bash
# Run setup
./setup_claude_bedrock.sh

# Load environment manually
source .env
```

## Documentation

- Claude Code: https://github.com/anthropics/claude-code
- VSCode Extension: https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code
- Getting Started: https://docs.anthropic.com/claude/docs/claude-code

## Troubleshooting

### Connection test fails
Check your token in `.env` file and ensure it hasn't expired.

### npm/nvm issues
The script auto-installs nvm and npm. If issues persist:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install --lts
```

### MCP server issues
Install manually:
```bash
# Playwright
claude mcp add playwright npx @playwright/mcp@latest

# Serena (requires uvx)
curl -LsSf https://astral.sh/uv/install.sh | sh
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project $(pwd)
```
