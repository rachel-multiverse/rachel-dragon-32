# Rachel - Dragon 32/Tandy CoCo Client

A render-only client for the Rachel card game, written in 6809 assembly for Dragon 32/64 and Tandy Color Computer.

## Requirements

- Dragon 32/64 or Tandy CoCo (or emulator like XRoar)
- DragonWiFi or CoCoSDC with networking
- Rachel iOS host application

## Building

```bash
make
```

Requires asm6809 or lwasm cross-assembler.

## Features

- 32-column text display
- TCP/IP networking via DragonWiFi
- RUBP binary protocol (64-byte messages)
- Compatible with Dragon and CoCo

## Architecture

The 6809 is a more elegant CPU than the 6502:
- 16-bit accumulators (D = A:B)
- Index registers (X, Y)
- User/System stack pointers
- Position-independent code support

Display uses the VDG (Video Display Generator):
- 32x16 text mode (standard)
- Memory-mapped at $0400

## Controls

- Left/Right: Move cursor
- Space: Select/deselect card
- Enter: Play selected cards
- D: Draw card
- Break: Quit

## Network Protocol

Uses RUBP (Rachel Unified Binary Protocol):
- 64-byte fixed-size messages
- 16-byte header + 48-byte payload
- Big-endian byte order

Full specification: [rachel-multiverse/protocol](https://github.com/rachel-multiverse/protocol) — also rendered at <https://rachel.stevehill.xyz/protocol>.

## License

MIT License - See LICENSE file
