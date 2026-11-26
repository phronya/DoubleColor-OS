# DoubleColor OS

**Версия: x.0.02611.0**

Рабочий дистрибутив на базе Arch Linux: i3wm на X11, ядро `linux-zen`, ZRAM вместо swap
на диске, Wine для 32- и 64-битных Windows-приложений, монитор нагрузки по `Ctrl+Shift+Tab`.

Минимальные системные требования для работоспособности операционной системы: **2 ядра, 4 ГБ ОЗУ, от 20 ГБ свободного места на диске.**

---

## Что внутри

| Компонент | Решение | Почему так |
|---|---|---|
| Ядро | `linux-zen` | отзывчивость десктопа, low-latency |
| Рабочая среда | KDE Plasma (Wayland) + SDDM | интерфейс как в Windows 10: панель, меню, виджеты, анимации |
| Браузер | `chromium` + `install-chrome.sh` | Chrome ставится одной командой из AUR |
| Сеть | NetworkManager + `plasma-nm`, `bluedevil` | Wi-Fi, Ethernet, Bluetooth в трее |
| Перо | `libwacom` + `wacomtablet` | настройка пера и планшета в параметрах системы |
| Память | `zram-generator`, `zram-size = ram` | при 4 ГБ это не ускорение, а необходимость |
| SSD | `fstrim.timer` | еженедельный TRIM |
| Windows-софт | `wine` + `wine-mono` + `winetricks` | x64 и x86 через new WoW64 |
| Мониторинг | `btop` по `Ctrl+Shift+Tab` | плавающее окно 1000×700 |
| Журнал | 100 МБ максимум | не раздувается на маленьком диске |

Ядро `linux-zen`, `i3`, `dmenu`, `picom`, `alacritty`, `pipewire`, `libreoffice-fresh`,
`firefox`, `zathura`, `cups`, `sane`, `remmina`, `keepassxc`, `archinstall` на Live.

---

## Структура репозитория

```
doublecolor-os/
├── profiledef.sh              # параметры ISO: имя, метка, bootmodes, права
├── packages.x86_64            # список пакетов (комментарии вырезаются prepare.sh)
├── pacman.conf                # pacman для СБОРКИ (multilib включён)
├── prepare.sh                 # копия профиля + симлинки сервисов + проверки
├── build.sh                   # prepare.sh + mkarchiso + sha256
├── test-qemu.sh               # запуск ISO в QEMU (UEFI/BIOS, 2 vCPU, 4 ГБ)
├── docker-build.sh            # сборка в контейнере archlinux
├── .github/workflows/build-iso.yml  # сборка образа в GitHub Actions
├── .gitattributes             # LF для скриптов, чтобы не сломать shebang
├── efiboot/                   # systemd-boot для UEFI
├── syslinux/                  # BIOS
└── airootfs/
    ├── etc/
    │   ├── pacman.conf        # multilib в установленной системе
    │   ├── locale.gen         # en_US + ru_RU
    │   ├── vconsole.conf      # консольный шрифт с кириллицей
    │   ├── sysctl.d/99-work.conf
    │   ├── systemd/zram-generator.conf
    │   ├── systemd/journald.conf.d/99-work.conf
    │   ├── systemd/system/…   # автологин root на tty1 (Live)
    │   └── skel/              # i3, i3status, picom, «Диски», Wine, .bash_profile
    ├── root/                  # заполняется prepare.sh копией skel
    └── usr/
        ├── local/bin/
        │   ├── doublecolor-install         # установка на внутренний диск (archinstall)
        │   └── doublecolor-portable        # установка на USB + переносимый загрузчик
        └── share/doublecolor/
            ├── packages.txt                # список пакетов для установщиков
            └── portable/mkinitcpio.conf    # хуки для загрузки на разном железе
```

`prepare.sh` собирает дерево в `build/profile/` — исходники остаются чистыми для git.

---

## Сборка

### Вариант A: Arch-хост

