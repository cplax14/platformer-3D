# 3D Platformer Game Plan

## Overview

- **Engine**: Godot 4.x (GDScript)
- **Genre**: 3D platformer with light combat
- **Audience**: Boys ages 6-10
- **Core loop**: Jump, run, collect, fight simple enemies, beat levels
- **Tone**: Colorful, fun, forgiving

## Audience Considerations (Ages 6-10)

- Simple controls: Jump, move, one attack button — no complex combos
- Forgiving difficulty: Generous checkpoints, health pickups, no permadeath
- Visual feedback: Big particle effects, screen shake, juice on every action
- Clear objectives: Obvious paths, collectibles that guide the player
- Short levels: 2-5 minute levels to match attention span
- Rewarding: Stars/coins/collectibles with satisfying sounds and animations

## Project Structure

```
project.godot
src/
├── characters/
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   ├── player_animation.gd
│   │   └── player_combat.gd
│   └── enemies/
│       ├── base_enemy.tscn
│       ├── base_enemy.gd
│       ├── slime/
│       └── turret/
├── levels/
│   ├── level_base.gd
│   ├── world_1/
│   │   ├── level_1_1.tscn
│   │   ├── level_1_2.tscn
│   │   └── level_1_3.tscn
│   └── world_2/
├── ui/
│   ├── hud.tscn
│   ├── hud.gd
│   ├── main_menu.tscn
│   ├── pause_menu.tscn
│   └── level_complete.tscn
├── objects/
│   ├── collectibles/
│   │   ├── coin.tscn
│   │   ├── health_pickup.tscn
│   │   └── star.tscn
│   ├── platforms/
│   │   ├── moving_platform.tscn
│   │   ├── crumbling_platform.tscn
│   │   └── bouncy_platform.tscn
│   └── hazards/
│       ├── spikes.tscn
│       └── lava.tscn
├── systems/
│   ├── game_manager.gd
│   ├── save_manager.gd
│   ├── audio_manager.gd
│   └── camera/
│       └── follow_camera.gd
├── resources/
│   ├── player_stats.tres
│   └── enemy_data/
├── shaders/
│   └── toon_shader.gdshader
└── assets/
	├── models/
	├── textures/
	├── audio/
	│   ├── sfx/
	│   └── music/
	└── animations/
```

## Core Mechanics

### Player Movement

- Walk/Run: Left stick / WASD, with acceleration/deceleration curves
- Jump: Single press = jump, hold = higher jump (variable height)
- Double Jump: Unlocked from the start
- Ground Pound: Jump + attack in air — smashes enemies and breakable objects
- Wall Slide / Wall Jump: Optional — introduced in later levels
- Dash: Short burst of speed, small cooldown

### Combat (Light)

- Spin Attack: Single button, hits enemies in a radius
- Ground Pound: Air + attack, area damage on landing
- No health bars on enemies: 1-2 hits to defeat, satisfying pop/explosion
- Player HP: 3-5 hearts, displayed as icons on HUD
- Invincibility frames: After taking damage, generous i-frames with flashing

### Camera

- Third-person follow camera with auto-rotation
- Slight look-ahead in movement direction
- Manual camera rotation with right stick (gentle, not required)
- Camera zooms out during jumps for better spatial awareness

## Enemy Types

| Enemy | Behavior | Hits to Kill |
|-------|----------|--------------|
| Slime | Patrols back and forth | 1 |
| Spiny | Stationary, damages on touch (must ground pound) | 1 (ground pound only) |
| Turret | Shoots slow projectiles at intervals | 2 |
| Charger | Charges at player when in range | 2 |
| Boss (per world) | Pattern-based, telegraphed attacks | 5-8 |

## Level Design

- **World 1 — Grassy Plains**: Teaches jumping, collecting, basic enemies
- **World 2 — Crystal Caves**: Moving platforms, darkness/light mechanics
- **World 3 — Sky Fortress**: Wind, falling platforms, more combat
- 3 levels + 1 boss per world
- Each level has 3 stars (completion, time, collect-all) for replayability

## Implementation Phases

### Phase 1: Project Setup & Player Controller ← START HERE

- [x] Initialize Godot 4.x project with folder structure
- [ ] Create .gitignore for Godot
- [ ] Implement CharacterBody3D player with:
  - [ ] Movement (acceleration-based)
  - [ ] Variable-height jump + double jump
  - [ ] Ground pound
  - [ ] Spin attack
  - [ ] Coyote time
  - [ ] Jump buffering
- [ ] Create follow camera with smooth interpolation
- [ ] Placeholder CSG geometry for testing

### Phase 2: Core Systems (Autoloads)

- [ ] GameManager: Game state, level tracking, score, lives
- [ ] SaveManager: Save/load progress (JSON to user://)
- [ ] AudioManager: SFX pooling, music crossfade
- [ ] HUD: Hearts, coin count, star display
- [ ] Pause menu with resume/restart/quit
- [ ] Scene transitions with fade

### Phase 3: Platforming Objects

- [ ] Coins (rotate, bob, collect with particle burst)
- [ ] Health pickups
- [ ] Stars (end-of-level collectibles)
- [ ] Moving platforms (path-follow)
- [ ] Crumbling platforms (shake, then fall after delay)
- [ ] Bouncy platforms (launch player upward)
- [ ] Spikes / lava (instant damage zones)
- [ ] Checkpoints (flag/totem that activates on touch)
- [ ] Breakable crates

### Phase 4: Enemies

- [ ] Base enemy class with shared logic
- [ ] Slime: simple patrol
- [ ] Spiny: stationary hazard
- [ ] Turret: timed projectile shooting
- [ ] Charger: detection zone + charge behavior
- [ ] Death animations and player damage/knockback

### Phase 5: World 1 Level Design

- [ ] Level 1-1: Tutorial level
- [ ] Level 1-2: Moving platforms, more enemies
- [ ] Level 1-3: Combined mechanics, optional challenge paths
- [ ] Boss 1: 3 telegraphed attack patterns
- [ ] Level select screen

### Phase 6: Art & Polish

- [ ] Toon/cel shader
- [ ] Character model (low-poly, stylized)
- [ ] Environment art (modular tileset)
- [ ] Particle effects for all actions
- [ ] Screen shake
- [ ] Sound effects and music
- [ ] Squash/stretch and juice

### Phase 7: Menus & Flow

- [ ] Main menu: Play, Options, Quit
- [ ] Level select with star display
- [ ] Options: Volume sliders, control remapping
- [ ] Level complete screen
- [ ] Game over / retry screen

### Phase 8: Testing & Balancing

- [ ] Playtesting with target age group
- [ ] Difficulty tuning
- [ ] Performance profiling (target 60fps)
- [ ] Controller support verification
- [ ] Keyboard + mouse fallback

## Risks

| Level | Risk | Mitigation |
|-------|------|------------|
| HIGH | 3D art asset creation is time-intensive | Use placeholder CSG geometry first; consider asset packs |
| HIGH | Camera in 3D platformers is hard | Iterate early, use SpringArm3D, test with kids |
| MEDIUM | Scope creep | Ship World 1 first as vertical slice |
| MEDIUM | Godot 4.x 3D performance on low-end hardware | Profile early, use LOD and occlusion culling |
| LOW | GDScript performance for complex AI | Enemy AI is simple enough |

## Tech Notes

- Godot version: 4.3+ (stable, good 3D support)
- Language: GDScript
- Physics: Godot's built-in Jolt physics
- Export targets: PC first, then consider web/console later
