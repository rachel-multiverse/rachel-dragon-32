; =============================================================================
; DRAGON 64 NETWORK DRIVER
; On-board SY6551 ACIA + transparent Hayes-compatible RS-232 WiFi modem
; =============================================================================

net_state       fcb     0

net_init
        sta     ACIA_STATUS     ; 6551 programmed reset (value is ignored)
        lda     #$1E            ; internal clock, 9600 baud, 8N1
        sta     ACIA_CONTROL
        lda     #$0B            ; DTR/RTS low, RX on, interrupts disabled
        sta     ACIA_COMMAND
        leax    at_attention,pcr
        jsr     send_string
        jsr     wait_response
        bcs     ni_fail
        andcc   #$FE
        rts
ni_fail
        orcc    #$01
        rts

net_connect
        lda     #1
        sta     net_state
        ; Hayes modem transparent TCP dial: ATD<IPv4>:6502
        leax    at_connect,pcr
        jsr     send_string
        ldx     #server_ip
        ldb     #4
nc_ip
        lda     ,x+
        jsr     send_decimal
        decb
        beq     nc_port
        lda     #'.'
        jsr     send_byte
        bra     nc_ip
nc_port
        leax    at_port,pcr
        jsr     send_string
        jsr     wait_response
        bcs     nc_fail
        lda     #2
        sta     net_state
        andcc   #$FE
        rts
nc_fail
        clra
        sta     net_state
        orcc    #$01
        rts

at_attention fcc    /AT/
             fcb    13,0
at_connect  fcc     /ATD/
            fcb     0
at_port     fcc     /:6502/
            fcb     13,0

net_close
        ; A physical modem can be reset or power-cycled to hang up. Sending
        ; escape text while binary mode is active could corrupt a RUBP frame.
        clra
        sta     net_state
        rts

net_send
        lda     net_state
        cmpa    #2
        bne     ns_fail
        ldx     #TX_BUFFER
        ldb     #64
ns_loop
        lda     ,x+
        jsr     send_byte
        decb
        bne     ns_loop
        andcc   #$FE
        rts
ns_fail
        orcc    #$01
        rts

net_recv
        lda     net_state
        cmpa    #2
        bne     nr_fail
        ; Ignore modem banners and synchronise on the RUBP frame magic.
nr_find_r
        jsr     recv_byte_timeout
        bcs     nr_fail
        cmpa    #'R'
        bne     nr_find_r
        ldx     #RX_BUFFER
        sta     ,x+
        ldy     #rubp_magic
        ldb     #1
nr_magic
        jsr     recv_byte_timeout
        bcs     nr_fail
        cmpa    b,y
        bne     nr_find_r
        sta     ,x+
        incb
        cmpb    #4
        bne     nr_magic
        ldb     #60
nr_loop
        jsr     recv_byte_timeout
        bcs     nr_partial
        sta     ,x+
        decb
        bne     nr_loop
        andcc   #$FE
        rts
nr_partial
nr_fail
        orcc    #$01
        rts

send_byte
        pshs    a
sb_wait
        lda     ACIA_STATUS
        anda    #ACIA_TDRE
        beq     sb_wait
        puls    a
        sta     ACIA_DATA
        rts

recv_byte_timeout
        ldy     #$FFFF
rbt_loop
        lda     ACIA_STATUS
        anda    #ACIA_RDRF
        bne     rbt_got
        leay    -1,y
        bne     rbt_loop
        orcc    #$01
        rts
rbt_got
        lda     ACIA_DATA
        andcc   #$FE
        rts

wait_response
        ldy     #$FFFF
wr_loop
        jsr     recv_byte_timeout
        bcs     wr_timeout
        cmpa    #'O'
        beq     wr_ok_tail
        cmpa    #'C'            ; CONNECT from a Hayes modem
        beq     wr_connect_tail
        bra     wr_loop
wr_ok_tail
        jsr     recv_byte_timeout
        bcs     wr_timeout
        cmpa    #'K'
        bne     wr_loop
        bra     wr_connected
wr_connect_tail
        leax    connect_tail,pcr
wr_connect_char
        jsr     recv_byte_timeout
        bcs     wr_timeout
        cmpa    ,x+
        bne     wr_loop
        tst     ,x
        bne     wr_connect_char
wr_connected
        andcc   #$FE
        rts
wr_timeout
        orcc    #$01
        rts

send_string
        lda     ,x+
        beq     ss_done
        jsr     send_byte
        bra     send_string
ss_done
        rts

; Send unsigned A as decimal. Preserves X and B for the IP loop.
send_decimal
        pshs    x,b
        tfr     a,b
        clra
        sta     decimal_hundreds
sd_hundreds
        cmpb    #100
        blo     sd_tens_start
        subb    #100
        inca
        sta     decimal_hundreds
        bra     sd_hundreds
sd_tens_start
        tsta
        beq     sd_no_hundreds
        adda    #'0'
        jsr     send_byte
sd_no_hundreds
        clra
sd_tens
        cmpb    #10
        blo     sd_units
        subb    #10
        inca
        bra     sd_tens
sd_units
        tsta
        bne     sd_emit_tens
        tst     decimal_hundreds
        beq     sd_emit_units
sd_emit_tens
        adda    #'0'
        jsr     send_byte
sd_emit_units
        tfr     b,a
        adda    #'0'
        jsr     send_byte
        puls    x,b,pc

rubp_magic fcc  /RACH/
connect_tail fcc /ONNECT/
             fcb 0
decimal_hundreds fcb 0
