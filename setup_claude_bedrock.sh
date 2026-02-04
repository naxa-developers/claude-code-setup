#!/bin/bash
# ============================================================================
# Claude Code + AWS Bedrock Setup Script
# ============================================================================
# This script automates the installation and configuration of Claude Code CLI
# with AWS Bedrock integration. It handles dependencies, validates credentials,
# and configures your development environment.
#
# Author: NAXA
# Platform: macOS and Linux
# ============================================================================

set -e  # Exit on any error

# ============================================================================
# Color Configuration
# ============================================================================
# Makes terminal output more readable with colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color (reset)

# ============================================================================
# Welcome Screen
# ============================================================================
# Display NAXA logo
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

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Claude Code CLI + Bedrock Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# ============================================================================
# Show What Will Be Installed
# ============================================================================
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
echo -e "${YELLOW}Requirements:${NC}"
echo "  - Internet connection"
echo "  - .env file with AWS credentials"
echo "  - Bash, Zsh, or Fish shell"
echo ""

# ============================================================================
# User Confirmation
# ============================================================================
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

# ============================================================================
# Step 0: Load and Validate Environment Variables
# ============================================================================

# Check if .env file exists
ENV_FILE="${1:-.env}"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at: $ENV_FILE${NC}"
    echo ""
    echo "Please create a .env file with the following content:"
    echo ""
    cat << 'EOF'
export AWS_BEARER_TOKEN_BEDROCK="your-token-here"
export AWS_REGION="us-east-1"
export CLAUDE_CODE_USE_BEDROCK="1"
EOF
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo -e "${GREEN}✓ Found .env file: $ENV_FILE${NC}"
echo "Loading environment variables from .env file..."
echo ""

# Load environment variables
set -a  # Automatically export all variables
source "$ENV_FILE"
set +a

# Verify required variables are set
if [ -z "$AWS_BEARER_TOKEN_BEDROCK" ]; then
    echo -e "${RED}Error: AWS_BEARER_TOKEN_BEDROCK not set in .env file${NC}"
    exit 1
fi

# Set defaults for optional variables
if [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}Warning: AWS_REGION not set, defaulting to us-east-1${NC}"
    export AWS_REGION="us-east-1"
fi

if [ -z "$CLAUDE_CODE_USE_BEDROCK" ]; then
    echo -e "${YELLOW}Warning: CLAUDE_CODE_USE_BEDROCK not set, defaulting to 1${NC}"
    export CLAUDE_CODE_USE_BEDROCK="1"
fi

echo -e "${GREEN}✓ Environment variables loaded successfully${NC}"
echo "  - AWS_BEARER_TOKEN_BEDROCK: ${AWS_BEARER_TOKEN_BEDROCK:0:20}..."
echo "  - AWS_REGION: $AWS_REGION"
echo "  - CLAUDE_CODE_USE_BEDROCK: $CLAUDE_CODE_USE_BEDROCK"
echo ""

# ============================================================================
# Test AWS Bedrock Connection (Before Installing Anything!)
# ============================================================================
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

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Connection successful! (HTTP $HTTP_CODE)${NC}"
    echo -e "${BLUE}Response preview:${NC}"
    echo "$RESPONSE_BODY" | head -c 200
    echo -e "\n..."
else
    echo -e "${RED}✗ Connection failed (HTTP $HTTP_CODE)${NC}"
    echo -e "${RED}Response:${NC}"
    echo "$RESPONSE_BODY"
    echo ""
    echo -e "${RED}ERROR: Invalid AWS credentials in .env file${NC}"
    echo -e "${YELLOW}Please check your credentials and try again:${NC}"
    echo "  1. Verify AWS_BEARER_TOKEN_BEDROCK is correct"
    echo "  2. Ensure the token hasn't expired"
    echo "  3. Check AWS_REGION is valid"
    echo ""
    echo "Edit .env file: nano $ENV_FILE"
    exit 1
fi

echo ""

# Detect current shell and operating system
CURRENT_SHELL=$(basename "$SHELL")
OS_TYPE=$(uname -s)
echo -e "${YELLOW}Detected OS: $OS_TYPE${NC}"
echo -e "${YELLOW}Detected shell: $CURRENT_SHELL${NC}\n"

# ============================================================================
# Helper Functions
# ============================================================================

