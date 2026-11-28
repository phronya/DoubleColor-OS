#!/usr/bin/env bash
# apply.sh — переносит оформление и настройки DoubleColor OS в уже
# установленную систему.
#
#   apply.sh /mnt
#
# Скрипт рассчитан на запуск из живой системы: все файлы берутся из
# /usr/share/doublecolor/branding.
set -euo pipefail

TARGET="${1:-}"
BRAND="/usr/share/doublecolor/branding"

[ -n "$TARGET" ] || { echo "ОШИБКА: укажите корень целевой системы, например /mnt" >&2; exit 1; }
[ -d "$TARGET/etc" ] || { echo "ОШИБКА: в $TARGET нет каталога /etc" >&2; exit 1; }
[ -d "$BRAND" ] || { echo "ОШИБКА: нет $BRAND" >&2; exit 1; }

say() { printf '   %s\n' "$*"; }

# --- версия и сведения о системе -----------------------------------------
install -Dm644 "$BRAND/os-release" "$TARGET/usr/lib/os-release"
if [ -f "$TARGET/etc/os-release" ] && [ ! -L "$TARGET/etc/os-release" ]; then
    install -Dm644 "$BRAND/os-release" "$TARGET/etc/os-release"
fi
install -Dm644 "$BRAND/lsb-release" "$TARGET/etc/lsb-release"
install -Dm644 "$BRAND/issue" "$TARGET/etc/issue"
say "/usr/lib/os-release (x.0.2811.0 beta)"

# --- быстрое выключение ---------------------------------------------------
install -Dm644 "$BRAND/systemd/10-doublecolor.conf" \
    "$TARGET/etc/systemd/system.conf.d/10-doublecolor.conf"
install -Dm755 "$BRAND/system-shutdown/doublecolor-poweroff.sh" \
    "$TARGET/usr/lib/systemd/system-shutdown/doublecolor-poweroff.sh"
say "/etc/systemd/system.conf.d, system-shutdown"

# --- заставка загрузки и выключения --------------------------------------
install -Dm644 "$BRAND/plymouth/plymouthd.conf" "$TARGET/etc/plymouth/plymouthd.conf"
install -d "$TARGET/usr/share/plymouth/themes/doublecolor"
for file in doublecolor.plymouth doublecolor.script logo.png panel.png bar.png bar_bg.png; do
    install -m644 "$BRAND/plymouth/$file" \
        "$TARGET/usr/share/plymouth/themes/doublecolor/$file"
done
say "/usr/share/plymouth/themes/doublecolor"

# --- окно «О системе» -----------------------------------------------------
install -Dm755 "$BRAND/about/doublecolor-about" "$TARGET/usr/local/bin/doublecolor-about"
install -Dm644 "$BRAND/about/doublecolor-about.desktop" \
    "$TARGET/usr/share/applications/doublecolor-about.desktop"
install -Dm644 "$BRAND/about/doublecolor.png" "$TARGET/usr/share/pixmaps/doublecolor.png"
say "/usr/local/bin/doublecolor-about"

# --- единый список приложений --------------------------------------------
install -Dm644 "$BRAND/menus/plasma-applications.menu" \
    "$TARGET/etc/xdg/menus/plasma-applications.menu"
say "/etc/xdg/menus/plasma-applications.menu"

# --- тема меню загрузки GRUB ---------------------------------------------
if [ -f "$TARGET/etc/default/grub" ] || [ -d "$TARGET/boot/grub" ]; then
    install -d "$TARGET/boot/grub/themes/doublecolor"
    cp -a "$BRAND/grub/." "$TARGET/boot/grub/themes/doublecolor/"
    install -Dm644 "$BRAND/grub/default-grub" "$TARGET/etc/default/grub"
    say "/boot/grub/themes/doublecolor, /etc/default/grub"
fi

# --- запасной пункт «Безопасная графика» в меню установленной системы ------
if [ -d "$TARGET/boot/grub" ] && [ -f "$TARGET/etc/grub.d/41_custom" ]; then
    uuid="$(findmnt -no UUID "$TARGET" 2>/dev/null || true)"
    kernel="$(ls "$TARGET"/boot/vmlinuz-* 2>/dev/null | head -n1 || true)"
    if [ -n "$uuid" ] && [ -n "$kernel" ]; then
        kernel="/${kernel##*/}"
        initrd="${kernel/vmlinuz-/initramfs-}.img"
        cat > "$TARGET/boot/grub/custom.cfg" <<CUSTOM
menuentry "Безопасная графика (nomodeset)" --id doublecolor-safe {
    search --no-floppy --set=root --file ${kernel}
    linux ${kernel} root=UUID=${uuid} rw nomodeset nowatchdog
    initrd ${initrd}
}
CUSTOM
        say "/boot/grub/custom.cfg (пункт «Безопасная графика»)"
    fi
fi

exit 0
