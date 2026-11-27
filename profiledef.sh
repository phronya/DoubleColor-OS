#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="doublecoloros"
iso_label="DOUBLECOLOR"
iso_publisher="DoubleColor <https://example.org/doublecolor>"
iso_application="DoubleColor OS x.0.02711.0 Live - рабочая ОС на базе Arch Linux"
iso_version="x.0.02711.0"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.xinitrc"]="0:0:755"
  ["/root/.local/bin/sysmon.sh"]="0:0:755"
  ["/root/.local/bin/drives.py"]="0:0:755"
  ["/root/.local/bin/wine-bootstrap.sh"]="0:0:755"
  ["/root/.local/bin/install-yay.sh"]="0:0:755"
  ["/root/.local/bin/doublecolor-postinstall.sh"]="0:0:755"
  ["/etc/skel/.xinitrc"]="0:0:755"
  ["/etc/skel/.local/bin/sysmon.sh"]="0:0:755"
  ["/etc/skel/.local/bin/drives.py"]="0:0:755"
  ["/etc/skel/.local/bin/wine-bootstrap.sh"]="0:0:755"
  ["/etc/skel/.local/bin/install-yay.sh"]="0:0:755"
  ["/etc/skel/.local/bin/install-chrome.sh"]="0:0:755"
  ["/etc/skel/.local/bin/doublecolor-postinstall.sh"]="0:0:755"
  ["/usr/local/bin/doublecolor-install"]="0:0:755"
  ["/usr/local/bin/doublecolor-portable"]="0:0:755"
)