```bash
sudo pacman -S --needed archiso git qemu-full edk2-ovmf
git clone <этот-репозиторий> doublecolor-os && cd doublecolor-os
chmod +x prepare.sh build.sh test-qemu.sh docker-build.sh
./build.sh
```

Скрипт сам вызовет `prepare.sh`, затем `sudo mkarchiso`. Время: 15–30 минут,
результат — `build/out/doublecoloros.iso` + `SHA256SUMS`. Версия в имя файла не
попадает: она хранится в `VERSION`, в `iso_application` и в CHANGELOG.
Свободного места нужно ~10 ГБ.

### Вариант B: контейнер (Windows/macOS с Docker)

```bash
./docker-build.sh
```

Контейнер запускается `--privileged` — иначе `mount` и `loop`-устройства недоступны.
На Docker Desktop / WSL2 сборка может упасть на `losetup`; тогда используйте вариант C.

### Вариант C: Arch в виртуальной машине

Создайте VM (4 vCPU, 8 ГБ ОЗУ, 40 ГБ диск), установите Arch, скопируйте репозиторий внутрь,
запустите `./build.sh`. Самый надёжный путь с Windows. Готовый ISO забирается через `scp`
или общую папку.

### Вариант D: GitHub Actions — без своего Linux

Проще всего, если у вас только Windows. Образ собирается в облаке в контейнере
`archlinux`, локально ничего ставить не нужно.

```bash
git init && git add -A && git commit -m "DoubleColor OS"
git branch -M main
git remote add origin https://github.com/<ваш-логин>/doublecolor-os.git
git push -u origin main
```

Дальше: вкладка **Actions** → workflow **Build ISO** → **Run workflow**
(или просто дождитесь автоматического запуска после push). Через 15–25 минут
в разделе **Artifacts** появятся:

| Артефакт | Что внутри |
|---|---|
| `doublecoloros` | готовый ISO целиком (если он уложился в лимит) |
| `doublecoloros-parts` | ISO, разбитый на части по 1800 МБ |
| `doublecoloros-sha256` | `SHA256SUMS` |

Если скачался вариант с частями:

```bash
cat doublecoloros.iso.part* > doublecoloros.iso
sha256sum -c SHA256SUMS
```

Запись на USB (Linux/macOS; на Windows — Rufus или balenaEtcher в режиме DD):

```bash
sudo dd if=doublecolor-os.iso of=/dev/sdX bs=8M status=progress oflag=sync
```

Workflow лежит в `.github/workflows/build-iso.yml`, запускается по push в `main`,
по тегу `v*` и вручную. Артефакты хранятся 14 дней — скачайте сразу.

### Переменные окружения

```bash
SESSION=i3 ./build.sh        # сейчас поддерживается только i3
```

---

## Тестирование

```bash
./test-qemu.sh              # UEFI, 2 vCPU, 4 ГБ, диск 20 ГБ
./test-qemu.sh --bios       # BIOS/SeaBIOS
```

Учётная запись Live: **root без пароля**, автологин на tty1, сразу `startx` → i3.

Чек-лист приёмки:

```bash
free -h                                  # цель: 350–500 МБ в простое
zramctl                                  # zram0, zstd
swapon --show                            # только /dev/zram0
systemctl status fstrim.timer
sudo fstrim -av
btop                                     # и Ctrl+Shift+Tab
vulkaninfo --summary
pacman -Sl multilib | head -3
```

Если при загрузке чёрный экран — выберите в меню пункт **«без KMS»** (`nomodeset`).

---

## Установка на диск

Одной командой с Live-образа:

```bash
sudo doublecolor-install
```

Что происходит:

1. запускается `archinstall` (ядро **`linux-zen`**, профиль minimal, без рабочего стола);
2. в целевую систему переносится всё, что живёт только на Live: `/etc/skel` (i3,
   окно «Диски», монитор нагрузки, скрипты Wine), ZRAM, `sysctl`, лимит журнала,
   локали, `pacman.conf` с `multilib`;
3. доустанавливается рабочий набор пакетов (i3, Wine, LibreOffice, печать, проводник);
4. включаются сервисы, генерируются локали, обновляется загрузчик.

