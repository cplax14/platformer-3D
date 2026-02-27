# Platformer 3D

A colorful 3D platformer with light combat built in Godot 4.6 (Forward+). Designed to be kid-friendly with a procedurally animated robot character, toon-shaded visuals, and accessible difficulty options.

## Gameplay

Play as a small robot navigating platforming challenges across two themed worlds. Collect coins, find hidden stars, defeat enemies, and beat bosses to unlock new abilities.

### Controls

| Action | Input |
|--------|-------|
| Move | WASD / Left Stick |
| Jump | Space / A Button |
| Attack (ground) | Spin attack |
| Attack (air) | Ground pound |
| Dash (air) | Air dash (unlockable) |
| Slide | Crouch while moving |
| Pause | Escape |

### Core Abilities (always available)

- **Jump** with variable height (hold for higher, release for shorter)
- **Double Jump** for extra air time
- **Coyote Time** and **Jump Buffering** for forgiving platforming
- **Ground Pound** — slam down from the air, bounce on landing
- **Spin Attack** — melee attack on the ground with cooldown
- **Ground Slide** — slide under obstacles, can slide-jump for momentum

### Unlockable Abilities

Earned by defeating bosses:

| Ability | Unlock Condition |
|---------|-----------------|
| Wall Slide | Beat World 1 Boss |
| Wall Run | Beat World 1 Boss |
| Air Dash | Beat World 2 Boss |

### Worlds

- **World 1 — Green Hills**: 3 levels + Boss (King Slime). Grassy outdoor platforming with spikes, bouncy platforms, crumbling platforms, and moving platforms.
- **World 2 — Crystal Caves**: 3 levels + Boss (Crystal Golem). Underground cave environments with crystal formations, crystal bat enemies, and new hazards.

Each level has 3 collectible stars (1 for completion, 2 hidden). Collecting 9 World 1 stars unlocks World 2.

### Enemies

| Enemy | Behavior |
|-------|----------|
| Slime | Patrols back and forth |
| Spiny | Patrols, can't be jumped on |
| Turret | Stationary, shoots projectiles |
| Charger | Rushes at the player |
| Crystal Bat | Flying enemy in World 2 |

### Systems

- **Coin Bank** — Coins persist across levels. Every 30 coins earns an extra life. Accumulated coins can be spent in the Color Shop.
- **Color Shop** — Spend coins on 6 cosmetic robot colors (Blue, Red, Green, Pink, Gold, Purple) from the main menu.
- **Time Trials** — Every level has a running timer. Beat your best time to see "NEW BEST!" and a ghost replay of your previous run on the next attempt.
- **Difficulty Assists** — Toggle accessibility options in the Options menu:
  - Long Coyote Time (0.15s to 0.4s)
  - Slow Fall (reduced gravity and fall speed)
  - Infinite Double Jumps
  - Easy Wall Angles (more forgiving wall run/slide detection)
- **Save System** — Progress auto-saves to `user://save_data.json` (stars, coin bank, settings, assists, best times, owned colors).

## Project Structure

```
src/
  characters/
    player/          # Player controller + robot mesh
    enemies/         # Slime, Spiny, Turret, Charger, Crystal Bat, Bosses
  levels/
    level_base.gd    # Shared level logic (timer, ghost, respawn)
    world_1/         # 3 levels + boss
    world_2/         # 3 levels + boss
  objects/
    collectibles/    # Coin, Star, Health Pickup, Level End
    hazards/         # Spikes, Lava, Checkpoint, Breakable Crate, Damage Zone
    platforms/       # Bouncy, Moving, Crumbling
  systems/
    game_manager.gd  # Central game state (autoload)
    save_manager.gd  # JSON persistence (autoload)
    audio_manager.gd # Music + SFX playback (autoload)
    material_library.gd # Toon-shaded materials (autoload)
    sound_library.gd # SFX references (autoload)
    music_library.gd # Music references (autoload)
    camera/          # Third-person follow camera
    vfx/             # Particles, screen shake, juice effects
  shaders/
    toon_shader.gdshader    # Cel-shaded lighting
    outline_shader.gdshader # Black outline pass
  ui/
    main_menu        # Play, Options, Shop, Quit
    level_select     # World tabs, level buttons, star + time display
    hud              # Hearts, coins, stars, boss HP bar, trial timer
    pause_menu       # Resume, restart, quit to menu
    options_menu     # Volume sliders + assist toggles
    shop             # Color shop (buy/select cosmetic colors)
    level_complete   # Stars earned, ability unlock notifications
    game_over        # Retry or quit
    scene_transition # Fade transitions between scenes
```

## Visual Style

All materials use a custom **toon shader** with:
- 3-step light banding (cel shading)
- Rim lighting
- Specular highlights
- Black outline pass on characters and enemies

The player robot is **procedurally built** from primitive meshes (boxes, spheres, cylinders) with procedural animation — walk cycles, idle bobbing, jumping poses, and state-specific animations are all driven by code, no imported assets needed.

## Requirements

- [Godot 4.6](https://godotengine.org/) or later
- Forward+ renderer

## Running

1. Clone the repository
2. Open `project.godot` in Godot 4.6
3. Press F5 or click Play
