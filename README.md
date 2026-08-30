# Rachel - Dragon 64 Client

A network client for the Rachel card game, written in 6809 assembly for the
Dragon 64.

## Requirements

- Dragon 64 (or an emulator such as XRoar with its 6551 serial port model)
- Hayes-compatible RS-232 WiFi modem supporting transparent `ATDhost:port`
- Rachel iOS host application

## Building

```bash
make
```

Requires asm6809 or lwasm cross-assembler.

## Features

- 32-column text display
- TCP/IP through the Dragon 64's on-board SY6551 and a serial WiFi modem
- RUBP binary protocol (64-byte messages)
- Dragon 32 and CoCo need the proposed 6551 cartridge described in
  `docs/dragon32-coco-network-cartridge.md`; they are not supported by the
  current binary.

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
