cat > ~/.config/rofi/scripts/wifi.sh <<'EOF'
#!/usr/bin/env bash

# Wi-Fi menu for Waybar — Rofi (Gruvbox)
THEME="$HOME/.config/rofi/themes/wifi.rasi"

action_off="󰖩  Turn Wi-Fi Off"
action_on="󰖪  Turn Wi-Fi On"
action_rescan="󰄉  Rescan"
action_disconnect="󰪏  Disconnect"

wifi_dev=$(nmcli -t -f TYPE,DEVICE device | awk -F: '$1 == "wifi" {print $2; exit}')

# ---------------------------------------------------------
# Toggle Wi-Fi radio
# ---------------------------------------------------------
toggle_wifi() {
    if nmcli radio wifi | grep -q enabled; then
        nmcli radio wifi off
    else
        nmcli radio wifi on
    fi
    exit 0
}

# ---------------------------------------------------------
# Rescan and reopen the menu with fresh results
# ---------------------------------------------------------
rescan() {
    nmcli device wifi rescan >/dev/null 2>&1
    sleep 1
    exec "$0"
}

# ---------------------------------------------------------
# Disconnect from the current network
# ---------------------------------------------------------
disconnect() {
    nmcli device disconnect "$wifi_dev" >/dev/null 2>&1
    exit 0
}

# ---------------------------------------------------------
# Connect to a network (saved profile or new + password).
# -w 0 returns instantly; NetworkManager keeps connecting in
# the background.
# ---------------------------------------------------------
connect() {
    local ssid="$1" password

    if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$ssid"; then
        ( nmcli -w 0 connection up "$ssid" >/dev/null 2>&1 ) &
        exit 0
    fi

    password=$(rofi -dmenu -password -p "󰠘  Password for $ssid" \
        -theme "$THEME" -theme-str "$(window_pos)")
    [[ -z "$password" ]] && exit 0

    ( nmcli -w 0 device wifi connect "$ssid" password "$password" >/dev/null 2>&1 ) &
    exit 0
}

# ---------------------------------------------------------
# Position the menu under the wifi icon (cursor is on it when clicked).
# rofi places the window's top-left at (x-offset, bar-height + y-offset),
# so clamp x to keep the window fully on screen.
# ---------------------------------------------------------
window_pos() {
    local cur_x=0 scr_w=1600
    if command -v hyprctl >/dev/null 2>&1; then
        read -r cur_x _ <<< "$(hyprctl cursorpos 2>/dev/null | tr ',' ' ')"
        scr_w=$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    m = json.load(sys.stdin)[0]
    print(int(m["width"] / m.get("scale", 1)))
except Exception:
    print(1600)' 2>/dev/null)
    fi
    [[ -z "$scr_w" || "$scr_w" -lt 1 ]] && scr_w=1600
    [[ -z "$cur_x" || "$cur_x" -lt 0 ]] && cur_x=0

    local max_x=$((scr_w - 338))
    (( max_x < 0 )) && max_x=0
    (( cur_x > max_x )) && cur_x=$max_x

    printf 'window { location: northwest; x-offset: %spx; y-offset: 8px; }' "$cur_x"
}

# ---------------------------------------------------------
# Main — uses NetworkManager's cached scan for instant startup
# ---------------------------------------------------------
netlist=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null)

# Networks sorted by signal, best per SSID, with signal icons
rows=$(
    printf '%s\n' "$netlist" |
    awk -F: '
        $2 != "" && $2 != "--" {
            ssid=$2; signal=$3; sec=$4
            if (!(ssid in best) || signal > best[ssid]) {
                best[ssid]=signal; secs[ssid]=sec
            }
        }
        END {
            for (ssid in best) {
                signal=best[ssid]
                if (signal >= 80) icon="󰤨"
                else if (signal >= 60) icon="󰤥"
                else if (signal >= 40) icon="󰤢"
                else icon="󰤟"
                printf "%s  %s  %s%%  %s\n", icon, ssid, signal, secs[ssid]
            }
        }' |
    sort -t' ' -k4 -rn
)

# Currently connected SSID (for the active row highlight + disconnect option)
conn_ssid=$(printf '%s\n' "$netlist" | awk -F: '$1 == "*" {print $2; exit}')

