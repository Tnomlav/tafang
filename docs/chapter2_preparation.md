# Chapter 2 Preparation

Chapter 2 is intentionally visible as development content, not playable content.

Current policy:

- `c02_s01.tscn` through `c02_s06.tscn` remain in the project as map/layout drafts.
- Stage catalog entries are marked with `status = "development"`.
- Development stages do not unlock from Chapter 1 and cannot be entered from level select.
- Wave data for Chapter 2 should not be added until the new enemy/mechanic plan is ready.

Before turning Chapter 2 playable:

- Add `c02_s01_wave_data.tres` through the required stage wave files.
- Change corresponding catalog `status` values from `development` to `playable`.
- Add new enemy or mechanic documentation for the chapter.
- Run `tools/verify_content.ps1` and a manual first-stage playtest.

Suggested Chapter 2 direction:

- Introduce one new enemy family rather than only increasing health.
- Add one map mechanic that affects path planning, such as teleport lanes or extended waypoint waits.
- Use `2-1` as a re-onboarding stage, `2-3` as the mechanic check, and `2-6` as the first Chapter 2 boss gate.
