param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
}

$catalogPath = Join-Path $ProjectRoot "resources/stages/stage_catalog.json"
if (-not (Test-Path -LiteralPath $catalogPath)) {
    throw "Missing stage catalog: $catalogPath"
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$chapterStageCount = if ($catalog.chapter_stage_count) { [int]$catalog.chapter_stage_count } else { 12 }

function Set-JsonProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

foreach ($entry in @($catalog.stages)) {
    $chapter = [int]$entry.chapter
    $stage = [int]$entry.stage
    if ($chapter -le 0 -or $stage -le 0) {
        continue
    }

    $sceneRelativePath = "scenes/stage/chapter{0:D2}/c{0:D2}_s{1:D2}.tscn" -f $chapter, $stage
    $waveRelativePath = "resources/waves/c{0:D2}_s{1:D2}_wave_data.tres" -f $chapter, $stage
    $scenePath = Join-Path $ProjectRoot $sceneRelativePath
    $wavePath = Join-Path $ProjectRoot $waveRelativePath

    Set-JsonProperty $entry "global_stage_number" (($chapter - 1) * $chapterStageCount + $stage)
    Set-JsonProperty $entry "scene_path" "res://$($sceneRelativePath -replace '\\', '/')"
    if (Test-Path -LiteralPath $wavePath) {
        Set-JsonProperty $entry "wave_data_path" "res://$($waveRelativePath -replace '\\', '/')"
        if (Test-Path -LiteralPath $scenePath) {
            Set-JsonProperty $entry "status" "playable"
        }
    } elseif ([string]$entry.status -eq "playable") {
        Set-JsonProperty $entry "wave_data_path" ""
        Set-JsonProperty $entry "status" "development"
    }
}

$json = $catalog | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($catalogPath, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Synced stage catalog from scene and wave resources: $catalogPath"
