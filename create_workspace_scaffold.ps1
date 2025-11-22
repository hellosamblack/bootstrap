<#
.SYNOPSIS
    VS Code Workspace Bootstrap Script
.DESCRIPTION
    Idempotent workspace initialization for consistent dev environments across machines.
    Automatically creates:
      - .vscode structure (settings.json with absolute interpreter path, tasks.json)
      - .ai directory with AI instruction files (common, gemini, copilot)
      - Python virtual environment (.venv)
      - Installs base dev packages (pytest, flake8)
      - Handles torch + torchvision with CU130 index
      - Clones spec-kit repo and optionally launches copilot CLI
.NOTES
    Author: hellosamblack
    Version: 1.0.0
    Repository: https://github.com/hellosamblack/bootstrap
    
    Usage:
      Run via user-level folderOpen task or manually:
        pwsh -NoProfile -ExecutionPolicy Bypass -File create_workspace_scaffold.ps1
    
    Settings Sync:
      - Generated workspace files (.vscode/settings.json, tasks.json) are NOT synced by default
      - This script should be fetched from the repo via user-level task (see README)
      - User-level tasks.json IS synced and will ensure script updates across machines
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Cross-platform compatibility (PowerShell 5.x & 7.x)
# ---------------------------------------------------------------------------
if (-not (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue)) { 
    $IsWindows = ($env:OS -eq 'Windows_NT') 
}
if (-not (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue)) { 
    $IsLinux = (-not $IsWindows) -and (Test-Path '/etc/os-release') 
}
try { $uname = (uname) 2>$null } catch { $uname = '' }
if (-not (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue)) { 
    $IsMacOS = (-not $IsWindows) -and (-not $IsLinux) -and ($uname -eq 'Darwin') 
}

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------
function Write-ScaffoldInfo {
    param([string]$Message)
    Write-Host "[workspace-scaffold] $Message" -ForegroundColor Cyan
}

function Write-ScaffoldError {
    param([string]$Message)
    Write-Host "[workspace-scaffold] ERROR: $Message" -ForegroundColor Red
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) { 
        New-Item -ItemType Directory -Path $Path -Force | Out-Null 
    }
}

function Ensure-File {
    param([string]$Path, [string]$Content)
    if (-not (Test-Path $Path)) { 
        Set-Content -Path $Path -Value $Content -Encoding UTF8 
    }
}

# ---------------------------------------------------------------------------
# Main Bootstrap Logic
# ---------------------------------------------------------------------------
$workspaceRoot = Get-Location
Write-ScaffoldInfo "Bootstrapping workspace at '$workspaceRoot'"

# ---------------------------------------------------------------------------
# 1. VSCode .vscode structure
# ---------------------------------------------------------------------------
$dirVscode = Join-Path -Path $workspaceRoot -ChildPath '.vscode'
$tasksFile = Join-Path -Path $dirVscode -ChildPath 'tasks.json'
$settingsFile = Join-Path -Path $dirVscode -ChildPath 'settings.json'
Ensure-Dir $dirVscode

if (-not (Test-Path $tasksFile)) {
    Write-ScaffoldInfo 'Creating workspace tasks.json'
    $tasksContent = @'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Create workspace venv (Windows)",
      "type": "shell",
      "command": "if (-not (Test-Path .venv\\Scripts\\python.exe)) { py -3 -m venv .venv }",
      "presentation": {
        "echo": false,
        "reveal": "never",
        "focus": false,
        "panel": "dedicated"
      },
      "runOptions": {
        "runOn": "folderOpen"
      },
      "problemMatcher": [],
      "windows": {
        "command": "if (-not (Test-Path .venv\\Scripts\\python.exe)) { py -3 -m venv .venv }"
      }
    },
    {
      "label": "Create workspace venv (Linux/Mac)",
      "type": "shell",
      "command": "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi",
      "presentation": {
        "echo": false,
        "reveal": "never",
        "focus": false,
        "panel": "dedicated"
      },
      "runOptions": {
        "runOn": "folderOpen"
      },
      "problemMatcher": [],
      "linux": {
        "command": "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi"
      },
      "osx": {
        "command": "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi"
      }
    }
  ]
}
'@
    Set-Content -Path $tasksFile -Value $tasksContent -Encoding UTF8
}

# ---------------------------------------------------------------------------
# 2. settings.json with absolute interpreter path
# ---------------------------------------------------------------------------
if (-not (Test-Path $settingsFile)) {
    Write-ScaffoldInfo 'Creating settings.json with absolute interpreter path'
    if ($IsWindows) {
        $interpreterAbsolute = Join-Path -Path $workspaceRoot -ChildPath '.venv\Scripts\python.exe'
    } else {
        $interpreterAbsolute = Join-Path -Path $workspaceRoot -ChildPath '.venv/bin/python'
    }
    
    $settingsObject = @{
        'python.defaultInterpreterPath' = $interpreterAbsolute
        'python.terminal.activateEnvInCurrentTerminal' = $true
        'python.terminal.useEnvFile' = $true
        'python.linting.enabled' = $true
        'python.linting.flake8Enabled' = $true
        'python.linting.flake8Args' = @('--max-line-length=120')
        'python.testing.pytestEnabled' = $true
        'python.testing.unittestEnabled' = $false
    }
    $settingsContent = $settingsObject | ConvertTo-Json -Depth 4
    Set-Content -Path $settingsFile -Value $settingsContent -Encoding UTF8
}

