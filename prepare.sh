#!/usr/bin/env bash
# prepare.sh — готовит чистую копию профиля для mkarchiso.
# Источник остаётся чистым (удобно для git), сборка идёт в build/profile.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
session="${SESSION:-plasma}"
profile="$here/build/profile"

info() { echo "==> $*"; }
die() { echo "ОШИБКА: $*" >&2; exit 1; }

command -v mkarchiso >/dev/null 2>&1 || \
    die "нет mkarchiso. Установите: sudo pacman -S archiso"

case "$session" in
    plasma|i3) pkgs="$here/packages.x86_64" ;;
    *)  die "неизвестный SESSION='$session' (доступно: plasma, i3)" ;;
esac

[ -f "$pkgs" ] || die "не найден список пакетов: $pkgs"

info "очищаю $profile"
rm -rf "$profile"
mkdir -p "$profile"

info "копирую профиль (без build/ и .git/)"
tar -C "$here" --exclude=./build --exclude=./.git -cf - . | tar -C "$profile" -xf -

info "список пакетов: $(basename "$pkgs")"
sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$pkgs" \
    > "$profile/packages.x86_64"

info "копирую список пакетов для установщика"
install -Dm644 "$profile/packages.x86_64" \
    "$profile/airootfs/usr/share/doublecolor/packages.txt"

info "включаю systemd-сервисы симлинками"
sys="$profile/airootfs/etc/systemd/system"
mkdir -p "$sys/graphical.target.wants" "$sys/multi-user.target.wants" "$sys/timers.target.wants"
ln -sfn /usr/lib/systemd/system/graphical.target "$sys/default.target"
enable_unit() {
    local unit="$1" target="$2"
    ln -sfn "/usr/lib/systemd/system/$unit" "$sys/$target/$unit"
}
enable_unit sddm.service              graphical.target.wants
enable_unit NetworkManager.service    multi-user.target.wants
enable_unit bluetooth.service         multi-user.target.wants
enable_unit systemd-timesyncd.service multi-user.target.wants
enable_unit cups.socket               multi-user.target.wants
enable_unit avahi-daemon.service      multi-user.target.wants
enable_unit pcscd.socket              multi-user.target.wants
enable_unit fstrim.timer              timers.target.wants
enable_unit paccache.timer            timers.target.wants

info "копирую /etc/skel в /root (Live-сессия запускается под root)"
install -d -m 750 "$profile/airootfs/root"
cp -a "$profile/airootfs/etc/skel/." "$profile/airootfs/root/"
chmod 755 "$profile/airootfs/root/.xinitrc"
find "$profile/airootfs/root/.local/bin" -type f \
    \( -name '*.sh' -o -name '*.py' \) -exec chmod 755 {} +

info "синхронизирую archiso-хуки mkinitcpio с профилем releng"
releng_conf="/usr/share/archiso/configs/releng/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
if [ -f "$releng_conf" ]; then
    cp "$releng_conf" "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
    info "   взято из $releng_conf"
else
    info "   releng не найден, оставляю файл из репозитория"
fi

info "собираю тему GRUB для меню загрузки"
brand_grub="$profile/airootfs/usr/share/doublecolor/branding/grub"
theme_dir="$profile/grub/themes/doublecolor"
mkdir -p "$theme_dir" "$profile/grub/fonts"
cp -a "$brand_grub/." "$theme_dir/"

# Тема использует только стандартный Unifont из unicode.pf2 — свои .pf2
# не генерируем: grub-mkfont в контейнере сборки ведёт себя по-разному,
# а без шрифта GRUB всё равно рисует меню стандартным.
if [ -f /usr/share/grub/unicode.pf2 ]; then
    cp /usr/share/grub/unicode.pf2 "$profile/grub/fonts/unicode.pf2"
    cp /usr/share/grub/unicode.pf2 "$theme_dir/unicode.pf2"
    info "   шрифт: unicode.pf2"
else
    info "   предупреждение: /usr/share/grub/unicode.pf2 не найден"
fi

info "проверяю версию сборки"
if [ -f "$profile/VERSION" ]; then
    file_version="$(tr -d '[:space:]' < "$profile/VERSION")"
    iso_version="$(sed -n 's/^iso_version="\(.*\)"$/\1/p' "$profile/profiledef.sh" | tr -d '[:space:]')"
    [ -n "$iso_version" ] || die "не удалось прочитать iso_version"
    [ "$file_version" = "$iso_version" ] || \
        die "VERSION=$file_version, а iso_version=$iso_version — приведите к одному"
    info "   версия: $file_version"
