#!/usr/bin/env python3
"""Build or check a Vice City 1.1 .dir/.img overlay pair.

The engine reads the .dir as a bare sequence of 32-byte entries (offset, size,
name) with offset and size in 2048-byte sectors. A mod overlay is a normal image
mounted after the stock archives; entries with the same name win over the stock
ones because images are scanned from the last index down.

    scripts/mk-overlay.py mods/my-mod/assets --out mods/my-mod/overlay
    scripts/mk-overlay.py --check mods/my-mod/overlay
"""

import argparse
import os
import struct
import sys

SECTOR = 2048
ENTRY = struct.Struct("<II24s")
KNOWN_EXT = {".dff", ".txd", ".col", ".ifp"}


def collect(src):
    if not os.path.isdir(src):
        sys.exit("not a directory: %s" % src)

    files = {}
    for root, _dirs, names in os.walk(src):
        for name in names:
            path = os.path.join(root, name)
            entry = name.upper()
            if len(entry) > 23:
                sys.exit("entry name longer than 23 bytes: %s" % path)
            try:
                entry.encode("ascii")
            except UnicodeEncodeError:
                sys.exit("entry name is not ASCII: %s" % path)
            if entry in files:
                sys.exit("duplicate entry %s: %s and %s" %
                         (entry, files[entry], path))
            if os.path.splitext(entry)[1].lower() not in KNOWN_EXT:
                print("warning: %s is not a streamed asset type" % entry)
            files[entry] = path
    if not files:
        sys.exit("no files under %s" % src)
    return sorted(files.items())


def build(src, prefix):
    entries = []
    image = bytearray()

    for name, path in collect(src):
        blob = open(path, "rb").read()
        if not blob:
            sys.exit("empty file: %s" % path)
        sectors = (len(blob) + SECTOR - 1) // SECTOR
        offset = len(image) // SECTOR
        image += blob
        image += b"\0" * (sectors * SECTOR - len(blob))
        entries.append((offset, sectors, name))

    img_path = prefix + ".img"
    dir_path = prefix + ".dir"
    with open(img_path, "wb") as f:
        f.write(image)
    with open(dir_path, "wb") as f:
        for offset, sectors, name in entries:
            f.write(ENTRY.pack(offset, sectors, name.encode("ascii")))

    print("%s: %d entries, %d sectors (%d bytes)" %
          (img_path, len(entries), len(image) // SECTOR, len(image)))
    print("%s: %d bytes" % (dir_path, len(entries) * ENTRY.size))


def check(prefix):
    img_path = prefix + ".img"
    dir_path = prefix + ".dir"
    for path in (img_path, dir_path):
        if not os.path.isfile(path):
            sys.exit("missing %s" % path)

    data = open(dir_path, "rb").read()
    if len(data) % ENTRY.size:
        sys.exit("%s is not a whole number of entries" % dir_path)

    total = 0
    names = set()
    for i in range(len(data) // ENTRY.size):
        offset, sectors, raw = ENTRY.unpack_from(data, i * ENTRY.size)
        name = raw.split(b"\0")[0].decode("ascii", "replace")
        if not name:
            sys.exit("entry %d has no name" % i)
        if sectors == 0:
            sys.exit("%s has zero size" % name)
        if offset != total:
            sys.exit("%s starts at sector %d, expected %d" %
                     (name, offset, total))
        if name in names:
            sys.exit("duplicate entry %s" % name)
        names.add(name)
        total += sectors

    size = os.path.getsize(img_path)
    if size < total * SECTOR:
        sys.exit("%s is %d bytes, entries need %d" %
                 (img_path, size, total * SECTOR))
    if size > total * SECTOR:
        print("warning: %d trailing bytes in %s" % (size - total * SECTOR, img_path))
    print("%s: %d entries, %d sectors, ok" % (img_path, len(names), total))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="asset folder, or the prefix to check")
    parser.add_argument("--out", help="output prefix (default: <source>/overlay)")
    parser.add_argument("--check", action="store_true",
                        help="verify an existing prefix instead of building")
    args = parser.parse_args()

    prefix = args.out or os.path.join(args.source, "overlay")
    if args.check:
        check(args.source)
    else:
        build(args.source, prefix)


if __name__ == "__main__":
    main()
