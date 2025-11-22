<#
.SYNOPSIS
    Ensures Python is installed (winget or download).
.DESCRIPTION
    Tries to locate Python via py, python3, python. If not found, attempts
    winget install for user scope, then fallback to downloading and running
    the official installer from python.org.
.NOTES
    Used by venv creation tasks when Python is missing.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info { param($m); Write-Host "[install-python] $m" -ForegroundColor Cyan }
function Write-Err { param($m); Write-Host "[install-python] ERROR: $m" -ForegroundColor Red }

# Check if Python already available
$pythonCmds = @('py', 'python3', 'python')
foreach ($cmd in $pythonCmds) {
    try {
        $null = & $cmd --version 2>$null
        Write-Info "Python found via '$cmd'"
        return
    }
    catch { }
}

Write-Info 'Python not found; attempting installation'

# Try winget first (user scope to avoid admin)
if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
        Write-Info 'Installing Python via winget (user scope)'
        & winget install Python.Python.3.12 --scope user --silent
        Write-Info 'Python installed successfully via winget'
        Write-Info 'You may need to restart your terminal or VS Code for PATH updates'
        return
    }
    catch {
        Write-Info "winget install failed: $_. Trying download method..."
    }
}

# Fallback: download official installer
Write-Info 'Downloading Python installer from python.org'
$installerUrl = 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe'
$installerPath = Join-Path $env:TEMP 'python-installer.exe'

try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Write-Info 'Running Python installer (user scope, no admin required)'
    
    # Install for current user only, add to PATH, include pip
    $args = @(
        '/quiet',
        'InstallAllUsers=0',
        'PrependPath=1',
        'Include_pip=1',
        'Include_test=0'
    )
    
    Start-Process -FilePath $installerPath -ArgumentList $args -Wait -NoNewWindow
    Remove-Item -Path $installerPath -Force
    
    Write-Info 'Python installation complete'
    Write-Info 'Please restart your terminal or VS Code for PATH updates to take effect'
}
catch {
    Write-Err "Failed to download/install Python: $_"
    Write-Err 'Please install Python manually from https://www.python.org/downloads/'
    exit 1
}