# ---------------------------------------------------------------------------
# 3. AI instruction files (.ai directory)
# ---------------------------------------------------------------------------
$aiDir = Join-Path $workspaceRoot '.ai'
Ensure-Dir $aiDir
$commonFile = Join-Path $aiDir 'common-ai-instructions.md'
$geminiFile = Join-Path $aiDir 'gemini.instructions.md'
$copilotFile = Join-Path $aiDir 'copilot.instructions.md'

$commonContent = @'
# Common AI Instructions

## Development Standards

### Python Environment
- **Virtual Environment**: Always use workspace `.venv` for Python tooling
- **Interpreter**: Absolute path configured in workspace settings
- **Global Installs**: Disabled to ensure isolation

### Code Style & Quality
- **Max Line Length**: 120 characters
- **Linter**: flake8 only (no Black formatter by default)
- **Tests**: pytest only (unittest disabled)
- **Type Hints**: Encouraged where beneficial

### Dependencies
- **Latest Versions**: Install unpinned packages at latest stable versions
- **PyTorch**: Always install `torch` + `torchvision` together via CU130 index:
  ```bash
  pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
  ```

### Security
- **Secrets Management**: Use environment variables via 1Password CLI
- **No Hardcoded Credentials**: All sensitive data via `${env:VAR_NAME}`
- **SSH Keys**: Use privateKeyPath with env vars for passwords

### Communication Style
- **Concise**: Provide direct answers unless verbosity requested
- **Actionable**: Focus on practical implementation
- **Context-Aware**: Reference workspace structure and existing patterns

## AI Toolkit Commands

When working with AI/Agent development, leverage these tools:

- `aitk-get_agent_code_gen_best_practices` - Best practices for AI agent development
- `aitk-get_tracing_code_gen_best_practices` - Tracing implementation guidance
- `aitk-get_ai_model_guidance` - AI model selection and usage
- `aitk-evaluation_planner` - Evaluation metrics clarification (multi-turn)
- `aitk-get_evaluation_code_gen_best_practices` - Evaluation code generation
- `aitk-evaluation_agent_runner_best_practices` - Agent runner best practices

## Repository Standards

