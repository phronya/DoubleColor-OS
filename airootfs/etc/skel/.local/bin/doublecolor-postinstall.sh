#!/usr/bin/env bash
# doublecolor-postinstall.sh — донастройка уже установленной системы.
# Запускать после archinstall: sudo ~/.local/bin/doublecolor-postinstall.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите через sudo: sudo $0" >&2
    exit 1
fi

echo "== Включаю сервисы"
for unit in NetworkManager bluetooth cups.socket avahi-daemon.service pcscd.socket systemd-timesyncd power-profiles-daemon; do
    systemctl enable "$unit" 2>/dev/null || echo "   пропущено: $unit"
done

echo "== Браузер по умолчанию"
if [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" xdg-settings set default-web-browser chromium.desktop 2>/dev/null || true
    echo "   chromium.desktop"
fi

systemctl enable fstrim.timer 2>/dev/null || true
systemctl enable paccache.timer 2>/dev/null || true

echo "== Локали"
if ! locale -a 2>/dev/null | grep -qi 'ru_RU.utf8'; then
    sed -i 's/^#\s*ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
    locale-gen
fi

echo "== ZRAM"
if [ -f /etc/systemd/zram-generator.conf ]; then
    systemctl daemon-reload
    systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
    zramctl 2>/dev/null || true
fi

echo "== Чистка кэша пакетов"
paccache -r || true

echo "== Состояние"
systemctl --no-pager --failed || true

cat <<'EOF'

Готово. Что осталось вручную:
  1. NVIDIA:  sudo pacman -S nvidia-open-dkms linux-zen-headers
              и добавьте nvidia_drm.modeset=1 в параметры ядра.
  2. yay:     ~/.local/bin/install-yay.sh
  3. Wine:    ~/.local/bin/wine-bootstrap.sh win64
  4. Перезагрузка: sudo reboot
EOF
