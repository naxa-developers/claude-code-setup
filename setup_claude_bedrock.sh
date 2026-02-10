#!/bin/bash
# Claude Code + AWS Bedrock Setup Script
# This script automates the installation and configuration of Claude Code CLI
# with AWS Bedrock integration.
#
# Author: NAXA | Platform: macOS and Linux
# Updated for cross-platform compatibility

set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Spinner frames
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# Detect OS
OS_TYPE=$(uname -s 2>/dev/null || echo "Linux")
CURRENT_SHELL=$(basename "${SHELL}" 2>/dev/null || echo "bash")

# --- Helper Functions ---

cleanup() {
    # Restore cursor
    tput cnorm
}
trap cleanup EXIT INT TERM

hide_cursor() {
    tput civis
}

progress_inline() {
    local text="$1"
    local duration="${2:-20}"
    hide_cursor
    for ((i=0; i<duration; i++)); do
        local frame_index=$((i % 10))
        printf "\r${BLUE}${SPINNER_FRAMES[$frame_index]}${NC} ${text}"
        sleep 0.1
    done
    printf "\r${GREEN}✓${NC} ${text}   \n"
}

progress_complete() {
    local text="$1"
    printf "\r${GREEN}✓${NC} ${text}\n"
}

check_requirements() {
    local missing=()
    for cmd in curl bash grep; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        printf "${RED}✗ Error: Missing required commands: ${missing[*]}${NC}\n"
        exit 1
    fi
}

# --- Main Script ---

check_requirements

printf "${BLUE}========================================${NC}\n"
printf "${BLUE}  Claude Code CLI + Bedrock Setup${NC}\n"
printf "${BLUE}========================================${NC}\n"
printf "Detected Platform: ${CYAN}${OS_TYPE}${NC} | Shell: ${CYAN}${CURRENT_SHELL}${NC}\n\n"

printf "${YELLOW}This setup script will:${NC}\n"
printf "  ${CYAN}1.${NC} Validate AWS Bedrock credentials\n"
printf "  ${CYAN}2.${NC} Install Node.js & npm (via nvm)\n"
printf "  ${CYAN}3.${NC} Install Claude Code CLI\n"
printf "  ${CYAN}4.${NC} Install MCP Servers (Playwright & Serena)\n"
printf "  ${CYAN}5.${NC} Configure environment variables\n\n"

read -p "Do you want to continue? [y/N]: " -n 1 -r
printf "\n"
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "${YELLOW}Installation cancelled.${NC}\n"
    exit 0
fi

# --- Step 1: AWS Configuration ---

export CLAUDE_CODE_USE_BEDROCK="1"

printf "\n${YELLOW}Configuring AWS Bedrock credentials...${NC}\n"
printf "${BLUE}Paste your AWS Bearer Token:${NC}\n"
read -r AWS_BEARER_TOKEN_BEDROCK

# Trim whitespace
AWS_BEARER_TOKEN_BEDROCK=$(echo "$AWS_BEARER_TOKEN_BEDROCK" | xargs)
export AWS_BEARER_TOKEN_BEDROCK="$AWS_BEARER_TOKEN_BEDROCK"

if [ -z "$AWS_BEARER_TOKEN_BEDROCK" ]; then
    printf "${RED}✗ Error: Token cannot be empty.${NC}\n"
    exit 1
fi

printf "\n${BLUE}Enter AWS Region (default: us-east-1):${NC} "
read -r USER_REGION
if [ -n "$USER_REGION" ]; then
    export AWS_REGION="$USER_REGION"
else
    export AWS_REGION="us-east-1"
fi

progress_inline "Verifying credentials with AWS..." 10

# Validating Connection
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "https://bedrock-runtime.$AWS_REGION.amazonaws.com/model/us.anthropic.claude-3-5-haiku-20241022-v1:0/converse" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AWS_BEARER_TOKEN_BEDROCK" \
  -d '{ "messages": [{ "role": "user", "content": [{"text": "Hi"}] }] }')

if [ "$HTTP_CODE" = "200" ]; then
    progress_complete "AWS Connection Validated!"
else
    printf "\r${RED}✗ Connection failed (HTTP $HTTP_CODE)${NC}\n"
    printf "Please check your token and region ($AWS_REGION) and try again.\n"
    exit 1
fi

# --- Step 2: NVM & Node.js ---

install_nvm() {
    export NVM_DIR="$HOME/.nvm"
    
    # Check if NVM exists
    if [ -d "$NVM_DIR" ]; then
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        progress_complete "NVM is already installed"
        return 0
    fi

    printf "${BLUE}→${NC} Installing NVM...\n"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash > /dev/null 2>&1
    
    # Load NVM for current session
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    
    if command -v nvm &> /dev/null; then
        progress_complete "NVM installed successfully"
    else
        printf "${RED}✗ Failed to install NVM.${NC}\n"
        return 1
    fi
}

install_node() {
    install_nvm || exit 1
    
    if command -v npm &> /dev/null; then
         progress_complete "Node.js is already installed ($(node -v))"
         return 0
    fi

    printf "${BLUE}→${NC} Installing Node.js LTS...\n"
    nvm install --lts > /dev/null 2>&1
    nvm use --lts > /dev/null 2>&1
    
    if command -v npm &> /dev/null; then
        progress_complete "Node.js installed ($(node -v))"
    else
        printf "${RED}✗ Failed to install Node.js.${NC}\n"
        exit 1
    fi
}

