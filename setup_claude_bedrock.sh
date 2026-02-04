#!/bin/bash
# Claude Code + AWS Bedrock Setup Script
# This script automates the installation and configuration of Claude Code CLI
# with AWS Bedrock integration. It handles dependencies, validates credentials,
# and configures your development environment.
#
# Author: NAXA | Platform: macOS and Linux

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cat << 'EOF'
                          #
####                      *##
#####                   **###
#######               ***####
##########          ****#####            ************      ***********  *****    *****  ************
###########       *#***######            **************  *************   ************ **************
#############   ******#######            *****    ***** *****    *****     ********   ****     *****
############# *******########            ****     ***** ****      ****      ******   *****      ****
########### *#******#########            ****     ***** *****    *****     ********   ****     *****
##########**********#***#####            ****     *****  *************   ************ **************
########*********** *******##            ****     *****    ***********  *****    *****  ************
######*********       ******#
#####******             #***#
###*##*                   **#
##*                         *
EOF

sleep 2
clear

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Claude Code CLI + Bedrock Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}This setup script will:${NC}"
echo ""
echo "  1. Validate AWS Bedrock credentials"
echo "  2. Install Claude Code CLI (via npm)"
echo "  3. Install Node.js & npm (via nvm, if not installed)"
echo "  4. Install MCP Servers (optional):"
echo "     - Playwright MCP (browser automation)"
echo "     - Serena MCP (IDE assistant)"
echo "     - uv/uvx (Python package installer, if needed)"
echo "  5. Install VSCode Extension (if VSCode CLI available)"
echo "  6. Configure shell (auto-load environment variables)"
echo ""

read -p "Do you want to continue with the installation? [y/N]: " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled by user.${NC}"
    echo "Run this script again when you're ready to install."
    exit 0
fi

echo ""
echo -e "${GREEN}Starting installation...${NC}"
echo ""

echo -e "${YELLOW}Configuring AWS Bedrock environment...${NC}"
echo ""

export CLAUDE_CODE_USE_BEDROCK="1"
export AWS_REGION="us-east-1"

# Ask for AWS Bearer Token (required)
echo -e "${YELLOW}Please provide your AWS Bedrock Bearer Token:${NC}"
echo -e "${BLUE}(It's a long encoded string, usually ~100+ characters)${NC}"
read -p "AWS_BEARER_TOKEN_BEDROCK: " AWS_BEARER_TOKEN_BEDROCK

AWS_BEARER_TOKEN_BEDROCK=$(echo -n "$AWS_BEARER_TOKEN_BEDROCK" | xargs)
export AWS_BEARER_TOKEN_BEDROCK="$AWS_BEARER_TOKEN_BEDROCK"

if [ -z "$AWS_BEARER_TOKEN_BEDROCK" ]; then
    echo -e "${RED}Error: AWS_BEARER_TOKEN_BEDROCK is required${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Token received (${#AWS_BEARER_TOKEN_BEDROCK} characters)${NC}"
echo "  Preview: ${AWS_BEARER_TOKEN_BEDROCK:0:20}...${AWS_BEARER_TOKEN_BEDROCK: -10}"

echo ""

echo -e "${YELLOW}AWS Region${NC}"
echo "  Default: us-east-1"
echo "  Examples: us-west-2, eu-west-1, ap-southeast-1"
read -p "Press Enter to use default, or type a different region: " USER_REGION

if [ -n "$USER_REGION" ]; then
    export AWS_REGION="$USER_REGION"
    echo -e "${GREEN}✓ Region set to: $AWS_REGION${NC}"
else
    echo -e "${GREEN}✓ Using default region: us-east-1${NC}"
fi

echo ""
echo -e "${GREEN}✓ Environment variables configured${NC}"
echo "  - AWS_BEARER_TOKEN_BEDROCK: ${AWS_BEARER_TOKEN_BEDROCK:0:20}..."
echo "  - AWS_REGION: $AWS_REGION"
echo "  - CLAUDE_CODE_USE_BEDROCK: $CLAUDE_CODE_USE_BEDROCK"
echo ""

echo -e "${GREEN}Testing AWS Bedrock connection...${NC}"

CURL_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "https://bedrock-runtime.$AWS_REGION.amazonaws.com/model/us.anthropic.claude-3-5-haiku-20241022-v1:0/converse" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AWS_BEARER_TOKEN_BEDROCK" \
  -d '{
    "messages": [
        {
            "role": "user",
            "content": [{"text": "Hello"}]
        }
    ]
  }')

