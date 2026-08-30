# Dragon 32 / CoCo network cartridge

The current Rachel client targets the real SY6551 ACIA built into the Dragon
64 at `$FF04-$FF07`. A stock Dragon 32 has no ACIA, and CoCo compatibility
should not be claimed merely because both machines use a 6809.

A practical add-on should reproduce the Dragon 64 register contract:

- 65C51/6551-compatible UART decoded at `$FF04-$FF07`
- 1.8432 MHz UART crystal
- buffered cartridge-bus address/data/control signals
- 3.3 V level conversion to an ESP32-class module
- transparent Hayes `ATDhost:port` firmware, with RTS/CTS flow control
- physical bypass or decode-disable option for use on a Dragon 64

Keeping the Dragon 64 addresses means the same Rachel transport can run on
both machines. A CoCo variant must first confirm that `$FF04-$FF07` does not
collide with the target model or common Multi-Pak hardware. Schematics,
Gerbers, firmware, and real-hardware signal-integrity tests are required before
calling this a supported adapter.
