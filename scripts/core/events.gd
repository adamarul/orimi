extends Node
## Autoload "Events": the global signal bus. Owner: lead (OKAA-1).
## Threads connect to and emit these signals; nobody but the lead edits this file.
## See docs/CONTRACTS.md for who emits what.

# --- Brush ---------------------------------------------------------------
signal brush_opened
signal brush_closed
## A recognised glyph was cast. glyph is &"bloom", &"slash" or &"gust".
## info keys are listed in docs/CONTRACTS.md ("Glyph info").
signal glyph_cast(glyph: StringName, info: Dictionary)
## A stroke was drawn but not recognised, or there was not enough ink.
## info has "reason" (&"unrecognised", &"no_ink", &"too_short") and "screen_points".
signal glyph_failed(info: Dictionary)
signal ink_changed(current: float, maximum: float)

# --- Player --------------------------------------------------------------
## A melee swing started. origin is the player's global transform at that moment.
signal player_attacked(attack: StringName, origin: Transform3D)
signal player_damaged(hp: int, max_hp: int)
signal player_healed(hp: int, max_hp: int)
signal player_died
signal player_respawned(at: Vector3)

# --- Enemies and brush targets --------------------------------------------
signal enemy_hit(enemy: Node3D, damage: float, at: Vector3)
## kind is &"splotchet" or &"reedwraith". Emitted once, when the dissolve starts.
signal enemy_died(enemy: Node3D, kind: StringName, at: Vector3)
## A Reedwraith lost its soot veil to a gust.
signal enemy_unveiled(enemy: Node3D)
## A thorn gate was cut by a slash.
signal thorns_cut(target: Node3D, at: Vector3)
## A soot bank was blown away by a gust.
signal soot_cleared(target: Node3D, at: Vector3)

# --- Zones and flow -------------------------------------------------------
signal zone_entered(zone_id: StringName)
signal zone_exited(zone_id: StringName)
## Bloom landed on a zone's sapling after its enemies were cleared.
signal zone_restore_started(zone_id: StringName, center: Vector3, radius: float)
signal zone_restored(zone_id: StringName)
## Bloom landed on the great tree. The restoration sequence begins.
signal finale_started(center: Vector3)
## The whole valley is restored. The slice is won.
signal valley_restored
## A level's bead was added to Orimi's cord (finish_level, first completion only).
signal bead_awarded(level_id: StringName, color: Color)
## Orimi was put back or pushed out: cause &"water" (DeepWater; at is on the water surface where
## she went in) or &"curse" (CursedGround; at is where she was hurt).
signal player_thrown_back(at: Vector3, cause: StringName)
## state is one of Game.STATE_* (&"title", &"playing", &"cutscene", &"paused", &"ended").
signal game_state_changed(state: StringName)
