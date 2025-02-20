#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

from pathlib import Path
from argparse import ArgumentParser

if __name__ == "__main__":
    parser = ArgumentParser(
        prog="Filelist cleaner",
        description="Resolve duplicates in filelist")
    parser.add_argument("filename")
    parser.add_argument("-o", "--output", help="Path to output file")

    args = parser.parse_args()

    filelist = Path(args.filename)
    assert filelist.exists() and not filelist.is_dir(), "Filelist must be a file!"

    flist_content = filelist.read_text().split("\n")

    files = {}
    dirs = {}
    result_flist = []
    for l in flist_content:
        l = l.strip()

        if l.startswith("+incdir+"):
            l = l.split()[0]  # Ignore everything past 1st whitespace
            dirs[l] = dirs.get(l, 0) + 1
            result = l if (dirs[l] == 1) else ("#" + l + " - ALREADY INCLUDED")
        elif not l.startswith("#") and len(l) > 0:
            l = l.split()[0]  # Ignore everything past 1st whitespace
            files[l] = files.get(l, 0) + 1
            result = l if (files[l] == 1) else ("#" + l + " - ALREADY INCLUDED")
        else:
            result = l

        result_flist.append(result)

    fixed_filelist = ""
    for l in result_flist:
        fixed_filelist += l + "\n"

    if args.output:
        out_flist = Path(args.output)
        assert not out_flist.is_dir(), "Output file can not be a directory!"
    else:
        out_flist = filelist

    print(f"Resolved filelist written to {out_flist}")

    out_flist.write_text(fixed_filelist)
