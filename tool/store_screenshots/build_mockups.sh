#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
font_regular="/System/Library/Fonts/HelveticaNeue.ttc"
font_bold="/System/Library/Fonts/HelveticaNeue.ttc"

render_mockup() {
  local platform="$1"
  local slug="$2"
  local eyebrow="$3"
  local headline="$4"
  local detail="$5"
  local raw="$repo_root/store/$platform/screenshots/raw/$slug.png"
  local output="$repo_root/store/$platform/screenshots/mockups/store-safe-exact/$slug.png"

  if [[ ! -f "$raw" ]]; then
    echo "Missing raw capture: $raw" >&2
    return 1
  fi

  if [[ "$platform" == "ios" ]]; then
    local canvas_width=1320
    local canvas_height=2868
    local screen_width=1040
    local screen_y=760
    local corner=82
    local headline_size=98
    local detail_size=38
    local eyebrow_size=28
    local copy_width=1080
    local copy_x=120
    local eyebrow_y=170
    local headline_y=235
    local detail_y=500
    local crop_top=150
  else
    local canvas_width=1080
    local canvas_height=1920
    local screen_width=760
    local screen_y=480
    local corner=58
    local headline_size=72
    local detail_size=30
    local eyebrow_size=24
    local copy_width=880
    local copy_x=100
    local eyebrow_y=108
    local headline_y=165
    local detail_y=342
    local crop_top=0
  fi

  local work_dir
  work_dir="$(mktemp -d)"
  local resized="$work_dir/resized.png"
  local mask="$work_dir/mask.png"
  local clipped="$work_dir/clipped.png"
  local shadow="$work_dir/shadow.png"
  local base="$work_dir/base.png"

  if (( crop_top > 0 )); then
    local raw_width
    local raw_height
    raw_width="$(magick identify -format '%w' "$raw")"
    raw_height="$(magick identify -format '%h' "$raw")"
    magick "$raw" \
      -crop "${raw_width}x$((raw_height - crop_top))+0+${crop_top}" +repage \
      -resize "${screen_width}x" "$resized"
  else
    magick "$raw" -resize "${screen_width}x" "$resized"
  fi
  local screen_height
  screen_height="$(magick identify -format '%h' "$resized")"

  magick -size "${screen_width}x${screen_height}" xc:none \
    -fill white -draw "roundrectangle 0,0 $((screen_width - 1)),$((screen_height - 1)) ${corner},${corner}" \
    "$mask"
  magick "$resized" "$mask" -alpha off -compose CopyOpacity -composite "$clipped"
  magick "$mask" -channel A -blur 0x26 -evaluate multiply 0.58 +channel \
    -fill black -colorize 100 "$shadow"

  magick -size "${canvas_width}x${canvas_height}" xc:'#151611' \
    -fill '#1F211A' -draw "circle $((canvas_width - 40)),$((canvas_height / 3)) $((canvas_width - 40)),$((canvas_height / 3 - canvas_width))" \
    -fill '#C8F135' -draw "rectangle 0,0 ${canvas_width},22" \
    "$base"

  magick "$base" \
    -font "$font_bold" -weight 700 -fill '#C8F135' -pointsize "$eyebrow_size" \
    -gravity NorthWest -annotate "+${copy_x}+${eyebrow_y}" "$eyebrow" \
    -font "$font_bold" -weight 700 -fill '#F3F5EA' -pointsize "$headline_size" \
    -gravity NorthWest -interline-spacing -8 \
    -annotate "+${copy_x}+${headline_y}" "$headline" \
    -font "$font_regular" -weight 400 -fill '#A9AD9D' -pointsize "$detail_size" \
    -gravity NorthWest -interline-spacing 5 \
    -annotate "+${copy_x}+${detail_y}" "$detail" \
    "$shadow" -geometry "+$(((canvas_width - screen_width) / 2 + 16))+$((screen_y + 28))" -composite \
    "$clipped" -geometry "+$(((canvas_width - screen_width) / 2))+$screen_y" -composite \
    -background '#151611' -alpha remove -alpha off -colorspace sRGB -type TrueColor -depth 8 \
    "$output"
}

mkdir -p \
  "$repo_root/store/ios/screenshots/mockups/store-safe-exact" \
  "$repo_root/store/android/screenshots/mockups/store-safe-exact"

render_mockup ios 01-today 'TODAY' $'Your next set,\nperfectly clear.' $'See today’s target and log reps in seconds.'
render_mockup ios 02-live 'COUNTED SESSIONS' $'Count every rep.\nSave once.' $'Use the iPhone camera or switch to manual counting.'
render_mockup ios 03-history 'HISTORY' $'Progress you\ncan trust.' $'Review every training day, live session and best.'
render_mockup ios 04-friends 'FRIENDS' $'Compete without\nthe noise.' $'Private leaderboards and timely lead-change alerts.'

render_mockup android 01-today 'TODAY' $'Your next set,\nperfectly clear.' $'See today’s target and log reps in seconds.'
render_mockup android 02-onboarding 'YOUR PLAN' $'Training that\nfits your life.' $'Choose your goal, schedule and coaching style.'
render_mockup android 03-history 'HISTORY' $'Progress you\ncan trust.' $'Review every training day, live session and best.'
render_mockup android 04-friends 'FRIENDS' $'Compete without\nthe noise.' $'Private leaderboards and timely lead-change alerts.'

magick \
  \( "$repo_root/store/ios/screenshots/mockups/store-safe-exact/01-today.png" -thumbnail 330x717 -background '#0F100C' -gravity center -extent 378x765 \) \
  \( "$repo_root/store/ios/screenshots/mockups/store-safe-exact/02-live.png" -thumbnail 330x717 -background '#0F100C' -gravity center -extent 378x765 \) \
  \( "$repo_root/store/ios/screenshots/mockups/store-safe-exact/03-history.png" -thumbnail 330x717 -background '#0F100C' -gravity center -extent 378x765 \) \
  \( "$repo_root/store/ios/screenshots/mockups/store-safe-exact/04-friends.png" -thumbnail 330x717 -background '#0F100C' -gravity center -extent 378x765 \) \
  +append -depth 8 "$repo_root/store/ios/screenshots/contact-sheet.png"

magick \
  \( "$repo_root/store/android/screenshots/mockups/store-safe-exact/01-today.png" -thumbnail 270x480 -background '#0F100C' -gravity center -extent 310x520 \) \
  \( "$repo_root/store/android/screenshots/mockups/store-safe-exact/02-onboarding.png" -thumbnail 270x480 -background '#0F100C' -gravity center -extent 310x520 \) \
  \( "$repo_root/store/android/screenshots/mockups/store-safe-exact/03-history.png" -thumbnail 270x480 -background '#0F100C' -gravity center -extent 310x520 \) \
  \( "$repo_root/store/android/screenshots/mockups/store-safe-exact/04-friends.png" -thumbnail 270x480 -background '#0F100C' -gravity center -extent 310x520 \) \
  +append -depth 8 "$repo_root/store/android/screenshots/contact-sheet.png"

echo "Rendered iOS and Android store-safe screenshot sets."
