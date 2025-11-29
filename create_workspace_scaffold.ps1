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

# ---------------------------------------------------------------------------
# Virtual Environment Helper (single-session creation)
# ---------------------------------------------------------------------------
function Ensure-Venv {
    if (Test-Path $venvPython) {
        Write-ScaffoldInfo 'Virtual environment already exists.'
        return
    }
    Write-ScaffoldInfo 'Creating virtual environment (.venv)'    
    $created = $false
    if ($IsWindowsPlatform) {
        foreach ($cmd in @('py -3', 'python3', 'python')) {
            try {
                Write-ScaffoldInfo "Trying: $cmd -m venv .venv"
                & $cmd -m venv .venv 2>$null
                if (Test-Path $venvPython) { $created = $true; break }
            }
            catch {}
        }
    }
    else {
        foreach ($cmd in @('python3', 'python')) {
            try {
                Write-ScaffoldInfo "Trying: $cmd -m venv .venv"
                & $cmd -m venv .venv 2>$null
                if (Test-Path $venvPython) { $created = $true; break }
            }
            catch {}
        }
    }
    if ($created) { Write-ScaffoldInfo 'Virtual environment created.' }
    else { Write-ScaffoldError 'Failed to create virtual environment (Python not found). Install Python first.' }
}

# -----------------------------
# Main Bootstrap Variables
# -----------------------------
$workspaceRoot = Get-Location
$dirVscode = Join-Path $workspaceRoot '.vscode'
$tasksFile = Join-Path $dirVscode 'tasks.json'
$settingsFile = Join-Path $dirVscode 'settings.json'
$aiDir = Join-Path $workspaceRoot '.ai'
$githubDir = Join-Path $workspaceRoot '.github'
$agentsDir = Join-Path $githubDir 'agents'
$docsDir = Join-Path $workspaceRoot 'docs'
$repoDir = Join-Path $workspaceRoot 'spec-kit'
$venvPython = if ($IsWindowsPlatform) { Join-Path $workspaceRoot '.venv\Scripts\python.exe' } else { Join-Path $workspaceRoot '.venv/bin/python' }
$bootstrapSentinel = Join-Path $workspaceRoot '.venv\.bootstrap_done'
$featureRecordFile = Join-Path $workspaceRoot '.bootstrap_features.json'

$allFeatures = @('vscode', 'ai', 'agents', 'python', 'docs', 'speckit', 'copilot')
$availableMap = @{ '1' = 'vscode'; '2' = 'ai'; '3' = 'agents'; '4' = 'python'; '5' = 'docs'; '6' = 'speckit'; '7' = 'copilot' }

