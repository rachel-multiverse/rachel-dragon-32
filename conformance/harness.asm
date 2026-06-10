; =============================================================================
; RUBP CODEC CONFORMANCE HARNESS (Dragon 32 / 6809)
; =============================================================================
; Drives the REAL client codec from ../src/rubp.asm with the golden fixture
; values and leaves the results in a RAM capture region. Built as a Dragon
; cartridge ROM ($C000): once BASIC boots, the cartridge autostart FIRQ jumps
; here, every test runs, and the harness parks. Run headless under
; emu198x-dragon, then memory_read the regions and diff against
; rubp-messages-v1.json. See run.py.
;
;   Encoders — build HELLO / PLAY_CARD / DRAW_CARD with the fixture field
;     values and copy each 64-byte TX_BUFFER out to a capture slot.
;   Decoders — load the golden WELCOME / GAME_STATE vectors into RX_BUFFER,
;     run the parsers, and capture what they extract.
;
; Capture region (RAM, clear of the codec/game vars at $6000-$6125):
;   $6800  HELLO encoder output      (64)
;   $6840  PLAY_CARD encoder output  (64)
;   $6880  DRAW_CARD encoder output  (64)
;   $68C0  WELCOME decode  : playerID lo/hi, gameID lo/hi, playerCount, connState
;   $68D0  GAME_STATE decode: currentTurn, direction, topCard, nominatedSuit,
;          pendingDraws, deckCount, playerCounts[8], gameOver, winnerIndex,
;          observedHash[8], hashValid
;   $68FF  done marker = $AA once every test has run

        include "../src/equates.asm"

CAP_HELLO   equ     $6800
CAP_PLAY    equ     $6840
CAP_DRAW    equ     $6880
CAP_WELCOME equ     $68C0
CAP_GS      equ     $68D0
CAP_DONE    equ     $68FF

        org     $C000

; -----------------------------------------------------------------------------
; Cartridge entry — reached via the autostart FIRQ once BASIC has booted.
; -----------------------------------------------------------------------------
cart_entry
        orcc    #$50                    ; mask IRQ/FIRQ — we own the machine now
        lds     #$7F00                  ; clean stack in high RAM

        jsr     test_hello
        jsr     test_play
        jsr     test_draw
        jsr     test_welcome
        jsr     test_game_state

        lda     #$AA
        sta     CAP_DONE
park
        bra     park

; -----------------------------------------------------------------------------
; HELLO: name DRAGON, seq 0x0021, playerID 0xFFFF, gameID 0x0042.
; -----------------------------------------------------------------------------
test_hello
        ldd     #$0021
        std     RUBP_SEQ
        ldd     #$FFFF
        std     RUBP_PLAYER_ID
        ldd     #$0042
        std     RUBP_GAME_ID
        jsr     send_hello
        ldy     #CAP_HELLO
        jsr     copy_tx
        rts

; -----------------------------------------------------------------------------
; PLAY_CARD: one card A-hearts (0x0E) selected, nominated suit clubs (0x02),
; seq 0x0022, playerID 0x0001, gameID 0x0042, observed hash = the play vector's.
; -----------------------------------------------------------------------------
test_play
        ldd     #$0022
        std     RUBP_SEQ
        ldd     #$0001
        std     RUBP_PLAYER_ID
        ldd     #$0042
        std     RUBP_GAME_ID
        lda     #$0E                    ; MY_HAND[0] = A-hearts
        sta     MY_HAND
        lda     #1
        sta     HAND_COUNT
        lda     #$01                    ; SELECTED_LO bit0 = card 0 selected
        sta     SELECTED_LO
        clr     SELECTED_HI
        lda     #$02                    ; nominated suit = clubs
        sta     NOMINATED_SUIT
        ldx     #hash_play
        jsr     set_obs_hash
        jsr     send_play_cards
        ldy     #CAP_PLAY
        jsr     copy_tx
        rts

