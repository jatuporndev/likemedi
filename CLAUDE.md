# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.6 multiplayer RPG prototype with a listen-server architecture (one player hosts, others join). Features card-based skills, enemy AI with pathfinding, dynamic map loading, and EOS P2P networking with NAT traversal.

## Commands

```bash
# Run project in editor
godot --path .

# Validate project loads (CI / pre-commit check)
godot --headless --path . --check-only

# Export Windows build
godot --headless --path . --export-release "Windows Desktop" likemedieval.exe

# Package into distributable zip
powershell -ExecutionPolicy Bypass -File tools/package_windows.ps1
```

Always use the Godot editor (not text tools) to edit `.tscn`, `.tres`, `.import`, and `.uid` files to keep serialization consistent.

**Testing:** No automated test suite. Test manually by running from `scenes/menu/main_menu.tscn`. For networking changes, test host+client with the transport set in `project.godot` (`likemedieval/network/transport`). Future tests go in `tests/` named after the behavior (e.g., `test_skill_deck.gd`).

## Architecture

### Networking Layer

```
MainMenu → NetworkManager → NetworkTransport (ENet or EOS P2P)
                ↓
          World scene loaded → GameManager spawns players/enemies
```

- `NetworkManager` (`scripts/network/network_manager.gd`) — global autoload; owns host/join/disconnect flow and Firebase auth
- `NetworkTransport` (`scripts/network/transports/`) — interface abstracting ENet vs EOS so game logic is transport-agnostic; swap via `project.godot` setting
- **Authority model:** Server is authoritative for movement, combat, and spawning. Clients send input via RPC; server validates and broadcasts state.

### Multiplayer Join Flow

1. **Host** calls `NetworkManager.host_game()` → transport creates room → world scene loads → local player spawns
2. **Client** joins via room code → RPC `request_initial_state` to server
3. **Server** syncs all players, enemies, and current map to the joining client via `spawn_player.rpc_id()`, `spawn_enemy.rpc_id()`, `_load_map_rpc.rpc_id()`

### Core Gameplay Systems

| System | Script | Role |
|--------|--------|------|
| `GameManager` | `scripts/game/game_manager.gd` | Player/enemy spawn & despawn via RPC; respawn management |
| `World` | `scripts/game/world.gd` | Loads maps dynamically; owns spawn blocks and respawn points |
| `Player` | `scripts/player/player.gd` | Authoritative local player; movement, skill casting, animation |
| `EnemyBot` | `scripts/enemies/enemy_bot.gd` | AI states: wander → aggro → attack; pathfinding avoidance |
| `SkillDeck` | `scripts/game/skill_deck.gd` | Draw/discard/shuffle pile management and hand tracking |
| `SkillCardDatabase` | `scripts/game/skill_card_database.gd` | Loads skill definitions from `config/cards.json` on demand |
| `SkillStamina` | `scripts/game/skill_stamina.gd` | Stamina pool (max 6); recharges on a 4-second cycle |
| `MapTransition` | `scripts/game/map_transition.gd` | Warp gates; updates player respawn location on map change |
| `HUD` | `scripts/ui/hud.gd` | Chat, skill hand, health/stamina bars, minimap, deck builder |

### Config-Driven Data

All gameplay tuning is in `config/` JSON — no magic numbers in scripts:

- `cards.json` — skill definitions (title, type, cost, damage, range, cast_time)
- `enemies.json` — enemy templates (`e1` melee, `e2` ranged fireball caster; speed, health, AI ranges)
- `maps.json` — which enemies spawn on which map and respawn timing
- `player_decks.json` / `player_collection.json` — saved player deck state

### EOS P2P Integration

`addons/epic-online-services-godot/` provides `EOSGMultiplayerPeer`, `HPlatform`, `HAuth`, `HLobbies`, `HP2P` (registered as autoloads in `project.godot`). Requires `config/eos.local.json` (git-ignored — use `config/eos.example.json` as template). Do not commit this file.

## Coding Style

- GDScript with **tabs** for indentation
- Typed variables and explicit return types: `func _ready() -> void`
- `UPPER_SNAKE_CASE` constants, `_underscore_prefix` for private methods/fields, `snake_case.gd` filenames
- Script layout order: exported properties → `@onready` refs → constants → state → lifecycle methods
- RPC patterns: `@rpc("authority", "call_local")` for server-owned state; `@rpc("any_peer", "reliable")` for client requests

## Map Creation

See `MAP_DRAWING.md` for the full step-by-step guide on creating Ragnarok-style maps, including tilemap setup, collision layers, warp gate placement, and enemy spawn block configuration.