**Почему это отдельный шаг.** `archinstall` ставит *стандартный* `/etc/skel` от Arch
и не знает про наши конфиги — без переноса после установки не было бы ни i3, ни
`drives.py`, ни ZRAM. Скрипт закрывает ровно этот разрыв.

Рекомендуемые ответы в `archinstall`: ядро `linux-zen`, профиль minimal, ФС `ext4`,
swap **не создавать** (ZRAM уже настроен), пользователь в группе `wheel`.
Разметка на 20 ГБ: `/` — 12 ГБ, `/home` — 7 ГБ, ESP — 512 МБ.

Если система уже установлена отдельно:

```bash
sudo doublecolor-install --skip-install            # донастроить /mnt
sudo doublecolor-install --skip-install --target=/mnt
```

После первой загрузки — необязательные шаги:

```bash
~/.local/bin/install-yay.sh
~/.local/bin/wine-bootstrap.sh win64
```

`doublecolor-postinstall.sh` остаётся как средство починки: включает сервисы,
генерирует локали, поднимает ZRAM на уже работающей системе.

### NVIDIA

```bash
sudo pacman -S nvidia-open-dkms linux-zen-headers nvidia-utils
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&nvidia_drm.modeset=1 /' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Параметр `nvidia_drm.modeset=1` уже включён в boot-конфиги Live.

### Если systemd-boot не видит linux-zen

`archinstall` создаёт загрузочные записи под то ядро, которое вы выбрали. Если вы
поставили `linux`, а потом доставили `linux-zen`, записи для нового ядра не появится.
Создайте `/boot/loader/entries/doublecolor.conf`:

```ini
title   DoubleColor OS
linux   /vmlinuz-linux-zen
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux-zen.img
options root=UUID=<UUID корневого раздела> rw quiet nvidia_drm.modeset=1 zswap.enabled=0 nowatchdog
```

UUID берётся так: `blkid -s UUID -o value /dev/nvme0n1p2` (подставьте свой раздел).

---

## Интерфейс, перо и сеть

Рабочая среда — **KDE Plasma** на Wayland, вход через **SDDM**. Это ближайший к
Windows 10 вариант из коробки: нижняя панель, меню приложений, список задач,
системный трей с Wi-Fi/Bluetooth/звуком, виджеты и настраиваемые анимации KWin.

| Что | Как выглядит |
|---|---|
| Меню «Пуск» | меню приложений Plasma (клавиша Super) |
| Панель задач | нижняя панель: закрепление, группировка окон, трей |
| Виджеты | `plasma-systemmonitor`, заметки, погода (`kdeplasma-addons`) |
| Настройки | «Параметры системы» — единое окно, как в Windows |
| Файлы | Dolphin, все диски в боковой панели |
| Перо | «Параметры системы → Графический планшет» (`wacomtablet`) |

**Анимации** включены по умолчанию и настраиваются в «Параметры системы →
Рабочая область → Эффекты». На слабом железе отключаются одним переключателем.

**Память.** Переход с i3 на Plasma — сознательный компромисс: простой системы
вырастает с 350–500 МБ до 700–900 МБ. Интерфейс был главным условием, поэтому
выбран Plasma; при 4 ГБ ОЗУ браузер с десятком вкладок потребует ZRAM. Для 2 ГБ
по-прежнему разумнее i3-профиль.

**Сети.** Wi-Fi и Ethernet — NetworkManager с апплетом в трее (`plasma-nm`),
подключение в два клика. Bluetooth — `bluedevil`: сопряжение, гарнитура, мышь.
Проводной интернет работает без настройки (DHCP).

**Браузер.** В образе стоит Chromium — тот же движок, что у Chrome, работает из
коробки. Google Chrome проприетарный и в официальных репозиториях Arch его нет:

```bash
~/.local/bin/install-chrome.sh     # собирает google-chrome из AUR, ставит по умолчанию
```

### Настройки как в Windows 10

| Что | Значение |
|---|---|
| Кнопки окна | справа: свернуть, развернуть, закрыть (`ButtonsOnRight=IAX`) |
| Открытие файлов | двойной клик (`SingleClick=false`) |
| Браузер по умолчанию | Chromium (`BrowserApplication=chromium.desktop`) |
| Меню | меню приложений Plasma по клавише Super |
| Настройки | «Параметры системы» — единое окно |

### Производительность

- индексация Baloo выключена (`Indexing-Enabled=false`) — не грузит диск и CPU;
- блюр и фон-контраст KWin отключены, композитор ограничен 60 FPS;
- `power-profiles-daemon` — профиль питания переключается в трее;
- ZRAM, `swappiness=150`, `nowatchdog`, `zswap.enabled=0` — уже в ядре и sysctl.

---

## Портативная система на USB

Live-ISO и портативная установка — разные вещи. ISO нужен, чтобы загрузиться и
поставить систему, а `doublecolor-portable` ставит **полноценную систему** на флешку
или внешний SSD: данные, настройки и пакеты сохраняются между загрузками, как в
Windows To Go.

```bash
# какой носитель ваш — проверить обязательно
lsblk -o NAME,SIZE,MODEL,TRAN,RM

