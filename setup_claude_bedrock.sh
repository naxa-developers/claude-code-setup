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
CYAN='\033[0;36m'
NC='\033[0m'

# Spinner frames
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
PROGRESS_STEP=0

# Progress animation - inline
progress_inline() {
    local text="$1"
    local duration="${2:-20}"
    local i=0
    for ((i=0; i<duration; i++)); do
        local frame_index=$((i % 10))
        printf "\r${BLUE}${SPINNER_FRAMES[$frame_index]}${NC} ${text}"
        sleep 0.08
    done
    printf "\r${GREEN}✓${NC} ${text}\n"
}

# Progress with percentage
progress_percent() {
    local current="$1"
    local total="$2"
    local text="$3"
    local percent=$((current * 100 / total))
    printf "\r${CYAN}[%3d%%]${NC} ${SPINNER_FRAMES[$((PROGRESS_STEP % 10))]} ${text}" "$percent"
    ((PROGRESS_STEP++))
}

# Complete progress
progress_complete() {
    local text="$1"
    printf "\r${GREEN}✓${NC} ${text}\n"
}

progress_inline "Initializing Claude Code + Bedrock Setup..." 15
sleep 0.3

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Claude Code CLI + Bedrock Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}This setup script will:${NC}"
echo -e "  ${CYAN}1.${NC} Validate AWS Bedrock credentials"
echo -e "  ${CYAN}2.${NC} Install Claude Code CLI (via npm)"
echo -e "  ${CYAN}3.${NC} Install Node.js & npm (via nvm, if not installed)"
echo -e "  ${CYAN}4.${NC} Install MCP Servers (optional)"
echo -e "  ${CYAN}5.${NC} Configure shell (auto-load environment variables)"
echo ""

read -p "Do you want to continue with the installation? [y/N]: " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled by user.${NC}"
    echo "Run this script again when you're ready to install."
    exit 0
fi

progress_inline "Starting setup sequence..." 15
progress_inline "Validating system environment..." 12

export CLAUDE_CODE_USE_BEDROCK="1"
export AWS_REGION="us-east-1"

# Ask for AWS Bearer Token (required)
echo ""
echo -e "${YELLOW}Configuring AWS Bedrock environment...${NC}"
echo -e "${BLUE}Please provide your AWS Bedrock Bearer Token:${NC}"
echo -e "${BLUE}(It's a long encoded string, usually ~100+ characters)${NC}"
read -p "AWS_BEARER_TOKEN_BEDROCK: " AWS_BEARER_TOKEN_BEDROCK

progress_inline "Processing token..." 10
AWS_BEARER_TOKEN_BEDROCK=$(echo -n "$AWS_BEARER_TOKEN_BEDROCK" | xargs)
export AWS_BEARER_TOKEN_BEDROCK="$AWS_BEARER_TOKEN_BEDROCK"

if [ -z "$AWS_BEARER_TOKEN_BEDROCK" ]; then
    echo -e "${RED}✗ Error: AWS_BEARER_TOKEN_BEDROCK is required${NC}"
    exit 1
fi

progress_complete "Token received (${#AWS_BEARER_TOKEN_BEDROCK} characters)"
echo "  Preview: ${AWS_BEARER_TOKEN_BEDROCK:0:20}...${AWS_BEARER_TOKEN_BEDROCK: -10}"
echo ""

echo -e "${YELLOW}AWS Region Configuration${NC}"
echo "  Default: us-east-1 | Examples: us-west-2, eu-west-1, ap-southeast-1"
read -p "Press Enter to use default, or type a different region: " USER_REGION

if [ -n "$USER_REGION" ]; then
    export AWS_REGION="$USER_REGION"
    progress_complete "Region set to: $AWS_REGION"
else
    progress_complete "Using default region: us-east-1"
fi

echo ""
progress_inline "Testing AWS Bedrock connection..." 20

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
    progress_complete "AWS Bedrock connection successful!"
else
    printf "\r${RED}✗ Connection failed (HTTP $HTTP_CODE)${NC}\n"
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
progress_complete "Detected OS: $OS_TYPE | Shell: $CURRENT_SHELL"
echo ""

