; =============================================================================
; RACHEL - DRAGON 32/COCO MAIN MODULE
; 6809 Assembly - Entry point and main loop
; =============================================================================

        org     $3000

start
        orcc    #$50            ; Disable interrupts
        jsr     init_system
        jsr     display_init
        jsr     display_title

        ; Get server address
        jsr     input_ip_address

        ; Connect to server
        jsr     do_connect
        lbcs    conn_failed

        ; Initialize RUBP
        jsr     rubp_init

        ; Send HELLO with player name and platform ID
        jsr     send_hello

        ; Wait for game to start
        jsr     wait_for_game

        ; Main game loop
main_loop
        jsr     net_recv
        bcs     ml_input

        jsr     rubp_validate
        bcs     ml_input

        jsr     get_message_type
        cmpa    #MSG_WELCOME
        bne     ml_not_welcome
        jsr     parse_welcome
        bra     ml_input

ml_not_welcome
        cmpa    #MSG_GAME_START
        bne     ml_not_start
        lda     #0                      ; replace hand
        jsr     parse_cards
        jsr     render_game
        bra     ml_input

ml_not_start
        cmpa    #MSG_CARD_DRAWN
        bne     ml_not_drawn
        lda     #1                      ; append to hand
        jsr     parse_cards
        jsr     render_game
        bra     ml_input

ml_not_drawn
        cmpa    #MSG_GAME_STATE
        bne     ml_input
        jsr     process_game_state
        jsr     render_game
        lda     GAME_OVER               ; GAME_STATE signals end-of-game
        bne     ml_game_over

ml_input
        ; Check if it's our turn
        lda     CURRENT_TURN
        cmpa    MY_INDEX
        bne     main_loop

        ; Handle input
        jsr     get_input
        cmpa    #KEY_QUIT
        beq     quit_game
        cmpa    #KEY_LEFT
        beq     ml_left
        cmpa    #KEY_RIGHT
        beq     ml_right
        cmpa    #KEY_SELECT
        beq     ml_select
        cmpa    #KEY_PLAY
        beq     ml_play
        cmpa    #KEY_DRAW
        beq     ml_draw
        bra     main_loop

ml_left
        jsr     cursor_left
        jsr     render_hand
        bra     main_loop

ml_right
        jsr     cursor_right
        jsr     render_hand
        bra     main_loop

ml_select
        jsr     toggle_select
        jsr     render_hand
        bra     main_loop

ml_play
        jsr     count_selected
        lbeq    main_loop       ; Nothing selected
        jsr     send_play_cards
        lbra    main_loop

ml_draw
        lda     #0              ; reason: cannot play
        jsr     send_draw
        lbra    main_loop

ml_game_over
        jmp     game_over

conn_failed
        jsr     display_clear
        leax    msg_conn_fail,pcr
        jsr     print_string
        jmp     wait_key

game_over
        jsr     display_clear
        leax    msg_game_over,pcr
        jsr     print_string
        jsr     wait_key

quit_game
        jsr     net_close
        rts

; -----------------------------------------------------------------------------
; Helper routines
; -----------------------------------------------------------------------------
init_system
        jsr     net_init
        rts

input_ip_address
        jsr     display_clear
        leax    msg_enter_ip,pcr
        jsr     print_string
        jsr     input_line
        rts

do_connect
        jsr     display_clear
        leax    msg_connecting,pcr
        jsr     print_string
        jsr     net_connect
        rts

wait_for_game
        jsr     display_clear
        leax    msg_waiting,pcr
        jsr     print_string
wfg_loop
        jsr     net_recv
        bcs     wfg_loop
        jsr     rubp_validate
        bcs     wfg_loop
        jsr     get_message_type
        cmpa    #MSG_WELCOME
        bne     wfg_not_welcome
        jsr     parse_welcome
        bra     wfg_loop
wfg_not_welcome
        cmpa    #MSG_GAME_START
        bne     wfg_loop
        lda     #0                      ; initial hand dealt -> start playing
        jsr     parse_cards
        rts

; rubp_validate and get_message_type live in rubp.asm.

; count_selected — A = number of selected cards (counts bits in the live
; SELECTED_LO/HI bitmask that toggle_select and the hand renderer maintain).
count_selected
        clrb                            ; B = count
        lda     SELECTED_LO
        bsr     cs_count_byte
        lda     SELECTED_HI
        bsr     cs_count_byte
        tfr     b,a
        rts
cs_count_byte
        tsta
        beq     cs_byte_done
cs_byte_loop
        lsra
        bcc     cs_byte_skip
        incb
cs_byte_skip
        tsta
        bne     cs_byte_loop
cs_byte_done
        rts

; wait_key is defined in input.asm

; -----------------------------------------------------------------------------
; Data
; -----------------------------------------------------------------------------
msg_enter_ip    fcc     /ENTER SERVER IP:/
                fcb     13
                fcb     0
msg_connecting  fcc     /CONNECTING.../
                fcb     13
                fcb     0
msg_waiting     fcc     /WAITING FOR GAME.../
                fcb     13
                fcb     0
msg_conn_fail   fcc     /CONNECTION FAILED/
                fcb     13
                fcb     0
msg_game_over   fcc     /GAME OVER!/
                fcb     13
                fcb     0

; -----------------------------------------------------------------------------
; Includes
; -----------------------------------------------------------------------------
        include "equates.asm"
        include "display.asm"
        include "input.asm"
        include "game.asm"
        include "connect.asm"
        include "rubp.asm"
        include "net/wifi.asm"

        end     start
