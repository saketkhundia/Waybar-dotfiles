cat > ~/.config/rofi/scripts/wifi.sh <<'EOF'
#!/usr/bin/env bash

THEME="$HOME/.config/rofi/launchers/type-1/style-1.rasi"

# Get NetworkManager's cached Wi-Fi results.
# No rescan — keeps Rofi opening instantly.
networks=$(
    nmcli -t -f SSID,SIGNAL,SECURITY,BSSID device wifi list 2>/dev/null |
    awk -F: '
        $1 != "" {
            ssid=$1
            signal=$2
            security=$3
            bssid=$4

            if (!(ssid in best) || signal > best[ssid]) {
                best[ssid]=signal
                sec[ssid]=security
                mac[ssid]=bssid
            }
        }

        END {
            for (ssid in best) {
                signal=best[ssid]

                if (signal >= 80)
                    icon="󰤨"
                else if (signal >= 60)
                    icon="󰤥"
                else if (signal >= 40)
                    icon="󰤢"
                else
                    icon="󰤟"

                printf "%s  %s  %s%%  %s\n",
                    icon, ssid, signal, sec[ssid]
            }
        }
    '
)

# Open Rofi immediately
selected=$(
    printf '%s\n' "$networks" |
    rofi -dmenu -i -p "Wi-Fi" -theme "$THEME"
)

# Cancel
[[ -z "$selected" ]] && exit 0

# Extract SSID safely
ssid=$(
    sed -E \
    's/^[^ ]+[[:space:]]+//; s/[[:space:]]+[0-9]+%[[:space:]]+.*$//' \
    <<< "$selected"
)

[[ -z "$ssid" ]] && exit 0

# ---------------------------------------------------------
# SAVED NETWORK
# ---------------------------------------------------------

saved_uuid=$(
    nmcli -t -f NAME,UUID connection show 2>/dev/null |
    awk -F: -v ssid="$ssid" '$1 == ssid {print $2; exit}'
)

if [[ -n "$saved_uuid" ]]; then

    # Connect using the exact saved connection.
    # Run in background so Rofi never waits for NetworkManager.
    (
        nmcli connection up uuid "$saved_uuid" >/dev/null 2>&1
    ) &

    exit 0
fi

# ---------------------------------------------------------
# NEW NETWORK
# ---------------------------------------------------------

password=$(
    rofi \
        -dmenu \
        -password \
        -p "Password" \
        -theme "$THEME"
)

[[ -z "$password" ]] && exit 0

# Create/connect the new NetworkManager profile in background.
(
    nmcli device wifi connect "$ssid" password "$password" \
        >/dev/null 2>&1
) &

exit 0
EOF

chmod +x ~/.config/rofi/scripts/wifi.sh