# Feature selection logic
$selectedFeatures = @()
if ($Skip -or $env:BOOTSTRAP_AUTO -eq '1') {
    if (Test-Path $featureRecordFile) {
        try { $selectedFeatures = (Get-Content $featureRecordFile | ConvertFrom-Json).features } catch { $selectedFeatures = $allFeatures }
    }
    else { $selectedFeatures = $allFeatures }
    Write-ScaffoldInfo '-Skip/auto enabled -> using recorded or all features.'
}
elseif ($env:BOOTSTRAP_AUTO -eq '0') {
    Write-ScaffoldInfo 'BOOTSTRAP_AUTO=0 -> skipping scaffold.'
    return
}
else {
    Write-ScaffoldInfo 'Select features to scaffold (comma-separated numbers or all; blank=all):'
    Write-Host '  1) VS Code config (.vscode)'
    Write-Host '  2) AI instruction files (.ai)'
    Write-Host '  3) Agent templates (.github/agents)'
    Write-Host '  4) Python dependencies (venv packages)'
    Write-Host '  5) Documentation site (Docusaurus + Typesense, default)'
    Write-Host '  6) spec-kit repository clone'
    Write-Host '  7) Launch copilot CLI (requires spec-kit)'
    Write-Host -NoNewline 'Enter selection: '
    $inputSel = Read-Host
    if (-not $inputSel -or $inputSel.Trim() -eq '' -or $inputSel.Trim().ToLower() -eq 'all') {
        $selectedFeatures = $allFeatures
    }
    else {
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
}
catch { Write-ScaffoldError "Failed to record features: $_" }

New-DirectoryIfMissing $dirVscode
New-DirectoryIfMissing (Join-Path $workspaceRoot '.venv')
Write-ScaffoldInfo "Bootstrapping workspace at '$workspaceRoot' with features: $($selectedFeatures -join ', ')"
if ($selectedFeatures -contains 'vscode') {
    $tasksContent = @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Bootstrap Workspace (Skip)",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-ExecutionPolicy","Bypass",
                "-File","bootstrap_repo/create_workspace_scaffold.ps1",
                "-Skip"
            ],
            "presentation": { "echo": true, "reveal": "always", "panel": "dedicated" },
            "problemMatcher": []
        },
        {
            "label": "Dev Cycle",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-Command",
                "if (Test-Path .venv\\Scripts\\python.exe) { $py = '.venv\\Scripts\\python.exe' } elseif (Test-Path .venv/bin/python) { $py = './.venv/bin/python' } else { echo 'Venv missing'; exit 1 }; Write-Host 'Running flake8...' -ForegroundColor Cyan; & $py -m flake8 .; if ($LASTEXITCODE -ne 0) { Write-Host 'Lint failures' -ForegroundColor Red }; Write-Host 'Running pytest...' -ForegroundColor Cyan; & $py -m pytest -q; if ($LASTEXITCODE -ne 0) { Write-Host 'Tests failed' -ForegroundColor Red }; Write-Host 'Formatting with black...' -ForegroundColor Cyan; & $py -m black .; Write-Host 'Dev Cycle complete.' -ForegroundColor Green"
            ],
            "presentation": { "echo": true, "reveal": "always", "panel": "shared" },
            "problemMatcher": []
        },
        {
            "label": "Docs: Start",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-ExecutionPolicy","Bypass",
                "-File","docs/start_docs.ps1"
            ],
            "presentation": { "echo": true, "reveal": "always", "panel": "dedicated" },
            "problemMatcher": []
        },
        {
            "label": "Docs: Build",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-ExecutionPolicy","Bypass",
                "-Command",
                "Push-Location docs; if (-not (Test-Path 'node_modules')) { pwsh -File setup_docs.ps1 }; npm run build; Pop-Location"
            ],
            "presentation": { "echo": true, "reveal": "always", "panel": "shared" },
            "problemMatcher": []
        },
        {
            "label": "Docs: Preview",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-NoProfile",
                "-ExecutionPolicy","Bypass",
                "-Command",
                "Push-Location docs; if (-not (Test-Path 'node_modules')) { pwsh -File setup_docs.ps1 }; npm run preview; Pop-Location"
            ],
            "presentation": { "echo": true, "reveal": "always", "panel": "dedicated" },
            "problemMatcher": []
        },
        
    ]
}
'@
    Set-Content -Path $tasksFile -Value $tasksContent -Encoding UTF8
    # Recommend editor extensions for improved formatting and linting
    $extensionsJson = @{
        recommendations         = @(
            'esbenp.prettier-vscode',
            'DavidAnson.vscode-markdownlint',
            'dbaeumer.vscode-eslint',
            'ms-python.python',
            'ms-python.black-formatter',
            'charliermarsh.ruff'
        )
        unwantedRecommendations = @()
    }
    $extensionsContent = $extensionsJson | ConvertTo-Json -Depth 3
    $extensionsFile = Join-Path $dirVscode 'extensions.json'
    if (-not (Test-Path $extensionsFile)) { Set-Content -Path $extensionsFile -Value $extensionsContent -Encoding UTF8 }
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
            'editor.defaultFormatter'                      = 'esbenp.prettier-vscode'
            'editor.formatOnSave'                          = $true
            'editor.codeActionsOnSave'                     = @{
                'source.fixAll'              = $true
                'source.fixAll.markdownlint' = $true
                'source.fixAll.eslint'       = $true
                'source.organizeImports'     = $true
            }
            'editor.codeActionsOnSaveTimeout'              = 1500
            'eslint.run'                                   = 'onSave'
            'eslint.autoFixOnSave'                         = $true
            '[markdown]'                                   = @{
                'editor.defaultFormatter'  = 'esbenp.prettier-vscode'
                'editor.formatOnSave'      = $true
                'editor.codeActionsOnSave' = @{
                    'source.fixAll'              = $true
                    'source.fixAll.markdownlint' = $true
                }
            }
            '[javascript]'                                 = @{
                'editor.defaultFormatter'  = 'esbenp.prettier-vscode'
                'editor.formatOnSave'      = $true
                'editor.codeActionsOnSave' = @{
                    'source.fixAll.eslint'   = $true
                    'source.organizeImports' = $true
                }
            }
            '[typescript]'                                 = @{
                'editor.defaultFormatter'  = 'esbenp.prettier-vscode'
                'editor.formatOnSave'      = $true
                'editor.codeActionsOnSave' = @{
                    'source.fixAll.eslint'   = $true
                    'source.organizeImports' = $true
                }
            }
        }
        $settingsContent = $settingsObject | ConvertTo-Json -Depth 4
        Set-Content -Path $settingsFile -Value $settingsContent -Encoding UTF8
        # Copy prettierrc and markdownlint config from bootstrap templates if present
        $scriptDir = $PSScriptRoot
        $repoPrettier = Join-Path $scriptDir '.prettierrc'
        $repoMdLint = Join-Path $scriptDir '.markdownlint.json'
        if (Test-Path $repoPrettier -and -not (Test-Path (Join-Path $workspaceRoot '.prettierrc'))) {
            Copy-Item -Path $repoPrettier -Destination (Join-Path $workspaceRoot '.prettierrc') -Force
            Write-ScaffoldInfo 'Copied .prettierrc into workspace'
        }
        if (Test-Path $repoMdLint -and -not (Test-Path (Join-Path $workspaceRoot '.markdownlint.json'))) {
            Copy-Item -Path $repoMdLint -Destination (Join-Path $workspaceRoot '.markdownlint.json') -Force
            Write-ScaffoldInfo 'Copied .markdownlint.json into workspace'
        }
        # Copy helper scripts into workspace (eg: fix_ trailing_backticks.ps1)
        $srcScripts = Join-Path $scriptDir 'scripts'
        $destScripts = Join-Path $workspaceRoot 'scripts'
        if (Test-Path $srcScripts -and -not (Test-Path $destScripts)) {
            Copy-Item -Path $srcScripts -Destination $destScripts -Recurse -Force
            Write-ScaffoldInfo 'Copied helper scripts into workspace (scripts/)'
        }
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
    $agentFilesAll = @('ignition-agent.md', 'llm-agent.md', 'homeassistant-agent.md', 'code-organizer.md', 'powershell-agent.md', 'docs-agent.md')
    foreach ($af in $agentFilesAll) {
        $agentFile = Join-Path $agentsDir $af
        if (-not (Test-Path $agentFile)) {
            try {
                Write-ScaffoldInfo "Downloading agent template: $af"
                Invoke-WebRequest -UseBasicParsing -Uri "$agentBaseUrl/$af" -OutFile $agentFile
            }
            catch { Write-ScaffoldError "Failed to download agent ${af}: $_" }
        }
    }
    Write-ScaffoldInfo "Agents available: $((Get-ChildItem $agentsDir -Filter '*.md').Name -join ', ')"
}
else { Write-ScaffoldInfo 'Skipping agents feature.' }