# план без единого изменения
sudo doublecolor-portable --device=/dev/sdX --dry-run

# установка
sudo doublecolor-portable --device=/dev/sdX --bootloader=grub
```

Разметка: GPT, 1 МиБ BIOS boot, 1 ГиБ ESP (FAT32), остальное — ext4 с меткой
`DOUBLECOLOR`. Требуется не меньше 8 ГБ; комфортно — 16 ГБ и больше.

Защита встроена: скрипт отказывается работать, если указан носитель, с которого
загружен Live-образ, если на устройстве есть смонтированные разделы или активный
swap, если места меньше 8 ГБ. Перед разметкой нужно ввести путь устройства целиком.

### Загрузчик: GRUB или systemd-boot

| | GRUB `--removable` | systemd-boot `--no-variables` |
|---|---|---|
| UEFI на чужом ПК | `EFI/BOOT/BOOTX64.EFI`, NVRAM не нужен | не пишет NVRAM, но запуск через меню прошивки |
| BIOS (legacy) | да, `--target=i386-pc` | нет |
| Размер | ~10 МБ | входит в systemd |
| Правка меню | `grub-mkconfig` | файлы в `/boot/loader/entries` |

По умолчанию выбран GRUB: покрывает и UEFI, и старый BIOS. Если BIOS не нужен —
`--bootloader=systemd-boot`.

### Почему грузится на разном железе

- установлены оба микрокода, `intel-ucode` и `amd-ucode`, загрузчик подаёт оба initrd;
- `/etc/mkinitcpio.conf` берётся из `usr/share/doublecolor/portable/mkinitcpio.conf`:
  `block` и `keyboard` стоят **до** `autodetect`, `kms` — тоже до него;
- `fstab` содержит только `/` и `/boot` по UUID, без swap (ZRAM);
- загрузчик ставится переносимо, без записи в NVRAM.

---

## Перенос на внутренний диск

Портативная система — это обычный Arch на ext4, поэтому переносится штатными
средствами. Условие: целевой диск не меньше занятого места, и после переноса нужно
обновить `fstab`, initramfs и загрузчик — UUID меняются.

### Вариант 1: клонирование (dd / Clonezilla)

```bash
# 1. загрузиться с Live, убедиться, что целевой диск не смонтирован
lsblk -f

# 2. клонировать весь носитель побайтово (копирует и пустое место)
sudo dd if=/dev/sdX of=/dev/sdY bs=8M status=progress conv=fsync

# 3. смонтировать клон: у нас 2 — ESP, 3 — корень
sudo mount /dev/sdY3 /mnt
sudo mount /dev/sdY2 /mnt/boot
sudo arch-chroot /mnt

# 4. внутри chroot — новые UUID
blkid /dev/sdY3 /dev/sdY2
nano /etc/fstab
nano /boot/loader/entries/doublecolor.conf    # для systemd-boot

# 5. пересобрать initramfs и загрузчик
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/boot \
             --bootloader-id=DoubleColor --removable
