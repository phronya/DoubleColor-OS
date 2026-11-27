#!/usr/bin/env bash
# DoubleColor: генерируем локали внутри образа.
# mkarchiso запускает этот файл в chroot после установки пакетов и удаляет его.
set -euo pipefail

locale-gen