install_nvm() {
    printf "${BLUE}→${NC} Installing nvm (Node Version Manager)..."
    if curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash &>/dev/null; then
        printf "\r${GREEN}✓${NC} nvm installed successfully\n"

        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        return 0
    else
        printf "\r${RED}✗${NC} nvm installation failed\n"
        return 1
    fi
}

ensure_npm() {
    if command -v npm &> /dev/null; then
        progress_complete "npm is already installed ($(npm --version 2>/dev/null))"
        return 0
    fi

    progress_inline "npm not found. Installing via nvm..." 15

    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    fi

    if ! command -v nvm &> /dev/null; then
        if ! install_nvm; then
            echo -e "${RED}✗ Failed to install nvm. Please install manually.${NC}"
            echo "Visit: https://github.com/nvm-sh/nvm"
            return 1
        fi
    else
        progress_complete "nvm is already installed"
    fi

    printf "${BLUE}→${NC} Installing Node.js LTS..."
    nvm install --lts 2>&1 | grep -E "Now using|already installed" | tail -1 || true
    nvm use --lts 2>&1 || true
    printf "\r${GREEN}✓${NC} Node.js installed ($(node --version 2>/dev/null))\n"

    if command -v npm &> /dev/null; then
        return 0
    else
        echo -e "${RED}✗ Failed to install npm via nvm${NC}"
        return 1
    fi
}

echo ""
progress_inline "Step 1/5: Installing Claude Code CLI..." 12
if command -v claude &> /dev/null; then
    progress_complete "Claude Code CLI is already installed ($(claude --version 2>/dev/null))"
else
    progress_inline "Claude Code CLI not found. Installing..." 15

    if ! ensure_npm; then
        printf "\r${RED}✗${NC} Cannot proceed without npm\n"
        exit 1
    fi

    printf "${BLUE}→${NC} Installing @anthropic-ai/claude-code..."
    if npm install -g @anthropic-ai/claude-code &>/dev/null; then
        printf "\r${GREEN}✓${NC} Claude Code CLI installed ($(claude --version 2>/dev/null))\n"
    else
        printf "\r${RED}✗${NC} Installation failed\n"
        echo "Try: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
fi

echo ""
progress_inline "Step 2/5: Configuring MCP Servers..." 12
echo "Would you like to install recommended MCP servers?"
echo -e "  ${CYAN}→${NC} Playwright (browser automation)"
echo -e "  ${CYAN}→${NC} Serena (IDE assistant)"
echo ""
read -p "Install MCP servers? [Y/n]: " -n 1 -r
echo ""

INSTALL_MCP=${REPLY:-Y}
MCP_INSTALLED=false

if [[ $INSTALL_MCP =~ ^[Yy]$ ]] || [[ -z $INSTALL_MCP ]]; then
    echo ""
    printf "${BLUE}→${NC} Installing Playwright MCP server..."
    if claude mcp add playwright npx @playwright/mcp@latest &>/dev/null; then
        printf "\r${GREEN}✓${NC} Playwright MCP server installed\n"
    else
        printf "\r${YELLOW}⚠${NC} Playwright MCP installation skipped\n"
    fi
    
    printf "${BLUE}→${NC} Installing Serena MCP server..."
    if ! command -v uvx &> /dev/null; then
        printf "\n${BLUE}→${NC} Installing uv (Python package installer)..."
        if [ "$OS_TYPE" = "Darwin" ]; then
            if command -v brew &> /dev/null; then
                brew install uv &>/dev/null && printf "\r${GREEN}✓${NC} uv installed via Homebrew\n" || printf "\r${YELLOW}⚠${NC} Homebrew uv failed\n"
            else
                curl -LsSf https://astral.sh/uv/install.sh | sh &>/dev/null && printf "\r${GREEN}✓${NC} uv installed\n" || printf "\r${YELLOW}⚠${NC} uv installation skipped\n"
            fi
        else
            curl -LsSf https://astral.sh/uv/install.sh | sh &>/dev/null && printf "\r${GREEN}✓${NC} uv installed\n" || printf "\r${YELLOW}⚠${NC} uv installation skipped\n"
        fi
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if command -v uvx &> /dev/null; then
        PROJECT_PATH=$(pwd)
        if claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project "$PROJECT_PATH" &>/dev/null; then
            printf "\r${GREEN}✓${NC} Serena MCP server installed\n"
            MCP_INSTALLED=true
        else
            printf "\r${YELLOW}⚠${NC} Serena MCP installation skipped\n"
        fi
    else
        printf "\r${YELLOW}⚠${NC} uvx not available, Serena MCP skipped\n"
    fi
