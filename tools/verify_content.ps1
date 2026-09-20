param(
    [string]$ProjectRoot = "",
    [string]$GodotExe = "C:\Godot\4.5.1\Godot_v4.5.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
}

$scripts = @(
    "res://tmp/verify_stage1_wave.gd",
    "res://tmp/verify_stage1_scenes.gd",
    "res://tmp/verify_archive_entries.gd",
    "res://tmp/verify_unlock_flow.gd",
    "res://tmp/verify_chapter2_development.gd",
    "res://tmp/verify_art_assets.gd"
)

foreach ($script in $scripts) {
    Write-Host "Running $script"
    $logFile = Join-Path $ProjectRoot "tmp\godot_verify.log"
    & $GodotExe --headless --log-file $logFile --path $ProjectRoot --script $script
    if ($LASTEXITCODE -ne 0) {
        throw "Verification failed: $script"
    }
}

Write-Host "Content verification passed."
