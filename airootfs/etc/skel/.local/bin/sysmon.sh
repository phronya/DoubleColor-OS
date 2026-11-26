#!/usr/bin/env bash
# sysmon.sh - monitor nagruzki po Ctrl+Shift+Tab
set -euo pipefail

term=""
for t in konsole alacritty xterm; do
    if command -v "$t" >/dev/null 2>&1; then
        term="$t"
        break
    fi
done

if [ -z "$term" ]; then
    echo "Не найден ни один терминал (konsole/alacritty/xterm)" >&2
    exit 1
fi

monitor=""
for m in btop htop top; do
    if command -v "$m" >/dev/null 2>&1; then
        monitor="$m"
        break
    fi
done

if [ -z "$monitor" ]; then
    echo "Не найден монитор (btop/htop/top)" >&2
    exit 1
fi

if [ "$term" = "konsole" ]; then
    exec konsole -e "$monitor"
fi

if [ "$term" = "alacritty" ]; then
    exec alacritty --class sysmon,Sysmon -e "$monitor"
fi

exec "$term" -e "$monitor"
