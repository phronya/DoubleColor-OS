#!/usr/bin/env bash
# docker-build.sh - sborka ISO v kontejnere archlinux (put dlya Windows/macOS)
# Trebuet Docker Desktop ili Docker Engine s --privileged.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image="${IMAGE:-archlinux:latest}"

command -v docker >/dev/null 2>&1 || {
    echo "Docker не найден. Альтернатива: собрать в Arch-VM по README." >&2
    exit 1
}

echo "==> сборка в $image (--privileged, нужно для loop/mount)"
docker run --rm -it \
    --privileged \
    -v "$here":/work \
    -w /work \
    "$image" \
    bash -lc 'pacman -Sy --noconfirm --needed archiso git && ./build.sh'

echo "==> готово, ISO в $here/build/out"
