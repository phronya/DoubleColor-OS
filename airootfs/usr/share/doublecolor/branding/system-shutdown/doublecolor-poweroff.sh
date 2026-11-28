#!/bin/sh
# DoubleColor OS: страховка выключения.
#
# systemd-shutdown запускает скрипты из /usr/lib/systemd/system-shutdown/
# на последнем шаге остановки системы и передаёт аргумент:
#   reboot | poweroff | halt | kexec
#
# Если ACPI не отключил питание за 25 секунд (частая проблема на некоторых
# платах), срабатывает SysRq «o» — ядро выключает питание принудительно.
# Для этого в /etc/sysctl.d/99-work.conf включён kernel.sysrq=1.

case "$1" in
    poweroff)
        (
            sleep 25
            sync
            echo o > /proc/sysrq-trigger 2>/dev/null
        ) &
        ;;
esac

exit 0
