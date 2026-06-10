; =============================================================================
; DRAGON 32/COCO WIFI NETWORK DRIVER
; 6809 Assembly - DragonWiFi via ACIA
; =============================================================================

net_state       fcb     0

net_init
        lda     #$03            ; Reset ACIA
        sta     ACIA_CTRL
        lda     #$16            ; 8N1, div by 64
        sta     ACIA_CTRL
        andcc   #$FE
        rts

net_connect
        lda     #1
        sta     net_state
        leax    at_connect,pcr
nc_send
        lda     ,x+
        beq     nc_wait
        jsr     send_byte
        bra     nc_send
nc_wait
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

at_connect  fcc     /AT+CIPSTART/
            fcb     13
            fcb     0

net_close
        leax    at_close,pcr
ncl_send
        lda     ,x+
        beq     ncl_done
        jsr     send_byte
        bra     ncl_send
ncl_done
        clra
        sta     net_state
        rts

at_close    fcc     /AT+CIPCLOSE/
            fcb     13
            fcb     0

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
        ldx     #RX_BUFFER
        ldb     #64
nr_loop
        jsr     recv_byte_timeout
        bcs     nr_partial
        sta     ,x+
        decb
        bne     nr_loop
        andcc   #$FE
        rts
nr_partial
        clra
nr_fill
        sta     ,x+
        decb
        bne     nr_fill
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
        bne     wr_loop
        jsr     recv_byte_timeout
        bcs     wr_timeout
        cmpa    #'K'
        bne     wr_loop
        andcc   #$FE
        rts
wr_timeout
        orcc    #$01
        rts
