# Content Pipeline

This project treats Excel files as the source for numeric and wave data.

## Excel-owned fields

`shuzhi.xlsx` owns exported combat values in character and enemy scenes. Character and enemy sections may live on separate worksheets; the sync scans all worksheets, with enemy data currently on Sheet2.

- Character: `unit_id`, `profession`, `attack_power`, `attack_speed`, `max_health`, `deploy_cost`, `deployment_cooldown`, `deployment_limit`, `attack_distance_tiles`, `attack_target_count`, `skill_description`, parsed skill effect fields.
- Enemy: `enemy_id`, `move_speed_tiles_per_second`, `attack_power`, `attack_speed`, `max_health`, `attack_distance_tiles`, `can_be_blocked`.

`guanqia.xlsx` owns wave resources:

- Stage wave entries, enemy ids, counts, delays, intervals, spawn/target orders, waypoints, waits, teleport pairs, teleport waits, enemy type.
- Stage wave config: `initial_deployment_cost`, `max_total_deployed_units`.

## Godot-owned fields

Edit these in Godot unless the pipeline is extended:

- Scene layout, tile maps, spawn/target/waypoint markers.
- Visuals, animation, collision shapes, UI layout, sounds.
- Stage catalog metadata: display name, reward character, tutorial/boss/development status.

## Sync behavior

Excel sync overwrites the Excel-owned fields above. Manual edits to those fields in `.tscn` or `.tres` files will be overwritten by the next sync.

Run:

```powershell
tools\sync_excel.ps1
```

By default this syncs both workbooks and then runs content verification. To skip verification:

```powershell
tools\sync_excel.ps1 -SkipVerify
```

Run verification only:

```powershell
tools\verify_content.ps1
```
