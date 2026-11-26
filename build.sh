#!/usr/bin/env bash
# build.sh - polnyj cikl: prepare.sh + mkarchiso
# Zapusk: ./build.sh   (parol sudo sprosit odin raz)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile="$here/build/profile"
work="$here/build/work"
out="$here/build/out"

if [ "${1:-}" = "--prepared" ]; then
    shift
else
    "$here/prepare.sh"
fi

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" --prepared
fi

mkdir -p "$work" "$out"

version="unknown"
if [ -f "$here/VERSION" ]; then
    version="$(tr -d '[:space:]' < "$here/VERSION")"
fi
echo "==> DoubleColor OS версия $version"

avail_kb="$(df -Pk "$here/build" | awk 'NR==2 {print $4}')"
need_kb=$((10 * 1024 * 1024))
if [ "${avail_kb:-0}" -lt "$need_kb" ]; then
    echo "ВНИМАНИЕ: свободно $((avail_kb / 1024 / 1024)) ГБ, для сборки нужно ~10 ГБ" >&2
fi

if [ -d "$work" ] && [ -n "$(ls -A "$work" 2>/dev/null)" ]; then
    echo "==> work-каталог не пуст, mkarchiso пересоберёт его"
fi

echo "==> mkarchiso стартует ($(date +%H:%M:%S))"
mkarchiso -v -w "$work" -o "$out" "$profile"

# mkarchiso добавляет версию в имя файла; оставляем чистое doublecoloros.iso,
# версия хранится в VERSION и внутри образа.
built="$(ls -t "$out"/*.iso | head -n1)"
final="$out/doublecoloros.iso"
if [ "$built" != "$final" ]; then
    mv -f "$built" "$final"
fi

echo
echo "==> готово ($(date +%H:%M:%S))"
ls -lh "$final"
sha256sum "$final" | sed "s|$out/||" | tee "$out"/SHA256SUMS