# ---------------------------------------------------------------------------
# 4. Python dependency bootstrap with torch handling
# ---------------------------------------------------------------------------
if ($selectedFeatures -contains 'python') {
    # Ensure virtual environment exists before dependency bootstrap
    if (-not (Test-Path $venvPython)) {
        Write-ScaffoldInfo 'Creating Python virtual environment (.venv)'
        $venvDir = Join-Path $workspaceRoot '.venv'
        $created = $false
        try { & py -3 -m venv $venvDir; $created = $true } catch {}
        if (-not $created) { try { & python3 -m venv $venvDir; $created = $true } catch {} }
        if (-not $created) { try { & python -m venv $venvDir; $created = $true } catch {} }
        if ($created) {
            Write-ScaffoldInfo 'Virtual environment created successfully.'
        }
        else { Write-ScaffoldError 'Could not create virtual environment; install Python and re-run.' }
    }
    $requirementsPath = Join-Path $workspaceRoot 'requirements.txt'
    # Ensure venv exists in this same session
    if (-not (Test-Path $venvPython)) { Ensure-Venv }
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
# 5. Docusaurus + Typesense documentation site (default)
# ---------------------------------------------------------------------------
if ($selectedFeatures -contains 'docs') {
    if (-not (Test-Path $docsDir)) {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-ScaffoldInfo 'Creating Docusaurus documentation site with Typesense search'
            try {
                Push-Location $workspaceRoot
                & npx create-docusaurus@latest docs classic --typescript
                if ($LASTEXITCODE -ne 0) {
                    throw "npx create-docusaurus failed with exit code $LASTEXITCODE"
                }
                Pop-Location
                # Install Typesense search plugin
                Push-Location $docsDir
                Write-ScaffoldInfo 'Installing Typesense search plugin'
                & npm install docusaurus-theme-search-typesense
                if ($LASTEXITCODE -ne 0) {
                    Write-ScaffoldError 'Failed to install Typesense search plugin'
                }
                Pop-Location
                # Create Diátaxis directory structure
                $docsContentDir = Join-Path $docsDir 'docs'
                New-DirectoryIfMissing (Join-Path $docsContentDir 'tutorials')
                New-DirectoryIfMissing (Join-Path $docsContentDir 'guides')
                New-DirectoryIfMissing (Join-Path $docsContentDir 'reference')
                New-DirectoryIfMissing (Join-Path $docsContentDir 'explanation')
                Write-ScaffoldInfo 'Documentation site created with Diátaxis structure'
            }
            catch { Write-ScaffoldError "Failed to create documentation site: $_"; Pop-Location }
        }
        else { Write-ScaffoldInfo 'npm not found; skipping documentation site creation' }
    }
    else { Write-ScaffoldInfo 'Documentation site already exists; skipping.' }

    # Configure Docusaurus with Typesense
    $docusaurusConfigPath = Join-Path $docsDir 'docusaurus.config.ts'
    $projectName = Split-Path -Leaf $workspaceRoot
    if (Test-Path $docusaurusConfigPath) {
        $cfgRaw = Get-Content $docusaurusConfigPath -Raw
        if ($cfgRaw -match "title: 'My Site'") {
            $enhancedCfg = @"
import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: '${projectName} Docs',
  tagline: '${projectName} Knowledge Base',
  favicon: 'img/favicon.ico',

  url: 'https://your-docusaurus-site.example.com',
  baseUrl: '/',

  organizationName: 'hellosamblack',
  projectName: '${projectName}',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  themes: [
    [
      require.resolve('docusaurus-theme-search-typesense'),
      {
        typesenseCollectionName: 'docs',
        typesenseServerConfig: {
          nodes: [
            {
              host: 'localhost',
              port: 8108,
              protocol: 'http',
            },
          ],
          apiKey: 'xyz', // Placeholder - use read-only search API key in production
        },
      },
    ],
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/hellosamblack/${projectName}/tree/main/docs/',
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ['rss', 'atom'],
            xslt: true,
          },
          editUrl: 'https://github.com/hellosamblack/${projectName}/tree/main/docs/',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    navbar: {
      title: '${projectName}',
      logo: {
        alt: '${projectName} Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialsSidebar',
          position: 'left',
          label: 'Tutorials',
        },
        {
          type: 'docSidebar',
          sidebarId: 'guidesSidebar',
          position: 'left',
          label: 'Guides',
        },
        {
          type: 'docSidebar',
          sidebarId: 'referenceSidebar',
          position: 'left',
          label: 'Reference',
        },
        {
          type: 'docSidebar',
          sidebarId: 'explanationSidebar',
          position: 'left',
          label: 'Explanation',
        },
        {to: '/blog', label: 'Blog', position: 'left'},
        {
          href: 'https://github.com/hellosamblack/${projectName}',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Tutorials',
              to: '/docs/tutorials/getting-started',
            },
            {
              label: 'Guides',
              to: '/docs/guides/overview',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'Blog',
              to: '/blog',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/hellosamblack/${projectName}',
            },
          ],
        },
      ],
      copyright: 'Built with Docusaurus.',
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
"@
            Set-Content -Path $docusaurusConfigPath -Value $enhancedCfg -Encoding UTF8
            Write-ScaffoldInfo 'docusaurus.config.ts enhanced with Diátaxis nav & Typesense search.'
        }
    }

    # Create sidebars.ts with Diátaxis categories
    $sidebarsPath = Join-Path $docsDir 'sidebars.ts'
    if (Test-Path $sidebarsPath) {
        $sidebarsContent = @"
import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialsSidebar: [
    {
      type: 'category',
      label: 'Tutorials',
      items: [{type: 'autogenerated', dirName: 'tutorials'}],
    },
  ],
  guidesSidebar: [
    {
      type: 'category',
      label: 'Guides',
      items: [{type: 'autogenerated', dirName: 'guides'}],
    },
  ],
  referenceSidebar: [
    {
      type: 'category',
      label: 'Reference',
      items: [{type: 'autogenerated', dirName: 'reference'}],
    },
  ],
  explanationSidebar: [
    {
      type: 'category',
      label: 'Explanation',
      items: [{type: 'autogenerated', dirName: 'explanation'}],
    },
  ],
};

