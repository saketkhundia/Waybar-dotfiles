#!/usr/bin/env bash

FIFO="/tmp/cava.fifo"

bars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

tail -f "$FIFO" | while IFS= read -r line; do
    out=""

    IFS=';' read -ra vals <<< "$line"

    for n in "${vals[@]}"; do
        [[ "$n" =~ ^[0-7]$ ]] || continue
        out+="${bars[$n]}"
    done

    printf '{"text":"%s"}\n' "$out"
done