printf "\n"
install_node

# --- Step 3: Claude Code CLI ---

printf "\n"
progress_inline "Installing Claude Code CLI..." 10

if command -v claude &> /dev/null; then
    progress_complete "Claude CLI is already installed"
else
    if npm install -g @anthropic-ai/claude-code > /dev/null 2>&1; then
        progress_complete "Claude CLI installed successfully"
    else
        printf "${RED}✗ Failed to install Claude CLI. Check permissions.${NC}\n"
        # Try with sudo if strictly necessary, but usually avoided with nvm
        exit 1
    fi
fi

# --- Step 4: MCP Servers ---

printf "\n"
printf "${YELLOW}Configure MCP Servers (Optional)${NC}\n"
read -p "Install Playwright & Serena MCP servers? [Y/n]: " -n 1 -r INSTALL_MCP
printf "\n"
INSTALL_MCP=${INSTALL_MCP:-Y}

if [[ $INSTALL_MCP =~ ^[Yy]$ ]]; then
    
    # Install Playwright
    printf "${BLUE}→${NC} Installing Playwright MCP...\n"
    if claude mcp add playwright npx @playwright/mcp@latest > /dev/null 2>&1; then
        progress_complete "Playwright MCP installed"
    else
        printf "${YELLOW}⚠ Playwright installation skipped or failed${NC}\n"
    fi

    # Install UV (Python tool) for Serena
    printf "${BLUE}→${NC} Checking 'uv' (required for Serena)...\n"
    if ! command -v uvx &> /dev/null; then
        if [ "$OS_TYPE" = "Darwin" ] && command -v brew &> /dev/null; then
             brew install uv > /dev/null 2>&1
        else
             curl -LsSf https://astral.sh/uv/install.sh | sh > /dev/null 2>&1
        fi
        
        # Add to path for current session
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Install Serena
    if command -v uvx &> /dev/null; then
        printf "${BLUE}→${NC} Installing Serena MCP...\n"
        PROJECT_PATH=$(pwd)
        if claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project "$PROJECT_PATH" > /dev/null 2>&1; then
            progress_complete "Serena MCP installed"
        else
             printf "${YELLOW}⚠ Serena installation failed${NC}\n"
        fi
    else
        printf "${YELLOW}⚠ 'uv' could not be installed. Skipping Serena.${NC}\n"
    fi
fi

# --- Step 5: Shell Configuration ---

printf "\n"
progress_inline "Updating shell configuration..." 10

SHELL_RC=""
case "$CURRENT_SHELL" in
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    bash)
        if [ "$OS_TYPE" = "Darwin" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
        ;;
    fish)
        SHELL_RC="$HOME/.config/fish/config.fish"
        mkdir -p "$(dirname "$SHELL_RC")"
        ;;
    *)
        SHELL_RC="$HOME/.profile"
        ;;
esac

# Function to safely append to config file
append_to_config() {
    local file="$1"
    local content="$2"
    
    if [ ! -f "$file" ]; then touch "$file"; fi
    
    # Avoid duplicate entries
    if ! grep -q "CLAUDE_CODE_USE_BEDROCK" "$file"; then
        echo -e "\n$content" >> "$file"
        return 0
    fi
    return 1
}

# Construct the config block
if [ "$CURRENT_SHELL" = "fish" ]; then
    CONFIG_BLOCK="# Claude Code Bedrock
set -gx CLAUDE_CODE_USE_BEDROCK 1
set -gx AWS_REGION \"$AWS_REGION\"
set -gx AWS_BEARER_TOKEN_BEDROCK \"$AWS_BEARER_TOKEN_BEDROCK\"
# Ensure uv/nvm paths
if test -d ~/.local/bin; set -gx PATH \$HOME/.local/bin \$PATH; end"
else
    CONFIG_BLOCK="# Claude Code Bedrock
export CLAUDE_CODE_USE_BEDROCK=\"1\"
export AWS_REGION=\"$AWS_REGION\"
export AWS_BEARER_TOKEN_BEDROCK=\"$AWS_BEARER_TOKEN_BEDROCK\"
# Ensure uv path
export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

if append_to_config "$SHELL_RC" "$CONFIG_BLOCK"; then
    progress_complete "Updated $SHELL_RC"
else
    progress_complete "Configuration already present in $SHELL_RC"
fi

# --- Step 6: VS Code ---

if command -v code &> /dev/null; then
    printf "${BLUE}→${NC} Installing VS Code Extension...\n"
    code --install-extension Anthropic.claude-code --force > /dev/null 2>&1
    progress_complete "VS Code extension installed"
fi

# --- Final ---

printf "\n${GREEN}========================================${NC}\n"
printf "${GREEN}  ✓ SETUP COMPLETE!${NC}\n"
printf "${GREEN}========================================${NC}\n\n"
printf "Please run the following command to apply changes immediately:\n"
printf "  ${CYAN}source $SHELL_RC${NC}\n\n"
printf "Then start coding with:\n"
printf "  ${CYAN}claude${NC}\n\n"