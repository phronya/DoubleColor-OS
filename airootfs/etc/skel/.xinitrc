#!/bin/sh
# ~/.xinitrc - резервный запуск Plasma (X11), если SDDM недоступен.
# Основной вход — SDDM, сессия Plasma (Wayland).

[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

exec startplasma-x11