export default sidebars;
"@
        Set-Content -Path $sidebarsPath -Value $sidebarsContent -Encoding UTF8
        Write-ScaffoldInfo 'sidebars.ts created with Diátaxis categories.'
    }

    # Seed pages for Diátaxis structure
    $docsContentDir = Join-Path $docsDir 'docs'
    $seedPages = @{
        (Join-Path $docsContentDir 'tutorials\getting-started.md') = @"
---
sidebar_position: 1
title: Getting Started
description: Quick start tutorial.
---

# Getting Started

Welcome! This tutorial walks you through the essentials.

## Prerequisites

- Node.js 18 or higher
- npm or yarn

## Steps

1. **Installation** - Set up your development environment
2. **Configuration** - Configure the project settings
3. **First deployment** - Deploy your first version

## Next Steps

Edit this page to tailor steps to your project.
"@
        (Join-Path $docsContentDir 'guides\overview.md') = @"
---
sidebar_position: 1
title: Project Overview Guide
description: High-level guide.
---

# Project Overview Guide

This guide provides a structured path for common tasks.

## Sections

- **Environment setup** - Configure your local development environment
- **Development workflow** - Day-to-day development practices
- **Testing & quality** - Ensure code quality and test coverage
- **Deployment procedures** - Release and deployment guidelines
"@
        (Join-Path $docsContentDir 'reference\index.md') = @"
---
sidebar_position: 1
title: API Reference Index
description: Entry point for reference material.
---

# API Reference

Reference pages document precise interfaces, commands, and configuration options.

Add files under `reference/` to expand this index automatically.

## Available References

- Configuration options
- CLI commands
- API endpoints
"@
        (Join-Path $docsContentDir 'explanation\concepts.md') = @"
---
sidebar_position: 1
title: Core Concepts
description: Deeper conceptual explanations.
---

# Core Concepts

Use explanation pages for reasoning, design decisions, and architecture notes.

## Topics

- **Architecture decisions** - Why we chose this approach
- **Design patterns** - Patterns used throughout the codebase
- **Trade-offs** - Understanding the compromises made
"@
    }
    foreach ($p in $seedPages.Keys) {
        $parentDir = Split-Path -Parent $p
        if (-not (Test-Path $parentDir)) { New-DirectoryIfMissing $parentDir }
        if (-not (Test-Path $p)) { Set-Content -Path $p -Value $seedPages[$p] -Encoding UTF8 }
    }

    # Create intro.md as docs landing page
    $introPath = Join-Path $docsContentDir 'intro.md'
    if (Test-Path $introPath) {
        $introRaw = Get-Content $introPath -Raw
        if ($introRaw -match 'Tutorial Intro') {
            $newIntro = @"
---
sidebar_position: 1
slug: /
title: Welcome
description: Entry point for the ${projectName} documentation.
---

# Welcome to ${projectName}

Welcome to the ${projectName} Knowledge Base.

## Documentation Structure

This documentation follows the [Diátaxis](https://diataxis.fr/) framework:

| Category | Purpose |
|----------|---------|
| **[Tutorials](/docs/tutorials/getting-started)** | Step-by-step learning experiences |
| **[Guides](/docs/guides/overview)** | Goal-oriented how-to guides |
| **[Reference](/docs/reference/)** | Technical descriptions and specifications |
| **[Explanation](/docs/explanation/concepts)** | Understanding-oriented discussion |

## Quick Links

- 🚀 [Getting Started Tutorial](/docs/tutorials/getting-started)
- 📖 [Guides Overview](/docs/guides/overview)
- 📚 [API Reference](/docs/reference/)
- 💡 [Core Concepts](/docs/explanation/concepts)

---

_This landing page was auto-generated; customize it anytime._
"@
            Set-Content -Path $introPath -Value $newIntro -Encoding UTF8
            Write-ScaffoldInfo 'Landing page replaced with Diátaxis overview.'
        }
    }

    # API reference generation helper script
    $genApiScript = Join-Path $docsDir 'generate_api_docs.ps1'
    if (-not (Test-Path $genApiScript)) {
        $genApiContent = @'
<#
.SYNOPSIS
    Generate API reference from source code comments (JSDoc/TSDoc/Python docstrings).
.PARAMETER SourceDir
    Root directory to scan for source files (default: ../src or ..).
.PARAMETER OutputDir
    Where to write generated markdown (default: docs/reference/api).
#>
param(
    [string]$SourceDir = '..',
    [string]$OutputDir = 'docs/reference/api'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Scanning $SourceDir for API documentation..." -ForegroundColor Cyan
    # TypeScript/JavaScript: requires typedoc
    $tsFiles = @(Get-ChildItem -Path $SourceDir -Recurse -Include *.ts,*.tsx,*.js,*.jsx -ErrorAction SilentlyContinue)
    if (@($tsFiles).Count -gt 0) {
        if (-not (Get-Command typedoc -ErrorAction SilentlyContinue)) {
            Write-Host 'typedoc not found; install: npm install -g typedoc typedoc-plugin-markdown' -ForegroundColor Yellow
        } else {
            Write-Host 'Generating TypeScript/JS API docs with typedoc...' -ForegroundColor Cyan
            & typedoc --out $OutputDir --plugin typedoc-plugin-markdown --entryPointStrategy expand $SourceDir
        }
    }
    # Python: requires pydoc-markdown
    $pyFiles = @(Get-ChildItem -Path $SourceDir -Recurse -Include *.py -ErrorAction SilentlyContinue)
    if (@($pyFiles).Count -gt 0) {
        if (-not (Get-Command pydoc-markdown -ErrorAction SilentlyContinue)) {
            Write-Host 'pydoc-markdown not found; install: pip install pydoc-markdown' -ForegroundColor Yellow
        } else {
            Write-Host 'Generating Python API docs with pydoc-markdown...' -ForegroundColor Cyan
            & pydoc-markdown --render-toc --output-directory $OutputDir
        }
    }
    Write-Host "API docs generated in $OutputDir" -ForegroundColor Green
}
finally { Pop-Location }
'@
        Set-Content -Path $genApiScript -Value $genApiContent -Encoding UTF8
        Write-ScaffoldInfo 'Created generate_api_docs.ps1 helper script.'
    }

    # Versioning helper script for Docusaurus
    $versionScript = Join-Path $docsDir 'version_docs.ps1'
    if (-not (Test-Path $versionScript)) {
        $versionContent = @'
<#
.SYNOPSIS
    Create versioned docs using Docusaurus versioning.
.PARAMETER Version
    Version tag (e.g., 1.0.0).
#>
param(
    [Parameter(Mandatory)]
    [string]$Version
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $versionedDocsDir = Join-Path $PSScriptRoot "versioned_docs/version-$Version"
    if (Test-Path $versionedDocsDir) { Write-Host "Version $Version already exists." -ForegroundColor Yellow; exit 0 }
    Write-Host "Creating versioned docs for $Version..." -ForegroundColor Cyan
    # Use Docusaurus CLI to create version
    & npm run docusaurus docs:version $Version
    Write-Host "Versioned docs created for $Version" -ForegroundColor Green
}
finally { Pop-Location }
'@
        Set-Content -Path $versionScript -Value $versionContent -Encoding UTF8
        Write-ScaffoldInfo 'Created version_docs.ps1 helper script.'
    }

    # Docs helper scripts (setup & start) - Docusaurus version
    $docsSetupScript = Join-Path $docsDir 'setup_docs.ps1'
    $docsStartScript = Join-Path $docsDir 'start_docs.ps1'
    $setupContent = @'
<#
.SYNOPSIS
    Install Docusaurus/Node dependencies for the docs site.
    Safe for Windows / cross-platform (no shebang to avoid /usr/bin/env invocation issues).
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  if (-not (Test-Path (Join-Path $PSScriptRoot 'package.json'))) {
    Write-Host 'Docs site not initialized. Run bootstrap with docs feature.' -ForegroundColor Yellow
    exit 1
  }
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host 'npm CLI not found. Install Node.js.' -ForegroundColor Red
    exit 1
  }
  if (-not (Test-Path 'node_modules')) {
    Write-Host 'Installing Docusaurus docs dependencies...' -ForegroundColor Cyan
    & npm install
  }
  else {
    Write-Host 'node_modules present; skipping npm install.' -ForegroundColor Yellow
  }
}
finally { Pop-Location }
'@
    $startContent = @'
