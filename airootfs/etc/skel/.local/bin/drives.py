#!/usr/bin/env python3
"""«Диски» — окно с буквами дисков для DoubleColor OS.

Сверху — буква диска, снизу — название (метка тома, модель или имя устройства).
Схема нумерации:
  * диск только с системой Linux                 -> A:
  * есть чужие ФС (NTFS, exFAT) или другая ОС    -> начиная с C:
  * остальные диски                              -> следующая свободная буква

Буквы — только отображение. Ядро, fstab и загрузчик работают с UUID.
"""

import json
import re
import shutil
import subprocess
import sys

try:
    import gi

    gi.require_version("Gtk", "3.0")
    from gi.repository import Gdk, Gtk, Pango
except (ImportError, ValueError):
    sys.stderr.write(
        "Нужны GTK3 и PyGObject:\n"
        "  sudo pacman -S --needed gtk3 python-gobject\n"
    )
    sys.exit(1)

# Файловые системы, которые не делают диск «чужим».
LINUX_FS = {
    "ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs",
    "swap", "zram", "vfat", "bcachefs",
}


def lsblk():
    result = subprocess.run(
        ["lsblk", "-J", "-o",
         "NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout).get("blockdevices", [])


def walk(node):
    yield node
    for child in node.get("children") or []:
        yield from walk(child)


def is_foreign(fstype):
    if not fstype:
        return False
    return fstype not in LINUX_FS


def collect():
    disks = []
    for top in lsblk():
        if top.get("type") != "disk":
            continue
        parts = [n for n in walk(top) if n.get("type") == "part"]
        disks.append({
            "name": top.get("name") or "",
            "path": top.get("path") or "",
            "model": (top.get("model") or "").strip(),
            "size": top.get("size") or "",
            "parts": parts,
        })
    return disks


def letter_map(disks):
    """A: dlya chistogo diska, inache nachinaya s C:."""
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    used = set()
    letters = {}
    for disk in disks:
        foreign = any(is_foreign(p.get("fstype")) for p in disk["parts"])
        start = alphabet.index("C") if foreign else 0
        for index in range(start, len(alphabet)):
            letter = alphabet[index]
            if letter not in used:
                used.add(letter)
                letters[disk["name"]] = letter + ":"
                break
        else:
            letters[disk["name"]] = "?"
    return letters


def display_name(disk):
    by_mount = {p.get("mountpoint"): p for p in disk["parts"]}
    for key in ("/", "/home"):
        part = by_mount.get(key)
        if part and part.get("label"):
            return part["label"]
    for part in disk["parts"]:
        if part.get("label"):
            return part["label"]
    if disk["model"]:
        return disk["model"]
    return disk["name"]


def mounted_path(disk):
    points = [p["mountpoint"] for p in disk["parts"] if p.get("mountpoint")]
    if not points:
        return None
    points.sort(key=lambda m: {"/": 0, "/home": 1}.get(m, 2))
    return points[0]


def mount_disk(disk):
    for part in disk["parts"]:
        fstype = part.get("fstype")
        if fstype in (None, "swap"):
            continue
        result = subprocess.run(
            ["udisksctl", "mount", "-b", part["path"]],
            capture_output=True, text=True,
        )
        match = re.search(r"at (.+?)\.?$", (result.stdout or "").strip())
        if match:
            return match.group(1)
        if part.get("mountpoint"):
            return part["mountpoint"]
    return None


def open_disk(disk, window):
    path = mounted_path(disk) or mount_disk(disk)
    if not path:
        dialog = Gtk.MessageDialog(
            transient_for=window, modal=True,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK,
            text="Не удалось смонтировать диск",
        )
        dialog.format_secondary_text(
            "Проверьте, что диск исправен и не занят другой системой."
        )
        dialog.run()
        dialog.destroy()
        return
    for opener in ("dolphin", "pcmanfm", "xdg-open"):
        if shutil.which(opener):
            subprocess.Popen([opener, path])
            return
    subprocess.Popen(["xdg-open", path])


class DrivesWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Диски")
        self.set_wmclass("Drives", "Drives")
        self.set_default_size(760, 460)
        self.set_border_width(12)
        self.set_keep_above(True)

        header = Gtk.Label()
        header.set_markup("<b>Диски</b>   <small>клик — открыть</small>")
        header.set_xalign(0)

        flow = Gtk.FlowBox()
        flow.set_valign(Gtk.Align.START)
        flow.set_max_children_per_line(6)
        flow.set_min_children_per_line(2)
        flow.set_selection_mode(Gtk.SelectionMode.NONE)
        flow.set_homogeneous(True)
        flow.set_row_spacing(8)
        flow.set_column_spacing(8)

        disks = collect()
        letters = letter_map(disks)
        if disks:
            for disk in disks:
                flow.add(self.make_tile(disk, letters.get(disk["name"], "?")))
        else:
            empty = Gtk.Label(label="Диски не найдены")
            flow.add(empty)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.add(flow)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.pack_start(header, False, False, 0)
        box.pack_start(scroll, True, True, 0)
        self.add(box)

        self.connect("key-press-event", self.on_key)

    def make_tile(self, disk, letter):
        button = Gtk.Button()
        button.set_relief(Gtk.ReliefStyle.NORMAL)
        button.set_tooltip_text(disk["path"])

        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        inner.set_border_width(8)

        big = Gtk.Label(label=letter)
        big.get_style_context().add_class("drive-letter")

        name = Gtk.Label(label=display_name(disk))
        name.get_style_context().add_class("drive-name")
        name.set_ellipsize(Pango.EllipsizeMode.END)
        name.set_max_width_chars(16)

        size = Gtk.Label(label=disk["size"])
        size.get_style_context().add_class("drive-size")

        inner.pack_start(big, False, False, 0)
        inner.pack_start(name, False, False, 0)
        inner.pack_start(size, False, False, 0)
        button.add(inner)
        button.connect("clicked", lambda _b: open_disk(disk, self))
        return button

    def on_key(self, _widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()
        return False


def main():
    css = b"""
    .drive-letter { font-size: 30px; font-weight: bold; }
    .drive-name   { font-size: 11px; }
    .drive-size   { font-size: 9px; opacity: 0.6; }
    """
    provider = Gtk.CssProvider()
    provider.load_from_data(css)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    window = DrivesWindow()
    window.connect("destroy", Gtk.main_quit)
    window.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
