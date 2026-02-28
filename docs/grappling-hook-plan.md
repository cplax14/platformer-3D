# Grappling Hook Feature — Implementation Plan

## Context

The game currently has 2 worlds with 3 levels + 1 boss each. Abilities unlock via boss stars: World 1 boss unlocks wall_run + wall_slide, World 2 boss unlocks dash. We're adding a **grappling hook** ability that unlocks from the World 2 boss (dash moves to World 1 boss unlock). This ability lets players auto-target nearby anchor points, fire a grapple, get pulled toward the anchor, and release mid-flight with preserved momentum. Level 3 (World 3) will be the showcase level with vertical climbs, moving anchor puzzles, and combat+traversal combos.

## Design Decisions

- **Targeting**: Auto-target nearest visible anchor within range (visual indicator on targeted anchor)
- **Input**: New dedicated `grapple` action — **F key** / **RB (right bumper)** on gamepad
- **Unlock**: Permanent unlock from World 2 boss (dash moves to World 1 boss alongside wall_run/wall_slide)
- **Release**: Press **jump** at any point during pull to disengage, keeping current momentum + gravity resumes

## Grapple Mechanics

- **Detection range**: 15.0 units (configurable `@export`)
- **Pull speed**: 18.0 m/s toward anchor (configurable)
- **Arrival threshold**: 1.5 units from anchor = auto-disengage with small upward boost
- **Momentum on release**: Player keeps velocity direction/magnitude at moment of release, gravity resumes
- **State conflicts**: Cancels ground pound, wall run, wall slide, dash, slide, spin attack on entry. Blocked by spin attack.
- **Visual rope**: Procedural line from player hand to anchor (ImmediateMesh or Line2D projected, or simple cylinder chain)

---

## Implementation Phases

### Phase 1: Input & Ability Unlock Refactor

**Files to modify:**
- `project.godot` — Add `grapple` input action (F key + RB button)
- `src/systems/game_manager.gd` — Add `"grapple"` to `unlocked_abilities`, move dash to W1 boss
- `src/systems/save_manager.gd` — Add `"grapple"` to `_default_data.unlocked_abilities`

**Changes:**
1. Add `grapple` input mapping: F key (physical_keycode 70) + Joypad button 5 (RB)
2. In `game_manager.gd`:
   - Add `"grapple": false` to `unlocked_abilities` dict (line 35) and `reset_game()` (line 91)
   - In `refresh_abilities()`: W1 boss unlocks wall_run + wall_slide + **dash**; W2 boss unlocks **grapple**
3. In `save_manager.gd`: Add `"grapple": false` to `_default_data` abilities dict

### Phase 2: Grapple Anchor Object

**New file:** `src/objects/interactables/grapple_anchor.gd`
**New file:** `src/objects/interactables/grapple_anchor.tscn`

A `StaticBody3D` (or `Area3D`) placed in levels as grapple target points.

**Properties:**
- `@export var is_moving: bool = false` — static vs moving anchor
- `@export var move_path: Path3D` — optional path for moving anchors
- `@export var move_speed: float = 3.0` — speed along path
- Visual: Glowing diamond/orb mesh (toon-shaded), bobs gently, pulses when targeted
- Collision: Area3D on Collectibles layer for detection
- Group: `"grapple_anchor"` for easy querying

**Visual States:**
- **Idle**: Gentle bob + slow rotation, dim glow
- **Targeted**: Brighter glow + scale pulse, connection indicator particles
- **Active (being grappled to)**: Bright steady glow

### Phase 3: Player Grapple State

**File to modify:** `src/characters/player/player.gd`

**New state:** Add `GRAPPLING` to the `State` enum

**New exports:**
```gdscript
@export var grapple_range: float = 15.0
@export var grapple_pull_speed: float = 18.0
@export var grapple_arrive_distance: float = 1.5
@export var grapple_release_boost: float = 3.0  # Small upward boost on arrival
```

**New state variables:**
```gdscript
var _is_grappling: bool = false
var _grapple_target: Node3D = null  # The anchor being grappled to
var _grapple_target_position: Vector3 = Vector3.ZERO
var _nearest_anchor: Node3D = null  # Currently targeted (for UI)
```

**New methods:**
- `_handle_grapple(delta)` — called in `_physics_process`, handles:
  1. **Targeting**: Every frame, find nearest visible anchor within `grapple_range` using `get_tree().get_nodes_in_group("grapple_anchor")` + distance check + optional raycast for line-of-sight
  2. **Activation**: Press `grapple` when `_nearest_anchor != null` and ability unlocked
  3. **During pull**: Move toward `_grapple_target.global_position` at `grapple_pull_speed`. Override gravity. Cancel horizontal input.
  4. **Release via jump**: Press jump → disengage, keep velocity, gravity resumes, grant double jump reset
  5. **Arrival**: Distance < `grapple_arrive_distance` → auto-disengage with small upward boost
- `_start_grapple()` — cancel conflicting states, set velocity toward target, VFX
- `_end_grapple(release_type)` — cleanup, VFX, sound. Types: "jump_release", "arrival", "damage"
- `_find_nearest_anchor()` — returns closest anchor in range with line-of-sight

**Integration points in existing code:**
- `_physics_process()`: Add `_handle_grapple(delta)` call after `_handle_dash`
- `_apply_gravity()`: Skip gravity when `_is_grappling` (like wall_run/dash)
- `_apply_movement()`: Skip horizontal input when `_is_grappling`
- `_update_state()`: Add `GRAPPLING` state check
- `take_damage()`: Cancel grapple on damage (like other states)
- `_animate_robot()`: Add `GRAPPLING` animation (one arm extended forward, legs tucked back — flying pose)

