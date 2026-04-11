#!/usr/bin/env pwsh
# Claude Code + AWS Bedrock Setup Script (Windows)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

function Test-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Install-NodeIfMissing {
    if (Test-Command "npm") {
        Write-Success "Node.js and npm are already installed"
        return
    }

    Write-Info "Node.js/npm not found. Installing Node.js LTS..."
    if (Test-Command "winget") {
        winget install --id OpenJS.NodeJS.LTS --exact --silent --accept-package-agreements --accept-source-agreements
    }
    elseif (Test-Command "choco") {
        choco install nodejs-lts -y
    }
    elseif (Test-Command "scoop") {
        scoop install nodejs-lts
    }
    else {
        Write-Fail "No supported package manager found (winget/choco/scoop). Install Node.js LTS manually and rerun."
    }

    Refresh-Path

    if (-not (Test-Command "npm")) {
        Write-Fail "Node.js installation did not expose npm in PATH. Reopen terminal and rerun."
    }
    Write-Success "Node.js and npm installed"
}

function Install-ClaudeIfMissing {
    if (Test-Command "claude") {
        Write-Success "Claude CLI is already installed"
        return
    }

    Write-Info "Installing Claude CLI..."
    npm install -g @anthropic-ai/claude-code

    if (-not (Test-Command "claude")) {
        Refresh-Path
    }
    if (-not (Test-Command "claude")) {
        Write-Fail "Claude CLI install completed but command is not in PATH. Reopen terminal and rerun."
    }
    Write-Success "Claude CLI installed"
}

function Install-UvIfMissing {
    if (Test-Command "uvx") {
        Write-Success "uv is already installed"
        return
    }

    Write-Info "Installing uv (required for Serena MCP)..."
    if (Test-Command "winget") {
        winget install --id astral-sh.uv --exact --silent --accept-package-agreements --accept-source-agreements
    }
    elseif (Test-Command "choco") {
        choco install uv -y
    }
    elseif (Test-Command "scoop") {
        scoop install uv
    }
    else {
        try {
            Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
        }
        catch {
            Write-Warn "uv installation failed via installer script."
        }
    }

    Refresh-Path
    if (Test-Command "uvx") {
        Write-Success "uv installed"
    }
    else {
        Write-Warn "uv could not be installed automatically; Serena MCP will be skipped."
    }
}

if ($env:OS -ne "Windows_NT") {
    Write-Fail "This script is for Windows. Use setup_claude_bedrock.sh on Linux/macOS."
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Claude Code CLI + Bedrock Setup" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

Write-Host "This setup script will:"
Write-Host "  1. Validate AWS Bedrock credentials"
Write-Host "  2. Install Node.js & npm (if missing)"
Write-Host "  3. Install Claude Code CLI"
Write-Host "  4. Optionally install MCP servers (Playwright and Serena)"
Write-Host "  5. Persist environment variables for your user"
Write-Host ""

$continueChoice = Read-Host "Do you want to continue? [y/N]"
if ($continueChoice -notmatch "^[Yy]$") {
    Write-Warn "Installation cancelled."
    exit 0
}

$env:CLAUDE_CODE_USE_BEDROCK = "1"

Write-Host ""
Write-Info "Configuring AWS Bedrock credentials..."
$token = (Read-Host "Paste your AWS Bearer Token").Trim()
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Fail "Token cannot be empty."
}

$regionInput = Read-Host "Enter AWS Region (default: us-east-1)"
$region = if ([string]::IsNullOrWhiteSpace($regionInput)) { "us-east-1" } else { $regionInput.Trim() }

Write-Info "Verifying credentials with AWS..."
$uri = "https://bedrock-runtime.$region.amazonaws.com/model/us.anthropic.claude-3-5-haiku-20241022-v1:0/converse"
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $token"
}
$body = '{ "messages": [{ "role": "user", "content": [{"text": "Hi"}] }] }'

$statusCode = $null
try {
    $response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $body
    $statusCode = [int]$response.StatusCode
}
catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }
    else {
        Write-Fail "Could not reach AWS Bedrock endpoint. $_"
    }
}

if ($statusCode -ne 200) {
    Write-Fail "Connection failed (HTTP $statusCode). Check token and region ($region)."
}
Write-Success "AWS connection validated"

Install-NodeIfMissing
Install-ClaudeIfMissing

$installMcp = Read-Host "Install Playwright & Serena MCP servers? [Y/n]"
if ([string]::IsNullOrWhiteSpace($installMcp) -or $installMcp -match "^[Yy]$") {
    Write-Info "Installing Playwright MCP..."
    try {
        claude mcp add playwright npx @playwright/mcp@latest | Out-Null
        Write-Success "Playwright MCP installed"
    }
    catch {
        Write-Warn "Playwright MCP installation skipped or failed."
    }

    Install-UvIfMissing
    if (Test-Command "uvx") {
        Write-Info "Installing Serena MCP..."
        $projectPath = (Get-Location).Path
        try {
            claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project $projectPath | Out-Null
            Write-Success "Serena MCP installed"
        }
        catch {
            Write-Warn "Serena MCP installation failed."
        }
    }
}

Write-Info "Persisting environment variables..."
[Environment]::SetEnvironmentVariable("CLAUDE_CODE_USE_BEDROCK", "1", "User")
[Environment]::SetEnvironmentVariable("AWS_REGION", $region, "User")
[Environment]::SetEnvironmentVariable("AWS_BEARER_TOKEN_BEDROCK", $token, "User")
Write-Success "Environment variables saved for current user"

if (Test-Command "code") {
    Write-Info "Installing VS Code extension..."
    try {
        code --install-extension Anthropic.claude-code --force | Out-Null
        Write-Success "VS Code extension installed"
    }
    catch {
        Write-Warn "Could not install VS Code extension automatically."
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Close and reopen your terminal (or restart PowerShell), then run:"
Write-Host "  claude" -ForegroundColor Cyan
Write-Host ""
