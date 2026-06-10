; =============================================================================
; DRAGON 32/COCO RUBP PROTOCOL MODULE (6809)
; =============================================================================
; RUBP v1 codec. Builds 64-byte messages into TX_BUFFER and parses them out of
; RX_BUFFER. All working storage lives in the RAM map (equates.asm) so this
; module is pure code + read-only data and can be assembled into a cartridge
; ROM for the conformance harness as-is.
;
; The 6809 is big-endian, so the multi-byte header and payload fields store
; straight to the wire with no byte-swapping — this is the first client whose
; CPU endianness matches the protocol.

; -----------------------------------------------------------------------------
; rubp_init — reset the sequence counter.
; -----------------------------------------------------------------------------
rubp_init
        ldd     #0
        std     RUBP_SEQ
        rts

; -----------------------------------------------------------------------------
; build_header — write the 16-byte RUBP v1 header into TX_BUFFER.
; A = message type. Sequence is written big-endian then post-incremented.
; -----------------------------------------------------------------------------
build_header
        sta     MSG_TYPE_TEMP
        ldx     #TX_BUFFER
        lda     #'R'
        sta     ,x+
        lda     #'A'
        sta     ,x+
        lda     #'C'
        sta     ,x+
        lda     #'H'
        sta     ,x+
        lda     #PROTOCOL_VER           ; version @4
        sta     ,x+
        lda     MSG_TYPE_TEMP           ; type @5
        sta     ,x+
        lda     RUBP_SEQ                ; sequence @6-7 (big-endian)
        sta     ,x+
        lda     RUBP_SEQ+1
        sta     ,x+
        ldd     RUBP_SEQ                ; post-increment 16-bit sequence
        addd    #1
        std     RUBP_SEQ
        lda     RUBP_PLAYER_ID          ; playerID @8-9 (big-endian)
        sta     ,x+
        lda     RUBP_PLAYER_ID+1
        sta     ,x+
        lda     RUBP_GAME_ID            ; gameID @10-11 (big-endian)
        sta     ,x+
        lda     RUBP_GAME_ID+1
        sta     ,x+
        clra                            ; timestamp @12-15 = 0
        sta     ,x+
        sta     ,x+
        sta     ,x+
        sta     ,x+
        rts

; -----------------------------------------------------------------------------
; clear_payload — zero the 48-byte payload of TX_BUFFER.
; -----------------------------------------------------------------------------
clear_payload
        ldx     #TX_BUFFER+PAYLOAD_START
        ldb     #PAYLOAD_SIZE
        clra
cp_loop
        sta     ,x+
        decb
        bne     cp_loop
        rts

; -----------------------------------------------------------------------------
; write_obs_hash — write the Flags byte + ObservedStateHash into the payload.
; B = payload offset of the Flags byte; the 8-byte hash follows at +1..+8.
; If no state hash has been captured the (already-cleared) bytes stay zero.
; -----------------------------------------------------------------------------
write_obs_hash
        lda     HASH_VALID
        beq     woh_done
        ldx     #TX_BUFFER+PAYLOAD_START
        lda     #$01                    ; Flags bit0 = ObservedStateHash present
        sta     b,x
        ldy     #OBSERVED_HASH
        lda     #8                      ; A = byte counter
woh_loop
        incb                            ; advance payload offset
        pshs    a
        lda     ,y+
        sta     b,x
        puls    a
        deca
        bne     woh_loop
woh_done
        rts

; -----------------------------------------------------------------------------
; send_hello — HELLO (0x01): player name, platform ID, spec version.
; reconnectToken is left zero (the vintage fleet does not reclaim slots).
; -----------------------------------------------------------------------------
send_hello
        lda     #MSG_HELLO
        jsr     build_header
        jsr     clear_payload

        ldx     #player_name            ; name @0-15 (fixed 16 bytes)
        ldy     #TX_BUFFER+PAYLOAD_START
        ldb     #16
sh_name
        lda     ,x+
        sta     ,y+
        decb
        bne     sh_name

        lda     #PLATFORM_ID_HI         ; platformID @16-17 (big-endian)
        sta     TX_BUFFER+PAYLOAD_START+16
        lda     #PLATFORM_ID_LO
        sta     TX_BUFFER+PAYLOAD_START+17
        lda     #SPEC_VERSION_HI        ; specVersion @18-19 (big-endian)
        sta     TX_BUFFER+PAYLOAD_START+18
        lda     #SPEC_VERSION_LO
        sta     TX_BUFFER+PAYLOAD_START+19

        jsr     net_send
        rts

