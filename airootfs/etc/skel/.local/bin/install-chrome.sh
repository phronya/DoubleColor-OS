#!/usr/bin/env bash
# install-chrome.sh — установка Google Chrome из AUR.
#
# В официальных репозиториях Arch Google Chrome нет: это проприетарный бинарник.
# В образе уже стоит Chromium (тот же движок). Этот скрипт ставит именно Chrome.
set -euo pipefail

die() { echo "ОШИБКА: $*" >&2; exit 1; }

command -v pacman >/dev/null 2>&1 || die "скрипт рассчитан на Arch Linux"

if pacman -Q google-chrome >/dev/null 2>&1; then
    echo "Google Chrome уже установлен:"
    google-chrome --version 2>/dev/null || true
    exit 0
fi

if command -v yay >/dev/null 2>&1; then
    echo "==> yay -S google-chrome"
    yay -S --needed --noconfirm google-chrome
elif command -v paru >/dev/null 2>&1; then
    echo "==> paru -S google-chrome"
    paru -S --needed --noconfirm google-chrome
else
    echo "==> yay/paru не найдены, собираю из AUR вручную"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone --depth 1 https://aur.archlinux.org/google-chrome.git "$tmp/google-chrome"
    cd "$tmp/google-chrome"
    makepkg -si --noconfirm
fi

if command -v xdg-settings >/dev/null 2>&1; then
    xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null || true
fi

echo
echo "Готово: $(google-chrome --version 2>/dev/null || echo 'google-chrome установлен')"
echo "Браузер по умолчанию: $(xdg-settings get default-web-browser 2>/dev/null || echo 'не задан')"
