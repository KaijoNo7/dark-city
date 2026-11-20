# 01 — Game design

## Pitch

> *One night, one street, three bosses.*
> A SWAT officer fights through a rainy downtown street full of thugs, clears three boss arenas
> and takes the city back. A run takes a few minutes. Short, readable, replayable.

| | |
|---|---|
| Genre | Side-scrolling run-and-gun platformer |
| Inspirations (genre) | Classic arcade run-and-guns: limited magazine, grenades, arena bosses with readable patterns |
| Session length | Roughly 3–6 minutes per run |
| Fail state | Lose all 10 hearts, or fall into a pit |
| Win state | Defeat the third boss |

## Core loop

```
 advance right ──► meet enemies ──► shoot / dodge / jump ──► collect pickups
      ▲                                                         │
      │                                                         ▼
 "AREA CLEAR" ◄── beat boss (learn its pattern) ◄── enter arena (walls close)
```

## Controls

| Action | Keyboard | Gamepad | Notes |
|---|---|---|---|
| Move | A / D, ← / → | D-pad, left stick | Accelerates to 95 px/s |
| Jump | Space, W, ↑ | A | Hold for a higher jump |
| Shoot | J, X, left mouse | X | Hold for auto-fire (about 7 shots/s) |
| Grenade | K, C, right mouse | B | Max 3 |
| Reload | R | Y | Automatic when the magazine is empty |
| Drop through platform | S + Space | Down + A | |
| Pause | Esc, P | Start | |

## Movement feel

The player controller uses several standard platformer techniques. Each one fixes a specific
frustration:

| Technique | Value | Problem it solves |
|---|---|---|
| **Acceleration** instead of instant speed | 900 px/s² (top speed in about 0.1 s) | Movement feels weightless and twitchy without it |
| **Coyote time** | 0.10 s | "I pressed jump right at the edge and fell!" You can still jump for a moment after leaving a ledge. |
| **Jump buffer** | 0.12 s | "I pressed jump just before landing and nothing happened!" The press is remembered briefly. |
| **Variable jump height** | gravity ×2.2 while rising without the button held | Lets the player choose a short hop or a full jump |
| **Terminal velocity** | 380 px/s | Falls stay readable and controllable |
| **Knockback + control lock** | (±140, −140), 0.25 s | Hits are felt and push you away from danger |
| **Invulnerability frames** | 1.0 s, flickering | Prevents being "juggled" to death by several hits at once |
| **Drop-through** | 0.25 s platform mask off | Platforms are an escape route, not a trap |

Jump physics: with `jump_velocity = −265` and `gravity = 720`, a full jump rises
`v² / 2g = 265² / 1440 ≈ 49 px` (3 tiles) and lasts about 0.74 s. Platforms are 2 or 4 tiles
above the ground, so the higher row needs a jump from a lower platform.

## Weapons

| Weapon | Damage | Rate / amount | Notes |
|---|---|---|---|
| Pistol | 1 | 0.14 s cooldown, 12-round magazine, 0.9 s reload | Slight random spread (±0.04 rad), tiny recoil and shake |
| Grenade | 6 (radius 28 px) | 3 max | Arcs, bounces (45 % energy), 1.1 s fuse or explodes on contact |

**Design intent:** the magazine and reload create a rhythm: shoot, reload, and use the reload
pause to reposition. Grenades are the "panic button" and the boss-damage tool.

## Pickups

| Pickup | Effect | Source |
|---|---|---|
| Health (red soda can) | +3 HP (up to 10) | 25 % drop from mooks; placed on the street; after each of bosses 1 and 2 |
| Grenade | +1 grenade (up to 3) | 10 % drop from mooks; placed on the street |

Dropped pickups vanish after 10 s (blinking for the last 3). Placed and boss-reward pickups never
expire. A pickup you don't need stays on the ground (`collect()` returns `false`).

## Level structure

```
x:  0        832  1216        2080 2464        3360 3744 3776
    │ street 1 │ARENA1│ street 2  │ARENA2│ street 3  │ARENA3│
    │ pit@544  │ Rook │ pit@1600  │ Bone │ pit@2848  │Plague│
    │ 4 mooks  │      │ 7 mooks   │      │ 8 mooks   │      │
```

