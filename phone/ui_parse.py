#!/usr/bin/env python3
"""Parse uiautomator window_dump.xml -> [x1,y1][x2,y2] label lines (stdlib only).
Usage: ui_parse.py <window_dump.xml>  (prints to stdout, max 200 lines)
Prefers content-desc, falls back to text. Skips empty/unlabeled nodes.
"""
import re, sys, xml.etree.ElementTree as ET

BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")

def main(path):
    try:
        root = ET.parse(path).getroot()
    except Exception as e:
        print(f"ui_parse: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(1)
    n = 0
    for node in root.iter("node"):
        if n >= 200:
            break
        label = (node.get("content-desc") or node.get("text") or "").strip()
        if not label:
            continue
        b = node.get("bounds", "")
        if not BOUNDS.search(b):
            continue
        print(f"{b} {label[:120]}")
        n += 1

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: ui_parse.py <window_dump.xml>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