grub-install --target=i386-pc /dev/sdY
grub-mkconfig -o /boot/grub/grub.cfg
exit

sudo umount -R /mnt
```

Clonezilla делает то же через `device-device` → диск в диск, дальше шаги 3–5.
После загрузки с внутреннего диска расширьте ФС, если диск больше:
`sudo resize2fs /dev/sdY3`.

### Вариант 2: tar-перенос (System Tar & Restore)

Копирует только данные: не требует диска того же размера и не тащит пустое место.

```bash
# на портативной системе: архив на внешний носитель, не на себя
sudo tar -C / --exclude=./proc --exclude=./sys --exclude=./dev \
     --exclude=./run --exclude=./tmp --exclude=./mnt --exclude=./media \
     --exclude=./boot --exclude=./lost+found \
     -cpf /path/to/backup/doublecolor.tar .

# загрузиться с Live, разметить целевой диск, смонтировать
sudo mount /dev/sdY3 /mnt
sudo mount /dev/sdY2 /mnt/boot
sudo tar -C /mnt -xpf /path/to/backup/doublecolor.tar
sudo genfstab -U /mnt > /mnt/etc/fstab

sudo arch-chroot /mnt
# /boot исключён из архива — ядро и initramfs создаются заново
pacman -S --noconfirm linux-zen intel-ucode amd-ucode
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/boot \
             --bootloader-id=DoubleColor --removable
grub-install --target=i386-pc /dev/sdY
grub-mkconfig -o /boot/grub/grub.cfg
exit
```

`systemtar` (AUR, `yay -S systemtar`) автоматизирует ровно это в режиме **Transfer**:
архивирует систему, разворачивает на новом диске, генерирует `fstab` и ставит загрузчик.

### Проверка после переноса

```bash
sudo blkid                       # UUID совпадают с /etc/fstab
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

---

## Ctrl+Shift+Tab

`~/.local/bin/sysmon.sh` открывает `btop` в `alacritty` с классом `Sysmon`.
Правило i3 делает окно плавающим 1000×700 по центру:

```i3
bindsym Ctrl+Shift+Tab exec --no-startup-id $HOME/.local/bin/sysmon.sh
for_window [class="(?i)sysmon"] floating enable, resize set 1000 700, move position center
```

Показывает CPU по ядрам, ОЗУ, ZRAM, диски с `%avail`, сеть, температуры.

---

## Диски и буквы A:/C:

В Linux букв дисков нет: есть `/dev/nvme0n1p2` и монтирование по UUID. Но в окне
проводника **«Диски»** (`Super+N`) сделана привычная нумерация:

| Диск | Буква |
|---|---|
| чистый, только система DoubleColor (ext4/btrfs, EFI, swap) | `A:` |
| есть чужие ФС (NTFS, exFAT) или другая ОС | начиная с `C:` |
| каждый следующий | ближайшая свободная буква |

Плитка устроена так, как вы просили: **сверху крупно буква**, снизу — метка тома
(или модель и объём). Клик открывает диск в `pcmanfm`; если раздел не смонтирован,
он монтируется через `udisks2` и polkit может спросить пароль.

Это только отображение. Ядро, `/etc/fstab` и загрузчик работают с UUID, поэтому
перестановка дисков, переименование метки или подключение нового накопителя ничего
не ломают — буквы пересчитываются при каждом открытии окна.

Из терминала: `lsblk -f`, `df -h`, `udisksctl mount -b /dev/sdX1`.

## Wine: x86 и x64

```bash
~/.local/bin/wine-bootstrap.sh win64   # 64-битный префикс
~/.local/bin/wine-bootstrap.sh win32   # 32-битный префикс
```

Префиксы: `~/.local/share/wineprefixes/{win64,win32}`.
Запуск: `WINEPREFIX=~/.local/share/wineprefixes/win64 wine app.exe`.

Проверка, что сборка Wine поддерживает new WoW64 (32-битные PE без 32-битных библиотек Linux):

