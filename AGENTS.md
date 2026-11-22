# Repository Guidelines

## Project Structure

Project TOWER is a ten-floor, top-down action roguelite built with Godot 4.7.2 and GDScript. The entry scene is `scenes/main.tscn`. It loads F1–F10 in the order declared by `Main.floors`. The independent title screen is `scenes/ui/title_screen.tscn`.

- `scripts/run_controller.gd` coordinates run phases, floor transitions, and checkpoints. `scripts/floor_manager.gd` runs waves. `scripts/run_save.gd` and `scripts/run_codex.gd` own the separate run and discovery formats.
- `scripts/arena_layout.gd` defines the shared hex boundary, cover, and pathfinding. `data/floor_topology.gd` defines distinct cover formations. `scripts/floor_features.gd` owns pots, arrow plates, and floor landmarks.
- `scripts/game_ui.gd`, `scripts/inventory_panel.gd`, and `scripts/settings_panel.gd` build the HUD, four inventory tabs, and menus. `localization/game.csv` owns the six-column Simplified Chinese and US English text table. Keep the two imported `.translation` resources with it.
- `assets/edition/` contains the game art. `docs/asset-handoff.md` records asset sources, dimensions, attachment points, and audio cues. `docs/GDD.md`, `docs/architecture.md`, and `docs/worldbuilding.md` document design, technical contracts, and story.

Keep Godot's relevant `.uid` and `.import` files with their source files. Git ignores `.godot/`, `android/`, `builds/`, and the machine-specific `.codex/config.toml`.

## Gameplay and Data Contracts

- Edit the **参数** and **楼层** sheets in `data/design/Project-TOWER-设定表.xlsx` to change workbook-managed combat, item, world, or floor settings. Run `tools/export_settings.py` to regenerate `data/edition_settings.gd` and `data/floors/floor_*.tres`. Commit the workbook and generated changes together. Keep entity IDs and parameter units stable.
- F1–F9 each unlock stairs and one blood bead after all waves are cleared. F10 keeps the player in control after the lord dies and completes the run when the player enters the exit. Use the shared layout for movement, cover, projectile obstruction, placement, and navigation.
- Calculate displayed and actual stats from the same equipment and corruption data. A mid-wave save must restore the wave opening. Free exploration must preserve completed actions. Keep the codex and settings independent of run rollback. See the save contract in `docs/architecture.md`.
- Use stable localization IDs, document matching placeholders in both locales, and return changed text to `draft` for bilingual review. Check both languages when changing UI layout.
- Keep attack timing and collision in gameplay code. Drive art, telegraphs, and sound from the same state or event. Record the resource slot, trigger, specification, and source in the asset handoff when adding assets.

## Development and Verification

Run these commands from the repository root. On macOS use `/Applications/Godot.app/Contents/MacOS/Godot` if `godot` is missing from PATH.

```sh
godot --editor --path .
godot --headless --path . --import
godot --headless --path . --script res://tests/test_mvp.gd -- --candidate
godot --headless --path . --script res://tests/test_settings.gd
python3 tools/export_settings.py data/design/Project-TOWER-设定表.xlsx --check
```

Run the relevant suites after changes. Use the main scene to verify affected input, UI, audiovisual feedback, and bilingual flows. Test title and in-game layouts at 1152 × 648 and 960 × 540 when changing interface layout.

Use the Windows x86_64 and macOS universal presets in `export_presets.cfg` with matching Godot export templates. Record the source commit, package hashes, device checks, and playtest limitations in the local QA record in the sibling `Project-TOWER-OnlineDocsCandidates` directory and the [team QA workbook](https://docs.qq.com/sheet/DT2piZmt4T3VIbUFZ?tab=fmlbif). Scripted progression and physical-device playtests are separate checks. Use the [team document index](https://docs.qq.com/sheet/DT2t0WEdBd3RGcFFz?tab=BB08J2) for production and delivery materials.

## Coding and Licensing

Use UTF-8 and LF line endings. Indent GDScript with tabs. Use `snake_case` for files, variables, and functions, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants. Keep unrelated changes to `addons/godot_ai/` out of project patches.

The root `LICENSE` covers original project material that the contributors can license. Preserve third-party notices, including Noto Sans SC's OFL and the Godot AI addon's own MIT license. Record provenance and any additional license terms for new assets and dependencies.

## Commits and Pull Requests

Use concise imperative commit subjects. Describe behavior changes and checks in pull requests, link related issues, and include images or recordings for visible changes. Call out render and physics setting changes.
