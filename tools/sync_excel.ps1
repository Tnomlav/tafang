param(
    [string]$ProjectRoot = "",
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
}

& (Join-Path $PSScriptRoot "sync_shuzhi.ps1") -ProjectRoot $ProjectRoot
& (Join-Path $PSScriptRoot "sync_guanqia.ps1") -ProjectRoot $ProjectRoot -SkipSceneBinding
& (Join-Path $PSScriptRoot "sync_stage_catalog.ps1") -ProjectRoot $ProjectRoot

if (-not $SkipVerify) {
    & (Join-Path $PSScriptRoot "verify_content.ps1") -ProjectRoot $ProjectRoot
}
