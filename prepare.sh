#!/usr/bin/env bash
# prepare.sh - готовит чистую копию профиля для mkarchiso.
# Источник остается чистым (удобно для git), сборка осуществляется внутри профиля.
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

info "проверяю версию сборки"
if [ -f "$profile/VERSION" ]; then
    file_version="$(tr -d '[:space:]' < "$profile/VERSION")"
    iso_version="$(sed -n 's/^iso_version="\(.*\)"$/\1/p' "$profile/profiledef.sh")"
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
if grep -rho 'archisolabel=[A-Za-z0-9_]*' "$profile/efiboot" "$profile/syslinux" \
    | sort -u | grep -qv "archisolabel=$label"; then
    die "метка в boot-конфигах не совпадает с iso_label=$label"
fi
info "   метка: $label"

info "проверяю обязательные файлы"
for f in profiledef.sh packages.x86_64 pacman.conf \
         airootfs/etc/pacman.conf airootfs/etc/skel/.xinitrc; do
    [ -f "$profile/$f" ] || die "отсутствует $f"
done

info "размер дерева: $(du -sh "$profile" | cut -f1)"
info "готово: $profile"