HTTP_CODE=$(echo "$CURL_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$CURL_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ AWS Bedrock connection successful!${NC}"
else
    echo -e "${RED}✗ Connection failed (HTTP $HTTP_CODE)${NC}"
    echo ""
    echo -e "${RED}ERROR: Invalid AWS credentials${NC}"
    echo -e "${YELLOW}Please verify and try again:${NC}"
    echo "  1. Check AWS_BEARER_TOKEN_BEDROCK is correct"
    echo "  2. Ensure the token hasn't expired"
    echo "  3. Verify AWS_REGION is valid: $AWS_REGION"
    echo ""
    echo "Run this script again to re-enter your credentials."
    if [ -n "${RESPONSE_BODY:-}" ]; then
        echo "Response: $RESPONSE_BODY"
    fi
    exit 1
fi

echo ""

CURRENT_SHELL=$(basename "${SHELL}" 2>/dev/null || echo "bash")
OS_TYPE=$(uname -s 2>/dev/null || echo "Linux")
echo -e "${YELLOW}Detected OS: $OS_TYPE${NC}"
echo -e "${YELLOW}Detected shell: $CURRENT_SHELL${NC}\n"

install_nvm() {
    echo "Installing nvm (Node Version Manager)..."
    if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; then
        echo -e "${RED}✗ nvm installation failed${NC}"
        return 1
    fi

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if command -v nvm &> /dev/null; then
        echo -e "${GREEN}✓ nvm installed successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ nvm installation failed${NC}"
        return 1
    fi
}

ensure_npm() {
    if command -v npm &> /dev/null; then
        echo -e "${GREEN}✓ npm is already installed${NC}"
        npm --version 2>/dev/null || true
        return 0
    fi

    echo -e "${YELLOW}npm not found. Installing via nvm...${NC}"

    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    fi

    if ! command -v nvm &> /dev/null; then
        echo "nvm not found. Installing nvm..."
        if ! install_nvm; then
            echo -e "${RED}Failed to install nvm. Please install manually.${NC}"
            echo "Visit: https://github.com/nvm-sh/nvm"
            return 1
        fi
    else
        echo -e "${GREEN}✓ nvm is already installed${NC}"
    fi

    echo "Installing Node.js LTS via nvm..."
    nvm install --lts 2>&1 || true
    nvm use --lts 2>&1 || true

    if command -v npm &> /dev/null; then
        echo -e "${GREEN}✓ Node.js and npm installed successfully via nvm${NC}"
        node --version 2>/dev/null || true
        npm --version 2>/dev/null || true
        return 0
    else
        echo -e "${RED}✗ Failed to install npm via nvm${NC}"
        return 1
    fi
}

echo -e "${GREEN}[Step 1/5] Installing Claude Code CLI...${NC}"

if command -v claude &> /dev/null; then
    echo -e "${YELLOW}Claude Code CLI is already installed.${NC}"
    claude --version
else
    echo "Claude Code CLI not found. Installing..."

    if ! ensure_npm; then
        echo -e "${RED}Cannot proceed without npm. Exiting.${NC}"
        exit 1
    fi

    echo "Installing @anthropic-ai/claude-code..."
    npm install -g @anthropic-ai/claude-code

    if command -v claude &> /dev/null; then
        echo -e "${GREEN}✓ Claude Code CLI installed successfully!${NC}"
        claude --version
    else
        echo -e "${RED}✗ Installation failed. Please try manual installation.${NC}"
        echo "Try: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
fi

echo ""

echo -e "${GREEN}[Step 2/5] Recommended MCP Servers${NC}"
echo ""
echo "Would you like to install recommended MCP servers?"
echo "  - Playwright (browser automation)"
echo "  - Serena (IDE assistant)"
echo ""
read -p "Install MCP servers? [Y/n]: " -n 1 -r
echo ""

INSTALL_MCP=${REPLY:-Y}
MCP_INSTALLED=false

if [[ $INSTALL_MCP =~ ^[Yy]$ ]] || [[ -z $INSTALL_MCP ]]; then
    echo -e "${GREEN}Installing recommended MCP servers...${NC}"
    echo ""
    MCP_INSTALLED=true

    echo -e "${BLUE}[1/2] Installing Playwright MCP server...${NC}"
    if claude mcp add playwright npx @playwright/mcp@latest; then
        echo -e "${GREEN}✓ Playwright MCP server installed${NC}"
    else
        echo -e "${YELLOW}⚠ Playwright MCP installation failed (non-critical)${NC}"
    fi
    echo ""

    echo -e "${BLUE}[2/2] Installing Serena MCP server...${NC}"

    if ! command -v uvx &> /dev/null; then
        echo "uvx not found. Installing uv (Python package installer)..."

        if [ "$OS_TYPE" = "Darwin" ]; then
            if command -v brew &> /dev/null; then
                echo "Installing uv via Homebrew..."
                brew install uv
            else
                echo "Installing uv via curl..."
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
        else
            echo "Installing uv via curl..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi

        export PATH="$HOME/.local/bin:$PATH"

        if command -v uvx &> /dev/null; then
            echo -e "${GREEN}✓ uv/uvx installed successfully${NC}"
        else
            echo -e "${YELLOW}⚠ uvx installation failed. Skipping Serena MCP.${NC}"
            echo "You can install uv manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
        fi
    else
        echo -e "${GREEN}✓ uvx is already installed${NC}"
    fi

    if command -v uvx &> /dev/null; then
        PROJECT_PATH=$(pwd)
        if claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project "$PROJECT_PATH"; then
            echo -e "${GREEN}✓ Serena MCP server installed${NC}"
        else
            echo -e "${YELLOW}⚠ Serena MCP installation failed (non-critical)${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}✓ MCP servers installation complete${NC}"
else
    echo -e "${YELLOW}Skipping MCP servers installation${NC}"
    echo "You can install them later with:"
    echo "  claude mcp add playwright npx @playwright/mcp@latest"
    echo "  claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project \$(pwd)"
fi

echo ""

echo -e "${GREEN}[Step 3/5] Configuring shell to auto-load environment...${NC}"

ENV_FILE_ABSOLUTE="$(cd "$(dirname "${ENV_FILE:-.env}")" && pwd)/$(basename "${ENV_FILE:-.env}")"

NVM_INSTALLED=false
if [ -d "$HOME/.nvm" ]; then
    NVM_INSTALLED=true
fi

UV_INSTALLED=false
if [ -d "$HOME/.local/bin" ] && [ -f "$HOME/.local/bin/uvx" ]; then
    UV_INSTALLED=true
fi

CONFIG_SUCCESS=false
case "$CURRENT_SHELL" in
    bash)
        SHELL_RC="$HOME/.bashrc"
        if [ "$OS_TYPE" = "Darwin" ] && [ ! -f "$HOME/.bashrc" ]; then
            SHELL_RC="$HOME/.bash_profile"
        fi
        
        # Add configuration entries
        if [ "$NVM_INSTALLED" = true ] && ! grep -q "NVM_DIR" "$SHELL_RC" 2>/dev/null; then
            echo -e "\n# nvm initialization\nexport NVM_DIR=\"\$HOME/.nvm\"\n[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\"" >> "$SHELL_RC"
        fi
        [ "$UV_INSTALLED" = true ] && ! grep -q ".local/bin" "$SHELL_RC" 2>/dev/null && echo -e "\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
        if ! grep -Fq "$ENV_FILE_ABSOLUTE" "$SHELL_RC" 2>/dev/null; then
            echo -e "\n# Claude Code Bedrock configuration\n[ -f \"$ENV_FILE_ABSOLUTE\" ] && source \"$ENV_FILE_ABSOLUTE\"" >> "$SHELL_RC"
        fi
        echo -e "${GREEN}✓ Configured: $SHELL_RC${NC}"
        CONFIG_SUCCESS=true
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        if [ "$NVM_INSTALLED" = true ] && ! grep -q "NVM_DIR" "$SHELL_RC" 2>/dev/null; then
            echo -e "\n# nvm initialization\nexport NVM_DIR=\"\$HOME/.nvm\"\n[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\"" >> "$SHELL_RC"
        fi
        [ "$UV_INSTALLED" = true ] && ! grep -q ".local/bin" "$SHELL_RC" 2>/dev/null && echo -e "\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
        if ! grep -Fq "$ENV_FILE_ABSOLUTE" "$SHELL_RC" 2>/dev/null; then
            echo -e "\n# Claude Code Bedrock configuration\n[ -f \"$ENV_FILE_ABSOLUTE\" ] && source \"$ENV_FILE_ABSOLUTE\"" >> "$SHELL_RC"
        fi
        echo -e "${GREEN}✓ Configured: $SHELL_RC${NC}"
        CONFIG_SUCCESS=true
        ;;
    fish)
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        mkdir -p "$HOME/.config/fish"
        [ "$NVM_INSTALLED" = true ] && ! grep -q "nvm" "$FISH_CONFIG" 2>/dev/null && echo -e "\n# nvm initialization\nif test -d ~/.nvm\n    bass source ~/.nvm/nvm.sh\nend" >> "$FISH_CONFIG"
        [ "$UV_INSTALLED" = true ] && ! grep -q ".local/bin" "$FISH_CONFIG" 2>/dev/null && echo -e "\nset -gx PATH \$HOME/.local/bin \$PATH" >> "$FISH_CONFIG"
        if ! grep -Fq "$ENV_FILE_ABSOLUTE" "$FISH_CONFIG" 2>/dev/null; then
            echo -e "\nif test -f $ENV_FILE_ABSOLUTE\n    source $ENV_FILE_ABSOLUTE\nend" >> "$FISH_CONFIG"
        fi
        echo -e "${GREEN}✓ Configured: $FISH_CONFIG${NC}"
        CONFIG_SUCCESS=true
        ;;
    *)
        echo -e "${YELLOW}⚠ Unsupported shell: $CURRENT_SHELL - manual config needed${NC}"
        ;;