; Fixed 16-byte player name (the client's own; the host treats it as user data).
player_name     fcc     "DRAGON"
                fcb     0,0,0,0,0,0,0,0,0,0

; -----------------------------------------------------------------------------
; is_selected — A = hand position; returns A nonzero if that card is selected.
; Reads the SELECTED_LO/HI bitmask. Clobbers B and X; preserves U.
; -----------------------------------------------------------------------------
is_selected
        cmpa    #8
        bhs     is_high
        tfr     a,b
        lda     SELECTED_LO
        bra     is_shift
is_high
        suba    #8
        tfr     a,b
        lda     SELECTED_HI
is_shift
        tstb
        beq     is_test
is_sloop
        lsra
        decb
        bne     is_sloop
is_test
        anda    #1
        rts

; -----------------------------------------------------------------------------
; send_play_cards — PLAY_CARD (0x04). Emits every card flagged in the
; SELECTED_LO/HI bitmask, the nominated suit, spec version, and the observed
; state hash. Payload: CardCount@0, Cards@1.., NominatedSuit@33,
; SpecVersion@34-35, Flags@36, ObservedStateHash@37-44.
; -----------------------------------------------------------------------------
send_play_cards
        lda     #MSG_PLAY_CARDS
        jsr     build_header
        jsr     clear_payload

        ldu     #TX_BUFFER+PAYLOAD_START+1   ; U = card write pointer
        clrb                                 ; B = hand position
spc_loop
        cmpb    HAND_COUNT
        bhs     spc_done
        pshs    b
        tfr     b,a
        jsr     is_selected                  ; preserves U
        puls    b
        tsta
        beq     spc_skip
        ldx     #MY_HAND
        lda     b,x
        sta     ,u+                          ; append selected card
spc_skip
        incb
        bra     spc_loop
spc_done
        tfr     u,d                          ; CardCount = U - cards base
        subd    #TX_BUFFER+PAYLOAD_START+1
        tfr     b,a
        sta     TX_BUFFER+PAYLOAD_START+0    ; CardCount @0

        lda     NOMINATED_SUIT
        sta     TX_BUFFER+PAYLOAD_START+33   ; NominatedSuit @33
        lda     #SPEC_VERSION_HI
        sta     TX_BUFFER+PAYLOAD_START+34   ; SpecVersion @34-35
        lda     #SPEC_VERSION_LO
        sta     TX_BUFFER+PAYLOAD_START+35
        ldb     #36                          ; Flags @36 + hash @37-44
        jsr     write_obs_hash

        jsr     net_send
        rts

; -----------------------------------------------------------------------------
; send_draw — DRAW_CARD (0x05). A = reason (0=cannot play, 1=attack penalty).
; Payload: Reason@0, Count@1, SpecVersion@2-3, Flags@4, ObservedStateHash@5-12.
; -----------------------------------------------------------------------------
send_draw
        pshs    a                            ; save reason
        lda     #MSG_DRAW_CARD
        jsr     build_header
        jsr     clear_payload
        puls    a
        sta     TX_BUFFER+PAYLOAD_START+0    ; Reason @0
        lda     #1
        sta     TX_BUFFER+PAYLOAD_START+1    ; Count @1 (a manual draw is 1)
        lda     #SPEC_VERSION_HI
        sta     TX_BUFFER+PAYLOAD_START+2    ; SpecVersion @2-3
        lda     #SPEC_VERSION_LO
        sta     TX_BUFFER+PAYLOAD_START+3
        ldb     #4                           ; Flags @4 + hash @5-12
        jsr     write_obs_hash

        jsr     net_send
        rts

; -----------------------------------------------------------------------------
; rubp_validate — C clear if RX_BUFFER carries the RACH magic, C set otherwise.
; -----------------------------------------------------------------------------
rubp_validate
        lda     RX_BUFFER
        cmpa    #'R'
        bne     rv_bad
        lda     RX_BUFFER+1
        cmpa    #'A'
        bne     rv_bad
        lda     RX_BUFFER+2
        cmpa    #'C'
        bne     rv_bad
        lda     RX_BUFFER+3
        cmpa    #'H'
        bne     rv_bad
        andcc   #$FE
        rts
rv_bad
        orcc    #$01
        rts

; -----------------------------------------------------------------------------
; get_message_type — A = the message type byte (@5).
; -----------------------------------------------------------------------------
get_message_type
        lda     RX_BUFFER+HDR_TYPE
        rts

; -----------------------------------------------------------------------------
; parse_welcome — WELCOME (0x02). Stores assignedPlayerID / gameID, the player
; count, our seat index, and advances to the WAITING connection state.
; Payload: AssignedPlayerID@0 (BE), GameID@2 (BE), PlayerCount@4, GameState@5.
; -----------------------------------------------------------------------------
parse_welcome
        lda     RX_BUFFER+PAYLOAD_START+0    ; AssignedPlayerID @0 (BE)
        sta     RUBP_PLAYER_ID
        lda     RX_BUFFER+PAYLOAD_START+1
        sta     RUBP_PLAYER_ID+1
        sta     MY_INDEX                     ; low byte = our seat
        lda     RX_BUFFER+PAYLOAD_START+2    ; GameID @2 (BE)
        sta     RUBP_GAME_ID
        lda     RX_BUFFER+PAYLOAD_START+3
        sta     RUBP_GAME_ID+1
        lda     RX_BUFFER+PAYLOAD_START+4    ; PlayerCount @4
        sta     PLAYER_COUNT
        lda     #CONN_WAITING
        sta     CONN_STATE
        rts

; -----------------------------------------------------------------------------
; process_game_state — GAME_STATE (0x07), the public state summary. Captures
; the fields the UI needs and, when Flags bit0 is set, latches the 8-byte state
; hash into OBSERVED_HASH so the next PLAY/DRAW echoes it. GAME_STATE carries no
; hand; cards arrive via GAME_START / CARD_DRAWN (parse_cards).
; -----------------------------------------------------------------------------
process_game_state
        lda     RX_BUFFER+PAYLOAD_START+0    ; CurrentPlayer @0
        sta     CURRENT_TURN
        lda     RX_BUFFER+PAYLOAD_START+1    ; Direction @1
        sta     DIRECTION
        lda     RX_BUFFER+PAYLOAD_START+2    ; TopCard @2
        sta     DISCARD_TOP
        lda     RX_BUFFER+PAYLOAD_START+3    ; NominatedSuit @3
        sta     NOMINATED_SUIT
        lda     RX_BUFFER+PAYLOAD_START+4    ; PendingDraws @4
        sta     PENDING_DRAWS
        lda     RX_BUFFER+PAYLOAD_START+5    ; PendingSkips @5
        sta     PENDING_SKIPS
        lda     RX_BUFFER+PAYLOAD_START+6    ; DeckCount @6
        sta     DECK_COUNT

        ldx     #RX_BUFFER+PAYLOAD_START+7   ; PlayerCardCounts @7-14
        ldy     #PLAYER_COUNTS
        ldb     #8
pgs_counts
        lda     ,x+
        sta     ,y+
        decb
        bne     pgs_counts

        lda     RX_BUFFER+PAYLOAD_START+15   ; IsGameOver @15
        sta     GAME_OVER
        lda     RX_BUFFER+PAYLOAD_START+16   ; WinnerIndex @16
        sta     WINNER_INDEX

        lda     RX_BUFFER+PAYLOAD_START+23   ; Flags @23
        anda    #$01
        beq     pgs_no_hash
        ldx     #RX_BUFFER+PAYLOAD_START+24  ; StateHash @24-31
        ldy     #OBSERVED_HASH
        ldb     #8
pgs_hash
        lda     ,x+
        sta     ,y+
        decb
        bne     pgs_hash
        lda     #1
        sta     HASH_VALID
pgs_no_hash
        rts

; -----------------------------------------------------------------------------
; parse_cards — GAME_START (0x03) / CARD_DRAWN (0x06): the private hand.
; A = 0 replaces the hand (GAME_START); A != 0 appends (CARD_DRAWN). The hand
; is clamped to its 16-card capacity. Payload: CardCount@0, Cards@1.. .
; -----------------------------------------------------------------------------
parse_cards
        tsta
        bne     pc_append
        clr     HAND_COUNT                   ; replace: fresh hand, clear UI state
        clr     SELECTED_LO
        clr     SELECTED_HI
        clr     CURSOR_POS
pc_append
        ldb     RX_BUFFER+PAYLOAD_START+0    ; cards in this message
        ldx     #RX_BUFFER+PAYLOAD_START+1   ; source
        ldy     #MY_HAND                     ; destination = MY_HAND + HAND_COUNT
        lda     HAND_COUNT
        leay    a,y
pc_loop
        tstb
        beq     pc_done
        lda     HAND_COUNT
        cmpa    #16                          ; stop at hand capacity
        bhs     pc_done
        lda     ,x+
        sta     ,y+
        inc     HAND_COUNT
        decb
        bra     pc_loop
pc_done
        rts