else
    info "   файла VERSION нет, проверка пропущена"
fi

info "проверяю метку ISO в boot-конфигах"
label="$(sed -n 's/^iso_label="\(.*\)"$/\1/p' "$profile/profiledef.sh")"
[ -n "$label" ] || die "не удалось прочитать iso_label из profiledef.sh"
if grep -rhoE 'archisolabel=[A-Za-z0-9_]+' "$profile/efiboot" "$profile/syslinux" "$profile/grub" \
    | sort -u | grep -qv "archisolabel=$label"; then
    die "метка в boot-конфигах не совпадает с iso_label=$label"
fi
info "   метка: $label"

info "проверяю, что initrd не ссылается на ucode-образы"
if grep -rqs -- '-ucode\.img\|ucode\.cpio' "$profile/syslinux" "$profile/efiboot" "$profile/grub"; then
    die "в boot-конфигах остались ссылки на ucode-образы: их нет в /boot, загрузка сломается"
fi
info "   ucode встроен в initramfs, отдельных образов нет — ок"

info "проверяю boot-конфиги"
grub_cfg="$profile/grub/grub.cfg"
linux_lines="$(grep -cE '^[[:space:]]*linux ' "$grub_cfg" || true)"
initrd_lines="$(grep -cE '^[[:space:]]*initrd ' "$grub_cfg" || true)"
firstboot_lines="$(grep -c -- 'systemd.firstboot=0' "$grub_cfg" || true)"
[ "$linux_lines" -ge 5 ] || die "в grub.cfg меньше пяти пунктов загрузки (linux=$linux_lines)"
[ "$linux_lines" -eq "$initrd_lines" ] || \
    die "в grub.cfg linux=$linux_lines, а initrd=$initrd_lines — пары не совпадают"
[ "$firstboot_lines" -ge "$linux_lines" ] || \
    die "не во всех пунктах grub.cfg есть systemd.firstboot=0"
grep -q -- 'amdgpu.dc=0' "$grub_cfg" || die "в grub.cfg нет amdgpu.dc=0"
grep -q -- 'nomodeset' "$grub_cfg" || die "в grub.cfg нет безопасного пункта (nomodeset)"
grep -m1 -E '^[[:space:]]*linux ' "$grub_cfg" | grep -q -- 'nomodeset' || \
    die "первый пункт grub.cfg не гарантированный: в нём нет nomodeset"
grep -q -- 'copytoram=y' "$grub_cfg" || die "в grub.cfg нет пункта с copytoram"
for entry in "$profile/efiboot/loader/entries/"*.conf; do
    grep -qE '^initrd ' "$entry" || die "в $(basename "$entry") нет initrd"
    grep -q -- 'archisolabel=' "$entry" || die "в $(basename "$entry") нет archisolabel"
done
menu_labels="$(grep -cE '^LABEL ' "$profile/syslinux/syslinux.cfg" || true)"
[ "$menu_labels" -ge 7 ] || die "в syslinux.cfg меньше семи пунктов (LABEL=$menu_labels)"
info "   grub: $linux_lines пунктов, syslinux: $menu_labels"

info "проверяю обязательные файлы"
for f in profiledef.sh packages.x86_64 pacman.conf \
         grub/grub.cfg syslinux/syslinux.cfg syslinux/splash.png \
         airootfs/etc/pacman.conf airootfs/etc/skel/.xinitrc \
         airootfs/usr/share/doublecolor/branding/os-release \
         airootfs/usr/share/doublecolor/branding/about/doublecolor-about \
         airootfs/usr/share/doublecolor/branding/apply.sh \
         airootfs/usr/share/doublecolor/branding/menus/plasma-applications.menu \
         airootfs/usr/share/doublecolor/branding/plymouth/doublecolor.script \
         airootfs/usr/share/doublecolor/branding/system-shutdown/doublecolor-poweroff.sh; do
    [ -f "$profile/$f" ] || die "отсутствует $f"
done

info "размер дерева: $(du -sh "$profile" | cut -f1)"
info "готово: $profile"
