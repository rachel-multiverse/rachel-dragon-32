; =============================================================================
; DRAGON 32/TANDY COCO EQUATES
; Motorola 6809 Assembly
; =============================================================================

; VDG (Video Display Generator)
SCREEN_BASE     equ     $0400           ; 32x16 text screen
SCREEN_WIDTH    equ     32
SCREEN_HEIGHT   equ     16

; PIA (Peripheral Interface Adapter)
PIA0_DA         equ     $FF00           ; PIA 0 Data A (keyboard rows)
PIA0_CA         equ     $FF01           ; PIA 0 Control A
PIA0_DB         equ     $FF02           ; PIA 0 Data B (keyboard cols)
PIA0_CB         equ     $FF03           ; PIA 0 Control B

PIA1_DA         equ     $FF20           ; PIA 1 Data A
PIA1_CA         equ     $FF21           ; PIA 1 Control A
PIA1_DB         equ     $FF22           ; PIA 1 Data B
PIA1_CB         equ     $FF23           ; PIA 1 Control B

; DragonWiFi / Serial
ACIA_CTRL       equ     $FF04           ; ACIA Control
ACIA_STATUS     equ     $FF04           ; ACIA Status (same address)
ACIA_DATA       equ     $FF05           ; ACIA Data

; ACIA Status bits
ACIA_RDRF       equ     %00000001       ; Receive Data Register Full
ACIA_TDRE       equ     %00000010       ; Transmit Data Register Empty

; Key codes (Dragon keyboard matrix)
KEY_LEFT        equ     $08             ; Left arrow
KEY_RIGHT       equ     $09             ; Right arrow
KEY_UP          equ     $0C             ; Up arrow
KEY_DOWN        equ     $0A             ; Down arrow
KEY_RETURN      equ     $0D             ; Enter
KEY_SPACE       equ     $20             ; Space
KEY_BREAK       equ     $03             ; Break
KEY_D           equ     'D'
KEY_d           equ     'd'

; BASIC ROM entry points
POLCAT          equ     $A000           ; Poll keyboard
CHROUT          equ     $A002           ; Output character
CLS             equ     $A004           ; Clear screen

; RUBP Protocol Constants
MAGIC_0         equ     'R'
MAGIC_1         equ     'A'
MAGIC_2         equ     'C'
MAGIC_3         equ     'H'
PROTOCOL_VER    equ     1

; Header offsets
; Header layout (RUBP v1): magic@0-3, version@4, type@5, sequence@6-7 (BE),
; playerID@8-9 (BE), gameID@10-11 (BE), timestamp@12-15. The 6809 is natively
; big-endian, so multi-byte fields store straight to the wire with no swap.
HDR_MAGIC       equ     0
HDR_VERSION     equ     4
HDR_TYPE        equ     5
HDR_SEQ         equ     6
HDR_PLAYER_ID   equ     8
HDR_GAME_ID     equ     10
HDR_TIMESTAMP   equ     12
PAYLOAD_START   equ     16
PAYLOAD_SIZE    equ     48

; Message types (RUBP v1)
MSG_HELLO       equ     $01             ; C->H: connect / slot claim
MSG_WELCOME     equ     $02             ; H->C: slot assigned
MSG_GAME_START  equ     $03             ; H->C: initial hand (private)
MSG_PLAY_CARDS  equ     $04             ; C->H: play one or more cards
MSG_DRAW_CARD   equ     $05             ; C->H: draw
MSG_CARD_DRAWN  equ     $06             ; H->C: cards just drawn (private)
MSG_GAME_STATE  equ     $07             ; H->C: public state summary

; Platform ID (Dragon 32/64 = 0x00A0)
PLATFORM_ID_HI  equ     $00
PLATFORM_ID_LO  equ     $A0

; RachelSpec version this client speaks (negotiated via HELLO/WELCOME)
SPEC_VERSION_HI equ     $00
SPEC_VERSION_LO equ     $01

; Connection states
CONN_DISCONNECTED equ   0
CONN_HANDSHAKE    equ   1
CONN_WAITING      equ   2               ; got WELCOME, waiting for GAME_START
CONN_PLAYING      equ   3

; Card constants
SUIT_HEARTS     equ     0
SUIT_DIAMONDS   equ     1
SUIT_CLUBS      equ     2
SUIT_SPADES     equ     3

RANK_ACE        equ     1
RANK_JACK       equ     11
RANK_QUEEN      equ     12
RANK_KING       equ     13

; -----------------------------------------------------------------------------
; RAM map. Kept in high RAM ($6000+) clear of the text screen ($0400-$05FF),
; BASIC's low workspace, and the system stack — so the conformance cartridge
; (which runs after BASIC boots) and the EXEC-at-$3000 program both stay safe.
; -----------------------------------------------------------------------------

; RUBP codec working storage
TX_BUFFER       equ     $6000           ; 64-byte outgoing message
RX_BUFFER       equ     $6040           ; 64-byte incoming message
RUBP_SEQ        equ     $6080           ; 16-bit sequence counter
RUBP_PLAYER_ID  equ     $6082           ; 16-bit, assigned by WELCOME
RUBP_GAME_ID    equ     $6084           ; 16-bit, assigned by WELCOME
MSG_TYPE_TEMP   equ     $6086           ; build_header scratch
OBSERVED_HASH   equ     $6087           ; last GAME_STATE hash (8 bytes)
HASH_VALID      equ     $608F           ; 1 once a state hash is captured
PLAYER_COUNT    equ     $6090           ; total players (from WELCOME)
CONN_STATE      equ     $6091           ; CONN_* connection state

; Game state variables
CURRENT_TURN    equ     $6100
DIRECTION       equ     $6101
DISCARD_TOP     equ     $6102
NOMINATED_SUIT  equ     $6103
PENDING_DRAWS   equ     $6104
PENDING_SKIPS   equ     $6105
MY_INDEX        equ     $6106
HAND_COUNT      equ     $6107
PLAYER_COUNTS   equ     $6108           ; 8 bytes
MY_HAND         equ     $6110           ; 16 bytes
CURSOR_POS      equ     $6120
SELECTED_LO     equ     $6121
SELECTED_HI     equ     $6122
DECK_COUNT      equ     $6123           ; cards left in deck (GAME_STATE @6)
GAME_OVER       equ     $6124           ; 0=playing, 1=over (GAME_STATE @15)
WINNER_INDEX    equ     $6125           ; winner seat, 0xFF none (GAME_STATE @16)

; Key aliases for game controls
KEY_QUIT        equ     KEY_BREAK
KEY_SELECT      equ     KEY_SPACE
KEY_PLAY        equ     KEY_RETURN
KEY_DRAW        equ     KEY_D
