#!/usr/bin/env bash

MAX_LENGTH=24

status=$(playerctl -a status 2>/dev/null | head -n1)

# Nothing playing/paused → completely hide
if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
    echo '{"text":"","class":"hidden","tooltip":""}'
    exit 0
fi

title=$(playerctl metadata --format '{{title}}' 2>/dev/null)
artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null)

# No title → hide
if [[ -z "$title" ]]; then
    echo '{"text":"","class":"hidden","tooltip":""}'
    exit 0
fi

# Short display text
display="$title"

# Add artist only when there is enough room
if [[ -n "$artist" ]]; then
    display="$title — $artist"
fi

# Truncate UTF-8 safely
display=$(printf '%s' "$display" | cut -c1-"$MAX_LENGTH")

# Add ellipsis if original was longer
original_length=$(printf '%s' "$title — $artist" | wc -m)

if (( original_length > MAX_LENGTH )); then
    display="${display%?}…"
fi

if [[ "$status" == "Playing" ]]; then
    icon="󰎈"
else
    icon="󰏤"
fi

# Tooltip keeps the FULL information
tooltip="$title"
[[ -n "$artist" ]] && tooltip="$title — $artist"

# Escape JSON characters
json_escape() {
    printf '%s' "$1" |
        sed 's/\\/\\\\/g; s/"/\\"/g'
}

display=$(json_escape "$display")
tooltip=$(json_escape "$tooltip")

echo "{\"text\":\"$icon  $display\",\"class\":\"$status\",\"tooltip\":\"$tooltip\"}"