<#
.SYNOPSIS
    Start Docusaurus docs dev server with host/port.
.PARAMETER Port
    Port to bind (default 3000).
.PARAMETER Expose
    Bind to 0.0.0.0 instead of localhost.
.PARAMETER NoBrowser
    Skip auto-opening browser.
#>
param(
  [int]$Port = 3000,
  [switch]$Expose,
  [switch]$NoBrowser
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$uname=''; try { $uname=(uname) 2>$null } catch {}
$IsWindowsPlatform=($env:OS -eq 'Windows_NT')
$IsLinuxPlatform=(-not $IsWindowsPlatform -and (Test-Path '/etc/os-release'))
$IsMacOSPlatform=(-not $IsWindowsPlatform -and -not $IsLinuxPlatform -and $uname -eq 'Darwin')
Push-Location $PSScriptRoot
try {
  $HostBind = if ($Expose) { '0.0.0.0' } else { 'localhost' }
  if (-not (Test-Path (Join-Path $PSScriptRoot 'package.json'))) { Write-Host 'Docs site not initialized. Run bootstrap with docs feature.' -ForegroundColor Yellow; exit 1 }
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Write-Host 'npm CLI not found. Install Node.js.' -ForegroundColor Red; exit 1 }
  if (-not (Test-Path (Join-Path $PSScriptRoot 'node_modules'))) { Write-Host 'node_modules missing; invoking setup_docs.ps1' -ForegroundColor Yellow; & (Join-Path $PSScriptRoot 'setup_docs.ps1') }
  $Url = "http://${HostBind}:${Port}/"
  Write-Host "Starting Docusaurus docs dev server on ${HostBind}:${Port} (blocking)..." -ForegroundColor Cyan
  if (-not $NoBrowser) {
    Start-Job -ScriptBlock { param($H,$P)
      for ($i=0;$i -lt 30;$i++) { try { $r=Invoke-WebRequest -Uri "http://${H}:${P}/" -UseBasicParsing -ErrorAction SilentlyContinue; if ($r.StatusCode -eq 200) { try { Start-Process "http://${H}:${P}/" } catch {}; break } } catch {} ; Start-Sleep 1 }
    } -ArgumentList $HostBind,$Port | Out-Null
  }
  $npmExe = (Get-Command npm).Source
  & $npmExe start -- --port $Port --host $HostBind
  Write-Host 'Docs dev process exited.' -ForegroundColor Yellow
}
finally { Pop-Location }
'@
    # Always update/create the scripts for Docusaurus
    Set-Content -Path $docsSetupScript -Value $setupContent -Encoding UTF8
    Set-Content -Path $docsStartScript -Value $startContent -Encoding UTF8
    Write-ScaffoldInfo 'Docs helper scripts ensured (setup_docs.ps1, start_docs.ps1).'
}
else { Write-ScaffoldInfo 'Skipping documentation site feature.' }

