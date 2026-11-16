class_name Layers
extends RefCounted
## Physics layer bits and canvas layer indices. Owner: lead (OKAA-1).
## The physics layer names are also set in project.godot.

# Physics layers (bit values for collision_layer / collision_mask)
const WORLD := 1 << 0         # layer 1: static terrain and solid props
const PLAYER := 1 << 1        # layer 2: the player body
const ENEMY := 1 << 2         # layer 3: enemy bodies
const BRUSH_TARGET := 1 << 3  # layer 4: things a glyph can act on (saplings, thorns, soot, the tree)
const TRIGGER := 1 << 4       # layer 5: zone and trigger areas
const PLAYER_HIT := 1 << 5    # layer 6: the player's attack hitboxes
const ENEMY_HIT := 1 << 6     # layer 7: enemy attack hitboxes

## What a brush ray may hit.
const BRUSH_RAY_MASK := WORLD | ENEMY | BRUSH_TARGET

# Canvas layers
const CANVAS_POST := 5
const CANVAS_HUD := 20
const CANVAS_BRUSH := 30
const CANVAS_MENU := 40
const CANVAS_FADE := 50

# Groups
const GROUP_PLAYER := &"player"
const GROUP_ENEMY := &"enemy"
const GROUP_BRUSH_TARGET := &"brush_target"
const GROUP_CURSED_ZONE := &"cursed_zone"
