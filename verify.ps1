#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scripts = @(
    (Join-Path $PSScriptRoot 'start-tv2m.ps1'),
    (Join-Path $PSScriptRoot 'android\tv2m-receiver\build.ps1')
)
foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $script,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    if ($errors.Count) {
        throw "PowerShell syntax errors in $script`n$($errors -join "`n")"
    }
}

$forbiddenPatterns = @(
    '192\.168\.1\.159',
    '\b[0-9a-f]{12,16}\b',
    'DogeTV',
    '06G03'
)
$sourceFiles = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File |
    Where-Object {
        $_.FullName -ne $PSCommandPath -and
        $_.FullName -notmatch '\\build\\' -and
        $_.FullName -notmatch '\\.git\\'
    }
foreach ($pattern in $forbiddenPatterns) {
    $matches = $sourceFiles |
        Select-String -Pattern $pattern -ErrorAction SilentlyContinue
    if ($matches) {
        throw "Local identifier pattern '$pattern' found in tracked source."
    }
}

& (Join-Path $PSScriptRoot 'android\tv2m-receiver\build.ps1')

Write-Output 'Repository verification completed successfully.'
