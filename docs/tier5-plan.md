# Plan: Tier 5 — Systems

## Context

Tiers 1-4 are complete. Tier 5 adds four systems: ability unlock progression, a collectible shop, difficulty assists, and time trial mode. All four require persistence through SaveManager (JSON at `user://save_data.json`).

**Current state:**
- SaveManager persists: `collected_stars`, `unlocked_worlds`, audio `settings`. No coins, abilities, cosmetics, or times.
- GameManager tracks runtime: health, coins (reset each level), lives, stars, world/level. No persistent coin bank.
- Player abilities: all always enabled, no gating flags.
- Options menu: 3 volume sliders in a `VBoxContainer` with `back_requested` signal pattern.
- Main menu: Play, Options, Quit buttons in `main_menu.tscn`.
- HUD (`hud.gd`): hearts, coin count, star indicators, boss HP bar. No timer display.
- Checkpoints (`checkpoint.gd`): visual-only — don't actually update respawn point.
- MaterialLibrary: `"player"` material is `Color(0.2, 0.6, 1.0)` with outline. Player robot mesh references it.

---

## Feature 11: Ability Unlock Progression

Gate wall run, wall slide, and air dash behind world completion. Core moves (jump, double jump, ground pound, spin attack, ground slide) are always available.

### Unlock Rules
- **Start**: Core abilities only
- **Beat World 1 boss** (star on `"1_4"`): Unlock wall slide + wall run
- **Beat World 2 boss** (star on `"2_4"`): Unlock air dash

### Implementation

**`game_manager.gd`** — Add:
```gdscript
var unlocked_abilities: Dictionary = {"wall_run": false, "wall_slide": false, "dash": false}
```
- `is_ability_unlocked(name: String) -> bool`
- `refresh_abilities()` — derives state from `collected_stars` (boss level star = boss beaten)

**`player.gd`** — Add early return guard at top of:
- `_handle_wall_run()`: `if not GameManager.is_ability_unlocked("wall_run"): return`
- `_handle_wall_slide()`: `if not GameManager.is_ability_unlocked("wall_slide"): return`
- `_handle_dash()`: `if not GameManager.is_ability_unlocked("dash"): return`

**`save_manager.gd`** — Add `unlocked_abilities` to save/load. Call `refresh_abilities()` in `load_game()`.

**`level_complete.gd`** — After boss completion, check if new abilities unlocked and show notification text.

**Files:** `game_manager.gd`, `player.gd`, `save_manager.gd`, `level_complete.gd`

---

## Feature 12: Collectible Shop

Spend coins on cosmetic player colors.

### Persistent Coin Bank
- `GameManager.coin_bank: int = 0` — survives `reset_level_state()`.
- `add_coins()` also increments `coin_bank`.

### Color Palette (in MaterialLibrary)
| Key | Color | Cost |
|-----|-------|------|
| `blue` (default) | `(0.2, 0.6, 1.0)` | Free |
| `red` | `(1.0, 0.25, 0.2)` | 50 |
| `green` | `(0.2, 0.85, 0.3)` | 50 |
| `gold` | `(1.0, 0.85, 0.0)` | 100 |
| `purple` | `(0.6, 0.2, 0.9)` | 100 |
| `pink` | `(1.0, 0.4, 0.7)` | 75 |

Register as `"player_red"`, `"player_green"`, etc. via `_create_toon_mat(color, true)`.

### GameManager State
```gdscript
var coin_bank: int = 0
var owned_colors: Array = ["blue"]
var selected_color: String = "blue"
```
- `buy_color(name, cost) -> bool` — deducts from `coin_bank`, appends to `owned_colors`
- `select_color(name)` — sets `selected_color`

### Shop UI — New `src/ui/shop.gd` + `shop.tscn`
Full-screen Control overlay (same pattern as `options_menu`). Shows coin bank at top, grid of color buttons. Each button: colored square + label + Buy/Select/Selected state. `back_requested` signal. Saves on back.

### Main Menu — Add "Shop" button between Options and Quit.

### Player — In `_build_robot_mesh()`, use `MaterialLibrary.get_material("player_" + GameManager.selected_color)` instead of `"player"`.

