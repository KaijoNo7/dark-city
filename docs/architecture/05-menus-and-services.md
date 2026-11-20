# 05 — Menus, settings & services

How the menus, the intro and the three service autoloads (`Settings`, `Audio`, `SaveGame`) fit
around the original gameplay code. The gameplay scripts barely changed: they gained one-line calls
such as `Audio.sfx("shoot", global_position)`. Everything else is new files.

---

## The pieces

```
                       ┌─────────────── autoloads (live for the whole game) ───────────────┐
                       │ Settings   prefs · bindings · pads · overlay (layer 128) · toasts │
                       │ Audio      buses · music x2 · sfx pool · ui pool · ambience       │
                       │ SaveGame   savegame.json · pending restore                        │
                       │ Game       run state · gameplay event bus                         │
                       └─────▲──────────────▲─────────────────▲──────────────▲────────────┘
                             │              │                 │              │
  intro.gd ──► title.gd ─────┤              │                 │              │
     uses         │ opens    │         options_menu.gd ──► SettingRow  (one row = one option)
  city_backdrop   ├────────► customize_menu.gd                │
  weather         │                                           │
                  └─NEW GAME/CONTINUE─► level.gd ── weather.gd, SaveGame.apply_pending()
                                           │
                                         hud.gd ── pause menu ──► options_menu.gd
                                                  stage card, save/load buttons
```

| File | Kind | Responsibility |
|---|---|---|
| `autoload/settings.gd` | autoload `Settings` | Preferences, bindings, controller tracking, overlay |
| `autoload/audio.gd` | autoload `Audio` | All sound playback |
| `autoload/save_game.gd` | autoload `SaveGame` | Save slot |
| `input/pad_info.gd` | static library | Controller family detection, button names |
| `ui/options_menu.gd` | `Control` (no scene) | SETTINGS window: tabs, rows, rebinding, guided pad set-up |
| `ui/setting_row.gd` | `class_name SettingRow extends Button` | One slider / choice / toggle row |
| `ui/customize_menu.gd` | `Control` (no scene) | Name, tag, character, colour, preview |
| `ui/city_backdrop.gd` | `Control` | Night street diorama with parallax layers (title + intro) |
| `ui/intro.gd` | scene root | The opening cinematic |
| `ui/post_process.gdshader` | canvas shader | Brightness, contrast, gamma, scanlines, vignette |
| `level/weather.gd` | `Node` | Rain level, lightning, thunder, rain ambience |

---

## Design decisions

### 1. Settings are data, rows are generic

All options live in one `DEFAULTS` dictionary. A menu row only needs a label and a key:

```gdscript
_list.add_child(SettingRow.slider("Music", "audio/music"))
_list.add_child(SettingRow.toggle("V-Sync", "video/vsync"))
_list.add_child(SettingRow.choice("Rain", "video/rain", Settings.RAIN_LEVELS))
```

The row reads its value with `Settings.get_value(key)` and writes it back with
`Settings.set_value(key, v)`. It knows nothing about rain or V-Sync. Whoever cares listens to
`Settings.changed`. Adding an option means one line in `DEFAULTS` and one line in the menu.

### 2. One focusable control per row

Each `SettingRow` is a single `Button`. Up/down moves focus between rows (Godot's normal focus
navigation), and left/right are caught in `_gui_input()` to change the value. This is why every
menu works the same with a mouse, a keyboard and any gamepad, without special cases.

### 3. Menus are opened on top, not by changing scene

`options_menu.gd` is added as a child of the title (or of the HUD while paused). The game behind
keeps its state: the paused level is still there, and the title's rain keeps falling. On close the
menu emits `closed`, and the opener shows its own buttons again and restores focus to the one that
opened the menu.

`Esc` handling relies on input order: `_unhandled_input()` reaches the newest, deepest node first.
The settings window is a child of the HUD, so it receives `Esc` (`ui_cancel` / `pause`) first,
closes itself, and marks the event handled. The HUD never sees it and doesn't un-pause.

### 4. Rebinding grabs input before the GUI

While waiting for a new key, `options_menu.gd` uses `_input()`, which runs *before* GUI controls
get the event, and marks every event handled. Otherwise pressing Enter to bind Enter would also
press the focused button. A 250 ms grace period ignores the press that started listening, and a
350 ms pause after each binding stops one press from filling two slots.

### 5. The save is a snapshot plus a recipe

A save stores a few numbers (position, HP, grenades, score, time, bosses beaten), not the whole
scene. Loading rebuilds the level from its normal `.tscn` and then *applies* the numbers
(`apply_pending()`). That keeps the format tiny and robust: the level can change between versions
and old saves still load.

### 6. The intro is a script, not an animation

`intro.gd` runs one `async` function, `_run()`, that reads like a screenplay:

```gdscript
await _type("02:47 AM.   THE POWER GRID IS DOWN.")
await _wait(1.3)
for i in BOSSES.size():
    await _reveal_boss(i)
await _logo_slam()
```

Every helper checks `_done` first, so skipping (any key) stops the sequence cleanly wherever it
is. An `AnimationPlayer` timeline would also work. The script is easier to read and diff, and it
can use the player's chosen character and name, which are only known at runtime.

### 7. Developer tools are sandboxed

`Settings.persist = false` and `SaveGame.path = "user://<tool>_save.json"` let the playtest bot
and the screenshot tool run on a machine where someone actually plays, without touching their
files.

---

## Pause menu flow

```
 [Esc] ──► _toggle_pause(): tree paused, music muffled, "pause_in"
              │
              ▼
        PAUSED ─ RESUME ───────────────────────► un-pause, "pause_out"
               ─ SAVE GAME ── save_now() ──► toast "Game saved" (disabled in boss fights)
               ─ LOAD GAME ── confirm dialog ─► Game.continue_game()
               ─ SETTINGS  ── options_menu (child of HUD) ─ closed ─► back to PAUSED
               ─ RESTART   ── Game.restart_level()
               ─ QUIT TO TITLE ── Game.go_to_title()
```

The settings window works while paused because the HUD has `process_mode = ALWAYS` and the window
is its child (children inherit the process mode). `Settings` and `Audio` are `ALWAYS` too, so the
toast animates and the menu blips play.
