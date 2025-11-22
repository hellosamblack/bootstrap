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
    }
    else {
        $interpreterAbsolute = Join-Path -Path $workspaceRoot -ChildPath '.venv/bin/python'
    }
    
    $settingsObject = @{
        'python.defaultInterpreterPath'                = $interpreterAbsolute
        'python.terminal.activateEnvInCurrentTerminal' = $true
        'python.terminal.useEnvFile'                   = $true
        'python.linting.enabled'                       = $true
        'python.linting.flake8Enabled'                 = $true
        'python.linting.flake8Args'                    = @('--max-line-length=120')
        'python.testing.pytestEnabled'                 = $true
        'python.testing.unittestEnabled'               = $false
    }
    $settingsContent = $settingsObject | ConvertTo-Json -Depth 4
    Set-Content -Path $settingsFile -Value $settingsContent -Encoding UTF8
}

# ---------------------------------------------------------------------------
# 3. AI instruction files (.ai directory)
# ---------------------------------------------------------------------------
$aiDir = Join-Path $workspaceRoot '.ai'
Ensure-Dir $aiDir

# Download AI instruction templates from bootstrap repo
$templateBaseUrl = 'https://raw.githubusercontent.com/hellosamblack/bootstrap/main/templates/ai-instructions'
$aiTemplates = @{
    'common-ai-instructions.md' = Join-Path $aiDir 'common-ai-instructions.md'
    'gemini.instructions.md'    = Join-Path $aiDir 'gemini.instructions.md'
    'copilot.instructions.md'   = Join-Path $aiDir 'copilot.instructions.md'
}

foreach ($template in $aiTemplates.Keys) {
    $localPath = $aiTemplates[$template]
    if (-not (Test-Path $localPath)) {
        try {
            Write-ScaffoldInfo "Downloading AI instruction template: $template"
            Invoke-WebRequest -UseBasicParsing -Uri "$templateBaseUrl/$template" -OutFile $localPath
        }
        catch {
            Write-ScaffoldError "Could not download $template (will use defaults): $_"
        }
    }
}

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
    'ignition'      = 'ignition-agent.md'
    'llm'           = 'llm-agent.md'
    'homeassistant' = 'homeassistant-agent.md'
}

if ($agentFiles.ContainsKey($projectType)) {
    $agentFile = Join-Path $agentsDir $agentFiles[$projectType]
    if (-not (Test-Path $agentFile)) {
        try {
            Write-ScaffoldInfo "Downloading $($agentFiles[$projectType]) agent template"
            Invoke-WebRequest -UseBasicParsing -Uri "$agentBaseUrl/$($agentFiles[$projectType])" -OutFile $agentFile
        }
        catch {
            Write-ScaffoldInfo "Could not download agent template (will be available after repo sync): $_"
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Python dependency bootstrap with torch handling
# ---------------------------------------------------------------------------
if ($IsWindows) { 
    $venvPython = Join-Path $workspaceRoot '.venv\Scripts\python.exe' 
}
else { 
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
# 5. Astro Starlight documentation site
# ---------------------------------------------------------------------------
$docsDir = Join-Path $workspaceRoot 'docs'
if (-not (Test-Path $docsDir)) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-ScaffoldInfo 'Creating Astro Starlight documentation site'
        try {
            Push-Location $workspaceRoot
            & npm create astro@latest docs -- --template starlight --install --no-git --typescript strict
            
            # Create Diátaxis directory structure
            $contentDir = Join-Path $docsDir 'src\content\docs'
            Ensure-Dir (Join-Path $contentDir 'tutorials')
            Ensure-Dir (Join-Path $contentDir 'guides')
            Ensure-Dir (Join-Path $contentDir 'reference')
            Ensure-Dir (Join-Path $contentDir 'explanation')
            
            Write-ScaffoldInfo 'Documentation site created with Diátaxis structure'
            Pop-Location
        }
        catch {
            Write-ScaffoldError "Failed to create documentation site: $_"
            Pop-Location
        }
    }
    else {
        Write-ScaffoldInfo 'npm not found; skipping documentation site creation'
    }
}

# ---------------------------------------------------------------------------
# 6. spec-kit repository clone & copilot CLI launch
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
