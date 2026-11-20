# 04 — UI, effects & palette

## The UI is built in code

`hud.tscn` and `title.tscn` each contain **one node**. Every label, icon, panel and button is
created in `_ready()` with helpers from `scripts/ui/ui_kit.gd`.

**Why build UI in code here?**

* Positions are exact pixel numbers on a 384 × 216 canvas, so code is as precise as the editor.
* A shared helper (`UI.label`, `UI.button`, `UI.dialog`) guarantees consistent styling.
* The HUD and title can be read top-to-bottom as one script.

**Trade-off:** you can't see the layout in the editor without running the scene (F6). For bigger
UIs, a hand-built scene with a `Theme` resource is usually better. See the exercises in
[Let's learn, chapter 11](../lets-learn/chapter-11-user-interface.md).

## UI kit (`ui_kit.gd`)

`extends RefCounted`, and every function is `static`, so it's a **function library**. Nobody
creates an instance. You use it through `const UI := preload("res://scripts/ui/ui_kit.gd")`.

| Helper | Builds |
|---|---|
| `UI.icon(33)` | `load("res://asset/UI/Icons/33.png")` |
| `UI.panel(size)` | `NinePatchRect` over `UI.png` region `(112,108,48,48)`, 4 px margins |
| `UI.label(text, size, color, outline)` | `Label` with font size/colour overrides, dark 3 px outline, centred |
| `UI.button(text, callable)` | `Button` 100×16, four `StyleBoxFlat`s (normal/hover/focus/pressed), `pressed` connected |
| `UI.dialog(title, info, buttons, title_color)` | Full-rect root → 60 % black dim → centred panel → `VBoxContainer` (title, info, buttons) |

### 9-slice panels

A **NinePatchRect** cuts a texture into 9 parts using the margins. Corners stay fixed, edges
stretch in one direction, and the centre stretches in both. One small 48 × 48 frame can become a
98 × 30 status box or a 190 × 130 dialog without distorting the border.

```
┌──┬────────┬──┐
│C │  edge  │C │   C = corner (never stretched)
├──┼────────┼──┤
│e │ centre │e │
├──┼────────┼──┤
│C │  edge  │C │
└──┴────────┴──┘
```

## HUD layout (384 × 216)

```
┌────────────────────────────────────────────────────────────┐
│┌──────────────┐                                 000100    │  score: accent, 10 px, right-aligned
││♥♥♥♥♥♥♥♥♥♥    │                                  00:42    │  time: light, 8 px
││▮ 12/12  ● ● ●│                                           │
│└──────────────┘                                           │
│                   WARNING!                                │  centre message at y=55, 16 px,
│                 DEADEYE ROOK                              │  fades in 0.15 s, out 0.4 s
│                                                           │
│                                                           │
│                  DEADEYE ROOK                             │
│              ☠ ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇                       │  boss bar: 200 px wide at y=192
└────────────────────────────────────────────────────────────┘
```

| Element | Source | Behaviour |
|---|---|---|
| Hearts ×10 | icon 33 at 0.5 scale (8 px), 9 px apart | Red if `i < hp`, grey otherwise. Hidden if `i >= max_hp`. |
| Bullet icon + ammo | icon 26 + Label | Shows `"RELOAD..."` while reloading |
| Grenades ×3 | icon 1 | Olive if available, near-transparent if used |
| Score | Label `"%06d"` | Zero-padded to 6 digits |
| Time | `Game.format_time()` | Updated every frame |
| Boss bar | skull icon 25 + 2 `ColorRect`s | Width tweens to `200 × hp / max_hp` over 0.15 s |

**Why tween the boss bar:** an instant jump is hard to notice. A 0.15 s slide shows *how much*
damage you did.

## Dialogs

| Dialog | Trigger | Buttons |
|---|---|---|
| PAUSED (accent title) | Esc / P / Start | RESUME, RESTART, QUIT TO TITLE |
| YOU DIED (danger title) | `player_died` + 1.6 s | RETRY, TITLE |
| CITY SAVED (accent title) | final `boss_defeated` + 3 s | PLAY AGAIN, TITLE |

The first button **grabs focus**, so keyboard and gamepad users can confirm immediately.

## Title screen composition

```
                      DARK CITY          ← 32 px, accent
         one night - one street - three bosses
                       [ START ]
                       [ QUIT  ]
   ┌──────┐                                   ┌────────┐
   │burger│        🧍        👤 👤 👤          │ yellow │   ← tinted buildings
   │ shop │       hero     3 bosses (2×)      │building│
═══════════════════ sidewalk tiles ═════════════════════
   Move A/D  Jump Space  Shoot J  Grenade K  Reload R
     Drop down S+Space  Pause Esc  Gamepad works too
```

All four actors play `idle` at 2× with `speed_scale = randf_range(0.8, 1.2)`, so they don't breathe
in perfect sync, which would look robotic.

## Particle effects

| Effect | Node | Settings |
|---|---|---|
| Bullet spark | `CPUParticles2D` created in `bullet.gd` | one-shot, 6 particles, 0.25 s, explosiveness 1, spread 180°, 30–70 px/s, gravity 200, `spark_color`; frees itself on `finished` |
| Rain | `CPUParticles2D` in `level_1.tscn` | see [03](03-tiles-and-level-art.md) |

`CPUParticles2D` (rather than `GPUParticles2D`) is simple to set up from code and fine for a few
hundred particles. It also works with the Compatibility renderer.

## Motion effects

| Effect | How | Strength used |
|---|---|---|
| **Screen shake** | `Camera2D.offset` = random ±strength px, decays at 20 px/s | shot 0.8, boss intro 3, hurt 4, explosion 5, wall slam 6, boss death 8 |
| **Hit-stop** | `Engine.time_scale = 0.05` for N real seconds | player hurt 0.06 s, boss death 0.15 s |
| **Recoil** | `velocity.x -= facing * 8` per shot | |
| **Knockback** | player: (±140, −140). Mooks: ±40–50 px/s. | |
| **Pickup bob** | looping Tween, y 0 → −3 → 0, sine easing, 0.5 s each way | |
| **Pickup blink** | `visible = fmod(life, 0.2) > 0.1` in the last 3 s | |
| **Message fade** | Tween `modulate:a` 0 → 1 (0.15 s) → hold → 0 (0.4 s) | |

## Colour palette

| Name | Value | Use |
|---|---|---|
| `COLOR_TEXT` | `Color(0.16, 0.11, 0.11)` | Dark brown text on beige panels and buttons |
| `COLOR_LIGHT` | `Color(0.96, 0.92, 0.85)` | Off-white text on the dark world |
| `COLOR_ACCENT` | `Color(1.0, 0.72, 0.2)` | Gold: title, score, focused button, victory |
| `COLOR_DANGER` | `Color(0.85, 0.2, 0.25)` | Red: hearts, boss bar, "YOU DIED" |
| Button normal | `Color(0.82, 0.74, 0.66)` | Beige |
| Button pressed | `Color(0.9, 0.5, 0.15)` | Orange |
| Text outline | `Color(0.05, 0.03, 0.08)` | Near-black purple |
| Clear colour | `Color(0.05, 0.04, 0.09)` | Background |
| Sky gradient | `(0.04,0.03,0.10)` → `(0.25,0.13,0.27)` | |
| Night tint | `Color(0.8, 0.77, 0.95)` | Cool violet over the world |
| Player bullet spark | `Color(1, 0.85, 0.3)` | Gold |
| Enemy bullet / spark | `(1, 0.45, 0.4)` / `(1, 0.4, 0.3)` | Red, so enemy fire is instantly readable |

**Readability rule used throughout:** *gold = yours / good, red = danger.* Player bullets are
gold and enemy bullets are red. The score is gold and hearts are red.
