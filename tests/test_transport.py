#!/usr/bin/env python3
"""Static regression checks for the Dragon 64's on-board 6551."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
EQUATES = (ROOT / "src/equates.asm").read_text()
SOURCE = (ROOT / "src/net/wifi.asm").read_text()
def test_dragon64_6551_contract() -> None:
    for register, address in {"ACIA_DATA": "$FF04", "ACIA_STATUS": "$FF05", "ACIA_COMMAND": "$FF06", "ACIA_CONTROL": "$FF07"}.items():
        assert register in EQUATES and address in EQUATES
    assert "ACIA_RDRF       equ     %00001000" in EQUATES
    assert "ACIA_TDRE       equ     %00010000" in EQUATES
    assert "lda     #$1E" in SOURCE
    assert "lda     #$0B" in SOURCE
    assert "fcc     /ATD/" in SOURCE
    assert "fcc     /:8765/" in SOURCE
if __name__ == "__main__":
    test_dragon64_6551_contract()
    print("Dragon 64 transport checks passed")
