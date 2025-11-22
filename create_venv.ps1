<#
.SYNOPSIS
    Idempotent virtual environment creation helper.
.DESCRIPTION
    Creates a Python virtual environment in .venv if it does not already
    contain an interpreter. Cross-platform; picks sensible default Python.
.PARAMETER Python
    Optional explicit python launcher/executable. Example: py -3.11, python3.12
.EXAMPLE
    pwsh -File create_venv.ps1
.EXAMPLE
    pwsh -File create_venv.ps1 -Python "py -3"
.NOTES
    Used by tasks or manually; keeps logic out of tasks.json.
#>
[CmdletBinding()]
param(
    [string]$Python
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Python) {
    if ($env:OS -eq 'Windows_NT') { $Python = 'py -3' } else { $Python = 'python3' }
}

# Resolve python command to full invocation pieces
$pythonParts = $Python -split '\s+'
$pythonExe = $pythonParts[0]
$pythonArgs = $pythonParts[1..($pythonParts.Count - 1)]

$venvDir = Join-Path (Get-Location) '.venv'
$winInterpreter = Join-Path $venvDir 'Scripts\python.exe'
$unixInterpreter = Join-Path $venvDir 'bin/python'

function Write-Info { param($m); Write-Host "[create-venv] $m" -ForegroundColor Cyan }
function Write-Err { param($m); Write-Host "[create-venv] ERROR: $m" -ForegroundColor Red }

$alreadyExists = (Test-Path $winInterpreter) -or (Test-Path $unixInterpreter)
if ($alreadyExists) {
    Write-Info 'Interpreter already present; skipping venv creation.'
    return
}

Write-Info "Creating virtual environment using: $Python"
try {
    & $pythonExe $pythonArgs -m venv $venvDir
    if (Test-Path $winInterpreter) { Write-Info "Created venv: $winInterpreter" }
    elseif (Test-Path $unixInterpreter) { Write-Info "Created venv: $unixInterpreter" }
    else { Write-Err 'Venv creation reported success but interpreter missing.' }
}
catch {
    Write-Err "Failed to create venv: $_"
    exit 1
}
