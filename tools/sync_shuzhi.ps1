param(
    [string]$Workbook = "shuzhi.xlsx",
    [string]$ProjectRoot = ""
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

$CharacterHeader = [string]([char]0x89D2) + [string]([char]0x8272)
$EnemyHeader = [string]([char]0x654C) + [string]([char]0x4EBA)
$NoChar = [string]([char]0x65E0)
$SameCellText = [string]([char]0x540C) + [string]([char]0x683C)
$GroupText = [string]([char]0x7FA4) + [string]([char]0x4F53)
$SplashText = [string]([char]0x6E85) + [string]([char]0x5C04) + [string]([char]0x4F24) + [string]([char]0x5BB3)
$SplashShortText = [string]([char]0x6E85) + [string]([char]0x5C04)
$RadiusText = [string]([char]0x534A) + [string]([char]0x5F84)
$ForText = [string]([char]0x4E3A)
$IsText = [string]([char]0x662F)
$FullWidthColonText = [string]([char]0xFF1A)
$SlowText = [string]([char]0x51CF) + [string]([char]0x901F)
$StunText = [string]([char]0x7729) + [string]([char]0x6655)
$HealBackText = [string]([char]0x56DE) + [string]([char]0x8840)
$HealSelfText = [string]([char]0x56DE) + [string]([char]0x590D) + [string]([char]0x81EA) + [string]([char]0x8EAB)
$CriticalText = [string]([char]0x66B4) + [string]([char]0x51FB)
$DamageText = [string]([char]0x4F24) + [string]([char]0x5BB3)
$ReduceText = [string]([char]0x964D) + [string]([char]0x4F4E)
$TauntText = [string]([char]0x5632) + [string]([char]0x8BBD)
$HalfHealthText = [string]([char]0x751F) + [string]([char]0x547D) + [string]([char]0x503C) + [string]([char]0x4F4E) + [string]([char]0x4E8E) + [string]([char]0x4E00) + [string]([char]0x534A) + [string]([char]0x540E)
$AttackSpeedText = [string]([char]0x653B) + [string]([char]0x51FB) + [string]([char]0x901F) + [string]([char]0x5EA6)
$MoveSpeedText = [string]([char]0x79FB) + [string]([char]0x52A8) + [string]([char]0x901F) + [string]([char]0x5EA6)
$AttackPowerText = [string]([char]0x653B) + [string]([char]0x51FB) + [string]([char]0x529B)
$FullWidthMinusText = [string]([char]0xFF0D)

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

function Read-XlsxSheets {
	param([string]$Path)

	Add-Type -AssemblyName System.IO.Compression.FileSystem
	Add-Type -AssemblyName System.IO.Compression
	$stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
	$zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
	try {
        [xml]$workbook = Read-ZipEntryText $zip "xl/workbook.xml"
        [xml]$relationships = Read-ZipEntryText $zip "xl/_rels/workbook.xml.rels"

        $relationshipMap = @{}
        foreach ($relationship in $relationships.SelectNodes("//*[local-name()='Relationship']")) {
            $relationshipMap[$relationship.Id] = $relationship.Target
        }

        $sharedStrings = @()
        $sharedStringText = Read-ZipEntryText $zip "xl/sharedStrings.xml"
        if (-not [string]::IsNullOrEmpty($sharedStringText)) {
            [xml]$sharedStringXml = $sharedStringText
            foreach ($item in $sharedStringXml.SelectNodes("//*[local-name()='si']")) {
                $parts = @($item.SelectNodes(".//*[local-name()='t']") | ForEach-Object { $_.InnerText })
                $sharedStrings += ($parts -join "")
            }
        }

		$sheets = @()
		foreach ($sheet in @($workbook.SelectNodes("//*[local-name()='sheet']"))) {
			$relationshipId = $sheet.GetAttribute("id", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
			$target = [string]$relationshipMap[$relationshipId]
			if ([string]::IsNullOrWhiteSpace($target)) {
				continue
			}
			$normalizedTarget = $target.TrimStart("/")
			$sheetPath = if ($normalizedTarget.StartsWith("xl/")) { $normalizedTarget } else { "xl/" + $normalizedTarget }

			[xml]$sheetXml = Read-ZipEntryText $zip $sheetPath
			$rows = @()
			foreach ($row in @($sheetXml.SelectNodes("//*[local-name()='sheetData']/*[local-name()='row']"))) {
				$values = @{}
				$maxColumn = 0
				foreach ($cell in @($row.SelectNodes("./*[local-name()='c']"))) {
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

			$sheets += ,@{
				name = [string]$sheet.name
				rows = $rows
			}
		}
		return $sheets
	} finally {
		$zip.Dispose()
		$stream.Dispose()
	}
}

function Read-XlsxFirstSheetRows {
	param([string]$Path)

	$sheets = Read-XlsxSheets $Path
	if ($sheets.Count -eq 0) {
		return @()
	}
	return @($sheets[0].rows)
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

function Test-IsNumber {
    param($Value)

    $text = ([string]$Value).Trim()
    if ($text -eq "") {
        return $false
    }

    $number = 0.0
    return [double]::TryParse(
        $text,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$number
    )
}

function Format-GodotFloat {
    param([double]$Value)

    $text = $Value.ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
    if (-not $text.Contains(".")) {
        $text += ".0"
    }
    return $text
}

function Escape-GodotString {
    param([string]$Value)

    return $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\n").Replace("`n", "\n")
}

function Get-ProfessionId {
    param([string]$Profession)

    switch ($Profession.Trim().ToLowerInvariant()) {
        "rogue" { return 0 }
        "warrior" { return 1 }
        "knight" { return 2 }
        "archer" { return 3 }
        "wizard" { return 4 }
        "priest" { return 5 }
        default {
            throw "Unknown profession: $Profession"
        }
    }
}

function Get-DefaultDeploymentLimit {
    param([int]$Profession)

    if ($Profession -eq 0) {
        return 4
    }
    return 2
}

function Get-CanBeBlockedValue {
    param([string]$Text)

    $trimmed = $Text.Trim().ToLowerInvariant()
    if ($trimmed -eq "0" -or $trimmed -eq "false" -or $trimmed -eq "no") {
        return 0
    }
    if ($trimmed.Contains($NoChar) -or $trimmed.Contains("cannot") -or $trimmed.Contains("unblock")) {
        return 0
    }
    return 1
}

function Get-RootNodeBlockMatch {
    param([string]$SceneText)

    $match = [regex]::Match($SceneText, "(?ms)^\[node name=`"[^`"]+`" type=`"CharacterBody2D`"\].*?(?=^\[node |\z)")
    if (-not $match.Success) {
        throw "Could not find CharacterBody2D root node block."
    }
    return $match
}

function Set-RootNodeName {
    param(
        [string]$SceneText,
        [string]$NodeName
    )

    $escapedName = Escape-GodotString $NodeName
    return [regex]::Replace($SceneText, "(?m)^\[node name=`"[^`"]+`" type=`"CharacterBody2D`"\]", "[node name=`"$escapedName`" type=`"CharacterBody2D`"]", 1)
}

function Set-SceneProperty {
    param(
        [string]$SceneText,
        [string]$PropertyName,
        [string]$PropertyValue
    )

    $blockMatch = Get-RootNodeBlockMatch $SceneText
    $block = $blockMatch.Value
    $linePattern = "(?m)^" + [regex]::Escape($PropertyName) + " = .*$"

    if ([regex]::IsMatch($block, $linePattern)) {
        $newBlock = [regex]::Replace($block, $linePattern, "$PropertyName = $PropertyValue")
    } else {
        $scriptMatch = [regex]::Match($block, "(?m)^script = .*$")
        if ($scriptMatch.Success) {
            $newBlock = $block.Insert($scriptMatch.Index + $scriptMatch.Length, "`n$PropertyName = $PropertyValue")
        } else {
            $newBlock = $block.TrimEnd() + "`n$PropertyName = $PropertyValue`n"
        }
    }

    return $SceneText.Remove($blockMatch.Index, $blockMatch.Length).Insert($blockMatch.Index, $newBlock)
}

function Get-CharacterTemplatePath {
    param([string]$CharacterId)

    $baseId = ([regex]::Match($CharacterId, "^[a-zA-Z]+")).Value.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($baseId)) {
        return ""
    }

    while ($baseId.Length -gt 0) {
        $candidate = Join-Path $ProjectRoot "scenes/units/characters/$baseId.tscn"
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
        $baseId = $baseId.Substring(0, $baseId.Length - 1)
    }
    return ""
}

function Ensure-CharacterScene {
    param([string]$CharacterId)

    $path = Join-Path $ProjectRoot "scenes/units/characters/$CharacterId.tscn"
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    $templatePath = Get-CharacterTemplatePath $CharacterId
    if ([string]::IsNullOrWhiteSpace($templatePath)) {
        throw "Missing character scene: $path"
    }

    Copy-Item -LiteralPath $templatePath -Destination $path
    return $path
}

function Get-EnemyTemplatePath {
    param([string]$EnemyId)

    $normalizedId = $EnemyId.Trim().ToLowerInvariant()
    $match = [regex]::Match($normalizedId, "^(\d+)([a-z]+)$")
    if ($match.Success) {
        $chapter = ConvertTo-Int $match.Groups[1].Value 0
        $letter = $match.Groups[2].Value
        for ($candidateChapter = $chapter - 1; $candidateChapter -ge 1; $candidateChapter--) {
            $candidate = Join-Path $ProjectRoot "scenes/units/enemies/enemy_$candidateChapter$letter.tscn"
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    $fallback = Join-Path $ProjectRoot "scenes/units/enemies/enemy_1a.tscn"
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }
    return ""
}

function Ensure-EnemyScene {
    param([string]$EnemyId)

    $path = Join-Path $ProjectRoot "scenes/units/enemies/enemy_$EnemyId.tscn"
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    $templatePath = Get-EnemyTemplatePath $EnemyId
    if ([string]::IsNullOrWhiteSpace($templatePath)) {
        throw "Missing enemy scene: $path"
    }

    Copy-Item -LiteralPath $templatePath -Destination $path
    return $path
}

function Sync-CharacterScene {
    param([hashtable]$Entry)

    $path = Ensure-CharacterScene $Entry.id

    $scene = [System.IO.File]::ReadAllText($path)
    $scene = Set-SceneProperty $scene "unit_id" "`"$(Escape-GodotString $Entry.id)`""
    $scene = Set-SceneProperty $scene "profession" ([string]$Entry.profession)
    $scene = Set-SceneProperty $scene "attack_power" ([string]$Entry.attack_power)
    $scene = Set-SceneProperty $scene "attack_speed" (Format-GodotFloat $Entry.attack_speed)
    $scene = Set-SceneProperty $scene "max_health" ([string]$Entry.max_health)
    $scene = Set-SceneProperty $scene "deploy_cost" ([string]$Entry.deploy_cost)
    $scene = Set-SceneProperty $scene "deployment_cooldown" (Format-GodotFloat $Entry.deployment_cooldown)
    $scene = Set-SceneProperty $scene "deployment_limit" ([string]$Entry.deployment_limit)
    $scene = Set-SceneProperty $scene "attack_distance_tiles" (Format-GodotFloat $Entry.attack_distance_tiles)
    $scene = Set-SceneProperty $scene "attack_target_count" ([string]$Entry.attack_target_count)
    $scene = Set-SceneProperty $scene "splash_damage_radius_tiles" (Format-GodotFloat $Entry.splash_damage_radius_tiles)
    $scene = Set-SceneProperty $scene "skill_description" "`"$(Escape-GodotString $Entry.skill_description)`""
    $scene = Set-SceneProperty $scene "active_skill_description" "`"$(Escape-GodotString $Entry.active_skill_description)`""
    $scene = Set-SceneProperty $scene "active_skill_effect" "`"$(Escape-GodotString $Entry.active_skill_effect)`""
    $scene = Set-SceneProperty $scene "upgrade_method" "`"$(Escape-GodotString $Entry.upgrade_method)`""
    $scene = Set-SceneProperty $scene "attack_heal_amount" (Format-GodotFloat $Entry.attack_heal_amount)

    $scene = Set-SceneProperty $scene "deployment_cost_growth_bonus" (Format-GodotFloat $Entry.deployment_cost_growth_bonus)
    $scene = Set-SceneProperty $scene "attack_hits_cell_enemies" ($Entry.attack_hits_cell_enemies.ToString().ToLowerInvariant())
    $scene = Set-SceneProperty $scene "attack_slow_percent" (Format-GodotFloat $Entry.attack_slow_percent)
    $scene = Set-SceneProperty $scene "attack_slow_duration" (Format-GodotFloat $Entry.attack_slow_duration)
    $scene = Set-SceneProperty $scene "attack_stun_duration" (Format-GodotFloat $Entry.attack_stun_duration)
    $scene = Set-SceneProperty $scene "critical_hit_chance" (Format-GodotFloat $Entry.critical_hit_chance)
    $scene = Set-SceneProperty $scene "critical_hit_multiplier" (Format-GodotFloat $Entry.critical_hit_multiplier)
    $scene = Set-SceneProperty $scene "incoming_damage_reduction" (Format-GodotFloat $Entry.incoming_damage_reduction)
    $scene = Set-SceneProperty $scene "incoming_damage_multiplier" (Format-GodotFloat $Entry.incoming_damage_multiplier)

    [System.IO.File]::WriteAllText($path, $scene, $Utf8NoBom)
    return $path
}

function Sync-EnemyScene {
    param([hashtable]$Entry)

    $path = Ensure-EnemyScene $Entry.id

    $scene = [System.IO.File]::ReadAllText($path)
    $scene = Set-RootNodeName $scene $Entry.id.ToUpperInvariant()
    $scene = Set-SceneProperty $scene "enemy_id" "`"$($Entry.id.ToUpperInvariant())`""
    $scene = Set-SceneProperty $scene "move_speed_tiles_per_second" (Format-GodotFloat $Entry.move_speed_tiles_per_second)
    $scene = Set-SceneProperty $scene "attack_power" ([string]$Entry.attack_power)
    $scene = Set-SceneProperty $scene "attack_speed" (Format-GodotFloat $Entry.attack_speed)
    $scene = Set-SceneProperty $scene "max_health" ([string]$Entry.max_health)
    $scene = Set-SceneProperty $scene "attack_distance_tiles" (Format-GodotFloat $Entry.attack_distance_tiles)
    $scene = Set-SceneProperty $scene "attack_target_count" ([string]$Entry.attack_target_count)
    $scene = Set-SceneProperty $scene "splash_damage_radius_tiles" (Format-GodotFloat $Entry.splash_damage_radius_tiles)
    $scene = Set-SceneProperty $scene "can_be_blocked" ([string]$Entry.can_be_blocked)
    $scene = Set-SceneProperty $scene "attack_stun_duration" (Format-GodotFloat $Entry.attack_stun_duration)
    $scene = Set-SceneProperty $scene "taunt_level" ([string]$Entry.taunt_level)
    $scene = Set-SceneProperty $scene "incoming_damage_reduction" ([string]$Entry.incoming_damage_reduction)
    $scene = Set-SceneProperty $scene "half_health_attack_speed_multiplier" (Format-GodotFloat $Entry.half_health_attack_speed_multiplier)
    $scene = Set-SceneProperty $scene "half_health_move_speed_multiplier" (Format-GodotFloat $Entry.half_health_move_speed_multiplier)
    $scene = Set-SceneProperty $scene "half_health_attack_power_bonus" ([string]$Entry.half_health_attack_power_bonus)
    $scene = Set-SceneProperty $scene "skill_description" "`"$(Escape-GodotString $Entry.skill_description)`""

    [System.IO.File]::WriteAllText($path, $scene, $Utf8NoBom)
    return $path
}

function Parse-SkillEffect {
    param(
        [string]$SkillDescription,
        [string]$SkillEffect
    )

    $text = $SkillDescription + "`n" + $SkillEffect
    $result = @{
        deployment_cost_growth_bonus = 0.0
        attack_hits_cell_enemies = $false
        splash_damage_radius_tiles = 0.0
        attack_slow_percent = 0.0
        attack_slow_duration = 0.0
        attack_stun_duration = 0.0
        attack_heal_amount = 0.0
        critical_hit_chance = 0.0
        critical_hit_multiplier = 2.0
        incoming_damage_reduction = 0.0
        incoming_damage_multiplier = 1.0
        taunt_level = 0
        half_health_attack_speed_multiplier = 1.0
        half_health_move_speed_multiplier = 1.0
        half_health_attack_power_bonus = 0
    }

    $growthMatch = [regex]::Match($text, "\+([0-9]+(?:\.[0-9]+)?)")
    if ($growthMatch.Success) {
        $result.deployment_cost_growth_bonus = [double]::Parse($growthMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($text.Contains($SameCellText) -or $text.Contains($GroupText)) {
        $result.attack_hits_cell_enemies = $true
    }

    if (($text.Contains($SplashText) -or $text.Contains($SplashShortText)) -and $text.Contains($RadiusText)) {
        $radiusConnectorPattern = "(?:" + [regex]::Escape($ForText) + "|" + [regex]::Escape($IsText) + "|=|:|" + [regex]::Escape($FullWidthColonText) + ")?"
        $radiusMatch = [regex]::Match($text, [regex]::Escape($RadiusText) + "\s*" + $radiusConnectorPattern + "\s*([0-9]+(?:\.[0-9]+)?)")
        if ($radiusMatch.Success) {
            $result.splash_damage_radius_tiles = [double]::Parse($radiusMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
    }

    if ($text.Contains($SlowText)) {
        $percentMatch = [regex]::Match($text, "([0-9]+(?:\.[0-9]+)?)%")
        if ($percentMatch.Success) {
            $result.attack_slow_percent = [double]::Parse($percentMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture) / 100.0
        }

        $durationMatch = [regex]::Match($text, "([0-9]+(?:\.[0-9]+)?)\s*" + [string]([char]0x79D2))
        if ($durationMatch.Success) {
            $result.attack_slow_duration = [double]::Parse($durationMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
    }

    if ($text.Contains($StunText)) {
        $durationMatch = [regex]::Match($text, "([0-9]+(?:\.[0-9]+)?)\s*" + [string]([char]0x79D2))
        if ($durationMatch.Success) {
            $result.attack_stun_duration = [double]::Parse($durationMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
    }

    $healMatch = [regex]::Match($text, [regex]::Escape($HealSelfText) + "\s*([0-9]+(?:\.[0-9]+)?)")
    if ($healMatch.Success) {
        $result.attack_heal_amount = [double]::Parse($healMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($result.attack_heal_amount -le 0.0 -and $text.Contains($HealBackText)) {
        $result.attack_heal_amount = 1.0
    }

    if ($text.Contains($CriticalText)) {
        $result.critical_hit_chance = 0.5
        $chanceMatch = [regex]::Match($text, "([0-9]+(?:\.[0-9]+)?)%\s*" + [regex]::Escape($CriticalText))
        if ($chanceMatch.Success) {
            $result.critical_hit_chance = [double]::Parse($chanceMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture) / 100.0
        }
        $multiplierMatch = [regex]::Match($text, [regex]::Escape($CriticalText) + ".*?([0-9]+(?:\.[0-9]+)?)\s*" + [string]([char]0x500D))
        if ($multiplierMatch.Success) {
            $result.critical_hit_multiplier = [double]::Parse($multiplierMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
    }

    $minusPattern = "(?:-|" + [regex]::Escape($FullWidthMinusText) + ")"
    $flatReductionMatch = [regex]::Match($text, [regex]::Escape($DamageText) + "\s*" + $minusPattern + "\s*([0-9]+(?:\.[0-9]+)?)")
    if ($flatReductionMatch.Success) {
        $result.incoming_damage_reduction = ConvertTo-Float ($flatReductionMatch.Groups[1].Value.Trim()) 0.0
    } elseif ($text.Contains($DamageText) -and $text.Contains($ReduceText)) {
        $result.incoming_damage_reduction = 1.0
        $flatReductionMatch = [regex]::Match($text, [regex]::Escape($ReduceText) + "\s*([0-9]+(?:\.[0-9]+)?)")
        if ($flatReductionMatch.Success) {
            $result.incoming_damage_reduction = ConvertTo-Float ($flatReductionMatch.Groups[1].Value.Trim()) 0.0
        }
        $reductionMatch = [regex]::Match($text, [regex]::Escape($ReduceText) + "\s*([0-9]+(?:\.[0-9]+)?)%")
        if ($reductionMatch.Success) {
            $reduction = [double]::Parse($reductionMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture) / 100.0
            $result.incoming_damage_reduction = 0.0
            $result.incoming_damage_multiplier = [Math]::Max(0.0, 1.0 - $reduction)
        }
    }

    $tauntMatch = [regex]::Match($text, [regex]::Escape($TauntText) + "\s*\+\s*([0-9]+)")
    if ($tauntMatch.Success) {
        $result.taunt_level = [int]$tauntMatch.Groups[1].Value
    }

    if ($text.Contains($HalfHealthText)) {
        $attackSpeedMatch = [regex]::Match($text, [regex]::Escape($AttackSpeedText) + "\s*[xX*]\s*([0-9]+(?:\.[0-9]+)?)")
        if ($attackSpeedMatch.Success) {
            $result.half_health_attack_speed_multiplier = [double]::Parse($attackSpeedMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
        $moveSpeedMatch = [regex]::Match($text, [regex]::Escape($MoveSpeedText) + "\s*[xX*]\s*([0-9]+(?:\.[0-9]+)?)")
        if ($moveSpeedMatch.Success) {
            $result.half_health_move_speed_multiplier = [double]::Parse($moveSpeedMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
        $powerMatch = [regex]::Match($text, [regex]::Escape($AttackPowerText) + "\s*\+\s*([0-9]+)")
        if ($powerMatch.Success) {
            $result.half_health_attack_power_bonus = [int]$powerMatch.Groups[1].Value
        }
    }

    return $result
}

$sheets = Read-XlsxSheets $WorkbookPath
$characters = @()
$enemies = @()

foreach ($sheetObject in $sheets) {
	$mode = ""
	foreach ($rowObject in @($sheetObject.rows)) {
		$row = @($rowObject)
		if ($row.Count -eq 0) {
			continue
		}

		$first = ([string](Get-CellOrEmpty $row 0)).Trim()
		if ($first -eq $CharacterHeader) {
			$mode = "characters"
			continue
		}
		if ($first -eq $EnemyHeader) {
			$mode = "enemies"
			continue
		}
		if ($first -eq "") {
			continue
		}

		if ($mode -eq "characters") {
			$profession = Get-ProfessionId ([string](Get-CellOrEmpty $row 1))
			$defaultDeploymentLimit = Get-DefaultDeploymentLimit $profession
			$hasDeploymentLimitColumn = Test-IsNumber (Get-CellOrEmpty $row 9)
			$deploymentLimit = if ($hasDeploymentLimitColumn) {
				ConvertTo-Int (Get-CellOrEmpty $row 9) $defaultDeploymentLimit
			} else {
				$defaultDeploymentLimit
			}
			$skillDescriptionIndex = if ($hasDeploymentLimitColumn) { 10 } else { 9 }
			$skillEffectIndex = if ($hasDeploymentLimitColumn) { 11 } else { 10 }
			$activeSkillDescriptionIndex = if ($hasDeploymentLimitColumn) { 12 } else { 11 }
			$activeSkillEffectIndex = if ($hasDeploymentLimitColumn) { 13 } else { 12 }
			$upgradeMethodIndex = if ($hasDeploymentLimitColumn) { 14 } else { 13 }
			$skillDescription = [string](Get-CellOrEmpty $row $skillDescriptionIndex)
			$skillEffect = [string](Get-CellOrEmpty $row $skillEffectIndex)
			$activeSkillDescription = [string](Get-CellOrEmpty $row $activeSkillDescriptionIndex)
			$activeSkillEffect = [string](Get-CellOrEmpty $row $activeSkillEffectIndex)
			$parsedSkill = Parse-SkillEffect $skillDescription $skillEffect
			$characters += ,@{
				id = $first.ToLowerInvariant()
				profession = $profession
				attack_power = ConvertTo-Int (Get-CellOrEmpty $row 2) 1
				attack_speed = ConvertTo-Float (Get-CellOrEmpty $row 3) 1.0
				max_health = ConvertTo-Int (Get-CellOrEmpty $row 4) 1
				deploy_cost = ConvertTo-Int (Get-CellOrEmpty $row 5) 1
				deployment_cooldown = ConvertTo-Float (Get-CellOrEmpty $row 6) 1.0
				attack_distance_tiles = ConvertTo-Float (Get-CellOrEmpty $row 7) 1.0
				attack_target_count = ConvertTo-Int (Get-CellOrEmpty $row 8) 1
				deployment_limit = $deploymentLimit
				skill_description = $skillDescription
				active_skill_description = $activeSkillDescription
				active_skill_effect = $activeSkillEffect
				upgrade_method = [string](Get-CellOrEmpty $row $upgradeMethodIndex)
                deployment_cost_growth_bonus = $parsedSkill.deployment_cost_growth_bonus
                attack_hits_cell_enemies = $parsedSkill.attack_hits_cell_enemies
                splash_damage_radius_tiles = $parsedSkill.splash_damage_radius_tiles
				attack_slow_percent = $parsedSkill.attack_slow_percent
				attack_slow_duration = $parsedSkill.attack_slow_duration
				attack_stun_duration = $parsedSkill.attack_stun_duration
				attack_heal_amount = $parsedSkill.attack_heal_amount
				critical_hit_chance = $parsedSkill.critical_hit_chance
				critical_hit_multiplier = $parsedSkill.critical_hit_multiplier
				incoming_damage_reduction = $parsedSkill.incoming_damage_reduction
				incoming_damage_multiplier = $parsedSkill.incoming_damage_multiplier
			}
		} elseif ($mode -eq "enemies") {
            $parsedSkill = Parse-SkillEffect ([string](Get-CellOrEmpty $row 8)) ""
			$enemies += ,@{
				id = $first.ToLowerInvariant()
				move_speed_tiles_per_second = ConvertTo-Float (Get-CellOrEmpty $row 1) 1.0
				attack_power = ConvertTo-Int (Get-CellOrEmpty $row 2) 1
				attack_speed = ConvertTo-Float (Get-CellOrEmpty $row 3) 1.0
				max_health = ConvertTo-Int (Get-CellOrEmpty $row 4) 1
				attack_distance_tiles = ConvertTo-Float (Get-CellOrEmpty $row 5) 0.0
                attack_target_count = ConvertTo-Int (Get-CellOrEmpty $row 6) 1
                can_be_blocked = Get-CanBeBlockedValue ([string](Get-CellOrEmpty $row 7))
                skill_description = [string](Get-CellOrEmpty $row 8)
                splash_damage_radius_tiles = $parsedSkill.splash_damage_radius_tiles
                attack_stun_duration = $parsedSkill.attack_stun_duration
                taunt_level = $parsedSkill.taunt_level
                incoming_damage_reduction = [int]$parsedSkill.incoming_damage_reduction
                half_health_attack_speed_multiplier = $parsedSkill.half_health_attack_speed_multiplier
                half_health_move_speed_multiplier = $parsedSkill.half_health_move_speed_multiplier
                half_health_attack_power_bonus = $parsedSkill.half_health_attack_power_bonus
			}
		}
	}
}

if ($characters.Count -eq 0 -and $enemies.Count -eq 0) {
    throw "No character or enemy rows were found in $WorkbookPath."
}

$changed = @()
foreach ($entry in $characters) {
    $changed += Sync-CharacterScene $entry
}
foreach ($entry in $enemies) {
    $changed += Sync-EnemyScene $entry
}

Write-Host "Synced shuzhi data from: $WorkbookPath"
foreach ($path in $changed) {
    Write-Host "  $path"
}