### Workspace Bootstrap
- This workspace was initialized via [bootstrap](https://github.com/hellosamblack/bootstrap)
- Scaffold script creates consistent structure across machines
- Settings Sync propagates user-level tasks automatically

### Default Actions
- **spec-kit**: Automatically cloned to workspace root
- **copilot CLI**: Launched in spec-kit directory if available
- **Dev Packages**: pytest, flake8 installed automatically on first bootstrap
'@

$geminiContent = @'
# Gemini Instructions

Refer to [Common AI Instructions](./common-ai-instructions.md) for base standards.

## Model-Specific Notes

**Model**: Google Gemini (latest)

### Strengths & Usage
- **Structured Output**: Emphasize JSON formatting when requested
- **Code Generation**: Leverage strong context window for large codebases
- **Security**: Maintain strict adherence to security & lint rules
- **Multimodal**: Can process images/diagrams when provided

### Response Style
- Prioritize clarity and structure
- Use markdown formatting extensively
- Provide code examples in fenced blocks with language tags
'@

$copilotContent = @'
# Copilot Instructions

Refer to [Common AI Instructions](./common-ai-instructions.md) for base standards.

## Model-Specific Notes

**Model**: GitHub Copilot (GPT-based)

### Strengths & Usage
- **Repository Context**: Leverage deep understanding of repo structure
- **Coding Standards**: Follow repository coding patterns automatically
- **Security Practices**: Enforce secure coding practices
- **Incremental Development**: Excel at iterative refinement

### Response Style
- Brief, actionable responses by default
- Code-first approach when appropriate
- Contextual awareness of recent changes
'@

Ensure-File $commonFile  $commonContent
Ensure-File $geminiFile  $geminiContent
Ensure-File $copilotFile $copilotContent

# ---------------------------------------------------------------------------
# 3b. GitHub Agents directory (.github/agents/)
# ---------------------------------------------------------------------------
$githubDir = Join-Path $workspaceRoot '.github'
$agentsDir = Join-Path $githubDir 'agents'
Ensure-Dir $githubDir
Ensure-Dir $agentsDir

# Detect project type and create appropriate agent files
$projectType = 'general'
if (Test-Path (Join-Path $workspaceRoot 'ignition')) { $projectType = 'ignition' }
elseif ((Test-Path (Join-Path $workspaceRoot 'models')) -or (Test-Path (Join-Path $workspaceRoot 'scripts/train.py'))) { $projectType = 'llm' }
elseif ((Test-Path (Join-Path $workspaceRoot 'homeassistant')) -or (Test-Path (Join-Path $workspaceRoot 'configuration.yaml'))) { $projectType = 'homeassistant' }

Write-ScaffoldInfo "Detected project type: $projectType"

# Download agent templates from bootstrap repo
$agentBaseUrl = 'https://raw.githubusercontent.com/hellosamblack/bootstrap/main/.github/agents'
$agentFiles = @{
    'ignition' = 'ignition-agent.md'
    'llm' = 'llm-agent.md'
    'homeassistant' = 'homeassistant-agent.md'
}

if ($agentFiles.ContainsKey($projectType)) {
    $agentFile = Join-Path $agentsDir $agentFiles[$projectType]
    if (-not (Test-Path $agentFile)) {
        try {
            Write-ScaffoldInfo "Downloading $($agentFiles[$projectType]) agent template"
            Invoke-WebRequest -UseBasicParsing -Uri "$agentBaseUrl/$($agentFiles[$projectType])" -OutFile $agentFile
        } catch {
            Write-ScaffoldInfo "Could not download agent template (will be available after repo sync): $_"
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Python dependency bootstrap with torch handling
# ---------------------------------------------------------------------------
if ($IsWindows) { 
    $venvPython = Join-Path $workspaceRoot '.venv\Scripts\python.exe' 
} else { 
    $venvPython = Join-Path $workspaceRoot '.venv/bin/python' 
}
$bootstrapSentinel = Join-Path $workspaceRoot '.venv\.bootstrap_done'
$requirementsPath = Join-Path $workspaceRoot 'requirements.txt'

if ((Test-Path $venvPython) -and (-not (Test-Path $bootstrapSentinel))) {
    Write-ScaffoldInfo 'Bootstrapping Python dependencies'
    try {
        & $venvPython -m pip install --upgrade pip | Out-Null
        Write-ScaffoldInfo 'Installing base dev packages (pytest, flake8)'
        & $venvPython -m pip install pytest flake8 | Out-Null
        
        if (Test-Path $requirementsPath) {
            $reqLines = Get-Content -Path $requirementsPath
            $torchPresent = $reqLines | Where-Object { $_ -match '^\s*torch(\b|[=<>])' }
            $torchvisionPresent = $reqLines | Where-Object { $_ -match '^\s*torchvision(\b|[=<>])' }
            
            if ($torchPresent -and -not $torchvisionPresent) {
                Write-ScaffoldInfo 'Adding torchvision to requirements.txt'
                Add-Content -Path $requirementsPath -Value 'torchvision'
                $reqLines = Get-Content -Path $requirementsPath
            }
            
            if ($torchPresent) {
                Write-ScaffoldInfo 'Installing torch + torchvision (CU130 index)'
                & $venvPython -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
            }
            
            $remaining = $reqLines | Where-Object { 
                $_ -and 
                ($_ -notmatch '^\s*torch(\b|[=<>])') -and 
                ($_ -notmatch '^\s*torchvision(\b|[=<>])') -and
                ($_ -notmatch '^\s*#') -and
                ($_ -notmatch '^\s*$')
            }
            
            if ($remaining.Count -gt 0) {
                $tempReq = Join-Path $env:TEMP 'req_remaining.txt'
                Set-Content -Path $tempReq -Value $remaining -Encoding UTF8
                Write-ScaffoldInfo 'Installing remaining requirements'
                & $venvPython -m pip install -r $tempReq
                Remove-Item -Path $tempReq -Force
            }
        }
        
        New-Item -ItemType File -Path $bootstrapSentinel -Force | Out-Null
        Write-ScaffoldInfo 'Dependency bootstrap complete'
    }
    catch {
        Write-ScaffoldError "Dependency bootstrap failed: $_"
    }
}

# ---------------------------------------------------------------------------
# 5. spec-kit repository clone & copilot CLI launch
# ---------------------------------------------------------------------------
$repoDir = Join-Path $workspaceRoot 'spec-kit'
if (-not (Test-Path $repoDir)) {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-ScaffoldInfo 'Cloning spec-kit repository'
        try { 
            & gh repo clone github/spec-kit $repoDir 
        } 
        catch { 
            Write-ScaffoldError "Failed to clone spec-kit: $_" 
        }
    }
    elseif (Get-Command git -ErrorAction SilentlyContinue) {
        Write-ScaffoldInfo 'Cloning spec-kit repository (via git)'
        try {
            & git clone https://github.com/github/spec-kit.git $repoDir
        }
        catch {
            Write-ScaffoldError "Failed to clone spec-kit: $_"
        }
    }
    else {
        Write-ScaffoldInfo 'Neither gh nor git CLI found; skipping spec-kit clone'
    }
}

if ((Test-Path $repoDir) -and (Get-Command copilot -ErrorAction SilentlyContinue)) {
    try {
        Write-ScaffoldInfo 'Launching copilot CLI in spec-kit'
        Push-Location $repoDir
        & copilot
        Pop-Location
    }
    catch {
        Write-ScaffoldError "copilot CLI launch failed: $_"
    }
}
elseif (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-ScaffoldInfo 'copilot CLI not available; skipping launch'
}

Write-ScaffoldInfo 'Workspace scaffold complete!'
