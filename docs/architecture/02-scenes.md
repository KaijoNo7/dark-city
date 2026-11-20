# 02 — Scenes

Every scene in the game, with its node tree and the reason for each node.
Coordinates are in game pixels. **Y grows downward** in Godot 2D.

A convention used everywhere: **a character's origin (0, 0) is at its feet.** The sprite is moved
*up* by half its height, so placing a character at `y = 176` (the ground surface) puts its feet on
the ground.

---

## `scenes/player/player.tscn`

```
Player            CharacterBody2D   layer 2, mask 17 (world+platforms), group "player"
├── Sprite        AnimatedSprite2D  position (0,-16), frames = resources/frames/player.tres
├── Shape         CollisionShape2D  10×18 rectangle at (0,-9)
├── Muzzle        Marker2D          (9,-7) where bullets appear
└── Camera        Camera2D          (0,-28), smoothing 7, script game_camera.gd
```

| Node | Why |
|---|---|
| `CharacterBody2D` | Moves with `move_and_slide()`, which handles slopes, floors and walls, and gives `is_on_floor()`. Made for player-controlled characters. |
| `Sprite` at y −16 | Frames are 32×32 with feet at the bottom edge, so shifting up 16 puts the feet on the origin. |
| `Shape` 10×18 | Narrower than the 32 px frame because the art has empty space around the character. A tight box feels fair. |
| `Muzzle` | A `Marker2D` is an invisible point you can see and drag in the editor. The script mirrors its `x` when the player turns. |
| `Camera` as a child | It follows the player automatically. The −28 offset frames the action slightly above the feet. `limit_smoothed` makes it ease into the arena locks instead of snapping. |
| `floor_snap_length = 4` | Keeps the body glued to the floor on small steps instead of briefly "flying". |

## `scenes/enemies/mook_gunner.tscn` and `mook_brute.tscn`

```
mook_gunner       CharacterBody2D   layer 4, mask 17, script mook_gunner.gd, max_hp 4, score 100
├── Sprite        AnimatedSprite2D  (0,-16)
├── Shape         CollisionShape2D  10×18 at (0,-9)     ← body: collides with the world
├── Hitbox        Area2D            layer 0, mask 2     ← detects the player for contact damage
│   └── Shape     CollisionShape2D  12×16 at (0,-9)
└── Muzzle        Marker2D          (11,-7)
```

The brute is identical in structure (`max_hp 6`, `score 150`, `mook_brute.gd`).

**Why two shapes?** The body `Shape` is for **physics** (standing on floors, being blocked by
walls). The `Hitbox` is an `Area2D` that **detects** overlap with the player without pushing them,
so touching an enemy hurts instead of shoving you. The hitbox is slightly larger so contact feels
reliable.

## `scenes/bosses/*.tscn`

Same structure as a mook, at **2× scale**:

| Scene | Script | HP | Score | Body shape | Hitbox | Muzzle |
|---|---|---|---|---|---|---|
| `boss_rook.tscn` | `boss_rook.gd` | 60 | 2000 | 18×36 | 20×34 | (22,−14) |
| `boss_bonecrusher.tscn` | `boss_bonecrusher.gd` | 90 | 3000 | 22×36 | 24×34 | (22,−14) |
| `boss_plague_doctor.tscn` | `boss_plague_doctor.gd` (final) | 120 | 5000 | 18×36 | 20×34 | (22,−14) |

In all three, the sprite is scaled ×2 and sits at (0, −32), and the shapes are centred at (0, −18).

Only the **Sprite** is scaled, not the root. Scaling a physics body's root distorts collision, so
the shapes are simply made twice as large instead.

## `scenes/projectiles/bullet.tscn`

```
Bullet            Area2D            layer 0, mask set in code, script bullet.gd
├── Sprite        Sprite2D          texture asset/Characters/Other/Charge 1.png
└── Shape         CollisionShape2D  6×3
```

An `Area2D` rather than a body, because a bullet doesn't need to be *blocked*. It needs to know
*when it touches something* (`body_entered`), then it disappears.

## `scenes/projectiles/shockwave.tscn`

```
Shockwave         Area2D            script bullet.gd (!), speed 140, lifetime 2.2,
│                                   hits_world = false, spark_color orange
├── Sprite        Sprite2D          AtlasTexture: frame of Granate_Explosion.png, scale 0.5
└── Shape         CollisionShape2D  14×12
```

The shockwave **reuses `bullet.gd`** with different exported values. That is the payoff of
exported variables: one script, two different-feeling projectiles.

## `scenes/projectiles/grenade.tscn`

```
Grenade           CharacterBody2D   layer 0, mask 1|16, script grenade.gd
├── Sprite        AnimatedSprite2D  frames grenade.tres (spinning)
├── Shape         CollisionShape2D  circle r=3  ← bounces on world/platforms
└── Hitbox        Area2D            mask 4 (player's) or 2 (boss's)
    └── Shape     CollisionShape2D  circle r=5  ← explode on touching a target
```

