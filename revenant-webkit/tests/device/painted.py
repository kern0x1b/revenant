#!/usr/bin/env python3
"""How much of the page area a screenshot actually drew.

    tests/device/painted.py SHOT [R,G,B]

A blank page is the failure this catches, and "blank" has to mean the page area
only: the browser's own chrome is always painted, so a screenshot is never
uniformly white and a whole-image measure would call every failure a success.
With a colour, it reports how much of the page area is that colour instead.
"""
import argparse
import sys

PAGE_AREA = (0, 150, 640, 880)
TOLERANCE = 40


def colour(text):
    parts = tuple(int(part) for part in text.split(","))
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("a colour is R,G,B")
    return parts


def share(matched, total, empty):
    percent = matched * 100 // total
    return empty if percent < 1 else f"{percent}%"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("shot", help="screenshot to measure")
    parser.add_argument("wanted", nargs="?", type=colour, help="R,G,B to look for instead of any ink")
    args = parser.parse_args()

    try:
        from PIL import Image
    except ImportError:
        print("no PIL")
        return 0

    try:
        image = Image.open(args.shot).crop(PAGE_AREA)
    except Exception:
        print("no shot")
        return 0

    if args.wanted is None:
        pixels = list(image.convert("L").getdata())
        print(share(sum(1 for value in pixels if value < 200), len(pixels), "blank"))
        return 0

    pixels = list(image.convert("RGB").getdata())
    matched = sum(1 for pixel in pixels
                  if all(abs(pixel[band] - args.wanted[band]) < TOLERANCE for band in range(3)))
    print(share(matched, len(pixels), "absent"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
