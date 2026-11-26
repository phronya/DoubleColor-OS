#!/usr/bin/env bash
# wine-bootstrap.sh - sozdanie gotovogo Wine-prefiksa (x86 ili x64)
# Ispolzovanie: wine-bootstrap.sh [win64|win32]
set -euo pipefail

arch="${1:-win64}"
case "$arch" in
    win64|win32) ;;
    *)
        echo "Использование: $0 [win64|win32]" >&2
        exit 1
        ;;
esac

command -v wine >/dev/null 2>&1 || {
    echo "wine не установлен: sudo pacman -S wine wine-mono wine-gecko winetricks" >&2
    exit 1
}

export WINEPREFIX="$HOME/.local/share/wineprefixes/$arch"
export WINEARCH="$arch"

mkdir -p "$WINEPREFIX"

echo "== Wine: $(wine --version)"
echo "== Префикс: $WINEPREFIX ($WINEARCH)"

if [ "$arch" = "win32" ]; then
    echo "== Проверка 32-бит: если wineboot упадёт, сборка wine без WoW64 —"
    echo "   установите lib32-* из multilib (см. README)."
fi

WINEDEBUG=-all wineboot -u

# Базовые компоненты: шрифты и runtime. Ошибки не фатальны.
for verb in corefonts vcrun2019 dxvk; do
    echo "== winetricks $verb"
    winetricks -q "$verb" || echo "   пропущено: $verb"
done

cat <<EOF

Готово.
  Запуск программы:  WINEPREFIX=$WINEPREFIX wine program.exe
  Проводник:         WINEPREFIX=$WINEPREFIX wine explorer
  Настройка:         WINEPREFIX=$WINEPREFIX winecfg

Launcher'ы (Steam, Epic) лучше ставить в отдельный префикс:
  WINEPREFIX=\$HOME/.local/share/wineprefixes/launchers $0 win64
EOF