A body for bouncing (`move_and_collide` + `velocity.bounce()`), plus an area for "did I touch an
enemy?".

## `scenes/projectiles/explosion.tscn`

```
Explosion         Area2D            mask 4 or 2, script explosion.gd
├── Sprite        AnimatedSprite2D  frames explosion.tres (8 × 64 px), at (0,-22)
└── Shape         CollisionShape2D  circle r=28 at (0,-10)
```

## `scenes/pickups/pickup.tscn`

```
Pickup            Area2D            layer 8, mask 2, script pickup.gd
├── Sprite        Sprite2D          texture set in code (soda can or grenade)
└── Shape         CollisionShape2D  14×14 at (0,-8)
```

## `scenes/level/boss_arena.tscn`

```
BossArena         Node2D            script boss_arena.gd  (origin = left edge, on the ground)
├── Trigger       Area2D            (110,-200), mask 2: 16×400 strip the player walks through
│   └── Shape
├── WallLeft      StaticBody2D      (-8,-300)
│   └── Shape     16×600, disabled = true
├── WallRight     StaticBody2D      (392,-300)
│   └── Shape     16×600, disabled = true
└── BossSpawn     Marker2D          (300,-120): the boss drops from here
```

The walls start **disabled**. When the fight starts, the script enables them, trapping the player
in a 384 px (one screen wide) arena. The trigger sits 110 px inside, so the player is fully in
before the walls close.

## `scenes/ui/intro.tscn`, `hud.tscn` and `title.tscn`

```
Intro   Control       full-rect anchors, script intro.gd   (the main scene)
HUD     CanvasLayer   layer 10, process_mode = Always, script hud.gd
Title   Control       full-rect anchors, script title.gd
```

These scenes are **a single node**. All their children (hearts, labels, boss bar, menus) are
created in code in `_ready()` using `ui_kit.gd`. That is why they look empty in the editor. See
[graphics/04-ui-effects-palette.md](../graphics/04-ui-effects-palette.md).

* **`CanvasLayer`** draws on its own layer, ignoring the camera, so the HUD stays fixed on screen.
* **`process_mode = Always` (3)** keeps the HUD running while `get_tree().paused = true`, so the
  pause menu can still react to clicks.

### Menus without scenes

The settings window (`options_menu.gd`) and the customize screen (`customize_menu.gd`) have **no
`.tscn` at all**. They are `Control` scripts created with `OptionsMenu.new()` and added on top of
whichever screen opened them: the title, or the HUD while paused. Each emits `closed` when done,
so the opener can show its own menu again and restore the focus. See
[05 — Menus, settings & services](05-menus-and-services.md).

### Layers at runtime

| Layer | Contents |
|---|---|
| −20 | Sky (level) |
| 0 | World / title / intro |
| 5 | Rain particles |
| 6 | Lightning flash (`weather.gd`) |
| 10 | HUD, pause menu, settings window while paused |
| 128 | `Settings` overlay: brightness/contrast/gamma/scanline shader, FPS counter, toasts |

## `scenes/level/level_1.tscn` (generated)

Built by `tools/build_level.gd`, but a normal scene you can edit. Top-level nodes:

| Node | Type | Purpose |
|---|---|---|
| `Level1` | Node2D + `level.gd` | Sets camera limits (0 → 3776), shows the opening message |
| `Sky` | CanvasLayer, layer −20 | Gradient + `Stars` (moon & twinkling stars). On a canvas layer, it never scrolls. |
| `FarCity`, `MidCity` | Parallax2D (scroll 0.2 / 0.45) | Silhouette skylines that move slower than the camera, for depth |
| `Buildings` | Node2D, z −5 | Full-colour shop fronts, signs, posters |
| `Props` | Node2D, z −2 | Dumpsters, crates, cones… in front of buildings, behind characters |
| `Ground` | TileMapLayer | 3 rows of solid street tiles, with 3 pits |
| `Platforms` | TileMapLayer | One-way roof ledges |
| `BoundLeft/Right` | StaticBody2D | Invisible walls at the level ends |
| `Rain` | CanvasLayer 5 + CPUParticles2D | Slanted raindrops over everything except the HUD. At runtime `weather.gd` adopts it and sets the count from the *Rain* setting (0 / 60 / 140 / 260). |
| `NightTint` | CanvasModulate | Tints the whole world a cool blue-violet (does not affect CanvasLayers) |
| `Player` | instance | Starts at (40, 176) |
| `BossArena1..3` | instances | At tiles 52, 130, 210 |
| `Enemies` | Node2D | 19 mook instances |
| `Pickups` | Node2D | 5 free pickups (non-expiring) |
| `HUD` | instance | |

## Tool scenes

`tools/build_level.tscn`, `playtest.tscn`, `snap.tscn`, `menu_shots.tscn` are each **one `Node`**
with a script. They exist only so the tools can run as scenes, which means the autoloads are
loaded.