# ----------------------------------------------------------------------------
# Function: install_nvm
# Purpose: Installs Node Version Manager (nvm) for managing Node.js versions
# ----------------------------------------------------------------------------
install_nvm() {
    echo "Installing nvm (Node Version Manager)..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    # Load nvm into current session
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

# ----------------------------------------------------------------------------
# Function: ensure_npm
# Purpose: Ensures npm is available, installs it via nvm if needed
# ----------------------------------------------------------------------------
ensure_npm() {
    # Check if npm is already installed
    if command -v npm &> /dev/null; then
        echo -e "${GREEN}✓ npm is already installed${NC}"
        npm --version
        return 0
    fi

    echo -e "${YELLOW}npm not found. Installing via nvm...${NC}"

    # Check if nvm is installed
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

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

    # Install Node.js LTS via nvm
    echo "Installing Node.js LTS via nvm..."
    nvm install --lts
    nvm use --lts

    # Verify npm is now available
    if command -v npm &> /dev/null; then
        echo -e "${GREEN}✓ Node.js and npm installed successfully via nvm${NC}"
        node --version
        npm --version
        return 0
    else
        echo -e "${RED}✗ Failed to install npm via nvm${NC}"
        return 1
    fi
}

# ============================================================================
# Step 1: Install Claude Code CLI
# ============================================================================
echo -e "${GREEN}[Step 1/5] Installing Claude Code CLI...${NC}"

if command -v claude &> /dev/null; then
    echo -e "${YELLOW}Claude Code CLI is already installed.${NC}"
    claude --version
else
    echo "Claude Code CLI not found. Installing..."

    # Ensure npm is available (install via nvm if needed)
    if ! ensure_npm; then
        echo -e "${RED}Cannot proceed without npm. Exiting.${NC}"
        exit 1
    fi

    # Install claude-code globally via npm
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

# ============================================================================
# Step 2: Install MCP Servers (Optional)
# ============================================================================
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

    # --------------------------------------------------------------------
    # Install Playwright MCP
    # --------------------------------------------------------------------
    echo -e "${BLUE}[1/2] Installing Playwright MCP server...${NC}"
    if claude mcp add playwright npx @playwright/mcp@latest; then
        echo -e "${GREEN}✓ Playwright MCP server installed${NC}"
    else
        echo -e "${YELLOW}⚠ Playwright MCP installation failed (non-critical)${NC}"
    fi
    echo ""

    # --------------------------------------------------------------------
    # Install Serena MCP (requires uvx)
    # --------------------------------------------------------------------
    echo -e "${BLUE}[2/2] Installing Serena MCP server...${NC}"

    # Check if uvx is available
    if ! command -v uvx &> /dev/null; then
        echo "uvx not found. Installing uv (Python package installer)..."

        # Install uv based on operating system
        if [ "$OS_TYPE" = "Darwin" ]; then
            # macOS installation
            if command -v brew &> /dev/null; then
                echo "Installing uv via Homebrew..."
                brew install uv
            else
                echo "Installing uv via curl..."
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
        else
            # Linux installation
            echo "Installing uv via curl..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi

        # Add uv to PATH for current session
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

    # Install Serena MCP if uvx is available
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

# ============================================================================
# Step 3: Configure Shell to Auto-Load Environment
# ============================================================================
echo -e "${GREEN}[Step 3/5] Configuring shell to auto-load .env file...${NC}"

ENV_FILE_ABSOLUTE="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"

# Check if tools were installed and need shell configuration
NVM_INSTALLED=false
if [ -d "$HOME/.nvm" ]; then
    NVM_INSTALLED=true
fi

UV_INSTALLED=false
if [ -d "$HOME/.local/bin" ] && [ -f "$HOME/.local/bin/uvx" ]; then
    UV_INSTALLED=true
fi

# Configure based on detected shell
case "$CURRENT_SHELL" in
    bash)
        # ------------------------------------------------------------
        # Bash Configuration
        # ------------------------------------------------------------
        # macOS uses .bash_profile, Linux uses .bashrc
        if [ "$OS_TYPE" = "Darwin" ]; then
            SHELL_RC="$HOME/.bash_profile"
            # Create .bashrc and source it from .bash_profile
            if [ ! -f "$HOME/.bashrc" ]; then
                touch "$HOME/.bashrc"
            fi
            if ! grep -q ".bashrc" "$SHELL_RC" 2>/dev/null; then
                echo "" >> "$SHELL_RC"
                echo "# Source .bashrc if it exists" >> "$SHELL_RC"
                echo "[ -f ~/.bashrc ] && source ~/.bashrc" >> "$SHELL_RC"
            fi
            SHELL_RC="$HOME/.bashrc"
        else
            SHELL_RC="$HOME/.bashrc"
        fi

        # Add nvm initialization if nvm was installed
        if [ "$NVM_INSTALLED" = true ] && ! grep -q "NVM_DIR" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# nvm (Node Version Manager) initialization" >> "$SHELL_RC"
            echo 'export NVM_DIR="$HOME/.nvm"' >> "$SHELL_RC"
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$SHELL_RC"
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$SHELL_RC"
            echo -e "${GREEN}✓ Added nvm initialization to $SHELL_RC${NC}"
        fi

        # Add uv to PATH if uv was installed
        if [ "$UV_INSTALLED" = true ] && ! grep -q ".local/bin" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# uv/uvx (Python package installer) PATH" >> "$SHELL_RC"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
            echo -e "${GREEN}✓ Added uv/uvx to PATH in $SHELL_RC${NC}"
        fi

        # Add .env auto-load
        SOURCE_LINE="[ -f \"$ENV_FILE_ABSOLUTE\" ] && source \"$ENV_FILE_ABSOLUTE\""

        if ! grep -Fq "$ENV_FILE_ABSOLUTE" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Auto-load Claude Code Bedrock configuration" >> "$SHELL_RC"
            echo "$SOURCE_LINE" >> "$SHELL_RC"
            echo -e "${GREEN}✓ Added auto-load to $SHELL_RC${NC}"
        else
            echo -e "${YELLOW}✓ Auto-load already configured in $SHELL_RC${NC}"
        fi

        if [ "$OS_TYPE" = "Darwin" ]; then
            echo -e "${YELLOW}Run 'source ~/.bash_profile' or restart your terminal to apply changes.${NC}"
        else
            echo -e "${YELLOW}Run 'source ~/.bashrc' or restart your terminal to apply changes.${NC}"
        fi
        ;;

    zsh)
        # ------------------------------------------------------------
        # Zsh Configuration
        # ------------------------------------------------------------
        SHELL_RC="$HOME/.zshrc"

        # On macOS, ensure .zshrc exists and is sourced from .zprofile
        if [ "$OS_TYPE" = "Darwin" ]; then
            if [ ! -f "$SHELL_RC" ]; then
                touch "$SHELL_RC"
            fi
            # Create .zprofile to source .zshrc
            if [ ! -f "$HOME/.zprofile" ]; then
                echo "# Source .zshrc" > "$HOME/.zprofile"
                echo "[ -f ~/.zshrc ] && source ~/.zshrc" >> "$HOME/.zprofile"
            fi
        fi

        # Add nvm initialization if nvm was installed
        if [ "$NVM_INSTALLED" = true ] && ! grep -q "NVM_DIR" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# nvm (Node Version Manager) initialization" >> "$SHELL_RC"
            echo 'export NVM_DIR="$HOME/.nvm"' >> "$SHELL_RC"
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$SHELL_RC"
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$SHELL_RC"
            echo -e "${GREEN}✓ Added nvm initialization to ~/.zshrc${NC}"
        fi

        # Add uv to PATH if uv was installed
        if [ "$UV_INSTALLED" = true ] && ! grep -q ".local/bin" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# uv/uvx (Python package installer) PATH" >> "$SHELL_RC"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
            echo -e "${GREEN}✓ Added uv/uvx to PATH in ~/.zshrc${NC}"
        fi

        # Add .env auto-load
        SOURCE_LINE="[ -f \"$ENV_FILE_ABSOLUTE\" ] && source \"$ENV_FILE_ABSOLUTE\""

        if ! grep -Fq "$ENV_FILE_ABSOLUTE" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Auto-load Claude Code Bedrock configuration" >> "$SHELL_RC"
            echo "$SOURCE_LINE" >> "$SHELL_RC"
            echo -e "${GREEN}✓ Added auto-load to ~/.zshrc${NC}"
        else
            echo -e "${YELLOW}✓ Auto-load already configured in ~/.zshrc${NC}"
        fi
        echo -e "${YELLOW}Run 'source ~/.zshrc' or restart your terminal to apply changes.${NC}"
        ;;

    fish)
        # ------------------------------------------------------------
        # Fish Shell Configuration
        # ------------------------------------------------------------
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        mkdir -p "$HOME/.config/fish"

        # Add nvm initialization (fish uses nvm.fish plugin)
        if [ "$NVM_INSTALLED" = true ] && ! grep -q "nvm" "$FISH_CONFIG" 2>/dev/null; then
            echo "" >> "$FISH_CONFIG"
            echo "# nvm (Node Version Manager) initialization" >> "$FISH_CONFIG"
            echo "# Note: For fish, consider installing fisher and nvm.fish plugin:" >> "$FISH_CONFIG"
            echo "# fisher install jorgebucaran/nvm.fish" >> "$FISH_CONFIG"
            echo "if test -d ~/.nvm" >> "$FISH_CONFIG"
            echo '    bass source ~/.nvm/nvm.sh' >> "$FISH_CONFIG"
            echo "end" >> "$FISH_CONFIG"
            echo -e "${YELLOW}Note: For full nvm support in fish, install: fisher install jorgebucaran/nvm.fish${NC}"
        fi

        # Add uv to PATH if uv was installed
        if [ "$UV_INSTALLED" = true ] && ! grep -q ".local/bin" "$FISH_CONFIG" 2>/dev/null; then
            echo "" >> "$FISH_CONFIG"
            echo "# uv/uvx (Python package installer) PATH" >> "$FISH_CONFIG"
            echo 'set -gx PATH $HOME/.local/bin $PATH' >> "$FISH_CONFIG"
            echo -e "${GREEN}✓ Added uv/uvx to PATH in fish config${NC}"
        fi

        # Add .env auto-load
        if ! grep -Fq "$ENV_FILE_ABSOLUTE" "$FISH_CONFIG" 2>/dev/null; then
            echo "" >> "$FISH_CONFIG"
            echo "# Auto-load Claude Code Bedrock configuration" >> "$FISH_CONFIG"
            echo "if test -f $ENV_FILE_ABSOLUTE" >> "$FISH_CONFIG"
            echo "    source $ENV_FILE_ABSOLUTE" >> "$FISH_CONFIG"
            echo "end" >> "$FISH_CONFIG"
            echo -e "${GREEN}✓ Added auto-load to $FISH_CONFIG${NC}"
        else
            echo -e "${YELLOW}✓ Auto-load already configured in $FISH_CONFIG${NC}"
        fi
        echo -e "${YELLOW}Run 'source ~/.config/fish/config.fish' or restart your terminal.${NC}"
        ;;

    *)
        # ------------------------------------------------------------
        # Unsupported Shell - Show Manual Instructions
        # ------------------------------------------------------------
        echo -e "${YELLOW}⚠ Unsupported shell: $CURRENT_SHELL${NC}"
        echo -e "\n${BLUE}=== MANUAL SETUP INSTRUCTIONS ===${NC}"
        echo "Add this line to your shell configuration file:"
        echo ""
        echo "[ -f \"$ENV_FILE_ABSOLUTE\" ] && source \"$ENV_FILE_ABSOLUTE\""
        echo ""
        echo "Or add this to auto-load .env file:"
        echo "if [ -f .env ]; then source .env; fi"
        echo ""
        echo "Common config files:"
        echo "  - bash: ~/.bashrc or ~/.bash_profile"
        echo "  - zsh: ~/.zshrc"
        echo "  - fish: ~/.config/fish/config.fish"
        echo ""
        ;;
esac

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

# ============================================================================
# Step 4: Install VSCode Extension
# ============================================================================
echo -e "${GREEN}[Step 4/5] Installing VSCode Extension...${NC}"

if command -v code &> /dev/null; then
    echo "VSCode command-line tool detected. Installing Claude Code extension..."

    # Check if extension is already installed
    if code --list-extensions | grep -q "Anthropic.claude-code"; then
        echo -e "${YELLOW}✓ Claude Code extension is already installed${NC}"
    else
        # Install the extension
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

# ============================================================================
# Step 5: Setup Complete!
# ============================================================================
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

# Show Claude Code version
echo -e "${BLUE}Claude Code Version:${NC}"
if command -v claude &> /dev/null; then
    claude --version
else
    echo "  Claude CLI not found"
fi
echo ""

# Final success message
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All Done! Happy Coding with Claude!${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Show documentation links
echo -e "${BLUE}Documentation & Resources:${NC}"
echo "  • Claude Code CLI: https://github.com/anthropics/claude-code"
echo "  • VSCode Extension: https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code"
echo "  • Getting Started: https://docs.anthropic.com/claude/docs/claude-code"
echo "  • VSCode Integration: https://code.visualstudio.com/docs/editor/artificial-intelligence#_claude-code"
echo ""