esac

if [ "$CONFIG_SUCCESS" = true ]; then
    echo -e "${YELLOW}Restart your terminal or run 'source' to apply changes.${NC}"
fi

# Add .env to .gitignore if this is a git repository
if [ -d .git ]; then
    GITIGNORE_FILE=".gitignore"
    if [ ! -f "$GITIGNORE_FILE" ]; then
        echo "# Environment variables" > "$GITIGNORE_FILE"
        echo ".env" >> "$GITIGNORE_FILE"
        echo -e "${GREEN}✓ Created .gitignore with .env${NC}"
    elif ! grep -q "^\.env$" "$GITIGNORE_FILE" 2>/dev/null; then
        echo "" >> "$GITIGNORE_FILE"
        echo "# Environment variables" >> "$GITIGNORE_FILE"
        echo ".env" >> "$GITIGNORE_FILE"
        echo -e "${GREEN}✓ Added .env to .gitignore${NC}"
    else
        echo -e "${YELLOW}✓ .env already in .gitignore${NC}"
    fi
fi

echo ""

echo -e "${GREEN}[Step 4/5] Installing VSCode Extension...${NC}"

if command -v code &> /dev/null; then
    echo "VSCode command-line tool detected. Installing Claude Code extension..."

    if code --list-extensions | grep -q "Anthropic.claude-code"; then
        echo -e "${YELLOW}✓ Claude Code extension is already installed${NC}"
    else
        if code --install-extension Anthropic.claude-code; then
            echo -e "${GREEN}✓ Claude Code extension installed successfully!${NC}"
        else
            echo -e "${RED}✗ Failed to install extension automatically${NC}"
            echo -e "${YELLOW}Please install manually from VSCode Extensions marketplace${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ VSCode command-line tool not found${NC}"
    echo "The extension will need to be installed manually."
    echo "Install from: https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code"