# ---------------------------------------------------------------------------
# 6. spec-kit repository clone (robust) & copilot CLI (manual)
# ---------------------------------------------------------------------------
if ($selectedFeatures -contains 'speckit') {
    $forceGit = ($env:BOOTSTRAP_CLONE_MODE -eq 'git')
    $sshKeyDir = Join-Path $HOME '.ssh'
    $hasSshKeys = $false
    if (Test-Path $sshKeyDir) {
        $hasSshKeys = (Get-ChildItem -Path $sshKeyDir -Filter 'id_*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'id_(ed25519|rsa)$' }) -ne $null
    }
    $preferGit = $forceGit -or (-not $hasSshKeys)

    if (-not (Test-Path $repoDir)) {
        # Attempt gh clone only if not preferring git directly and gh exists
        if (-not $preferGit -and (Get-Command gh -ErrorAction SilentlyContinue)) {
            $proto = ''
            try { $proto = (& gh config get git_protocol) 2>$null } catch {}
            if ($proto -eq 'ssh') {
                Write-ScaffoldInfo 'gh protocol ssh -> switching to https.'
                try { & gh config set git_protocol https } catch { Write-ScaffoldError "Failed to set gh protocol: $_" }
                $proto = ''; try { $proto = (& gh config get git_protocol) 2>$null } catch {}
            }
            if ($proto -ne 'https') {
                Write-ScaffoldInfo 'gh still using ssh/unknown; falling back to git HTTPS.'
                $preferGit = $true
            }
            if (-not $preferGit) {
                Write-ScaffoldInfo 'Cloning spec-kit via gh (https).'
                & gh repo clone github/spec-kit $repoDir
                if ($LASTEXITCODE -ne 0) {
                    Write-ScaffoldError 'gh clone failed; switching to git HTTPS.'
                    $preferGit = $true
                    if (Test-Path $repoDir) { try { Remove-Item -Path $repoDir -Recurse -Force } catch {} }
                }
            }
        }
        if ($preferGit) {
            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-ScaffoldInfo 'Cloning spec-kit via git HTTPS.'
                & git clone https://github.com/github/spec-kit.git $repoDir
                if ($LASTEXITCODE -ne 0) {
                    Write-ScaffoldError 'git HTTPS clone failed; initiating zip fallback.'
                    if (Test-Path $repoDir) { try { Remove-Item -Path $repoDir -Recurse -Force } catch {} }
                    $zipUrl = 'https://codeload.github.com/github/spec-kit/zip/refs/heads/main'
                    $zipPath = Join-Path $env:TEMP 'spec-kit.zip'
                    try {
                        Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -OutFile $zipPath
                        $extractRoot = Join-Path $env:TEMP 'spec-kit_extract'
                        if (Test-Path $extractRoot) { Remove-Item -Path $extractRoot -Recurse -Force }
                        New-Item -ItemType Directory -Path $extractRoot | Out-Null
                        Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
                        $extractedDir = Join-Path $extractRoot 'spec-kit-main'
                        if (Test-Path $extractedDir) {
                            Move-Item -Path $extractedDir -Destination $repoDir -Force
                            Write-ScaffoldInfo 'spec-kit obtained via zip fallback.'
                        }
                        else { Write-ScaffoldError 'Zip extraction did not produce spec-kit-main directory.' }
                        Remove-Item -Path $zipPath -Force
                    }
                    catch { Write-ScaffoldError "Zip fallback failed: $_" }
                }
            }
            else {
                Write-ScaffoldInfo 'git not found; initiating zip fallback.'
                $zipUrl = 'https://codeload.github.com/github/spec-kit/zip/refs/heads/main'
                $zipPath = Join-Path $env:TEMP 'spec-kit.zip'
                try {
                    Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -OutFile $zipPath
                    $extractRoot = Join-Path $env:TEMP 'spec-kit_extract'
                    if (Test-Path $extractRoot) { Remove-Item -Path $extractRoot -Recurse -Force }
                    New-Item -ItemType Directory -Path $extractRoot | Out-Null
                    Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
                    $extractedDir = Join-Path $extractRoot 'spec-kit-main'
                    if (Test-Path $extractedDir) {
                        Move-Item -Path $extractedDir -Destination $repoDir -Force
                        Write-ScaffoldInfo 'spec-kit obtained via zip fallback.'
                    }
                    else { Write-ScaffoldError 'Zip extraction did not produce spec-kit-main directory.' }
                    Remove-Item -Path $zipPath -Force
                }
                catch { Write-ScaffoldError "Zip fallback failed: $_" }
            }
        }
    }
    else { Write-ScaffoldInfo 'spec-kit repository already present; skipping clone.' }
}
else { Write-ScaffoldInfo 'Skipping spec-kit clone feature.' }

# Copilot auto-launch disabled (manual invocation recommended)
if ($selectedFeatures -contains 'copilot') {
    Write-ScaffoldInfo 'Copilot feature selected; auto-launch disabled. Run manually: cd spec-kit; copilot'
}
else { Write-ScaffoldInfo 'Skipping copilot CLI feature.' }

Write-ScaffoldInfo 'Workspace scaffold complete!'
