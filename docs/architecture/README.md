# Architecture & structure

How the game is put together: which files exist, how scenes nest, how objects talk to each other
without knowing about each other, and what each script exposes.

| Document | Contents |
|---|---|
| [01 — Overview](01-overview.md) | Folder layout, runtime flow (title → level → end screen), core design principles, class hierarchy |
| [02 — Scenes](02-scenes.md) | The node tree of every `.tscn` and why each node is there |
| [03 — Communication](03-communication.md) | The `Game` event bus, signals, groups, and the duck-typed `take_damage` / `collect` contracts |
| [04 — Script reference](04-script-reference.md) | Every script: purpose, exported properties, public methods, signals used |

## One-minute summary

```
            ┌────────────────────────── Game (autoload) ──────────────────────────┐
            │ score · bosses_defeated · run_time · running                        │
            │ signals: player_hp_changed, player_ammo_changed, player_died,       │
            │          boss_started, boss_hp_changed, boss_defeated,              │
            │          show_message, score_changed, shake_requested               │
            └──────▲────────────────▲──────────────────▲──────────────┬───────────┘
          emit     │          emit  │            emit  │       listen │
          ┌────────┴───┐   ┌────────┴──────┐   ┌───────┴─────┐  ┌─────▼──────┐
          │  Player    │   │ Enemies/Bosses│   │ BossArena   │  │ HUD, Camera│
          └─────┬──────┘   └───────▲───────┘   └─────────────┘  └────────────┘
     spawns     │                  │ take_damage()
          ┌─────▼──────┐           │
          │ Bullet /   ├───────────┘
          │ Grenade /  │  (duck typing: "if body.has_method('take_damage')")
          │ Explosion  │
          └────────────┘
```

* **Scenes are small and self-contained.** Each one has a root node with one script.
* **Gameplay objects never hold references to the UI.** They emit signals on `Game`, and the
  HUD and camera listen.
* **Damage is a contract, not a class.** Anything with a `take_damage(amount, from_pos)` method
  can be hurt.
* **Enemies share code through inheritance:** `EnemyBase` → `MookGunner` / `MookBrute` /
  `BossBase` → three bosses.
