#!/usr/bin/env bash
# Developer tool: copies the sound effects the game uses out of the CC0
# "Essential Retro Video Game Sound Effects Collection [512 sounds]" by
# Juhani Junkala (https://opengameart.org/content/512-sound-effects-8-bit-style)
# into asset/audio/sfx/ with short, descriptive names, and loudness-normalises
# them with ffmpeg so every effect sits at a similar volume.
#
# Usage:   tools/audio/import_sfx.sh /path/to/extracted/pack/folder
# Needs:   ffmpeg
set -euo pipefail
SRC="${1:?give the extracted pack folder}"
OUT="$(cd "$(dirname "$0")/../.." && pwd)/asset/audio/sfx"
mkdir -p "$OUT"

# game name            | file inside the pack
MAP=(
  "shoot|Weapons/Single Shot Sounds/sfx_weapon_singleshot2.wav"
  "enemy_shoot|Weapons/Single Shot Sounds/sfx_weapon_singleshot7.wav"
  "reload|Weapons/Out of Ammo/sfx_wpn_reload.wav"
  "empty|Weapons/Out of Ammo/sfx_wpn_noammo1.wav"
  "throw|Weapons/Melee/sfx_wpn_sword2.wav"
  "explosion|Explosions/Short/sfx_exp_short_hard2.wav"
  "boss_explode|Explosions/Long/sfx_exp_long1.wav"
  "impact|General Sounds/Impacts/sfx_sounds_impact6.wav"
  "enemy_hurt|General Sounds/Simple Damage Sounds/sfx_damage_hit3.wav"
  "player_hurt|General Sounds/Negative Sounds/sfx_sounds_damage1.wav"
  "enemy_die|Death Screams/Human/sfx_deathscream_human1.wav"
  "player_die|Death Screams/Human/sfx_deathscream_human4.wav"
  "jump|Movement/Jumping and Landing/sfx_movement_jump1.wav"
  "land|Movement/Jumping and Landing/sfx_movement_jump9_landing.wav"
  "pickup_health|General Sounds/Positive Sounds/sfx_sounds_powerup2.wav"
  "pickup_grenade|General Sounds/Coins/sfx_coin_double1.wav"
  "ui_move|General Sounds/Menu Sounds/sfx_menu_move1.wav"
  "ui_select|General Sounds/Menu Sounds/sfx_menu_select1.wav"
  "ui_back|General Sounds/Pause Sounds/sfx_sounds_pause1_out.wav"
  "pause_in|General Sounds/Pause Sounds/sfx_sounds_pause2_in.wav"
  "pause_out|General Sounds/Pause Sounds/sfx_sounds_pause2_out.wav"
  "error|General Sounds/Negative Sounds/sfx_sounds_error1.wav"
  "save|General Sounds/Positive Sounds/sfx_sounds_powerup10.wav"
  "alarm|General Sounds/Alarms/Alarms/sfx_alarm_loop1.wav"
  "enrage|General Sounds/Weird Sounds/sfx_sound_nagger1.wav"
  "boss_win|General Sounds/Fanfares/sfx_sounds_fanfare1.wav"
  "shockwave|Weapons/Cannon/sfx_wpn_cannon1.wav"
  "slam|Weapons/Cannon/sfx_wpn_cannon4.wav"
  "type|General Sounds/Simple Bleeps/sfx_sounds_Blip7.wav"
  "power_on|General Sounds/Weird Sounds/sfx_sound_poweron.wav"
)
for row in "${MAP[@]}"; do
  name="${row%%|*}"; file="${row#*|}"
  ffmpeg -v error -y -i "$SRC/$file" -af "loudnorm=I=-16:TP=-1.5" -ar 44100 -ac 1 "$OUT/$name.wav"
  echo "  $name  <-  $file"
done

# Thunder: a long explosion slowed to half speed, with the highs cut off.
ffmpeg -v error -y -i "$SRC/Explosions/Long/sfx_exp_long5.wav" \
  -af "asetrate=22050,aresample=44100,lowpass=f=700,volume=2.0,afade=t=out:st=4:d=4" "$OUT/thunder.wav"
echo "  thunder  <-  Explosions/Long/sfx_exp_long5.wav (slowed + low-passed)"
