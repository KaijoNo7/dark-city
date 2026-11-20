# 05 — Settings, save games & controllers

This page is the technical reference for three systems:

* **Settings** (`scripts/autoload/settings.gd`): every player preference, the input bindings and
  the post-processing overlay.
* **Save games** (`scripts/autoload/save_game.gd`): one save slot plus automatic checkpoints.
* **Controllers** (`scripts/input/pad_info.gd` + `Settings`): detection of Xbox / PlayStation 2,
  3, 4, 5 / Switch / generic pads, button naming, rebinding and vibration.

For a line-by-line walkthrough of how they were written, see
[Let's learn, chapter 13](../lets-learn/chapter-13-menus-settings-and-saves.md).

---

## Where files are stored

Both files live in Godot's **`user://`** folder, which is per-user and writable even in an
exported game:

| OS | `user://` is… |
|---|---|
| Linux | `~/.local/share/godot/app_userdata/Dark city/` |
| Windows | `%APPDATA%\Godot\app_userdata\Dark city\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Dark city/` |

| File | Format | Written by |
|---|---|---|
| `settings.cfg` | `ConfigFile` (INI-like) | `Settings.save()`, 0.4 s after the last change |
| `savegame.json` | JSON | `SaveGame.save_now()` (pause menu or autosave) |

Delete a file to reset it. A missing, corrupted or wrong-version file is ignored, never a crash.

---

## Part A — Settings

### Every key and its default

All defaults sit in one dictionary, `Settings.DEFAULTS`. Saving and loading loop over it, so adding
an option is a one-line change.

| Key | Default | Range / values | Effect |
|---|---|---|---|
| `audio/master` | 80 | 0–100 % | Master bus volume |
| `audio/music` | 70 | 0–100 % | Music bus |
| `audio/sfx` | 80 | 0–100 % | Sound-effect bus |
| `audio/ambience` | 60 | 0–100 % | Rain loop and thunder |
| `audio/ui` | 70 | 0–100 % | Menu blips |
| `video/window_mode` | 0 | Windowed / Borderless full / Exclusive full | `DisplayServer.window_set_mode()` |
| `video/resolution` | 1 | index into `RESOLUTIONS` | Window size when windowed (768×432 … 3840×2160, all 16:9 multiples of 384×216). Sizes bigger than the monitor are hidden. |
| `video/pixel_perfect` | true | on/off | `content_scale_stretch` = integer (crisp pixels, maybe black borders) or fractional (fills the window) |
| `video/vsync` | true | on/off | `DisplayServer.window_set_vsync_mode()` |
| `video/fps_cap` | 0 | Unlimited, 30, 60, 120, 144, 240 | `Engine.max_fps` |
| `video/show_fps` | false | on/off | FPS counter, bottom left |
| `video/brightness` | 100 | 50–150 % | Post-process shader |
| `video/contrast` | 100 | 50–150 % | Post-process shader |
| `video/gamma` | 100 | 50–150 % | Post-process shader |
| `video/scanlines` | false | on/off | Darkens every other game pixel row |
| `video/vignette` | false | on/off | Darkens the corners |
| `video/rain` | 2 | Off / Light / Normal / Heavy | Rain particle count (0 / 60 / 140 / 260) and rain-loop volume |
| `video/lightning` | true | on/off | Lightning flashes (turn off if flashes bother you; thunder still plays) |
| `video/screen_shake` | 100 | 0–100 % | Multiplies every `Game.shake()` |
| `video/intro` | true | on/off | Play the intro when the game starts |
| `input/deadzone` | 20 | 5–60 % | Stick dead zone, applied to every action |
| `input/vibration` | 70 | 0–100 % | Rumble strength (0 = off) |
| `input/glyphs` | 0 | Auto / Xbox / PlayStation | Which button names menus show |
| `profile/name` | "VEGA" | up to 12 characters | Player name |
| `profile/tag` | "SWAT" | up to 4 characters | Shown as `[TAG] NAME` |
| `profile/character` | 0 | VEGA / KADE / RIX | Player sprite set |
| `profile/tint` | 0 | Standard, Crimson, Cobalt, Toxic, Gold, Violet, Ghost | `self_modulate` colour on the player sprite |
| `profile/show_tag` | true | on/off | Name floating above the player |

### Reading and reacting

```gdscript
var level: int = Settings.get_value("video/rain")        # read
Settings.set_value("video/rain", 0)                       # write (applies + saves)
Settings.changed.connect(func(key: String) -> void: ...)  # react live
```

`set_value()` applies video options at once (`_apply_video()`), emits `changed(key)` and starts a
0.4 s timer that writes the file. The timer means dragging a slider writes the file once, not 20
times.

### The post-processing overlay

`Settings` owns a `CanvasLayer` at **layer 128** (above the HUD and menus) holding a full-screen
`ColorRect` with `scripts/ui/post_process.gdshader`. The shader reads the finished frame through
`hint_screen_texture` and applies contrast → brightness → gamma, then scanlines and vignette. When
every value is neutral the rect is hidden, so the default costs nothing.

The same layer holds the **FPS counter** and the **toast** label (`Settings.toast("Game saved")`),
which work in every scene, paused or not.

---

## Part B — Input bindings

### The model

```gdscript
Settings.binds = {
    "jump": {
        "keys":  [Space, W, Up],          # KEY_SLOTS = 3 keyboard slots (null = empty)
        "pad":   [Button 0, null],         # PAD_SLOTS = 2 gamepad slots
        "mouse": [],                       # mouse events: kept, not rebindable
    },
    ...
}
```

* At start-up the bindings from `project.godot` are copied into `_default_binds` (used by
  **RESET**), then `settings.cfg` overrides them, then `apply_bindings()` rewrites the
  `InputMap`.
* Gameplay code doesn't change at all: the player still calls `Input.is_action_pressed("jump")`.
* All gamepad events use **device −1** ("any device"), so every connected pad can play.

### Rebindable actions

`move_left`, `move_right`, `move_down`, `jump`, `shoot`, `grenade`, `reload`, `pause`. Menu
navigation uses Godot's built-in `ui_*` actions (arrows, d-pad, left stick, Enter/Space, Cross/A to
accept, Esc/Circle/B to go back), so a bad binding can never lock you out of the menus.