* **Length:** 236 tiles = 3,776 px, about 10 screens.
* **Pits:** 3, each 3 tiles (48 px) wide, one per street section.
* **Platforms:** two heights (2 and 4 tiles up), placed for escaping gunfire and reaching pickups.
* **Mooks:** 19 placed (10 gunners, 9 brutes), some on platforms.
* **Difficulty curve:** street 1 is light, then more enemies and enemies on platforms later on.

## Enemies

| Enemy | HP | Score | Behaviour | How to beat it |
|---|---|---|---|---|
| **Gunner** | 4 | 100 | Keeps 60–150 px away, fires slow 3-shot bursts when you're level with him | Jump the bullets, or close in during his cooldown |
| **Brute** | 6 | 150 | Walks, then sprints when close. Axe swing with a short wind-up, 2 damage. | Back off while shooting. A hit cancels his swing. |

Both stagger briefly when hit, never walk off ledges, ignore you outside their aggro range, and
hurt you on contact (1 damage).

## Bosses

Each arena: walls close, the camera locks, "WARNING! <name>" appears, the boss drops in, and after
2 s the fight begins. Every boss has **phase 2 below 50 % HP** ("<name> IS ENRAGED!"): shorter
pauses, more bullets, faster attacks.

### Boss 1 — DEADEYE ROOK (60 HP, 2000 pts)
A gunslinger who teaches the player to **jump bullets and punish openings**.

| Attack | Tell | Counter |
|---|---|---|
| Aimed burst (3 → 5) | 0.25 s pause, "shot" pose | Jump or move vertically |
| Hop-back fan (3 → 5 bullets) | Hops away from you | Find the gap in the fan |
| Walk-in + 2-shot burst | Walks toward you | Back off |
| **Reload** (every 4th attack choice) | "recharge" animation, 1.3 s (0.9 s) | **Free damage!** |

### Boss 2 — BONECRUSHER (90 HP, 3000 pts)
A melee bruiser who teaches **reading tells and using the arena**.

| Attack | Tell | Counter |
|---|---|---|
| Charge (190 → 240 px/s, contact damage 2) | Blinks red for 0.65 s (0.45 s) | Jump over him, or get onto a platform |
| Wall slam → stunned 1.1 s (0.7 s) | He hits a wall | **Free damage, and he's harmless** (contact damage 0) |
| Leap + 2 floor shockwaves (×2 in phase 2) | "cast" pose, jumps | Jump the shockwaves |
| Swipe (2 damage) | You're within 44 px | Don't stand next to him |

### Boss 3 — THE PLAGUE DOCTOR (120 HP, 5000 pts, final)
A caster who tests **everything at once**.

| Attack | Tell | Counter |
|---|---|---|
| Spread volleys (2 → 3 fans of 5) | "shot" pose | Find the gaps, or jump |
| Grenade lob (2 → 3, 2 damage each) | "cast" pose | Keep moving. They land around where you were. |
| Dash to the far side | Jumps away (also when you're within 60 px) | Reposition |
| **Summon** two gunners (phase 2, every 9 s, max 2) | "BACKUP INCOMING!" | Kill them fast. All summons die with the boss. |

**Victory:** "CITY SAVED", with final score and time.

## Scoring

| Source | Points |
|---|---|
| Gunner | 100 |
| Brute | 150 |
| Summoned gunner | 50 |
| Deadeye Rook | 2,000 |
| Bonecrusher | 3,000 |
| The Plague Doctor | 5,000 |

The run timer (`MM:SS`) runs only while `Game.running` is `true` and stops on death or victory.
Speed is its own challenge.

## Feedback ("juice") summary

Every important event has at least two kinds of feedback:

| Event | Visual | Motion | Text |
|---|---|---|---|
| Player shoots | muzzle bullet, `shot` pose | shake 0.8, recoil | ammo counter |
| Bullet hits | spark particles | | |
| Enemy hit | white flash, stagger | knockback | |
| Player hit | `hurt` pose, flicker | shake 4, hit-stop 0.06 s, knockback | hearts |
| Grenade explodes | 64 px blast | shake 5 | |
| Boss arrives | drops in | shake 3 | "WARNING!" |
| Boss phase 2 | | shake 4 | "IS ENRAGED!" |
| Boss dies | 4 chained explosions, fade | shake 8, hit-stop 0.15 s | "DEFEATED!" |