else
    echo -e "${YELLOW}Skipping MCP servers installation${NC}"
fi

echo ""
progress_inline "Step 3/5: Configuring shell environment..." 15

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
        printf "\r${GREEN}✓${NC} Configured: $SHELL_RC\n"
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
        printf "\r${GREEN}✓${NC} Configured: $SHELL_RC\n"
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
        printf "\r${GREEN}✓${NC} Configured: $FISH_CONFIG\n"
        CONFIG_SUCCESS=true
        ;;
    *)
        printf "${YELLOW}⚠${NC} Unsupported shell: $CURRENT_SHELL - manual config needed\n"
        ;;
esac

if [ "$CONFIG_SUCCESS" = true ]; then
    echo -e "${YELLOW}Restart your terminal or run 'source' to apply changes.${NC}"
fi

echo ""

# Add .env to .gitignore if this is a git repository
if [ -d .git ]; then
    printf "${BLUE}→${NC} Adding .env to .gitignore..."
    GITIGNORE_FILE=".gitignore"
    if [ ! -f "$GITIGNORE_FILE" ]; then
        echo "# Environment variables" > "$GITIGNORE_FILE"
        echo ".env" >> "$GITIGNORE_FILE"
        printf "\r${GREEN}✓${NC} Created .gitignore with .env\n"
    elif ! grep -q "^\.env$" "$GITIGNORE_FILE" 2>/dev/null; then
        echo "" >> "$GITIGNORE_FILE"
        echo "# Environment variables" >> "$GITIGNORE_FILE"
        echo ".env" >> "$GITIGNORE_FILE"
        printf "\r${GREEN}✓${NC} Added .env to .gitignore\n"
    else
        printf "\r${YELLOW}✓${NC} .env already in .gitignore\n"
    fi
fi

echo ""
progress_inline "Step 4/5: Installing VSCode Extension..." 12
if command -v code &> /dev/null; then
    printf "${BLUE}→${NC} Checking VSCode extension..."
    if code --list-extensions 2>/dev/null | grep -q "Anthropic.claude-code"; then
        printf "\r${GREEN}✓${NC} Claude Code extension already installed\n"
    else
        printf "\r${BLUE}→${NC} Installing Claude Code extension..."
        if code --install-extension Anthropic.claude-code &>/dev/null; then
            printf "\r${GREEN}✓${NC} Claude Code extension installed\n"
        else
            printf "\r${YELLOW}⚠${NC} Extension installation skipped\n"
        fi
    fi
else
    printf "${YELLOW}⚠${NC} VSCode not found - install extension manually\n"
    echo "   From: https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code"
fi

echo ""
progress_inline "Step 5/5: Finalizing setup..." 12
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ SETUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Configuration Summary:${NC}"
echo "  ✓ Environment: $ENV_FILE_ABSOLUTE"
echo "  ✓ AWS Region: $AWS_REGION"
echo "  ✓ Bedrock: enabled"
echo "  ✓ Shell: configured"
if command -v code &> /dev/null && code --list-extensions 2>/dev/null | grep -q "Anthropic.claude-code"; then
    echo "  ✓ VSCode: Claude Code extension installed"
fi
[ "$MCP_INSTALLED" = true ] && echo "  ✓ MCP Servers: installed"
echo ""

if command -v claude &> /dev/null; then
    echo -e "${CYAN}Claude Code Version:${NC}"
    claude --version
fi
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo -e "  1. Source the environment: ${YELLOW}source .env${NC}"
echo -e "  2. Verify connection: ${YELLOW}claude --version${NC}"
echo -e "  3. Start coding: ${YELLOW}claude <your-file>${NC}"
echo ""
echo -e "${CYAN}Documentation:${NC}"
echo "  • CLI: https://github.com/anthropics/claude-code"
echo "  • Docs: https://docs.anthropic.com/claude/docs/claude-code"
echo ""
echo -e "${GREEN}Happy coding with Claude!${NC}"
echo ""