; -----------------------------------------------------------------------------
; DRAW_CARD: reason 0, seq 0x0023, playerID 0x0001, gameID 0x0042,
; observed hash = the draw vector's.
; -----------------------------------------------------------------------------
test_draw
        ldd     #$0023
        std     RUBP_SEQ
        ldd     #$0001
        std     RUBP_PLAYER_ID
        ldd     #$0042
        std     RUBP_GAME_ID
        ldx     #hash_draw
        jsr     set_obs_hash
        lda     #0                      ; reason = cannot play
        jsr     send_draw
        ldy     #CAP_DRAW
        jsr     copy_tx
        rts

; -----------------------------------------------------------------------------
; WELCOME: parse the golden vector, capture what it extracts.
; -----------------------------------------------------------------------------
test_welcome
        ldx     #welcome_msg
        jsr     load_rx
        jsr     parse_welcome
        lda     RUBP_PLAYER_ID+1        ; playerID low
        sta     CAP_WELCOME+0
        lda     RUBP_PLAYER_ID          ; playerID high
        sta     CAP_WELCOME+1
        lda     RUBP_GAME_ID+1          ; gameID low
        sta     CAP_WELCOME+2
        lda     RUBP_GAME_ID            ; gameID high
        sta     CAP_WELCOME+3
        lda     PLAYER_COUNT
        sta     CAP_WELCOME+4
        lda     CONN_STATE
        sta     CAP_WELCOME+5
        rts

; -----------------------------------------------------------------------------
; GAME_STATE: clear the hash state first so we prove the parser sets it, then
; parse the golden vector and capture everything it extracts.
; -----------------------------------------------------------------------------
test_game_state
        clr     HASH_VALID
        ldx     #OBSERVED_HASH
        ldb     #8
tgs_clr
        clr     ,x+
        decb
        bne     tgs_clr

        ldx     #game_state_msg
        jsr     load_rx
        jsr     process_game_state

        lda     CURRENT_TURN
        sta     CAP_GS+0
        lda     DIRECTION
        sta     CAP_GS+1
        lda     DISCARD_TOP
        sta     CAP_GS+2
        lda     NOMINATED_SUIT
        sta     CAP_GS+3
        lda     PENDING_DRAWS
        sta     CAP_GS+4
        lda     DECK_COUNT
        sta     CAP_GS+5
        ldx     #PLAYER_COUNTS
        ldy     #CAP_GS+6
        ldb     #8
tgs_pc
        lda     ,x+
        sta     ,y+
        decb
        bne     tgs_pc                  ; CAP_GS+6 .. +13
        lda     GAME_OVER
        sta     CAP_GS+14
        lda     WINNER_INDEX
        sta     CAP_GS+15
        ldx     #OBSERVED_HASH
        ldy     #CAP_GS+16
        ldb     #8
tgs_h
        lda     ,x+
        sta     ,y+
        decb
        bne     tgs_h                   ; CAP_GS+16 .. +23
        lda     HASH_VALID
        sta     CAP_GS+24
        rts

; -----------------------------------------------------------------------------
; Helpers.
; -----------------------------------------------------------------------------
; Copy 8 bytes at X into OBSERVED_HASH and mark it valid.
set_obs_hash
        ldy     #OBSERVED_HASH
        ldb     #8
soh_loop
        lda     ,x+
        sta     ,y+
        decb
        bne     soh_loop
        lda     #1
        sta     HASH_VALID
        rts

; Copy 64 bytes from X into RX_BUFFER.
load_rx
        ldy     #RX_BUFFER
        ldb     #64
lr_loop
        lda     ,x+
        sta     ,y+
        decb
        bne     lr_loop
        rts

; Copy the 64-byte TX_BUFFER to Y.
copy_tx
        ldx     #TX_BUFFER
        ldb     #64
ct_loop
        lda     ,x+
        sta     ,y+
        decb
        bne     ct_loop
        rts

; The real client codec under test.
        include "../src/rubp.asm"

; Serial stubs — the codec references these; we want no real I/O.
net_send
        rts
net_recv
        orcc    #$01                    ; report "no data"
        rts

; Golden observed-state-hash inputs (the play/draw fixture vectors).
hash_play   fcb     $11,$22,$33,$44,$55,$66,$77,$88
hash_draw   fcb     $88,$77,$66,$55,$44,$33,$22,$11

; Golden WELCOME / GAME_STATE vectors (regenerated from the fixtures by run.py).
        include "build/vectors.inc"
