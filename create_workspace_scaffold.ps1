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

param(
    [switch]$Force,
    [switch]$Skip
)

# Environment overrides:
#   BOOTSTRAP_AUTO=1  -> run without prompt
#   BOOTSTRAP_AUTO=0  -> skip without prompt
# Use -Force or -Skip switches to override manually.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Cross-platform compatibility (PowerShell 5.x & 7.x)
# ---------------------------------------------------------------------------
if (-not (Get-Variable -Name IsWindowsPlatform -ErrorAction SilentlyContinue)) { 
    $IsWindowsPlatform = ($env:OS -eq 'Windows_NT') 
}
if (-not (Get-Variable -Name IsLinuxPlatform -ErrorAction SilentlyContinue)) { 
    $IsLinuxPlatform = (-not $IsWindowsPlatform) -and (Test-Path '/etc/os-release') 
}
try { $uname = (uname) 2>$null } catch { $uname = '' }
if (-not (Get-Variable -Name IsMacOSPlatform -ErrorAction SilentlyContinue)) { 
    $IsMacOSPlatform = (-not $IsWindowsPlatform) -and (-not $IsLinuxPlatform) -and ($uname -eq 'Darwin') 
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

function New-DirectoryIfMissing {
    param([string]$Path)
    if (-not (Test-Path $Path)) { 
        New-Item -ItemType Directory -Path $Path -Force | Out-Null 
    }
}

function New-FileIfMissing {
    param([string]$Path, [string]$Content)
    if (-not (Test-Path $Path)) { Set-Content -Path $Path -Value $Content -Encoding UTF8 }
}

# -----------------------------
# Main Bootstrap Variables
# -----------------------------
$workspaceRoot = Get-Location
$dirVscode    = Join-Path $workspaceRoot '.vscode'
$tasksFile    = Join-Path $dirVscode 'tasks.json'
$settingsFile = Join-Path $dirVscode 'settings.json'
$aiDir        = Join-Path $workspaceRoot '.ai'
$githubDir    = Join-Path $workspaceRoot '.github'
$agentsDir    = Join-Path $githubDir 'agents'
$docsDir      = Join-Path $workspaceRoot 'docs'
$repoDir      = Join-Path $workspaceRoot 'spec-kit'
$venvPython   = if ($IsWindowsPlatform) { Join-Path $workspaceRoot '.venv\Scripts\python.exe' } else { Join-Path $workspaceRoot '.venv/bin/python' }
$bootstrapSentinel = Join-Path $workspaceRoot '.venv\.bootstrap_done'
$featureRecordFile = Join-Path $workspaceRoot '.bootstrap_features.json'

$allFeatures = @('vscode','ai','agents','python','docs','speckit','copilot')
$availableMap = @{ '1'='vscode'; '2'='ai'; '3'='agents'; '4'='python'; '5'='docs'; '6'='speckit'; '7'='copilot' }

# Feature selection logic
$selectedFeatures = @()
if ($Skip -or $env:BOOTSTRAP_AUTO -eq '1') {
    if (Test-Path $featureRecordFile) {
        try { $selectedFeatures = (Get-Content $featureRecordFile | ConvertFrom-Json).features } catch { $selectedFeatures = $allFeatures }
    } else { $selectedFeatures = $allFeatures }
    Write-ScaffoldInfo '-Skip/auto enabled -> using recorded or all features.'
} elseif ($env:BOOTSTRAP_AUTO -eq '0') {
    Write-ScaffoldInfo 'BOOTSTRAP_AUTO=0 -> skipping scaffold.'
    return
} else {
    Write-ScaffoldInfo 'Select features to scaffold (comma-separated numbers or all; blank=all):'
    Write-Host '  1) VS Code config (.vscode)'
    Write-Host '  2) AI instruction files (.ai)'
    Write-Host '  3) Agent templates (.github/agents)'
    Write-Host '  4) Python dependencies (venv packages)'
    Write-Host '  5) Documentation site (Astro Starlight)'
    Write-Host '  6) spec-kit repository clone'
    Write-Host '  7) Launch copilot CLI (requires spec-kit)'
    Write-Host -NoNewline 'Enter selection: '
    $inputSel = Read-Host
    if (-not $inputSel -or $inputSel.Trim() -eq '' -or $inputSel.Trim().ToLower() -eq 'all') {
        $selectedFeatures = $allFeatures
    } else {
        $tokens = $inputSel -split '[,\s]+' | Where-Object { $_ }
        foreach ($t in $tokens) { if ($availableMap.ContainsKey($t)) { $selectedFeatures += $availableMap[$t] } }
        $selectedFeatures = $selectedFeatures | Select-Object -Unique
        if (@($selectedFeatures).Count -eq 0) { $selectedFeatures = $allFeatures }
    }
}

# Record selection
try {
    $recordObj = @{ features = $selectedFeatures; timestamp = (Get-Date).ToString('o') }
    $recordJson = $recordObj | ConvertTo-Json -Depth 3
    Set-Content -Path $featureRecordFile -Value $recordJson -Encoding UTF8
    Write-ScaffoldInfo "Recorded selected features: $($selectedFeatures -join ', ')"
} catch { Write-ScaffoldError "Failed to record features: $_" }

New-DirectoryIfMissing $dirVscode
New-DirectoryIfMissing (Join-Path $workspaceRoot '.venv')
Write-ScaffoldInfo "Bootstrapping workspace at '$workspaceRoot' with features: $($selectedFeatures -join ', ')"
    if ($selectedFeatures -contains 'vscode') {
        $tasksContent = @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Create workspace venv (Windows)",
            "type": "shell",
            "command": "pwsh",
                "args": [
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                "bootstrap_repo/create_venv.ps1"
            ],
            "presentation": {
                "echo": false,
                "reveal": "never",
                "focus": false,
                "panel": "dedicated"
            },
            "runOptions": { "runOn": "folderOpen" },
            "problemMatcher": [],
            "windows": {
                "command": "pwsh",
                "args": [
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    "bootstrap_repo/create_venv.ps1"
                ]
            }
        },
        {
            "label": "Create workspace venv (Linux/Mac)",
            "type": "shell",
            "command": "bash",
            "args": [
                "-lc",
                "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi"
            ],
            "presentation": {
                "echo": false,
                "reveal": "never",
                "focus": false,
                "panel": "dedicated"
            },
            "problemMatcher": [],
            "linux": {
                "command": "bash",
                "args": [
                    "-lc",
                    "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi"
                ]
            },
            "osx": {
                "command": "bash",
                "args": [
                    "-lc",
                    "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi"
                ]
            }
        },
        {
            "label": "Bootstrap Workspace",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                "bootstrap_repo/create_workspace_scaffold.ps1",
                "-Skip"
            ],
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "dedicated"
            },
            "runOptions": { "runOn": "folderOpen" },
            "problemMatcher": []
        }
        ,
        {
            "label": "Lint",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-Command",
                "if (Test-Path .venv\\Scripts\\python.exe) { .venv\\Scripts\\python -m flake8 . } elseif (Test-Path .venv/bin/python) { ./.venv/bin/python -m flake8 . } else { echo 'Venv missing'; exit 1 }"
            ],
            "presentation": { "echo": true, "reveal": "never" },
            "problemMatcher": []
        }
        ,
        {
            "label": "Test",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-Command",
                "if (Test-Path .venv\\Scripts\\python.exe) { .venv\\Scripts\\python -m pytest -q } elseif (Test-Path .venv/bin/python) { ./.venv/bin/python -m pytest -q } else { echo 'Venv missing'; exit 1 }"
            ],
            "presentation": { "echo": true, "reveal": "never" },
            "problemMatcher": []
        }
        ,
        {
            "label": "Validate",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-Command",
                "& \"${env:ComSpec}\" /c echo Running lint and tests sequentially; pwsh -NoProfile -Command \"if (Test-Path .venv\\Scripts\\python.exe) { .venv\\Scripts\\python -m flake8 . } elseif (Test-Path .venv/bin/python) { ./.venv/bin/python -m flake8 . } else { echo 'Venv missing'; exit 1 }\"; pwsh -NoProfile -Command \"if (Test-Path .venv\\Scripts\\python.exe) { .venv\\Scripts\\python -m pytest -q } elseif (Test-Path .venv/bin/python) { ./.venv/bin/python -m pytest -q } else { echo 'Venv missing'; exit 1 }\""
            ],
            "presentation": { "echo": true, "reveal": "always" },
            "problemMatcher": []
        }
    ]
}
'@
        if (-not (Test-Path $tasksFile)) { Set-Content -Path $tasksFile -Value $tasksContent -Encoding UTF8 }
        if (-not (Test-Path $settingsFile)) {
            Write-ScaffoldInfo 'Creating settings.json with absolute interpreter path'
            if ($IsWindowsPlatform) { $interpreterAbsolute = Join-Path -Path $workspaceRoot -ChildPath '.venv\Scripts\python.exe' }
            elseif ($IsLinuxPlatform) { $interpreterAbsolute = Join-Path -Path $workspaceRoot -ChildPath '.venv/bin/python' }
            elseif ($IsMacOSPlatform) { $interpreterAbsolute = Join-Path -Path $workspaceRoot -ChildPath '.venv/bin/python' }
            else { $interpreterAbsolute = Join-Path -Path $workspaceRoot -ChildPath '.venv/bin/python' }
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
    }
    else { Write-ScaffoldInfo 'Skipping VS Code config feature.' }

    # ---------------------------------------------------------------------------
    # 3. AI instruction files (.ai directory)
    # ---------------------------------------------------------------------------
    if ($selectedFeatures -contains 'ai') {
        New-DirectoryIfMissing $aiDir
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
                catch { Write-ScaffoldError "Could not download ${template}: $_" }
            }
        }
    }
    else { Write-ScaffoldInfo 'Skipping AI instruction feature.' }

    # ---------------------------------------------------------------------------
    # 3b. GitHub Agents directory (.github/agents/)
    # ---------------------------------------------------------------------------
    if ($selectedFeatures -contains 'agents') {
        New-DirectoryIfMissing $githubDir
        New-DirectoryIfMissing $agentsDir
        $projectType = 'general'
        if (Test-Path (Join-Path $workspaceRoot 'ignition')) { $projectType = 'ignition' }
        elseif ((Test-Path (Join-Path $workspaceRoot 'models')) -or (Test-Path (Join-Path $workspaceRoot 'scripts/train.py'))) { $projectType = 'llm' }
        elseif ((Test-Path (Join-Path $workspaceRoot 'homeassistant')) -or (Test-Path (Join-Path $workspaceRoot 'configuration.yaml'))) { $projectType = 'homeassistant' }
        Write-ScaffoldInfo "Detected project type: $projectType"
        $agentBaseUrl = 'https://raw.githubusercontent.com/hellosamblack/bootstrap/main/.github/agents'
        $agentFilesAll = @('ignition-agent.md','llm-agent.md','homeassistant-agent.md','code-organizer.md','powershell-agent.md','docs-agent.md')
        foreach ($af in $agentFilesAll) {
            $agentFile = Join-Path $agentsDir $af
            if (-not (Test-Path $agentFile)) {
                try {
                    Write-ScaffoldInfo "Downloading agent template: $af"
                    Invoke-WebRequest -UseBasicParsing -Uri "$agentBaseUrl/$af" -OutFile $agentFile
                } catch { Write-ScaffoldError "Failed to download agent ${af}: $_" }
            }
        }
        Write-ScaffoldInfo "Agents available: $((Get-ChildItem $agentsDir -Filter '*.md').Name -join ', ')"
    }
    else { Write-ScaffoldInfo 'Skipping agents feature.' }

    # ---------------------------------------------------------------------------
    # 4. Python dependency bootstrap with torch handling
    # ---------------------------------------------------------------------------
    if ($selectedFeatures -contains 'python') {
        $requirementsPath = Join-Path $workspaceRoot 'requirements.txt'
        # If no requirements.txt exists, seed from template (without black by default)
        if (-not (Test-Path $requirementsPath)) {
            $templateBase = Join-Path $workspaceRoot 'bootstrap_repo' | Join-Path -ChildPath 'templates' | Join-Path -ChildPath 'requirements.base.txt'
            if (Test-Path $templateBase) {
                try {
                    Copy-Item -Path $templateBase -Destination $requirementsPath -Force
                    Write-ScaffoldInfo 'Seeded requirements.txt from requirements.base.txt template.'
                }
                catch { Write-ScaffoldError "Could not seed requirements.txt: $_" }
            }
        }
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
                    $remaining = $reqLines | Where-Object { $_ -and ($_ -notmatch '^\s*torch(\b|[=<>])') -and ($_ -notmatch '^\s*torchvision(\b|[=<>])') -and ($_ -notmatch '^\s*#') -and ($_ -notmatch '^\s*$') }
                    if (@($remaining).Count -gt 0) {
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
            catch { Write-ScaffoldError "Dependency bootstrap failed: $_" }
        }
        else { Write-ScaffoldInfo 'Python feature selected but venv not ready or already bootstrapped.' }
    }
    else { Write-ScaffoldInfo 'Skipping Python dependency feature.' }

    # ---------------------------------------------------------------------------
    # 5. Astro Starlight documentation site
    # ---------------------------------------------------------------------------
    if ($selectedFeatures -contains 'docs') {
        if (-not (Test-Path $docsDir)) {
            if (Get-Command npm -ErrorAction SilentlyContinue) {
                Write-ScaffoldInfo 'Creating Astro Starlight documentation site'
                try {
                    Push-Location $workspaceRoot
                    & npm create astro@latest docs -- --template starlight --install --no-git --typescript strict
                    $contentDir = Join-Path $docsDir 'src\content\docs'
                    New-DirectoryIfMissing (Join-Path $contentDir 'tutorials')
                    New-DirectoryIfMissing (Join-Path $contentDir 'guides')
                    New-DirectoryIfMissing (Join-Path $contentDir 'reference')
                    New-DirectoryIfMissing (Join-Path $contentDir 'explanation')
                    Write-ScaffoldInfo 'Documentation site created with Diátaxis structure'
                    Pop-Location
                }
                catch { Write-ScaffoldError "Failed to create documentation site: $_"; Pop-Location }
            }
            else { Write-ScaffoldInfo 'npm not found; skipping documentation site creation' }
        }
        else { Write-ScaffoldInfo 'Documentation site already exists; skipping.' }
    }
    else { Write-ScaffoldInfo 'Skipping documentation site feature.' }

    # ---------------------------------------------------------------------------
    # 6. spec-kit repository clone & copilot CLI launch
    # ---------------------------------------------------------------------------
    if ($selectedFeatures -contains 'speckit') {
        if (-not (Test-Path $repoDir)) {
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                Write-ScaffoldInfo 'Cloning spec-kit repository'
                try { & gh repo clone github/spec-kit $repoDir } catch { Write-ScaffoldError "Failed to clone spec-kit: $_" }
            }
            elseif (Get-Command git -ErrorAction SilentlyContinue) {
                Write-ScaffoldInfo 'Cloning spec-kit repository (via git)'
                try { & git clone https://github.com/github/spec-kit.git $repoDir } catch { Write-ScaffoldError "Failed to clone spec-kit: $_" }
            }
            else { Write-ScaffoldInfo 'Neither gh nor git CLI found; skipping spec-kit clone' }
        }
        else { Write-ScaffoldInfo 'spec-kit repository already present; skipping clone.' }
    }
    else { Write-ScaffoldInfo 'Skipping spec-kit clone feature.' }

    if ($selectedFeatures -contains 'copilot') {
        if ((Test-Path $repoDir) -and (Get-Command copilot -ErrorAction SilentlyContinue)) {
            try { Write-ScaffoldInfo 'Launching copilot CLI in spec-kit'; Push-Location $repoDir; & copilot; Pop-Location } catch { Write-ScaffoldError "copilot CLI launch failed: $_" }
        }
        else { Write-ScaffoldInfo 'Copilot feature selected but prerequisites (spec-kit repo & copilot CLI) not met.' }
    }
    else { Write-ScaffoldInfo 'Skipping copilot CLI feature.' }

    Write-ScaffoldInfo 'Workspace scaffold complete!'
