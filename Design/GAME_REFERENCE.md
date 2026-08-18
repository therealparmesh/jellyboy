# Game-informed interface reference

jellyboy adapts the menu language of the English Pokémon Red and Blue Game Boy releases without shipping copied glyphs, borders, Pokémon names, character artwork, logos, maps, or sprites in the app interface.

The interaction model is measured from `pret/pokered` commit `0cd19d3b877b7dc66d12c7050bed9a7f38154d4b`, a disassembly whose build target reproduces the game data. Relevant behavioral sources are `home/text.asm`, `home/window.asm`, `home/start_menu.asm`, `home/print_text.asm`, and `engine/menus/draw_start_menu.asm`.

The Red and Blue Game Boy Color compatibility mappings are verified against SameBoy commit `213a12ce93d66b105a113debd9396306066a7cfc`: Red selects palette combination 13, whose background is palette 4; Blue selects combination 11, whose background is palette 28.

## Rules carried into jellyboy

- The source display is a 20 by 18 grid of 8 px tiles.
- Text uses jellyboy's original variable-width, mostly 5 by 7 glyph constructions. Narrow glyphs use their own compact advances, avoiding oversized gaps around `i` and `l` on high-density Apple displays. Menu rows still use two tile rows, matching the source interaction rhythm.
- A text box uses an original stepped double-track frame and plain interior. jellyboy scales that structure to accessible touch targets rather than adding nested ornamental frames or cartridge chrome.
- The active menu row uses the filled right arrow; inactive rows reserve the same leading cell without inventing checkmarks.
- Menus replace or dismiss immediately. Cursor changes and pressed-state inversion provide feedback. Modern slides, springs, fades, and background dimming are excluded.
- Light mode uses the selected version's CGB compatibility background palette exactly as RGB555 values. Dark mode is explicitly a derived rearrangement of the same four colors, because the games contain no dark UI mode.

## Palette data

| Version | CGB combination | Background palette | RGB555 lightest to darkest     |
| ------- | --------------: | -----------------: | ------------------------------ |
| Red     |              13 |                  4 | `7FFF`, `421F`, `1CF2`, `0000` |
| Blue    |              11 |                 28 | `7FFF`, `7E8C`, `7C00`, `0000` |

The bundled `jellyboy-pixel.ttf` is generated entirely from the local constructions in `script/generate_pixel_font.py`; the generator has no ROM, disassembly-art, image-download, or tile-sheet input. `PixelFrame` is drawn from separate original top, bottom, left, right, and corner patterns. These assets preserve a restrained pixel vocabulary without copying the source game's glyph or border pixels.

References:

- [Pinned pokered behavior reference](https://github.com/pret/pokered/tree/0cd19d3b877b7dc66d12c7050bed9a7f38154d4b)
- [Pinned SameBoy CGB boot ROM palette table](https://github.com/LIJI32/SameBoy/blob/213a12ce93d66b105a113debd9396306066a7cfc/BootROMs/cgb_boot.asm)
- [Pan Docs compatibility palette behavior](https://gbdev.io/pandocs/Power_Up_Sequence.html#compatibility-palettes)
