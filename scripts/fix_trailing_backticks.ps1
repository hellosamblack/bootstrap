param(
    [string]$Root = (Get-Location).Path
)

Write-Host "Scanning markdown files under: $Root"

$mdFiles = Get-ChildItem -Path $Root -Recurse -Include *.md -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\node_modules\\' -and $_.FullName -notmatch '\\.git\\' }
foreach ($file in $mdFiles) {
    try {
        $lines = Get-Content -Path $file.FullName -Encoding UTF8
        if ($lines.Length -gt 0) {
            $lastLine = $lines[-1].TrimEnd()
            if ($lastLine -eq '```') {
                $newLines = $lines[0..($lines.Length - 2)]
                $newLines | Set-Content -Path $file.FullName -Encoding UTF8
                Write-Host "Removed trailing fence from: $($file.FullName)"
            }
        }
    }
    catch {
        Write-Host "Failed to process $($file.FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Trailing fence cleanup complete."
