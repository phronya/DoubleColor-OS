#!/usr/bin/env bash
# DoubleColor OS: настройка готового образа.
# mkarchiso запускает этот файл в chroot после установки пакетов и удаляет его.
set -euo pipefail

BRAND="/usr/share/doublecolor/branding"

echo "==> локали"
locale-gen

echo "==> сведения о системе и версия"
install -Dm644 "$BRAND/os-release"  /usr/lib/os-release
install -Dm644 "$BRAND/lsb-release" /etc/lsb-release
install -Dm644 "$BRAND/issue"       /etc/issue

echo "==> быстрое и предсказуемое выключение"
install -Dm644 "$BRAND/systemd/10-doublecolor.conf" \
    /etc/systemd/system.conf.d/10-doublecolor.conf
install -Dm755 "$BRAND/system-shutdown/doublecolor-poweroff.sh" \
    /usr/lib/systemd/system-shutdown/doublecolor-poweroff.sh

echo "==> Plymouth отключён на Live (заставка остаётся в установленной системе)"
# Без хука в initramfs Plymouth стартует уже после переключения корня и при
# сбое скриптовой темы оставляет консоль в графическом режиме — со стороны
# это выглядит как чёрный экран. На живом носителе он не нужен.
install -d /usr/share/plymouth/themes/doublecolor
for file in doublecolor.plymouth doublecolor.script logo.png panel.png bar.png bar_bg.png; do
    install -m644 "$BRAND/plymouth/$file" /usr/share/plymouth/themes/doublecolor/"$file"
done
install -Dm644 "$BRAND/plymouth/plymouthd.conf" /etc/plymouth/plymouthd.conf
for unit in plymouth-start.service plymouth-quit.service plymouth-quit-wait.service \
            plymouth-read-write.service plymouth-poweroff.service \
            plymouth-reboot.service plymouth-halt.service; do
    ln -sfn /dev/null "/etc/systemd/system/$unit"
done

echo "==> окно «О системе»"
install -Dm755 "$BRAND/about/doublecolor-about" /usr/local/bin/doublecolor-about
install -Dm644 "$BRAND/about/doublecolor-about.desktop" \
    /usr/share/applications/doublecolor-about.desktop
install -Dm644 "$BRAND/about/doublecolor.png" /usr/share/pixmaps/doublecolor.png

echo "==> меню приложений одним списком (как в Windows 7)"
install -Dm644 "$BRAND/menus/plasma-applications.menu" \
    /etc/xdg/menus/plasma-applications.menu

echo "==> готово"