**Files:** `game_manager.gd`, `save_manager.gd`, `material_library.gd`, `shop.gd` (new), `shop.tscn` (new), `main_menu.gd`, `main_menu.tscn`, `player.gd`

---

## Feature 13: Difficulty Assists

Toggle options in the Options menu for accessibility.

### Assist Options
| Setting | Key | Default | Effect |
|---------|-----|---------|--------|
| Long Coyote Time | `assist_coyote` | false | `coyote_time` 0.15 → 0.4 |
| Slow Fall | `assist_slow_fall` | false | `max_fall_speed` 30 → 15, `gravity` 30 → 18 |
| Infinite Double Jumps | `assist_inf_jumps` | false | Never consume `_has_double_jump` |
| Easy Wall Angles | `assist_wall_angles` | false | Wall press threshold 0.3 → 0.0 |

### Implementation
**`game_manager.gd`** — Add `assists: Dictionary` with 4 boolean defaults. `get_assist(key) -> bool`.

**`player.gd`** — 4 conditional checks:
- `_update_timers()`: `coyote_time` vs `0.4`
- `_apply_gravity()`: reduced gravity/fall speed
- `_handle_jump()`: skip `_has_double_jump = false`
- `_handle_wall_run()`: threshold `0.0` instead of `0.3`

**`options_menu.gd` / `.tscn`** — Add "Assists" section header + 4 `CheckButton` rows after SFX slider, before Spacer2.

**`save_manager.gd`** — Persist `assists` inside `settings`.

**Files:** `game_manager.gd`, `player.gd`, `options_menu.gd`, `options_menu.tscn`, `save_manager.gd`

---

## Feature 14: Time Trial Mode

Per-level timer with ghost replay and local best times.

### Timer
- `level_base.gd`: `var _trial_time: float = 0.0`, counts up in `_physics_process`.
- Stops in `complete_level()`. Saves to `GameManager.best_times` if faster.
- Fall respawn does NOT reset timer (penalty).

### HUD Timer Display
- `hud.gd`: add timer label at top-right. Format: `M:SS.cc`.
- Show "NEW BEST!" bounce when beating record.
- `GameManager.trial_active: bool` and `trial_time: float` updated by level_base.

### Ghost Replay (runtime only, not saved to disk)
- `level_base.gd`: record player `global_position` + `rotation.y` every 5 physics frames into arrays.
- On level load, if ghost data exists for this level, spawn transparent mesh replaying the recording.
- `GameManager.ghost_data: Dictionary = {}` keyed by level_id. Not persisted (too large).

### Best Times
- `GameManager.best_times: Dictionary = {}` — `{ "1_1": 42.5 }`.
- Persisted by SaveManager.

### Level Select
- Show best time next to star display: `"Best: 0:42.50"` or `"—"`.

**Files:** `game_manager.gd`, `level_base.gd`, `hud.gd`, `level_select.gd`, `save_manager.gd`

---

## Implementation Order

1. **SaveManager + GameManager** — data model expansion (coin_bank, abilities, assists, best_times, colors)
2. **Ability unlock progression** — gates in player.gd + level_complete notification
3. **Difficulty assists** — options_menu UI + player conditionals
4. **Collectible shop** — MaterialLibrary colors + shop UI + main menu + player color
5. **Time trial mode** — timer + HUD + ghost + level select times
6. **Update `docs/feature-roadmap.md`**

## Verification

1. Fresh game — wall run, wall slide, dash locked. Core moves work.
2. Beat W1 boss — wall run + wall slide unlock with message.
3. Beat W2 boss — air dash unlocks with message.
4. Abilities persist across saves.
5. Coins accumulate in bank across levels.
6. Shop shows 6 colors. Buy/select works. Robot changes color.
7. Can't buy without enough coins.
8. Difficulty assists toggle in options and take effect immediately.
9. Assists persist across saves.
10. Timer visible during gameplay, stops on level complete.
11. Ghost replays previous best as transparent mesh.
12. "NEW BEST!" shown when beating record.
13. Level select shows best times.
14. All existing mechanics unchanged.
