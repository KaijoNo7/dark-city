# Audio

Everything you hear in Dark City: where it comes from, how it is mixed, and when it plays.

| Layer | Files | Source |
|---|---|---|
| **Music** | `asset/audio/music/*.ogg` (6 tracks) | Original, synthesised by `tools/audio/compose_music.py` |
| **Sound effects** | `asset/audio/sfx/*.wav` (31 sounds) | *The Essential Retro Video Game Sound Effects Collection [512 sounds]* by **Juhani Junkala**, **CC0** (public domain), from [OpenGameArt](https://opengameart.org/content/512-sound-effects-8-bit-style). Picked, renamed and loudness-normalised by `tools/audio/import_sfx.sh`. |
| **Ambience** | `asset/audio/sfx/rain_loop.ogg` | Synthesised (filtered noise + random droplets) by `compose_music.py` |

CC0 means no attribution is legally required, but the game credits the author anyway (title →
CREDITS, and the AUDIO settings tab).

For the step-by-step build of this system, read
[Let's learn, chapter 14 — Audio](../lets-learn/chapter-14-audio.md).

---

## The `Audio` autoload

`scripts/autoload/audio.gd` is the only script that creates audio players. Everyone else calls it:

```gdscript
Audio.play_music("boss")                 # cross-fade to a track (1 s by default)
Audio.stop_music(0.5)                     # fade out
Audio.sfx("shoot", global_position)       # positional effect (pans, fades with distance)
Audio.sfx("thunder")                      # non-positional effect
Audio.ui("ui_select")                     # menu sound, on the UI bus
Audio.ambience("rain_loop", -4.0)         # looping background layer at -4 dB
Audio.set_muffled(true)                   # low-pass the music (pause menu)
```

### Buses

Created in code by `_make_buses()` when the game starts:

```
Master ◄── Music      (+ a low-pass filter, enabled only while paused)
       ◄── SFX
       ◄── Ambience
       ◄── UI
```

Each bus has a volume slider in **SETTINGS → AUDIO**. Sliders are 0–100 %, converted with
`linear_to_db(percent / 100.0)`, because loudness is logarithmic: 50 % on the slider is about
−6 dB. At 0 % the bus is muted.

### Players

| Players | Count | Purpose |
|---|---|---|
| `AudioStreamPlayer` (Music) | 2 | Cross-fading: the new track fades in on one while the old fades out on the other |
| `AudioStreamPlayer` (SFX) | 12 | Non-positional effects, used round-robin |
| `AudioStreamPlayer2D` (SFX) | 12 | Positional effects, used round-robin |
| `AudioStreamPlayer` (UI) | 4 | Menu sounds |
| `AudioStreamPlayer` (Ambience) | 1 | Rain loop |

A **round-robin pool** reuses the oldest player for each new sound. With 12 players, a 13th
simultaneous sound cuts off the oldest one, which nobody notices in a busy fight. Creating and
freeing a player for each gunshot would be slower.

`Audio` runs with `process_mode = ALWAYS`, so music and menu sounds keep working while the game is
paused.

### Positional sound

`AudioStreamPlayer2D` measures its distance to the current `Camera2D` and pans left/right.
Settings in the pool: `max_distance = 520` (a bit more than one screen), `attenuation = 1.4`,
`panning_strength = 0.7`. An enemy shooting off-screen to the right is quieter and comes from the
right speaker. When there is no camera (title, intro), `sfx()` falls back to a plain player.

### Per-sound mix

The `SFX` table in `audio.gd` gives each effect a volume and a random pitch range:

```gdscript
"shoot": {"db": -8.0, "pitch": 0.08},   # ±8 % pitch every shot
```

Random pitch is the cheapest trick in game audio. The same gunshot 200 times in a row sounds
mechanical; ±8 % makes every shot slightly different.

---

## Music

| Track | Key, tempo, length | Where |
|---|---|---|
| `intro.ogg` "Static" | A minor drone, 64 BPM, 30 s loop | Intro cinematic. Heartbeat kick, distant bells with long echoes. |
| `title.ogg` "Neon Rain" | A minor, 84 BPM, 46 s loop | Title screen. Pads + arpeggio; drums and a melody join halfway. |
| `street.ogg` "Concrete Pulse" | E minor, 112 BPM, 34 s loop | The street. Octave-jumping bass, four-on-the-floor, 16th arpeggio, lead in the 2nd half. |
| `boss.ogg` "Iron Sirens" | D minor, 140 BPM, 27 s loop | Boss fights. 16th-note bass riff, stabs, tom fills, aggressive square lead. |
| `victory.ogg` | C major jingle, 8 s | CITY SAVED screen |
| `game_over.ogg` | A minor sting, 13 s | YOU DIED screen |

### When music changes

```
intro ──► title ──NEW GAME──► street ──arena trigger──► (silence + alarm)
                                 ▲                         │ 2 s intro
                                 │                         ▼
                      AREA CLEAR (+2 s) ◄── fanfare ◄── boss ──► final boss ──► victory
                                                           │
                                       player dies ──► game_over
```

Pausing doesn't stop the music. It turns on the Music bus low-pass filter (900 Hz), so the music
sounds muffled "behind a wall" until you resume.

---

## Sound effects map

| Name | Plays when | Script |
|---|---|---|
| `shoot` | player fires | `player.gd` |
| `enemy_shoot` | enemy or boss fires | `enemy_base.gd` |
| `reload` | reload starts | `player.gd` |
| `throw` | grenade thrown | `player.gd` |
| `explosion` | grenade explodes | `explosion.gd` |
| `boss_explode` | boss dies | `boss_base.gd` |
| `impact` | bullet hits a wall or the ground | `bullet.gd` |
| `enemy_hurt` / `enemy_die` | enemy hit / killed | `enemy_base.gd` |
| `player_hurt` / `player_die` | player hit / killed | `player.gd` |
| `jump` / `land` | jump / landing after > 0.25 s in the air | `player.gd` |
| `pickup_health` / `pickup_grenade` | pickup collected | `player.gd` (`collect()`) |
| `alarm` | boss arena locks | `boss_arena.gd` |
| `enrage` | boss enters phase 2 | `boss_base.gd` |
| `shockwave` | Bonecrusher lands a leap | `boss_bonecrusher.gd` |
| `boss_win` | a boss is defeated | `boss_arena.gd` |
| `thunder` | lightning (0.3–1.4 s after the flash) | `weather.gd` |
| `slam` | logo slam, boss reveals in the intro | `intro.gd` |
| `type` | typewriter letters in the intro | `intro.gd` |
| `ui_move` / `ui_select` / `ui_back` | focus moves / button pressed / menu closed | `ui_kit.gd`, menus |
| `pause_in` / `pause_out` | pause / resume | `hud.gd` |
| `save` / `error` | saved / action refused | `hud.gd` |
| `rain_loop` | ambience in every scene, volume by rain level | `weather.gd` |

`empty` and `power_on` are imported but unused, ready for future features.

---

## How the music generator works (short version)

`tools/audio/compose_music.py` (about 480 lines, numpy only):

1. **Notes** are tuples `(start_beat, length_beats, "A4")`. `midi("A4") = 69`,
   `mtof(69) = 440 Hz`.
2. **Instruments** are *additive synthesisers*: a saw wave is the sum of harmonics `sin(k·f)/k`.
   Each harmonic is weighted by a low-pass curve `1 / (1 + (k·f / cutoff)⁴)`. Making `cutoff` an
   array that falls over time gives the classic "pluck" filter envelope. Band-limiting comes free:
   harmonics above Nyquist are never generated.
3. **Drums:** kick = sine whose pitch drops from 155 Hz to 45 Hz; snare = band-passed noise + a
   185 Hz tone; hats = high-passed noise with a very short decay.
4. **Song** objects mix notes onto named stereo **buses** (drums, bass, pad, arp, lead…). When a
   note's tail runs past the end of a looping song, it **wraps around to the start** (`idx %=
   length`). That is why the loops are seamless.
5. **Effects:** sidechain ducking (pads dip on every kick), ping-pong delay with `np.roll`, and a
   convolution reverb whose impulse response is decaying filtered noise. The FFT convolution is
   circular too, so even the reverb tail wraps into the loop start.
6. **Master:** sum, soft-clip with `tanh`, normalise to about −1 dBFS, write a WAV, encode to Ogg
   Vorbis with ffmpeg.

`rng = np.random.default_rng(1984)` fixes the random seed, so running the script twice produces
identical files.