### Conflicts

`Settings.rebind(action, kind, slot, event)` removes the same event from any other slot first, so
one key never does two things. The menu tells you: *"L was removed from JUMP"*.

### Saved form

Events are stored as small dictionaries, not as Godot objects, so the file stays readable:

```ini
[bindings]
jump={"keys": [{"t": "key", "code": 32, "phys": true}, ...], "pad": [{"t": "btn", "i": 0}, null]}
```

| `t` | Fields | Meaning |
|---|---|---|
| `key` | `code`, `phys` | `phys = true`: a *physical* key position (`physical_keycode`), so WASD stays WASD on AZERTY keyboards. The menu shows the label of the user's layout. |
| `btn` | `i` | Joypad button index |
| `axis` | `i`, `v` | Joypad axis and direction (−1 or +1), e.g. left stick left, or a trigger |

---

## Part C — Controllers

### How Godot sees a gamepad

Godot reads controllers through **SDL's game controller database**. If a pad is in the database
(`Input.is_joy_known(device)` is true), its buttons are remapped to one standard layout:

| Index | Standard name | Xbox | PS4 / PS5 | PS3 / PS2 | Switch |
|---|---|---|---|---|---|
| 0 | bottom face | A | Cross | Cross | B |
| 1 | right face | B | Circle | Circle | A |
| 2 | left face | X | Square | Square | Y |
| 3 | top face | Y | Triangle | Triangle | X |
| 4 | back | View | Share | Select | − |
| 5 | guide | Xbox | PS | PS | Home |
| 6 | start | Menu | Options | Start | + |
| 7 / 8 | stick clicks | LS / RS | L3 / R3 | L3 / R3 | LS / RS |
| 9 / 10 | shoulders | LB / RB | L1 / R1 | L1 / R1 | L / R |
| 11–14 | d-pad | | | | |
| axis 4 / 5 | triggers | LT / RT | L2 / R2 | L2 / R2 | ZL / ZR |

So the same binding (button 0 = jump) works on every known pad. Only the **name printed on the
button** differs, and that is what `pad_info.gd` works out.

### Detection: `PadInfo.detect(device)`

Checks run in this order:

1. **PS2 adapters.** Name contains `ps2`, `playstation 2`, `twin usb`, `dual usb`, `psx`,
   `wisegroup`…, or the USB vendor ID is a known adapter chip (`0x0810`, `0x0925`).
