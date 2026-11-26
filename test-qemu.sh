#!/usr/bin/env bash
# test-qemu.sh - zapusk sobrannego ISO v QEMU
# Ispolzovanie: ./test-qemu.sh [--uefi|--bios] [put-k-iso]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="uefi"
iso=""

usage() {
    cat <<EOF
Использование: $0 [--uefi|--bios] [--gl] [путь-к-iso]

Без аргументов берёт самый свежий ISO из build/out и грузит в UEFI.
Параметры VM: 2 vCPU, 4 ГБ ОЗУ, диск 20 ГБ (build/test-disk.qcow2).
--gl включает 3D-ускорение (virtio-vga-gl), без него — совместимый режим.
EOF
}

gl=0
for arg in "$@"; do
    case "$arg" in
        --bios)   mode="bios" ;;
        --uefi)   mode="uefi" ;;
        --gl)     gl=1 ;;
        -h|--help) usage; exit 0 ;;
        *)        iso="$arg" ;;
    esac
done

if [ -z "$iso" ]; then
    iso="$(ls -t "$here"/build/out/*.iso 2>/dev/null | head -n1 || true)"
fi
[ -n "$iso" ] || { echo "ISO не найден. Сначала запустите ./build.sh" >&2; exit 1; }
[ -f "$iso" ] || { echo "Файл не найден: $iso" >&2; exit 1; }

command -v qemu-system-x86_64 >/dev/null 2>&1 || {
    echo "Нужен QEMU: sudo pacman -S qemu-full edk2-ovmf" >&2
    exit 1
}

accel=()
if [ -r /dev/kvm ]; then
    accel=(-enable-kvm -cpu host)
else
    echo "ВНИМАНИЕ: /dev/kvm недоступен, VM будет медленной" >&2
fi

disk="$here/build/test-disk.qcow2"
if [ ! -f "$disk" ]; then
    echo "==> создаю тестовый диск 20G: $disk"
    qemu-img create -f qcow2 "$disk" 20G >/dev/null
fi

if [ "$gl" -eq 1 ]; then
    video=(-device virtio-vga-gl -display gtk,gl=on)
else
    video=(-vga virtio -display gtk)
fi

common=(
    "${accel[@]}"
    -smp 2 -m 4096
    -cdrom "$iso" -boot d
    -drive file="$disk",if=virtio,format=qcow2
    -nic user,model=virtio-net-pci
    -usb -device usb-tablet
    "${video[@]}"
)

if [ "$mode" = "uefi" ]; then
    code="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
    vars_src="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
    [ -f "$code" ] || { echo "Нет $code (пакет edk2-ovmf)" >&2; exit 1; }
    vars="$here/build/OVMF_VARS.fd"
    [ -f "$vars" ] || cp "$vars_src" "$vars"
    echo "==> QEMU: UEFI (Secure Boot выключен), $iso"
    exec qemu-system-x86_64 "${common[@]}" \
        -drive if=pflash,format=raw,readonly=on,file="$code" \
        -drive if=pflash,format=raw,file="$vars"
fi

echo "==> QEMU: BIOS (SeaBIOS), $iso"
exec qemu-system-x86_64 "${common[@]}"
