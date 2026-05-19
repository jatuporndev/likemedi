# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.6 project. `project.godot` sets the main scene to `scenes/menu/main_menu.tscn` and registers network/EOS autoloads. Runtime scripts live in `scripts/`, grouped by feature: `player/`, `enemies/`, `effects/`, `game/`, `network/`, and `ui/`. Scene files live in `scenes/` with matching feature folders. Gameplay data is JSON in `config/`. Visual assets are split between `sprites/` and `assets/`; keep Godot metadata files (`*.import`, `*.uid`) with their source assets. Epic Online Services integration lives under `addons/epic-online-services-godot/`. Windows packaging helpers are in `tools/`.

## Build, Test, and Development Commands

- `godot --path .`: open/run the project from this repository root.
- `godot --headless --path . --check-only`: validate project loading in CI or before commits.
- `godot --headless --path . --export-release Windows Desktop likemedieval.exe`: export the Windows preset from `export_presets.cfg`.
- `powershell -ExecutionPolicy Bypass -File tools/package_windows.ps1`: package exported Windows files into `dist/likemedieval-windows.zip`.

Use the Godot editor for scene and resource edits so serialized `.tscn`, `.tres`, `.import`, and `.uid` files remain consistent.

## Coding Style & Naming Conventions

Use GDScript with tabs for indentation, typed variables where practical, and explicit return types (`func _ready() -> void`). Keep constants in `UPPER_SNAKE_CASE`, private fields and helpers prefixed with `_`, and file names in `snake_case.gd`. Prefer feature-local scripts and scenes over large shared files. Keep exported properties near the top of scripts, followed by `@onready` references, constants, state, and lifecycle methods.

## Testing Guidelines

There is no dedicated automated test suite yet. Before opening a PR, run the project from `scenes/menu/main_menu.tscn` and verify the affected gameplay flow manually. For networking changes, test host/client behavior with the active transport in `project.godot` (`likemedieval/network/transport`). When adding tests later, place them under `tests/` and name files after the behavior under test, for example `test_skill_deck.gd`.

## Commit & Pull Request Guidelines

Recent history uses short summaries such as `Add combat feedback updates` and `Update game UI and packaging`. Keep commits focused and describe the player-visible or tooling change. Pull requests should include a concise description, manual test notes, linked issues when applicable, and screenshots or clips for UI, animation, or visual gameplay changes. Mention any required local config such as `config/eos.local.json`.

## Security & Configuration Tips

Do not commit local EOS credentials. Use `config/eos.example.json` as the template and keep `config/eos.local.json` private. Do not commit generated exports, DLL copies, packaged builds, or `dist/` output.
