#!/usr/bin/env bash
# install-yay.sh - sbor yay iz AUR (nuzhny base-devel i git)
set -euo pipefail

for bin in git makepkg; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Не найден $bin. Установите: sudo pacman -S --needed base-devel git" >&2
        exit 1
    fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "== Клонирую yay"
git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"

echo "== Собираю (может занять несколько минут)"
cd "$tmp/yay"
makepkg -si --noconfirm

echo "== Готово: $(command -v yay)"