### Phase 4: Visual Rope / Tether

**Approach:** Use `ImmediateMesh` rendered as a line strip from player's hand position to anchor position, updated every frame during grapple.

**Implementation in `player.gd`:**
- Create `MeshInstance3D` with `ImmediateMesh` on grapple start
- Each frame: Clear surfaces, draw line from `_robot_arm_r.global_position` to `_grapple_target.global_position`
- Use emissive material (cyan/electric blue glow) for the rope
- Optional: Add slight sag/curve via bezier midpoint for visual flair
- Destroy mesh on grapple end

### Phase 5: VFX & SFX

**File to modify:** `src/systems/vfx/particles.gd`

New particle functions:
- `spawn_grapple_launch(pos, direction)` — burst of particles at player when grapple fires
- `spawn_grapple_trail(pos, direction)` — continuous trail particles along rope during pull
- `spawn_grapple_arrive(pos)` — impact burst when arriving at anchor
- `spawn_grapple_release(pos)` — momentum burst when jump-releasing mid-grapple
- `spawn_anchor_targeted(pos)` — subtle sparkle on targeted anchor

**File to modify:** `src/systems/sound_library.gd`

New sounds:
- `grapple_fire` — ascending chirp + metallic click (zipline launch feel)
- `grapple_pull` — filtered noise sweep (wind/zip sound, slightly longer)
- `grapple_release` — short burst chirp (like a snapping cable)
- `grapple_arrive` — impact thud + ding

### Phase 6: Grapple Anchor Visual Indicator (HUD)

**File to modify:** `src/characters/player/player.gd` (or new helper)

When `_nearest_anchor != null` and not grappling:
- Draw a targeting reticle/indicator at the anchor's screen position
- Use a simple `Sprite3D` or `MeshInstance3D` (diamond shape) that faces the camera, attached to the anchor
- Pulse animation when in range
- The anchor itself handles its "targeted" visual state via a method call from player

### Phase 7: Level 3-1 (World 3, Level 1) — Grapple Showcase

**New files:**
- `src/levels/world_3/level_3_1.tscn`

**Level Sections (5-6 sections):**

1. **Section 1 — Grapple Tutorial**
   - Flat ground with a single static anchor above and ahead
   - Coin trail leading to the anchor → teaches player to look up and grapple
   - Second anchor slightly higher → chain grapple practice
   - Safe landing platform after each

2. **Section 2 — Vertical Climb**
   - Tall vertical shaft with 4-5 anchors in a zigzag pattern
   - Must grapple anchor-to-anchor upward
   - Coins along the path reward good trajectories
   - Checkpoint at the top
   - **Star 1**: Hidden on a side platform only reachable by releasing mid-grapple with momentum to the side

3. **Section 3 — Gap Crossing with Momentum**
   - Wide gap (too far to jump/dash)
   - Anchor positioned above the midpoint of the gap
   - Must grapple to anchor, release at peak horizontal speed to clear the gap
   - Introduces the "grapple-and-release" momentum technique
   - Enemies (slimes) on the landing platform

4. **Section 4 — Moving Anchor Puzzle**
   - Anchors that move along paths (like moving platforms)
   - Must time grapple to catch a moving anchor
   - Moving anchor carries you across a hazard zone (lava/spikes below)
   - Release when over safe ground
   - Checkpoint after this section

5. **Section 5 — Combat Arena**
   - Elevated platforms at different heights with enemies
   - Multiple static anchors connecting the platforms
   - Must grapple between platforms to reach enemies
   - Ground pound combo: grapple up, release, ground pound onto enemies below
   - Breakable crates hiding coins

6. **Section 6 — Grand Finale**
   - Combines all techniques: vertical climb → moving anchor → momentum gap → enemies
   - Final approach to LevelEnd
   - **Star 2**: Hidden behind the goal area, requires grappling to a sneaky anchor behind/above the end platform

**Environment:**
- World 3 theme: "Sky Fortress" — floating platforms in the sky, metallic/tech aesthetic
- Sky: Bright blue with white clouds (ProceduralSkyMaterial)
- Platforms: Metal-grey CSGBox3D with blue accent edges
- Fall depth: -40.0 (high altitude feel)

---

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| `project.godot` | Edit | Add `grapple` input action |
| `src/systems/game_manager.gd` | Edit | Add grapple ability, move dash to W1 boss |
| `src/systems/save_manager.gd` | Edit | Add grapple to default save data |
| `src/characters/player/player.gd` | Edit | Add GRAPPLING state, targeting, pull mechanics, rope visual, animation |
| `src/systems/vfx/particles.gd` | Edit | Add grapple particle effects |
| `src/systems/sound_library.gd` | Edit | Add grapple sound effects |
| `src/objects/interactables/grapple_anchor.gd` | Create | Anchor point script |
| `src/objects/interactables/grapple_anchor.tscn` | Create | Anchor point scene |
| `src/levels/world_3/level_3_1.tscn` | Create | Level 3-1 scene |

---

## Verification

1. **Unit test the unlock flow**: Beat W1 boss → verify dash unlocks. Beat W2 boss → verify grapple unlocks.
2. **Manual playtest in-engine**:
   - Place test anchors in an existing level, verify targeting indicator appears
   - Press F → verify pull toward anchor at correct speed
   - Press Space mid-pull → verify momentum preservation + gravity resumes
   - Arrive at anchor → verify auto-disengage + small upward boost
   - Take damage while grappling → verify grapple cancels
   - Verify rope renders correctly and disappears on release
3. **Level 3-1 playtest**: Walk through all 6 sections, verify progression is learnable and fun
4. **Build verification**: `godot --headless --check-only` or run from editor to confirm no errors