2. **Sony vendor ID `0x054C`.** Product `0x0268` → PS3, `0x0CE6`/`0x0DF2` → PS5, anything else → PS4.
3. **Names:** `dualsense`/`ps5`, `dualshock 4`/`ps4`/`wireless controller`,
   `dualshock 3`/`ps3`/`sixaxis`, then `xbox`/`xinput` or Microsoft vendor `0x045E`, then
   `nintendo`/`switch`/`pro controller`.
4. Otherwise **generic** (menus show "Button 7").

Vendor and product IDs come from `Input.get_joy_info(device)`.

### Supported controllers

| Controller | Connection | Notes |
|---|---|---|
| Xbox 360 / One / Series | USB, Bluetooth, wireless adapter | Known layout, rumble works |
| PS4 DualShock 4 | USB, Bluetooth | Known layout, rumble works |
| PS5 DualSense | USB, Bluetooth | Known layout |
| PS3 DualShock 3 / Sixaxis | USB (Bluetooth needs OS drivers) | Known layout on most systems |
| PS2 DualShock 2 | needs a PS2→USB adapter | Adapters vary; many are **not** in SDL's database. The game detects them and shows "unknown layout - use SET UP". **SET UP CONTROLLER (GUIDED)** asks you to press the button for each action in turn, which fixes any adapter's button numbering. Analog sticks only work when the pad's ANALOG light is on. |
| Others | any | Work with the generic names and the guided set-up |

### Connect / disconnect

`Input.joy_connection_changed` → `Settings` shows a toast ("Controller connected: PlayStation 4
(DualShock 4)") and the GAMEPAD tab rebuilds its list. Plugging in mid-game just works.

### Prompts follow your hands

`Settings._input()` watches every event. A gamepad button or stick push sets `using_pad = true`; a
key or click sets it back. `input_device_changed` lets the title footer and the settings hint
switch between "Jump Space" and "Jump Cross" instantly. `Settings.action_prompt("jump")` returns the
right label.

### Vibration

`Settings.rumble(weak, strong, seconds)` scales by the *Vibration* setting and only rumbles the pad
you last used, and only when you're using a pad. Used when the player is hit (0.5/0.8, 0.25 s),
explosions (0.7/0.9, 0.3 s), player death and boss deaths (full, 0.6–0.8 s).

---

## Part D — Save games

### What is saved

```json
{
    "version": 1,
    "saved_at": "2026-11-20 21:04:10",
    "player_name": "[SWAT] VEGA",
    "character": 0,
    "score": 4350,
    "run_time": 133.2,
    "bosses_defeated": 1,
    "hp": 8,
    "grenades": 2,
    "x": 1296.0,
    "y": 176.0
}
```

`x`/`y` is `player.safe_position`: the last spot where the player **stood on the floor**, so a save
made mid-jump never reloads you above a pit.

### When you can save

`SaveGame.cannot_save_reason()` returns `""` or the reason:

| Situation | Allowed? |
|---|---|
| Walking the street | yes (pause → SAVE GAME) |
| Inside a locked boss arena (`Game.in_boss_fight`) | no: *"Can't save during a boss fight"* |
| Dead | no |
| Title screen | no (nothing to save) |

**Autosave:** after each of the first two bosses, `boss_arena.gd` calls `SaveGame.save_now()` once
the reward has dropped, with an "Autosaved" toast. That makes each arena a checkpoint.

### Loading

`Game.continue_game()` reads the file, restores score / time / bosses, stores the data in
`SaveGame.pending` and loads the level. When `level.gd` is ready it calls
`SaveGame.apply_pending(level)`, which:

1. moves the player to the saved spot and restores HP and grenades,
2. calls `mark_cleared()` on the first *N* arenas (`N = bosses_defeated`), so beaten bosses stay
   beaten and their walls stay open,
3. removes enemies more than 48 px behind the player, and pickups more than 32 px behind.

Enemies **ahead** of the save point come back, which is the usual checkpoint behaviour. Loading is
available from the title (**CONTINUE**), the pause menu (**LOAD GAME**, with a confirmation) and the
game-over screen (**LOAD LAST SAVE**).

### Versioning

`VERSION = 1`. If the format ever changes, bump it: older files are then ignored instead of being
misread.

### Developer tools never touch your files

`tools/playtest.gd` sets `SaveGame.path = "user://playtest_save.json"` and `Settings.persist =
false`; `tools/menu_shots.gd` does the same with its own path. Running the tests can't overwrite
your save or your settings.
