# ~/.profile - DoubleColor OS
# Графическую сессию поднимает SDDM (sddm.service в graphical.target).
# Автозапуск через startx здесь намеренно убран: он конфликтует с SDDM на tty1.

# Резервный запуск, если SDDM не стартовал:
#   startplasma-x11                          (X11)
#   dbus-run-session startplasma-wayland     (Wayland)