# Warm the AP cache in the background so the connection is fast once picked
( nmcli device wifi rescan >/dev/null 2>&1 ) &

# Assemble menu: actions, networks, rescan at the bottom
if nmcli radio wifi 2>/dev/null | grep -q enabled; then
    menu="$action_off\n"
else
    menu="$action_on\n"
fi
[[ -n "$conn_ssid" ]] && menu+="$action_disconnect\n"
menu+="$rows\n$action_rescan"

# Active row highlight for the connected network
active_arg=""
if [[ -n "$conn_ssid" ]]; then
    idx=$(printf '%s\n' "$menu" | grep -nF "$conn_ssid" | head -1 | cut -d: -f1)
    [[ -n "$idx" ]] && active_arg="-a $((idx - 1))"
fi

selected=$(
    printf '%b' "$menu" |
    rofi -dmenu -i $active_arg -p "󰤨  Wi-Fi" \
        -theme "$THEME" -theme-str "$(window_pos)"
)

[[ -z "$selected" ]] && exit 0

case "$selected" in
    "$action_off")          toggle_wifi ;;
    "$action_on")           toggle_wifi ;;
    "$action_rescan")       rescan ;;
    "$action_disconnect")   disconnect ;;
    *)
        ssid=$(sed -E 's/^[^ ]+[[:space:]]+//; s/[[:space:]]+[0-9]+%[[:space:]]+.*$//' <<< "$selected")
        [[ -n "$ssid" ]] && connect "$ssid"
        ;;
esac

exit 0
EOF

mkdir -p ~/.config/rofi/themes ~/.config/rofi/scripts
chmod +x ~/.config/rofi/scripts/wifi.sh

cat > ~/.config/rofi/themes/wifi.rasi <<'EOF'
* {
    font:               "JetBrainsMono Nerd Font 12";
    background-color:   transparent;
    text-color:         #ebdbb2;
    spacing:            0;
    margin:             0;
    padding:            0;
}

window {
    background-color:   #1d2021;
    border:             2px;
    border-color:       #504945;
    border-radius:      10px;
    padding:            10px;
    width:              320px;
    location:           center;
    anchor:             center;
}

mainbox {
    background-color:   transparent;
    padding:            0;
    margin:             0;
}

inputbar {
    background-color:   #282828;
    border-radius:      8px;
    padding:            8px 12px;
    margin:             0 0 8px 0;
    children:           [ prompt, entry ];
}

prompt {
    text-color:         #d79921;
    margin:             0 10px 0 0;
    background-color:   transparent;
}

entry {
    background-color:   transparent;
    text-color:         #ebdbb2;
    placeholder:        "Search networks...";
    placeholder-color:  #928374;
    cursor-color:       #d65d0e;
}

listview {
    background-color:   transparent;
    border-radius:      8px;
    padding:            0;
    margin:             0;
    lines:              10;
    columns:            1;
    spacing:            2px;
    dynamic:            true;
}

element normal.normal {
    background-color:   transparent;
    border-radius:      6px;
    padding:            9px 12px;
    text-color:         #ebdbb2;
}

element normal.urgent {
    background-color:   transparent;
    border-radius:      6px;
    padding:            9px 12px;
    text-color:         #cc241d;
}

element normal.active {
    background-color:   transparent;
    border-radius:      6px;
    padding:            9px 12px;
    text-color:         #98971a;
}

element selected.normal {
    background-color:   #3c3836;
    border-radius:      6px;
    padding:            9px 12px;
    text-color:         #ebdbb2;
}

element selected.urgent {
    background-color:   #3c3836;
    border-radius:      6px;
    padding:            9px 12px;
    text-color:         #cc241d;
}

element selected.active {
    background-color:   #3c3836;
    border-radius:      6px;
    padding:            9px 12px;
    text-color:         #d79921;
}

element-text {
    background-color:   transparent;
    text-color:         inherit;
}

element-icon {
    background-color:   transparent;
    text-color:         inherit;
    size:               1em;
}

message {
    background-color:   #282828;
    border-radius:      8px;
    padding:            8px 12px;
    margin:             8px 0 0 0;
}

error-message {
    background-color:   #282828;
    border-radius:      8px;
    padding:            10px;
    margin:             8px 0 0 0;
}


EOF