fi

echo ""

echo -e "${GREEN}[Step 5/5] Setup Complete!${NC}\n"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ SETUP SUCCESSFUL!${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Show configuration summary
echo -e "${BLUE}Configuration:${NC}"
echo "  ✓ Environment loaded from: $ENV_FILE_ABSOLUTE"
echo "  ✓ AWS_REGION: $AWS_REGION"
echo "  ✓ CLAUDE_CODE_USE_BEDROCK: enabled"
echo "  ✓ Shell auto-load: configured"
if command -v code &> /dev/null && code --list-extensions | grep -q "Anthropic.claude-code"; then
    echo "  ✓ VSCode extension: installed"
fi
if [ "$MCP_INSTALLED" = true ]; then
    echo "  ✓ MCP servers: installed (Playwright, Serena)"
fi
echo ""

echo -e "${BLUE}Claude Code Version:${NC}"
if command -v claude &> /dev/null; then
    claude --version
else
    echo "  Claude CLI not found"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All Done! Happy Coding with Claude!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Documentation & Resources:${NC}"
echo "  • Claude Code CLI: https://github.com/anthropics/claude-code"
echo "  • VSCode Extension: https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code"
echo "  • Getting Started: https://docs.anthropic.com/claude/docs/claude-code"
echo "  • VSCode Integration: https://code.visualstudio.com/docs/editor/artificial-intelligence#_claude-code"
echo ""
