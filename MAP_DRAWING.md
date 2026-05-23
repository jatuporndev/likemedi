# Drawing Ragnarok-Style Maps In Godot

This project is set up like a Ragnarok-style map flow:

- `scenes/world/world.tscn` is the game container. It keeps the player, HUD, enemies, and `MapRoot`.
- `scenes/world/maps/map_1.tscn` is Map 1.
- `scenes/world/maps/map_2.tscn` is Map 2.
- Each map has an edge warp. Walking into the edge warp unloads the current map file and loads the next map file.

The latest loaded map that contains `PlayerSpawnPoint` becomes the revive map. When the player dies and clicks `Revive`, the player respawns on that crystal's `SpawnAnchor`. If a later map should become the new revive point, add a `PlayerSpawnPoint` with a `SpawnAnchor` to that map.

## Paint A Map With Your Tiles

1. Open `scenes/world/maps/map_1.tscn` or `scenes/world/maps/map_2.tscn` in Godot.
2. Select `sprites/world/Floors_Tiles.png` in the FileSystem dock.
3. In Import, use:
	- Filter: `Nearest`
	- Mipmaps: `Off`
	- Repeat: `Disabled`
4. Click `Reimport`.
5. Add a child to the map root: `TileMapLayer`.
6. In Inspector, create a new `TileSet`.
7. Click the new `TileSet`, then open the `TileSet` editor at the bottom.
8. Add `sprites/world/Floors_Tiles.png` as an atlas source.
9. Set the tile size to match the image. For the current sheet, start with `80 x 80` if the file is `400 x 400`.
10. Click each tile in the atlas to create selectable tiles.
11. Go back to the `TileMapLayer`, open the `TileMap` editor, click a tile, then paint directly in the viewport.

Use one `TileMapLayer` per purpose:

- `Ground`: grass, dirt, stone, water.
- `Details`: edges, flowers, shadows, road decorations.
- `Blocked`: walls, cliffs, water collision.

## Add Collision To Blocked Tiles

1. Select the `TileSet`.
2. Add a Physics Layer.
3. In the TileSet atlas, select a tile that should block the player.
4. Draw the collision polygon/rectangle for that tile.
5. Paint blocked tiles on the `Blocked` layer.

The player already uses `CharacterBody2D`, so it will collide with tile physics when the TileMapLayer collision is set up.

## Map-To-Map Walking Gates

The current map scenes have these important nodes:

- `map_1.tscn` has `WarpToMap2` on the right edge.
- `map_1.tscn` has `SpawnFromMap2`, where the player appears after coming back from Map 2. This marker is placed on the connected warp.
- `map_2.tscn` has `WarpToMap1` on the left edge.
- `map_2.tscn` has `SpawnFromMap1`, where the player appears after coming from Map 1. This marker is placed on the connected warp.

To make more gates:

1. Add `Area2D`.
2. Add a `CollisionShape2D` rectangle under it.
3. Attach `res://scripts/game/map_transition.gd`.
4. Add a `Marker2D` where the player should appear.
5. Set `target_map_scene` on the `Area2D` to the next map file.
6. Set `target_spawn_name` to the exact name of the target map's `Marker2D`.
7. Set `display_name` to the map label players should see above the warp.

Example:

- In `map_1.tscn`, `WarpToMap2.target_map_scene` is `res://scenes/world/maps/map_2.tscn`.
- In `map_1.tscn`, `WarpToMap2.target_spawn_name` is `SpawnFromMap1`.

The warp draws a visible colored rectangle, arrow, and label at runtime. After a transition, the player is placed on the target warp and briefly locked from warping again so they do not bounce back instantly.

## Map Enemy Config

Map enemies are configured in `config/maps.json`. The map scene path is the key, and each map has an `enemies` array.

Example:

```json
{
  "res://scenes/world/maps/map_1.tscn": {
    "enemies": [
      {
        "enemy_id": "e1",
        "count": 2,
        "respawn_seconds": 30
      }
    ]
  }
}
```

Fields:

- `enemy_id`: enemy type from `config/enemies.json`.
- `count`: how many of that enemy should exist on this map.
- `respawn_seconds`: seconds to wait before replacing a dead enemy.

Enemies spawn randomly inside the loaded map's `Ground` rectangle. If the random point overlaps a physics body or area, the spawner tries another point. This means blocked TileMap collision can be used to keep enemies off walls, water, cliffs, and warp points.
