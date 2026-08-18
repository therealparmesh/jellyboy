#!/usr/bin/env python3
"""Generate jellyboy's original compact pixel font."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen


DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "Resources" / "jellyboy-pixel.ttf"
UNIT = 100
GRID_HEIGHT = 7


def rows(value: str) -> tuple[str, ...]:
    return tuple(value.split("/"))


# Original 5-by-7 and narrow pixel constructions drawn for jellyboy. Lowercase
# letters deliberately use a short x-height so the wordmark remains lowercase.
PATTERNS: dict[str, tuple[str, ...]] = {
    "A": rows(".###./#...#/#...#/#####/#...#/#...#/#...#"),
    "B": rows("####./#...#/#...#/####./#...#/#...#/####."),
    "C": rows(".####/#..../#..../#..../#..../#..../.####"),
    "D": rows("####./#...#/#...#/#...#/#...#/#...#/####."),
    "E": rows("#####/#..../#..../####./#..../#..../#####"),
    "F": rows("#####/#..../#..../####./#..../#..../#...."),
    "G": rows(".####/#..../#..../#.###/#...#/#...#/.###."),
    "H": rows("#...#/#...#/#...#/#####/#...#/#...#/#...#"),
    "I": rows("###/.#./.#./.#./.#./.#./###"),
    "J": rows("..###/...#./...#./...#./...#./#..#./.##.."),
    "K": rows("#...#/#..#./#.#../##.../#.#../#..#./#...#"),
    "L": rows("#..../#..../#..../#..../#..../#..../#####"),
    "M": rows("#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#"),
    "N": rows("#...#/##..#/#.#.#/#.#.#/#..##/#...#/#...#"),
    "O": rows(".###./#...#/#...#/#...#/#...#/#...#/.###."),
    "P": rows("####./#...#/#...#/####./#..../#..../#...."),
    "Q": rows(".###./#...#/#...#/#...#/#.#.#/#..#./.##.#"),
    "R": rows("####./#...#/#...#/####./#.#../#..#./#...#"),
    "S": rows(".####/#..../#..../.###./....#/....#/####."),
    "T": rows("#####/..#../..#../..#../..#../..#../..#.."),
    "U": rows("#...#/#...#/#...#/#...#/#...#/#...#/.###."),
    "V": rows("#...#/#...#/#...#/#...#/#...#/.#.#./..#.."),
    "W": rows("#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#"),
    "X": rows("#...#/#...#/.#.#./..#../.#.#./#...#/#...#"),
    "Y": rows("#...#/#...#/.#.#./..#../..#../..#../..#.."),
    "Z": rows("#####/....#/...#./..#../.#.../#..../#####"),
    "a": rows("...../...../.###./....#/.####/#...#/.####"),
    "b": rows("#..../#..../#.##./##..#/#...#/#...#/####."),
    "c": rows("...../...../.####/#..../#..../#..../.####"),
    "d": rows("....#/....#/.##.#/#..##/#...#/#...#/.####"),
    "e": rows("...../...../.###./#...#/#####/#..../.####"),
    "f": rows("..##./.#..#/.#.../####./.#.../.#.../.#..."),
    "g": rows("...../...../.####/#...#/.####/....#/.###."),
    "h": rows("#..../#..../#.##./##..#/#...#/#...#/#...#"),
    "i": rows("#/./#/#/#/#/#"),
    "j": rows("..#./..../..#./..#./..#./#.#./.##."),
    "k": rows("#..../#..../#..#./#.#../##.../#.#../#..#."),
    "l": rows("##./.#./.#./.#./.#./.#./.##"),
    "m": rows("...../...../##.#./#.#.#/#.#.#/#...#/#...#"),
    "n": rows("...../...../#.##./##..#/#...#/#...#/#...#"),
    "o": rows("...../...../.###./#...#/#...#/#...#/.###."),
    "p": rows("...../...../####./#...#/####./#..../#...."),
    "q": rows("...../...../.####/#...#/.####/....#/....#"),
    "r": rows("...../...../#.##./##..#/#..../#..../#...."),
    "s": rows("...../...../.####/#..../.###./....#/####."),
    "t": rows(".#.../.#.../####./.#.../.#.../.#..#/.##.."),
    "u": rows("...../...../#...#/#...#/#...#/#..##/.##.#"),
    "v": rows("...../...../#...#/#...#/#...#/.#.#./..#.."),
    "w": rows("...../...../#...#/#...#/#.#.#/##.##/#...#"),
    "x": rows("...../...../#...#/.#.#./..#../.#.#./#...#"),
    "y": rows("...../...../#...#/.#.#./..#../.#.../#...."),
    "z": rows("...../...../#####/...#./..#../.#.../#####"),
    "0": rows(".###./#..##/#.#.#/#.#.#/##..#/#...#/.###."),
    "1": rows(".#./##./.#./.#./.#./.#./###"),
    "2": rows(".###./#...#/....#/...#./..#../.#.../#####"),
    "3": rows("####./....#/....#/.###./....#/....#/####."),
    "4": rows("...#./..##./.#.#./#..#./#####/...#./...#."),
    "5": rows("#####/#..../#..../####./....#/....#/####."),
    "6": rows(".###./#..../#..../####./#...#/#...#/.###."),
    "7": rows("#####/....#/...#./..#../.#.../.#.../.#..."),
    "8": rows(".###./#...#/#...#/.###./#...#/#...#/.###."),
    "9": rows(".###./#...#/#...#/.####/....#/....#/.###."),
    "(": rows("..#./.#../#.../#.../#.../.#../..#."),
    ")": rows(".#../..#./...#/...#/...#/..#./.#.."),
    "[": rows("###/#../#../#../#../#../###"),
    "]": rows("###/..#/..#/..#/..#/..#/###"),
    ":": rows("./#/#/./#/#/."),
    ";": rows("./#/#/./#/#/#"),
    "é": rows("..#../.#.../.###./#...#/#####/#..../.####"),
    "'": rows("#/#/././././."),
    "-": rows("...../...../...../#####/...../...../....."),
    "?": rows(".###./#...#/....#/...#./..#../...../..#.."),
    "!": rows("#/#/#/#/#/./#"),
    ".": rows("././././././#"),
    "▶": rows("#..../###../#####/#####/#####/###../#...."),
    "▼": rows("#####/.###./.###./..#../..#../...../....."),
    "×": rows("...../#...#/.#.#./..#../.#.#./#...#/....."),
    "/": rows("....#/....#/...#./..#../.#.../#..../#...."),
    ",": rows("./././././#/#"),
}


def validate_patterns() -> None:
    for character, pattern in PATTERNS.items():
        if len(pattern) != GRID_HEIGHT:
            raise ValueError(f"{character!r} must have {GRID_HEIGHT} rows")
        width = len(pattern[0])
        if width == 0 or width > 5 or any(len(row) != width for row in pattern):
            raise ValueError(f"{character!r} has an invalid width")
        if any(pixel not in ".#" for row in pattern for pixel in row):
            raise ValueError(f"{character!r} contains an invalid pixel")


def glyph_from_pattern(pattern: tuple[str, ...]) -> object:
    pen = TTGlyphPen(None)
    for row, values in enumerate(pattern):
        for column, pixel in enumerate(values):
            if pixel != "#":
                continue
            x = column * UNIT
            y = (GRID_HEIGHT - row - 1) * UNIT
            pen.moveTo((x, y))
            pen.lineTo((x + UNIT, y))
            pen.lineTo((x + UNIT, y + UNIT))
            pen.lineTo((x, y + UNIT))
            pen.closePath()
    return pen.glyph()


def glyph_name(character: str) -> str:
    return f"uni{ord(character):04X}"


def build_font(output: Path) -> None:
    validate_patterns()
    glyph_order = [".notdef", "space"] + [glyph_name(character) for character in PATTERNS]
    glyphs = {
        ".notdef": glyph_from_pattern(PATTERNS["?"]),
        "space": glyph_from_pattern(rows(".../.../.../.../.../.../...")),
    }
    horizontal_metrics = {".notdef": (600, 0), "space": (400, 0)}

    for character, pattern in PATTERNS.items():
        name = glyph_name(character)
        glyphs[name] = glyph_from_pattern(pattern)
        horizontal_metrics[name] = ((len(pattern[0]) + 1) * UNIT, 0)

    builder = FontBuilder(800, isTTF=True)
    builder.setupGlyphOrder(glyph_order)
    character_map = {ord(" "): "space"}
    character_map.update({ord(character): glyph_name(character) for character in PATTERNS})
    character_map[ord("…")] = glyph_name(".")
    character_map[ord("•")] = glyph_name(".")
    character_map[ord("−")] = glyph_name("-")
    builder.setupCharacterMap(character_map)
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(horizontal_metrics)
    builder.setupHorizontalHeader(ascent=700, descent=0, lineGap=100)
    builder.setupNameTable(
        {
            "familyName": "jellyboy pixel",
            "styleName": "Regular",
            "uniqueFontIdentifier": "jellyboy-pixel-original-v1",
            "fullName": "jellyboy pixel Regular",
            "psName": "jellyboy-pixel-regular",
            "version": "Version 1.0",
        }
    )
    builder.setupOS2(
        sTypoAscender=700,
        sTypoDescender=0,
        sTypoLineGap=100,
        usWinAscent=700,
        usWinDescent=0,
    )
    builder.setupPost(isFixedPitch=0)
    builder.setupMaxp()
    output.parent.mkdir(parents=True, exist_ok=True)
    builder.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()
    try:
        build_font(arguments.output)
    except Exception as error:
        print(f"font generation failed: {error}", file=sys.stderr)
        return 1
    print(arguments.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
