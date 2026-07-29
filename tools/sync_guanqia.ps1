param(
    [string]$Workbook = "guanqia.xlsx",
    [string]$ProjectRoot = "",
    [int]$OnlyChapter = 0,
    [int]$OnlyStage = 0,
    [switch]$SkipSceneBinding
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
}

if ([System.IO.Path]::IsPathRooted($Workbook)) {
    $WorkbookPath = (Resolve-Path -LiteralPath $Workbook).Path
} else {
    $WorkbookPath = (Resolve-Path -LiteralPath (Join-Path $ProjectRoot $Workbook)).Path
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$BeginText = [string]([char]0x5F00) + [string]([char]0x59CB)
$EndText = [string]([char]0x7ED3) + [string]([char]0x675F)
$WaveHeaderText = [string]([char]0x6CE2) + [string]([char]0x6B21)
$InitialCostText = [string]([char]0x521D) + [string]([char]0x59CB) + [string]([char]0x8D39) + [string]([char]0x7528)
$DeploymentLimitText = [string]([char]0x90E8) + [string]([char]0x7F72) + [string]([char]0x4E0A) + [string]([char]0x9650)
$RewardCharacterText = [string]([char]0x901A) + [string]([char]0x5173) + [string]([char]0x8D60) + [string]([char]0x9001) + [string]([char]0x89D2) + [string]([char]0x8272)
$TeleportPointText = [string]([char]0x4F20) + [string]([char]0x9001) + [string]([char]0x70B9)
$TeleportWaitText = [string]([char]0x4F20) + [string]([char]0x9001) + [string]([char]0x7B49) + [string]([char]0x5F85) + [string]([char]0x0028) + [string]([char]0x79D2) + [string]([char]0x0029)
$EnemyTypeText = [string]([char]0x654C) + [string]([char]0x4EBA) + [string]([char]0x7C7B) + [string]([char]0x578B)
$ChineseComma = [string]([char]0xFF0C)
$ChineseSemicolon = [string]([char]0xFF1B)
$ChineseColon = [string]([char]0xFF1A)
$TeleportToText = [string]([char]0x5230)
$TeleportUntilText = [string]([char]0x81F3)
$ListSplitPattern = "[," + [regex]::Escape($ChineseComma) + ";" + [regex]::Escape($ChineseSemicolon) + "\s]+"
$WaitSplitPattern = "[," + [regex]::Escape($ChineseComma) + ";" + [regex]::Escape($ChineseSemicolon) + "]+"
$ColonPattern = "[:" + [regex]::Escape($ChineseColon) + "]"

function Read-ZipEntryText {
    param(
        [System.IO.Compression.ZipArchive]$ZipFile,
        [string]$Name
    )

    $entry = $ZipFile.GetEntry($Name)
    if ($null -eq $entry) {
        return $null
    }

    $reader = New-Object System.IO.StreamReader($entry.Open())
    try {
        return $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
}

function Get-ColumnIndex {
    param([string]$CellRef)

    $letters = ([regex]::Match($CellRef, "^[A-Z]+")).Value
    $index = 0
    foreach ($char in $letters.ToCharArray()) {
        $index = $index * 26 + ([int][char]$char - [int][char]"A" + 1)
    }
    return $index
}

function Get-CellText {
    param(
        $Cell,
        [object[]]$SharedStrings
    )

    $type = [string]$Cell.t
    if ($type -eq "inlineStr") {
        $texts = @($Cell.SelectNodes(".//*[local-name()='t']") | ForEach-Object { $_.InnerText })
        return ($texts -join "")
    }

    if ($null -eq $Cell.v) {
        return ""
    }

    $text = [string]$Cell.v
    if ($type -eq "s") {
        return [string]$SharedStrings[[int]$text]
    }
    return $text
}

function Read-XlsxSheetsRows {
    param([string]$Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        [xml]$workbook = Read-ZipEntryText $zip "xl/workbook.xml"
        [xml]$relationships = Read-ZipEntryText $zip "xl/_rels/workbook.xml.rels"

        $relationshipMap = @{}
        foreach ($relationship in @($relationships.SelectNodes("//*[local-name()='Relationship']"))) {
            $relationshipMap[$relationship.Id] = $relationship.Target
        }

        $sharedStrings = @()
        $sharedStringText = Read-ZipEntryText $zip "xl/sharedStrings.xml"
        if (-not [string]::IsNullOrEmpty($sharedStringText)) {
            [xml]$sharedStringXml = $sharedStringText
            foreach ($item in @($sharedStringXml.SelectNodes("//*[local-name()='si']"))) {
                $parts = @($item.SelectNodes(".//*[local-name()='t']") | ForEach-Object { $_.InnerText })
                $sharedStrings += ($parts -join "")
            }
        }

        $sheets = @()
        foreach ($sheet in @($workbook.SelectNodes("//*[local-name()='sheet']"))) {
            $relationshipId = $sheet.GetAttribute("id", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
            $target = [string]$relationshipMap[$relationshipId]
            $normalizedTarget = $target.TrimStart("/")
            $sheetPath = if ($normalizedTarget.StartsWith("xl/")) { $normalizedTarget } else { "xl/" + $normalizedTarget }

            [xml]$sheetXml = Read-ZipEntryText $zip $sheetPath
            $rows = @()
            foreach ($row in @($sheetXml.SelectNodes("//*[local-name()='sheetData']/*[local-name()='row']"))) {
                $values = @{}
                $maxColumn = 0
                foreach ($cell in @($row.SelectNodes("*[local-name()='c']"))) {
                    $column = Get-ColumnIndex $cell.r
                    $values[$column] = Get-CellText $cell $sharedStrings
                    if ($column -gt $maxColumn) {
                        $maxColumn = $column
                    }
                }

                $cells = @()
                for ($column = 1; $column -le $maxColumn; $column++) {
                    if ($values.ContainsKey($column)) {
                        $cells += $values[$column]
                    } else {
                        $cells += ""
                    }
                }
                $rows += ,$cells
            }
            $sheets += ,[ordered]@{
                name = [string]$sheet.name
                rows = $rows
            }
        }
        return $sheets
    } finally {
        $zip.Dispose()
    }
}

function ConvertTo-Int {
    param(
        $Value,
        [int]$Default = 0
    )

    $text = ([string]$Value).Trim()
    if ($text -eq "") {
        return $Default
    }
    return [int][double]::Parse($text, [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-Float {
    param(
        $Value,
        [double]$Default = 0.0
    )

    $text = ([string]$Value).Trim()
    if ($text -eq "") {
        return $Default
    }
    return [double]::Parse($text, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Format-GodotFloat {
    param([double]$Value)

    $text = $Value.ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
    if (-not $text.Contains(".")) {
        $text += ".0"
    }
    return $text
}

function Get-CellOrEmpty {
    param(
        [object[]]$Row,
        [int]$Index
    )

    if ($Index -lt $Row.Count) {
        return $Row[$Index]
    }
    return ""
}

function Parse-IntList {
    param($Value)

    $text = ([string]$Value).Trim()
    $result = @()
    if ($text -eq "") {
        return $result
    }

    foreach ($part in ($text -split $ListSplitPattern)) {
        $item = $part.Trim()
        if ($item -ne "") {
            $result += (ConvertTo-Int $item 0)
        }
    }
    return $result
}

function Parse-WaypointWaits {
    param(
        $Value,
        [object[]]$Waypoints
    )

    $text = ([string]$Value).Trim()
    $waits = [ordered]@{}
    if ($text -eq "") {
        return $waits
    }

    $parts = @()
    foreach ($part in ($text -split $WaitSplitPattern)) {
        $item = $part.Trim()
        if ($item -ne "") {
            $parts += $item
        }
    }

    $hasExplicitKey = $false
    foreach ($part in $parts) {
        if ($part -match $ColonPattern) {
            $hasExplicitKey = $true
        }
    }

    if ($hasExplicitKey) {
        foreach ($part in $parts) {
            $pieces = $part -split $ColonPattern, 2
            if ($pieces.Count -ne 2) {
                continue
            }

            $key = ConvertTo-Int $pieces[0] 0
            $duration = ConvertTo-Float $pieces[1] 0.0
            if ($key -gt 0 -and $duration -gt 0.0) {
                $waits[[string]$key] = $duration
            }
        }
        return $waits
    }

    return $waits
}

function Parse-WaypointWaitDurations {
    param(
        $Value,
        [object[]]$Waypoints
    )

    $text = ([string]$Value).Trim()
    $durations = @()
    if ($text -eq "" -or $Waypoints.Count -eq 0) {
        return $durations
    }

    $parts = @()
    foreach ($part in ($text -split $WaitSplitPattern)) {
        $item = $part.Trim()
        if ($item -ne "") {
            $parts += $item
        }
    }

    foreach ($part in $parts) {
        if ($part -match $ColonPattern) {
            return $durations
        }
    }

    for ($index = 0; $index -lt $parts.Count -and $index -lt $Waypoints.Count; $index++) {
        $durations += (ConvertTo-Float $parts[$index] 0.0)
    }
    return $durations
}

function Parse-TeleportPairs {
    param($Value)

    $text = ([string]$Value).Trim()
    $pairs = @()
    if ($text -eq "") {
        return $pairs
    }

    foreach ($part in ($text -split $WaitSplitPattern)) {
        $item = $part.Trim()
        if ($item -eq "") {
            continue
        }

        $separatorPattern = ">|-|:|$([regex]::Escape($ChineseColon))|$([regex]::Escape($TeleportToText))|$([regex]::Escape($TeleportUntilText))"
        $match = [regex]::Match($item, "^\s*(\d+)\s*(?:$separatorPattern)\s*(\d+)\s*$")
        if (-not $match.Success) {
            throw "Invalid teleport pair '$item'. Use formats like 1>2 or 1>2;3>4."
        }

        $pairs += ,[ordered]@{
            from = ConvertTo-Int $match.Groups[1].Value 0
            to = ConvertTo-Int $match.Groups[2].Value 0
        }
    }
    return $pairs
}

function Parse-TeleportWaits {
    param(
        $Value,
        [object[]]$Pairs
    )

    $text = ([string]$Value).Trim()
    $waits = @()
    if ($Pairs.Count -eq 0) {
        return $waits
    }
    if ($text -eq "") {
        for ($index = 0; $index -lt $Pairs.Count; $index++) {
            $waits += 0.0
        }
        return $waits
    }

    $parts = @()
    foreach ($part in ($text -split $WaitSplitPattern)) {
        $item = $part.Trim()
        if ($item -ne "") {
            $parts += $item
        }
    }

    for ($index = 0; $index -lt $Pairs.Count; $index++) {
        $waitText = if ($index -lt $parts.Count) { $parts[$index] } else { $parts[0] }
        $waits += (ConvertTo-Float $waitText 0.0)
    }
    return $waits
}

function Normalize-EnemyId {
    param([string]$EnemyId)

    $normalized = $EnemyId.Trim().ToLowerInvariant()
    switch ($normalized) {
        "a" { return "1a" }
        "b" { return "1b" }
        "c" { return "1c" }
        "d" { return "1d" }
        "e" { return "1e" }
        "f" { return "1f" }
        default { return $normalized }
    }
}

function Get-StageEntries {
    param(
        [object[]]$Rows,
        [int]$ChapterNumber = 0
    )

    $stages = [ordered]@{}
    $currentStage = $null
    $inData = $false

    foreach ($rowObject in $Rows) {
        $row = @($rowObject)
        if ($row.Count -eq 0) {
            continue
        }

        $first = ([string](Get-CellOrEmpty $row 0)).Trim()
        if ($first -eq "stage") {
            $sheetStageNumber = ConvertTo-Int (Get-CellOrEmpty $row 1) 0
            $stageNumber = if ($ChapterNumber -gt 0) {
                (($ChapterNumber - 1) * 12) + $sheetStageNumber
            } else {
                $sheetStageNumber
            }
            $chapterNumber = if ($ChapterNumber -gt 0) {
                $ChapterNumber
            } else {
                [int][Math]::Floor(($stageNumber - 1) / 12) + 1
            }
            $chapterStageNumber = if ($ChapterNumber -gt 0) {
                $sheetStageNumber
            } else {
                (($stageNumber - 1) % 12) + 1
            }
            $currentStage = [string]$stageNumber
            if ($stageNumber -gt 0 -and $sheetStageNumber -gt 0 -and -not $stages.Contains($currentStage)) {
                $stages[$currentStage] = @{
                    entries = @()
                    initial_cost = 5.0
                    deployment_limit = 0
                    reward_character = ""
                    chapter = $chapterNumber
                    stage = $chapterStageNumber
                }
            }
            if ($null -ne $currentStage -and ([string](Get-CellOrEmpty $row 2)).Trim() -eq $RewardCharacterText) {
                $stages[$currentStage].reward_character = ([string](Get-CellOrEmpty $row 3)).Trim().ToLowerInvariant()
            }
            $inData = $false
            continue
        }

        if ($first -eq $InitialCostText -and $null -ne $currentStage) {
            $stages[$currentStage].initial_cost = ConvertTo-Float (Get-CellOrEmpty $row 1) 5.0
            continue
        }

        if ($first -eq $DeploymentLimitText -and $null -ne $currentStage) {
            $stages[$currentStage].deployment_limit = ConvertTo-Int (Get-CellOrEmpty $row 1) 0
            continue
        }

        if ($null -ne $currentStage -and ([string](Get-CellOrEmpty $row 2)).Trim() -eq $RewardCharacterText) {
            $stages[$currentStage].reward_character = ([string](Get-CellOrEmpty $row 3)).Trim().ToLowerInvariant()
            continue
        }

        if ($first -eq $BeginText) {
            $inData = $true
            continue
        }

        if ($first -eq $EndText) {
            $inData = $false
            $currentStage = $null
            continue
        }

        if (-not $inData -or $null -eq $currentStage -or $first -eq $WaveHeaderText -or $first.ToLowerInvariant() -eq "wave" -or $first -eq "") {
            continue
        }

        $waypoints = @(Parse-IntList (Get-CellOrEmpty $row 7))
        $teleportPairs = @(Parse-TeleportPairs (Get-CellOrEmpty $row 9))
        $entry = [ordered]@{
            wave = ConvertTo-Int (Get-CellOrEmpty $row 0) 1
            enemy = Normalize-EnemyId ([string](Get-CellOrEmpty $row 1))
            count = ConvertTo-Int (Get-CellOrEmpty $row 2) 1
            delay = ConvertTo-Float (Get-CellOrEmpty $row 3) 0.0
            interval = ConvertTo-Float (Get-CellOrEmpty $row 4) 1.0
            spawn = ConvertTo-Int (Get-CellOrEmpty $row 5) 1
            target = ConvertTo-Int (Get-CellOrEmpty $row 6) 1
            waypoints = $waypoints
            waits = Parse-WaypointWaits (Get-CellOrEmpty $row 8) $waypoints
            wait_durations = @(Parse-WaypointWaitDurations (Get-CellOrEmpty $row 8) $waypoints)
            teleport_pairs = $teleportPairs
            teleport_waits = @(Parse-TeleportWaits (Get-CellOrEmpty $row 10) $teleportPairs)
            enemy_type = ConvertTo-Int (Get-CellOrEmpty $row 11) 0
        }

        if ([string]::IsNullOrWhiteSpace($entry.enemy)) {
            throw "Stage $currentStage wave $($entry.wave) has an empty enemy id."
        }

        $stages[$currentStage].entries += ,$entry
    }

    return $stages
}

function Write-WaveResource {
    param(
        [int]$StageNumber,
        [object[]]$Entries,
        [string]$OutputPath,
        [double]$InitialCost,
        [int]$DeploymentLimit
    )

    $enemyIds = @($Entries | ForEach-Object { $_.enemy } | Sort-Object -Unique)
    $waveNumbers = @($Entries | ForEach-Object { $_.wave } | Sort-Object { [int]$_ } -Unique)
    $loadSteps = 3 + $enemyIds.Count + $Entries.Count + $waveNumbers.Count + 1

    $enemyResourceIds = @{}
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("[gd_resource type=`"Resource`" script_class=`"WaveData`" load_steps=$loadSteps format=3]") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("[ext_resource type=`"Script`" uid=`"uid://cswe4diostrxg`" path=`"res://scripts/stage/wave_data.gd`" id=`"1_wave_data`"]") | Out-Null
    $lines.Add("[ext_resource type=`"Script`" uid=`"uid://c3frjon3woy81`" path=`"res://scripts/stage/enemy_wave.gd`" id=`"2_enemy_wave`"]") | Out-Null
    $lines.Add("[ext_resource type=`"Script`" uid=`"uid://nvh1jc8rp2w0`" path=`"res://scripts/stage/enemy_spawn_entry.gd`" id=`"3_spawn_entry`"]") | Out-Null

    $nextResourceId = 4
    foreach ($enemyId in $enemyIds) {
        $enemyScene = Join-Path $ProjectRoot "scenes/units/enemies/enemy_$enemyId.tscn"
        if (-not (Test-Path -LiteralPath $enemyScene)) {
            throw "Missing enemy scene for enemy '$enemyId': $enemyScene"
        }

        $resourceId = "$($nextResourceId)_enemy_$enemyId"
        $enemyResourceIds[$enemyId] = $resourceId
        $lines.Add("[ext_resource type=`"PackedScene`" path=`"res://scenes/units/enemies/enemy_$enemyId.tscn`" id=`"$resourceId`"]") | Out-Null
        $nextResourceId += 1
    }
    $lines.Add("") | Out-Null

    $waveIds = New-Object System.Collections.Generic.List[string]
    foreach ($waveNumber in $waveNumbers) {
        $waveEntries = @($Entries | Where-Object { $_.wave -eq $waveNumber })
        $entryIds = New-Object System.Collections.Generic.List[string]

        for ($entryIndex = 0; $entryIndex -lt $waveEntries.Count; $entryIndex++) {
            $entry = $waveEntries[$entryIndex]
            $suffix = if ($waveEntries.Count -gt 1) { "_$($entryIndex + 1)" } else { "" }
            $entryId = "EnemySpawnEntry_stage$($StageNumber)_wave$($waveNumber)_$($entry.enemy)$suffix"
            $entryIds.Add($entryId) | Out-Null

            $lines.Add("[sub_resource type=`"Resource`" id=`"$entryId`"]") | Out-Null
            $lines.Add("script = ExtResource(`"3_spawn_entry`")") | Out-Null
            $lines.Add("enemy_scene = ExtResource(`"$($enemyResourceIds[$entry.enemy])`")") | Out-Null
            $lines.Add("count = $($entry.count)") | Out-Null
            if ($entry.spawn -ne 1) {
                $lines.Add("spawn_point_order = $($entry.spawn)") | Out-Null
            }
            if ($entry.target -ne 1) {
                $lines.Add("target_point_order = $($entry.target)") | Out-Null
            }
            if ($entry.enemy_type -eq 1) {
                $lines.Add("enemy_type = 1") | Out-Null
            }
            if ($entry.waypoints.Count -gt 0) {
                $lines.Add("waypoint_orders = Array[int]([$(@($entry.waypoints) -join ', ')])") | Out-Null
            }
            if ($entry.waits.Count -gt 0) {
                $waitParts = @()
                foreach ($key in $entry.waits.Keys) {
                    $waitParts += "${key}: $(Format-GodotFloat $entry.waits[$key])"
                }
                $lines.Add("waypoint_waits = {$($waitParts -join ', ')}") | Out-Null
            }
            if ($entry.wait_durations.Count -gt 0) {
                $waitParts = @()
                foreach ($wait in $entry.wait_durations) {
                    $waitParts += "$(Format-GodotFloat $wait)"
                }
                $lines.Add("waypoint_wait_durations = Array[float]([$($waitParts -join ', ')])") | Out-Null
            }
            if ($entry.teleport_pairs.Count -gt 0) {
                $pairParts = @()
                foreach ($pair in $entry.teleport_pairs) {
                    $pairParts += "Vector2i($($pair.from), $($pair.to))"
                }
                $lines.Add("teleport_pairs = Array[Vector2i]([$($pairParts -join ', ')])") | Out-Null

                $waitParts = @()
                foreach ($wait in $entry.teleport_waits) {
                    $waitParts += "$(Format-GodotFloat $wait)"
                }
                $lines.Add("teleport_waits = Array[float]([$($waitParts -join ', ')])") | Out-Null
            }
            $lines.Add("delay_before_start = $(Format-GodotFloat $entry.delay)") | Out-Null
            $lines.Add("interval = $(Format-GodotFloat $entry.interval)") | Out-Null
            $lines.Add("") | Out-Null
        }

        $waveId = "EnemyWave_stage$($StageNumber)_$waveNumber"
        $waveIds.Add($waveId) | Out-Null
        $entryRefs = @($entryIds | ForEach-Object { "SubResource(`"$_`")" }) -join ", "
        $lines.Add("[sub_resource type=`"Resource`" id=`"$waveId`"]") | Out-Null
        $lines.Add("script = ExtResource(`"2_enemy_wave`")") | Out-Null
        $lines.Add("wave_number = $waveNumber") | Out-Null
        $lines.Add("entries = Array[ExtResource(`"3_spawn_entry`")]([$entryRefs])") | Out-Null
        $lines.Add("wait_after_clear = 0.0") | Out-Null
        $lines.Add("") | Out-Null
    }

    $waveRefs = @($waveIds | ForEach-Object { "SubResource(`"$_`")" }) -join ", "
    $lines.Add("[resource]") | Out-Null
    $lines.Add("script = ExtResource(`"1_wave_data`")") | Out-Null
    $lines.Add("initial_deployment_cost = $(Format-GodotFloat $InitialCost)") | Out-Null
    $lines.Add("max_total_deployed_units = $DeploymentLimit") | Out-Null
    $lines.Add("waves = Array[ExtResource(`"2_enemy_wave`")]([$waveRefs])") | Out-Null

    [System.IO.File]::WriteAllText($OutputPath, ($lines -join "`n") + "`n", $Utf8NoBom)
}

function Get-NextSceneResourceNumber {
    param([string]$SceneText)

    $max = 0
    foreach ($match in [regex]::Matches($SceneText, 'id="(\d+)[^"]*"')) {
        $number = [int]$match.Groups[1].Value
        if ($number -gt $max) {
            $max = $number
        }
    }
    return $max + 1
}

function Ensure-StageSceneBinding {
    param(
        [int]$StageNumber,
        [string]$WaveResourcePath,
        [double]$InitialCost,
        [int]$DeploymentLimit
    )

    $chapterNumber = [int][Math]::Floor(($StageNumber - 1) / 12) + 1
    $chapterStageNumber = (($StageNumber - 1) % 12) + 1
    $scenePath = Join-Path $ProjectRoot ("scenes/stage/chapter{0:D2}/c{0:D2}_s{1:D2}.tscn" -f $chapterNumber, $chapterStageNumber)
    if (-not (Test-Path -LiteralPath $scenePath)) {
        $scenePath = Join-Path $ProjectRoot ("scenes/stage/c{0:D2}_s{1:D2}.tscn" -f $chapterNumber, $chapterStageNumber)
    }
    if (-not (Test-Path -LiteralPath $scenePath)) {
        $scenePath = Join-Path $ProjectRoot ("scenes/stage/chapter{0:D2}_stage{1:D2}.tscn" -f $chapterNumber, $chapterStageNumber)
    }
    if (-not (Test-Path -LiteralPath $scenePath)) {
        $scenePath = Join-Path $ProjectRoot "scenes/stage/stage$StageNumber.tscn"
    }
    if (-not (Test-Path -LiteralPath $scenePath)) {
        Write-Warning "Stage scene not found, skipping binding: $scenePath"
        return
    }

    $sceneText = [System.IO.File]::ReadAllText($scenePath)
    $resPath = "res://resources/waves/c$($chapterNumber.ToString('00'))_s$($chapterStageNumber.ToString('00'))_wave_data.tres"
    $escapedResPath = [regex]::Escape($resPath)
    $resourceId = $null
    $changed = $false

    $existingResourceMatch = [regex]::Match($sceneText, "\[ext_resource type=`"Resource`"[^\n]*path=`"$escapedResPath`"[^\n]*id=`"([^`"]+)`"")
    if ($existingResourceMatch.Success) {
        $resourceId = $existingResourceMatch.Groups[1].Value
    } else {
        $resourceNumber = Get-NextSceneResourceNumber $sceneText
        $resourceId = "$($resourceNumber)_c$($chapterNumber)_s$($chapterStageNumber)_wave_data"
        $resourceLine = "[ext_resource type=`"Resource`" path=`"$resPath`" id=`"$resourceId`"]"
        $firstSubResourceMatch = [regex]::Match($sceneText, "(?m)^\[sub_resource ")
        if ($firstSubResourceMatch.Success) {
            $sceneText = $sceneText.Insert($firstSubResourceMatch.Index, $resourceLine + "`n")
        } else {
            $sceneText = $sceneText -replace "(?m)^(\[gd_scene[^\n]*\]\r?\n)", "`$1$resourceLine`n"
        }
        $sceneText = [regex]::Replace($sceneText, "^\[gd_scene load_steps=(\d+) ", {
            param($match)
            return "[gd_scene load_steps=$([int]$match.Groups[1].Value + 1) "
        })
        $changed = $true
    }

    $gameBlockMatch = [regex]::Match($sceneText, "(?ms)^\[node name=`"Game`" type=`"Node2D`"\].*?(?=^\[node |\z)")
    if (-not $gameBlockMatch.Success) {
        $gameBlockMatch = [regex]::Match($sceneText, "(?ms)^\[node name=`"[^`"]+`" type=`"Node2D`"\].*?script = ExtResource\(`"[^`"]+`"\).*?(?=^\[node |\z)")
    }
    if (-not $gameBlockMatch.Success) {
        Write-Warning "Game node block not found, skipping binding: $scenePath"
    } else {
        $gameBlock = $gameBlockMatch.Value
        $replacementBlock = $gameBlock
        if ($replacementBlock -match "(?m)^wave_data = ") {
            $replacementBlock = [regex]::Replace($replacementBlock, "(?m)^wave_data = .*$", "wave_data = ExtResource(`"$resourceId`")")
        } else {
            $anchorMatch = [regex]::Match($replacementBlock, "(?m)^shovel_target_cursor_texture = .*$")
            if ($anchorMatch.Success) {
                $replacementBlock = $replacementBlock.Insert($anchorMatch.Index + $anchorMatch.Length, "`nwave_data = ExtResource(`"$resourceId`")")
            } else {
                $replacementBlock = $replacementBlock.TrimEnd() + "`nwave_data = ExtResource(`"$resourceId`")`n"
            }
        }

        $initialCostLine = "initial_deployment_cost = $(Format-GodotFloat $InitialCost)"
        if ($replacementBlock -match "(?m)^initial_deployment_cost = ") {
            $replacementBlock = [regex]::Replace($replacementBlock, "(?m)^initial_deployment_cost = .*$", $initialCostLine)
        } elseif ($replacementBlock -match "(?m)^wave_data = .*$") {
            $replacementBlock = [regex]::Replace($replacementBlock, "(?m)^(wave_data = .*)$", "`$1`n$initialCostLine")
        } else {
            $replacementBlock = $replacementBlock.TrimEnd() + "`n$initialCostLine`n"
        }

        $deploymentLimitLine = "max_total_deployed_units = $DeploymentLimit"
        if ($replacementBlock -match "(?m)^max_total_deployed_units = ") {
            $replacementBlock = [regex]::Replace($replacementBlock, "(?m)^max_total_deployed_units = .*$", $deploymentLimitLine)
        } elseif ($replacementBlock -match "(?m)^initial_deployment_cost = .*$") {
            $replacementBlock = [regex]::Replace($replacementBlock, "(?m)^(initial_deployment_cost = .*)$", "`$1`n$deploymentLimitLine")
        } else {
            $replacementBlock = $replacementBlock.TrimEnd() + "`n$deploymentLimitLine`n"
        }

        if ($replacementBlock -ne $gameBlock) {
            $sceneText = $sceneText.Remove($gameBlockMatch.Index, $gameBlockMatch.Length).Insert($gameBlockMatch.Index, $replacementBlock)
            $changed = $true
        }
    }

    if ($changed) {
        [System.IO.File]::WriteAllText($scenePath, $sceneText, $Utf8NoBom)
    }
}

$chapterSheets = @(Read-XlsxSheetsRows $WorkbookPath)
$stages = [ordered]@{}
if ($chapterSheets.Count -le 1) {
    $rows = if ($chapterSheets.Count -eq 1) { $chapterSheets[0].rows } else { @() }
    $stages = Get-StageEntries $rows
} else {
    for ($sheetIndex = 0; $sheetIndex -lt $chapterSheets.Count; $sheetIndex++) {
        $chapterStages = Get-StageEntries $chapterSheets[$sheetIndex].rows ($sheetIndex + 1)
        foreach ($stageKey in $chapterStages.Keys) {
            $stages[$stageKey] = $chapterStages[$stageKey]
        }
    }
}

if ($stages.Count -eq 0) {
    throw "No stage blocks were found in $WorkbookPath."
}

if ($OnlyChapter -gt 0 -or $OnlyStage -gt 0) {
    $filteredStages = @{}
    foreach ($stageKey in $stages.Keys) {
        $stageData = $stages[$stageKey]
        $matchesChapter = $OnlyChapter -le 0 -or [int]$stageData.chapter -eq $OnlyChapter
        $matchesStage = $OnlyStage -le 0 -or [int]$stageData.stage -eq $OnlyStage
        if ($matchesChapter -and $matchesStage) {
            $filteredStages[$stageKey] = $stageData
        }
    }
    $stages = $filteredStages
    if ($stages.Count -eq 0) {
        throw "No stage blocks matched chapter=$OnlyChapter stage=$OnlyStage in $WorkbookPath."
    }
}

$catalogPath = Join-Path $ProjectRoot "resources/stages/stage_catalog.json"
if (Test-Path -LiteralPath $catalogPath) {
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    foreach ($catalogEntry in @($catalog.stages)) {
        $catalogStageNumber = (([int]$catalogEntry.chapter - 1) * 12) + [int]$catalogEntry.stage
        $catalogStageKey = [string]$catalogStageNumber
        if ($stages.Contains($catalogStageKey)) {
            $catalogEntry.reward_character = [string]$stages[$catalogStageKey].reward_character
        }
    }
    $catalogJson = $catalog | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($catalogPath, $catalogJson + [Environment]::NewLine, $Utf8NoBom)
}

$waveDir = Join-Path $ProjectRoot "resources/waves"
New-Item -ItemType Directory -Force -Path $waveDir | Out-Null

$generated = @()
foreach ($stageKey in $stages.Keys) {
    $stageNumber = [int]$stageKey
    $stageData = $stages[$stageKey]
    $entries = @($stageData.entries)
    if ($entries.Count -eq 0) {
        continue
    }

    $chapterNumber = [int]$stageData.chapter
    $chapterStageNumber = [int]$stageData.stage
    $outputPath = Join-Path $waveDir ("c{0:D2}_s{1:D2}_wave_data.tres" -f $chapterNumber, $chapterStageNumber)
    Write-WaveResource $stageNumber $entries $outputPath ([double]$stageData.initial_cost) ([int]$stageData.deployment_limit)
    $generated += $outputPath

    if (-not $SkipSceneBinding) {
        Ensure-StageSceneBinding $stageNumber $outputPath ([double]$stageData.initial_cost) ([int]$stageData.deployment_limit)
    }
}

Write-Host "Synced guanqia data from: $WorkbookPath"
foreach ($path in $generated) {
    Write-Host "  $path"
}
