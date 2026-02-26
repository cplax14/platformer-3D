# Feature Roadmap

## Tier 1: Core Feel — DONE

### 1. Sound Effects (Procedural) — DONE
Procedural audio synthesis via `SoundLibrary` autoload. 17 sounds generated at runtime using PCM synthesis (sine chirps, noise bursts, filtered sweeps, arpeggios). No external audio files needed.

**Files:**
- `src/systems/sound_library.gd` (new autoload)
- SFX calls in: `player.gd`, `base_enemy.gd`, `coin.gd`, `star.gd`, `level_end.gd`, `health_pickup.gd`, `breakable_crate.gd`, `checkpoint.gd`

### 2. Air Dash — DONE
Short horizontal burst mid-air. One dash per airtime, resets on landing or wall jump. Input: Left Shift / LB (L1).

**Stats:** `dash_speed=20`, `dash_duration=0.15`, `dash_cooldown=0.4`

**Files:**
- `player.gd` — DASHING state, `_handle_dash()`, integration with gravity/movement/damage
- `particles.gd` — `spawn_dash_trail()`
- `project.godot` — `dash` input action

---

## Tier 2: Movement Depth — DONE

### 3. Wall Slide — DONE
Passive slow descent on walls + wall jump. Player touches wall while falling → slides at reduced speed, can wall jump off.

**Files:** `player.gd` — WALL_SLIDING state, `particles.gd` — reuses `spawn_wall_run_dust()`

### 4. Ground Slide — DONE
Hold crouch while running to slide under obstacles and across ground. Slide-jump for extra distance. Input: crouch (Ctrl / gamepad B).

**Files:** `player.gd` — SLIDING state, `particles.gd` — `spawn_slide_dust()`, `project.godot` — `slide` input action

---

## Tier 3: Content — DONE

### 5. World 2: Crystal Caves — DONE
6 new cave materials in MaterialLibrary (crystal, crystal_glow, dark_stone, cave_platform, crystal_bat, boss_crystal). Dark cave atmosphere with low ambient light and dim directional. 3 new SFX (bat_screech, bat_swoop, crystal_shatter). 2 new particle functions (bat_death, crystal_sparkle).

**New Enemy:** Crystal Bat — flies, hovers, detects player within 8 units, swoops, returns. 1 HP.
**New Boss:** Crystal Golem — 8 HP, 3 attacks (crystal rain, slam+shockwave, summon bats), vulnerable windows.
**4 levels:** 2-1 Crystal Descent, 2-2 The Deep, 2-3 Crystal Labyrinth, 2-Boss Crystal Golem.

**Files:**
- `src/systems/material_library.gd` — 6 cave materials
- `src/systems/sound_library.gd` — 3 new sounds
- `src/systems/vfx/particles.gd` — `spawn_bat_death()`, `spawn_crystal_sparkle()`
- `src/characters/enemies/crystal_bat/crystal_bat.gd` + `.tscn`
- `src/characters/enemies/boss/boss_2.gd` + `.tscn`
- `src/levels/world_2/level_2_1.tscn` through `level_2_boss.tscn`
- `src/levels/level_base.gd` — boss→LevelEnd auto-connection
- `src/ui/level_select.gd` — multi-world with W2 unlock
- `src/ui/level_complete.gd` — hide Next for final level

### 6. Level Design Pass — DONE
Added new sections to World 1 levels showcasing wall slide, air dash, and ground slide:

**Level 1-1:** Wall Slide Alley (two parallel walls, wall slide + wall jump to coin platform). Secret area behind breakable crate with 3 bonus coins.
**Level 1-2:** Dash Gap (wide air dash gap with coin trail). Secret area behind breakable crate on combat ground with health pickup + coins.
**Level 1-3:** Slide Tunnel (low-ceiling ground slide passage with coins). Wall Slide Descent (tall wall next to TowerLedge2 for safe descent with coin trail).

**Boss Level Completion:** Both boss levels now have LevelEnd nodes activated via `boss_died` signal (handled in `level_base.gd`).

---

## Tier 4: Polish — DONE

### 7. Player Character Model — DONE
Replaced CapsuleMesh with a procedural robot built from primitives (no external assets). Multi-part model: BoxMesh body, SphereMesh head, two SphereMesh eyes, two BoxMesh arms, two BoxMesh legs, CylinderMesh antenna with glowing SphereMesh tip. Procedural animation per state: idle bob + antenna sway, sin-based walk cycle, arms-up jumping, tucked ground pound, streamlined dash pose, wall-run fast cycle.

**Files:**
- `src/characters/player/player.gd` — `_build_robot_mesh()`, `_animate_robot()`, 10 robot part variables

### 8. Screen Transitions — DONE
Iris wipe shader (circle SDF with animated progress uniform) and fade-to-black. `SceneTransition` enhanced with `Type` enum (FADE, IRIS). All scene changes throughout the game now go through `SceneTransition.transition_to_scene()` — no more raw `change_scene_to_file` cuts.

**Files:**
- `src/shaders/iris_wipe.gdshader` (new)
- `src/ui/scene_transition.gd` — Type enum, iris + fade support
- `src/systems/game_manager.gd` — `change_level()` and `_on_player_death()` wired
- `src/ui/level_complete.gd`, `main_menu.gd`, `level_select.gd`, `pause_menu.gd`, `game_over.gd` — all wired

### 9. Trail Effects + Wall-Run Polish — DONE
3 new particle functions: `spawn_dash_speed_lines()` (elongated bright blue trailing particles), `spawn_wall_run_sparkle()` (glowing blue-white sparkles), `spawn_spin_ring()` (expanding ring during spin attack). Wall-run entry now triggers screen shake. Wall-slide gets sparkle particles. Dash shows speed lines alongside existing trail. Spin attack spawns ring particles throughout entire duration.

**Files:**
- `src/systems/vfx/particles.gd` — 3 new functions
- `src/characters/player/player.gd` — enhanced VFX calls in dash, wall run, wall slide, spin attack

### 10. Music — DONE
4 procedural looping tracks generated at runtime via PCM synthesis (same pattern as SoundLibrary): world_1 (cheerful C major pentatonic, 120 BPM), world_2 (mysterious A minor, 90 BPM, echo effect), boss (intense E minor, 140 BPM, driving percussion), menu (calm arpeggios, 100 BPM). All use `AudioStreamWAV` with `LOOP_FORWARD`. Played via `AudioManager.play_music()` crossfade system.

**Files:**
- `src/systems/music_library.gd` (new autoload)
- `src/levels/level_base.gd` — plays world/boss music on `_ready()`
- `src/ui/main_menu.gd` — plays menu music
- `project.godot` — MusicLibrary autoload registered

---

## Tier 5: Systems

### 11. Ability Unlock Progression
Wall run, air dash, wall slide unlocked per world. Store in SaveManager. Gate new abilities behind world completion.

### 12. Collectible Shop
Spend coins on cosmetic mesh colors or particle trail styles. Simple UI + SaveManager persistence.

### 13. Difficulty Assists
Toggle menu: longer coyote time, slower fall, more forgiving angles, infinite double jumps. Store preferences in SaveManager.

### 14. Time Trial Mode
Per-level timer, ghost replay (record position each frame, replay as transparent mesh). Leaderboard stored locally via SaveManager.
