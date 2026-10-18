# Nekketsu — Super Dodge Ball for MiSTer

English · [한국어](README.ko.md) · [日本語](README.ja.md)

A MiSTer FPGA core for **Super Dodge Ball / Nekketsu Koukou Dodgeball Bu** (熱血高校ドッジボール部), the 1987 arcade game by Technos Japan.

This is a hobby project. It is **not an official jotego core**, although it is built on jotego's JTFRAME framework and borrows heavily from his Renegade and Double Dragon cores.

## AI-assisted development

This core was developed with the help of an AI coding assistant (Anthropic's Claude, through Claude Code).

## Supported games

| MAME set | Title | MRA |
|---|---|---|
| `nkdodge` | Nekketsu Koukou Dodgeball Bu (Japan) | `mra/Nekketsu Koukou Dodgeball Bu (Japan).mra` |
| `spdodgeb` | Super Dodge Ball (US) | `mra/Super Dodge Ball (US).mra` |

The bootleg `nkdodgeb` is not supported. ROMs are not included: put your own MAME sets (`nkdodge.zip`, `spdodgeb.zip`) in `games/mame/`.

## Goal: behave like the PCB

The aim is to behave like the original PCB, not to copy an emulator. Where sources disagree, this order decides:

1. The original PCB (recordings of real hardware).
2. Schematics of sibling Technos boards of the same generation, mainly Renegade (TA-0018), as redrawn in [jtcores](https://github.com/jotego/jtcores) (`cores/kunio/sch`).
3. MAME's `technos/spdodgeb.cpp` driver: trusted for what the game's program sees (memory map, I/O, MCU), used only as a hint for video timing.

No schematics of the Super Dodge Ball board (TA-0022) are known to be public.

## Hardware

| Part | Chip | Implementation |
|---|---|---|
| Main CPU | 6502 @ 2 MHz | `jt65c02` |
| Sound CPU | HD68A09P | `mc6809i` through `jtframe_sys6809` |
| MCU (inputs, protection) | HD63701Y0 @ 4 MHz (clock unconfirmed) | `jt63701y`, running the dumped ROM |
| FM | YM3812 | `jtopl2` |
| ADPCM | 2 × MSM5205 | `jt5205` |
| Video | 6 MHz pixel clock, 384 × 272 total, 256 × 238 visible | `jtframe_vtimer`, `jtframe_scroll`, own sprite engine |
| Colours | two colour PROMs, 4 bits per R/G/B | own colour mixer |

## Status

Works:

- Both sets boot, pass the MCU check and play.
- Music, sound effects and voices.
- Background, sprites and colours. Video timing follows the line counter of the sibling Renegade board: 238 visible lines (MAME shows 240, starting 9 lines higher), and the split under the score bar comes from the game's own IRQ timing. Over the lines both show, the attract mode matches MAME pixel for pixel except the first line under the score bar, which MAME leaves on the score bar's scroll.
- Double-tap to run (MCU input processing).
- Pause (JTFRAME, `P` key).

Known issues:

- During play, sprites sometimes flash while the court scrolls. The real PCB moves sprites and background together.
- Two-player play, DIP switches and reset have not been checked yet.
- Flip screen and cocktail mode are not supported.

## Controls

8-way joystick and two buttons:

| Input | Action |
|---|---|
| Button 1 | Shoot |
| Button 2 | Pass |
| Both buttons | Jump |
| Direction twice quickly | Run |

DIP switches (defaults come from the MRA, change them in the OSD): Coin A, Coin B, Demo Sounds, Difficulty, Allow Continue. Flip Screen is not offered.

## Building

See [BUILD.md](BUILD.md). The core is built inside a [jtcores](https://github.com/jotego/jtcores) checkout with jotego's `jtcore` tool.

## Credits

- **Jose Tejada (jotego)**: JTFRAME, and the cores and modules this one is based on: jtkunio (Renegade), jtdd (Double Dragon), `jt65c02`, `jt63701y`, `jtopl`, `jt5205`, `jtframe_scroll` and the Renegade schematics. https://github.com/jotego/jtcores
- **Alexey Melnikov (sorgelig) and the MiSTer project**: the MiSTer framework (`sys/`) that JTFRAME uses.
- **MAME**: the `spdodgeb` driver by Paul Hampson and Nicola Salmoria, used as a reference (no MAME code is included).
- **Technos Japan**: the original game.

## License

GPLv3, see [LICENSE](LICENSE). Parts taken from jtcores keep their GPLv3 licence and copyright headers.