```bash
wine --version
ls /usr/lib/wine/x86_64-windows/ | grep -E '^(kernel32|ntdll)'
```

Если `wineboot` для `win32` падает — сборка без WoW64, добавьте из `multilib`:

```bash
sudo pacman -S lib32-glibc lib32-libgcc lib32-vulkan-icd-loader lib32-mesa
```

`multilib` уже включён в `/etc/pacman.conf` образа.

---

## Про античиты: чего этот дистрибутив не делает

Это важно зафиксировать до сборки, чтобы не было разочарования.

- **Kernel-античиты (Valorant, Call of Duty, Battlefield, Apex) не работают и не будут.**
  Они загружают драйвер Ring 0 в ядро Windows, которого под Wine нет. Это архитектура,
  а не настройка.
- **Совместимость x86/x64 здесь не помогает.** Wine транслирует приложения и их
  системные вызовы, но не предоставляет ядро Windows, куда античит мог бы загрузить
  драйвер. Ни одна сборка на Linux — ни эта, ни коммерческая — этого не меняет.
- **User-mode античиты (EAC, BattlEye) работают только там, где издатель включил Linux.**
  Ваша сборка на это не влияет.
- **EAC Linux v2** опирается на Secure Boot + TPM и доверенный список дистрибутивов
  (Ubuntu, Fedora, Debian, openSUSE, Bazzite). Самосборка на Arch в него не входит.
- **Рабочее решение — dual boot**: Windows на отдельном диске для игр с непреодолимыми
  античитами, DoubleColor для работы, синглплеера и поддерживаемых онлайн-игр.

Для работы античиты не нужны вовсе. Именно поэтому сборка сделана work-first: без
`mangohud`, `gamemode` и игровых рантаймов, которые на 20 ГБ только мешают.

---

## Заметки по размеру

| Что | Объём |
|---|---|
| ISO | ~2.2–2.8 ГБ |
| Установленная система | 7–9 ГБ |
| Свободно на 20 ГБ | 11–13 ГБ под данные и игры |
| ОЗУ в простое (i3) | 350–500 МБ |
| ОЗУ с Firefox + 5 вкладок | 2.2–2.8 ГБ |

`linux-firmware` — мета-пакет (~1.5 ГБ). Если нужен запас, замените его в
`packages.x86_64` на подпакеты под ваше железо (`linux-firmware-amdgpu`,
`linux-firmware-intel`, `linux-firmware-realtek` и т.д., список — `pacman -Ss linux-firmware`).

---

## Диагностика

| Симптом | Причина и решение |
|---|---|
| `mkarchiso: command not found` | `sudo pacman -S archiso` |
| `No space left on device` в work | work-каталог на tmpfs: `-w /var/tmp/archiso-work` |
| Загрузка: `archisolabel=DOUBLECOLOR not found` | метка не совпала; `./prepare.sh` проверяет это автоматически |
| Чёрный экран после выбора пункта | пункт «без KMS», либо `nomodeset` вручную |
| `startx` не стартует | `cat ~/.local/share/doublecolor-startx.log` |
| Нет `Ctrl+Shift+Tab` | `which btop alacritty`; правило i3 требует класс `Sysmon` |
| Медленно всё на eMMC | ожидаемо; проверьте `sudo fstrim -av` |
| `failed to mount /dev/zram0` | `systemctl start systemd-zram-setup@zram0.service` |

Логи сборки: `build/work/` , `mkarchiso -v` печатает каждый шаг.

---

## Ограничение этого репозитория

Профиль написан и проверен на согласованность (метка ISO ↔ boot-конфиги, имена ядер
`linux-zen`, наличие всех файлов), но **ISO здесь не скомпилирован**: `mkarchiso` требует
Arch Linux с root и доступом к `loop`-устройствам. Первая сборка на Arch-хосте — это и есть
финальная проверка; при расхождении с вашей версией `archiso` ориентируйтесь на
`/usr/share/archiso/configs/releng/` как на эталон (в частности, `mkinitcpio.conf.d/archiso.conf`,
который `prepare.sh` подтягивает из releng автоматически).
