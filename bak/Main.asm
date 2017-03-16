
incasm "common.asm"

;-----------------------------------------------------------------------
;                   C-64 - T-E-T-R-I-S - C-L-O-N-E
;-----------------------------------------------------------------------

WATCH $FD
WATCH $FB
WATCH $20
WATCH CURRENT_PIECE_LOCATION_X
WATCH CURRENT_PIECE_LOCATION_Y

DEBUG CURRT_PIECE_PTR AUTO ON

;-----------------------------------------------------------------------
;                                                  BASIC AUTOSTART STUB
;-----------------------------------------------------------------------




;* = $0801

;        BYTE 12,8,0,0,158
;        BYTE 48+4
;        BYTE 48+0
;        BYTE 48+9
;        BYTE 48+6



FIELD_START_X = 15
FIELD_START_Y = 03
FIELD_END_X   = 22
FIELD_END_Y   = 20



PIECE_SQUARE    = $00
PIECE_L         = $0A
PIECE_L_REVERSE = $14
PIECE_T         = $1E

CURRT_PIECE_PTR = $20
PREV1_PIECE_PTR = $22
PREV2_PIECE_PTR = $24

; A generic piece pointer that always points to piece data, but can be
; set to any piece, depending on the operation.
GEN_PIECE_PTR = $26;

; points to either CURR_COLOR, PREV_COLOR, or PREV1_COLOR
COLOR_DATA_PTR = $28;

; The number of elements in one piece's data
PIECE_DATA_WIDTH = $06

;-----------------------------------------------------------------------
;                                                                  MAIN
;-----------------------------------------------------------------------

*= $1000

INIT

        JSR BASIC_OFF
        JSR INITIALIZE_SCREEN_MEMORY
        JSR SET_EXTENDED_COLOR_MODE
        JSR COPY_CUSTOM_CHARS
        JSR COPY_CUSTOM_SCREEN
        
        JSR SET_COLORS

        LDA #<PIECE_DATA
        STA CURRT_PIECE_PTR
        LDA #>PIECE_DATA
        STA 1+CURRT_PIECE_PTR
        LDA #$01
        STA COLOR
        LDA #6

@LOOP        
        JSR WAIT_FOR_RASTER
        LDA #1
        STA $D020
        JSR FLIP_SCREEN_BUFFERS
        JSR JOY_TEST
        JSR CLIP_PIECE_LOCATION
        JSR DRAW_CURRENT_PIECE
        LDA #0
        STA $D020
        JMP @LOOP
        LDX #0
        LDY #0
        
        JSR SET_SCREEN
        
@DONE
        LDA TEMPA
        CLC
        ADC #1
        JMP @LOOP
        JSR WAIT_FOR_RASTER
     ;   JSR SET_EXTENDED_COLOR_MODE
     ;   JSR FUCK_SHIT_UP
     ;   JSR WAIT_FOR_KEY
        RTS


          
;-----------------------------------------------------------------------
;                                                   COPY_CUSTOM_CHARS
;-----------------------------------------------------------------------
COPY_CUSTOM_CHARS

          LDA #<CUSTOM_CHARACTER_DATA
          STA POINTER1_LO
          LDA #>CUSTOM_CHARACTER_DATA
          STA POINTER1_HI 

          LDA BUFFER_CHARACTER
          STA POINTER2_LO
          LDA BUFFER_CHARACTER+1
          STA POINTER2_HI

          LDX #$00
          LDY #$78
          JSR MEMCPY

          RTS

;-----------------------------------------------------------------------
;                                                   COPY_CUSTOM_SCREEN
;-----------------------------------------------------------------------
COPY_CUSTOM_SCREEN

        LDA #<SCREEN1
        STA POINTER1_LO
        LDA #>SCREEN1
        STA POINTER1_HI 

        LDA BUFFER_SCREEN_FRONT
        STA POINTER2_LO
        LDA 1+BUFFER_SCREEN_FRONT
        STA POINTER2_HI

        LDX #$03
        LDY #$E8
        JSR MEMCPY

        LDA #<SCREEN1
        STA POINTER1_LO
        LDA #>SCREEN1
        STA POINTER1_HI 

        LDA BUFFER_SCREEN_BACK
        STA POINTER2_LO
        LDA 1+BUFFER_SCREEN_BACK
        STA POINTER2_HI

        LDX #$03
        LDY #$E8
        JSR MEMCPY

        LDA #<SCREEN1_COLOR
        STA POINTER1_LO
        LDA #>SCREEN1_COLOR
        STA POINTER1_HI

        LDA #<COLOR_MEMORY
        STA POINTER2_LO
        LDA #>COLOR_MEMORY
        STA POINTER2_HI
        
        LDX #$03
        LDY #$E8
        JSR MEMCPY
          
        RTS
          
;-----------------------------------------------------------------------
;                                                            SET_COLORS
;-----------------------------------------------------------------------

SET_COLORS
        
        LDA #$00
        STA $D020
        
        STA $D021

        LDA #7
        LDX #8
        LDY #9
        JSR SET_EXTENDED_COLORS
        RTS

;-----------------------------------------------------------------------
;                                                       Draw background 
;-----------------------------------------------------------------------

DRAW_BACKGROUND

        LDA BUFFER_SCREEN_CURRENT
        STA POINTER1_LO
        LDA 1+BUFFER_SCREEN_CURRENT
        STA POINTER1_HI

        LDA #0
        LDY #15
        RTS

;-----------------------------------------------------------------------
;                                                              JOY TEST        
;-----------------------------------------------------------------------

JOY_TEST

.UP
        LDA $DC01        
        BIT 1+BITS
        BNE .DOWN
        DEC CURRENT_PIECE_LOCATION_Y      

.DOWN
        BIT 2+BITS
        BNE .LEFT
        INC CURRENT_PIECE_LOCATION_Y

.LEFT
        BIT 3+BITS
        BNE .RIGHT
        DEC CURRENT_PIECE_LOCATION_X

.RIGHT
        BIT 4+BITS
        BNE .FIRE
        INC CURRENT_PIECE_LOCATION_X

.FIRE
        RTS


;-----------------------------------------------------------------------
;                                                   Clip piece location
;-----------------------------------------------------------------------
; Force CURRENT_PIECE_LOCATION to be in a position such that the current
; piece is inside the board. 

; To do this, we have to take into account how the pieces are defined
; and how that piece data is related to the CURRENT_PIECE_LOCATION.

; First, CURRENT_PIECE_LOCATION represents the upper left piece part of
; the piece. This is used to make sure that the piece is not above or to the
; right of the field.

; To check the piece against the right and bottom of the field, we have to
; know the size of the piece. We need the width of the piece to check the
; piece against the right side of the field, and we need the height of the
; piece to check the piece against the bottom of the field.
; ie make sure that:
; CURRENT_LOCATION + PIECE_WIDTH < RIGHT SIDE OF FIELD.
; CURRENT_LOCATION + PIECE_HEIGHT < BOTTOM SIDE OF FIELD.

; CURRENT_PIECE_PTR points to the PIECE_DATA representing the current piece. 
; This data defines the locations of the other 3 piece parts relative to 
; CURRENT_PIECE_LOCATION.

; More importantly, the fourth byte of the piece data is the width-1 of the piece
; and the fifth byte is the height-11


CLIP_PIECE_LOCATION

        LDA #FIELD_START_X
        CMP CURRENT_PIECE_LOCATION_X
        Bmi .XEND
        STA CURRENT_PIECE_LOCATION_X
        JMP .YSTART

.XEND
; First, get the width of the piece from the fourth byte of the piece data 
; pointed to by the current piece ptr
        LDA #FIELD_END_X                      ; Get field end
        LDY #$03
        SBC (CURRT_PIECE_PTR),Y               ; Subtract piece w-1
        
        CMP CURRENT_PIECE_LOCATION_X      ; Compare current location
        Bpl .YSTART
        STA CURRENT_PIECE_LOCATION_X

.YSTART 
        LDA #FIELD_START_Y
        CMP CURRENT_PIECE_LOCATION_Y
        BMI .YEND
        STA CURRENT_PIECE_LOCATION_Y
        RTS

.YEND        
        LDA #FIELD_END_Y                        ; Get field bottom
        LDY #$04
        SBC (CURRT_PIECE_PTR),Y                 ; Subtract piece h-1
        
        CMP CURRENT_PIECE_LOCATION_Y        ; Compare current location
        BPL @DONE
        STA CURRENT_PIECE_LOCATION_Y

@DONE
        RTS

;-----------------------------------------------------------------------
;                                                   Save Piece Location
;-----------------------------------------------------------------------
; Copy PREVIOUS1_PIECE_LOCAION to PREVIOUS2_PIECE_LOCATION then
; copy CURRENT_PIECE_LOCATION to PREVIOUS1_PIECE_LOCATION

SAVE_PIECE_LOCATION

        LDA PREVIOUS1_PIECE_LOCATION_X
        STA PREVIOUS2_PIECE_LOCATION_Y
        LDA PREVIOUS1_PIECE_LOCATION_X
        STA PREVIOUS2_PIECE_LOCATION_Y

        LDA CURRENT_PIECE_LOCATION_X
        STA PREVIOUS1_PIECE_LOCATION_X
        LDA CURRENT_PIECE_LOCATION_Y
        STA PREVIOUS1_PIECE_LOCATION_Y

        LDY #$00
        LDA (PREV1_PIECE_PTR),Y
        STA (PREV2_PIECE_PTR),Y

        LDA (CURRT_PIECE_PTR),Y
        STA (PREV1_PIECE_PTR),Y

        RTS



;-----------------------------------------------------------------------
;                                                    Draw current piece
;-----------------------------------------------------------------------
; COLOR is used to color the peice

DRAW_CURRENT_PIECE

        
        LDA CURRT_PIECE_PTR
        STA POINTER1_LO
        LDA 1+CURRT_PIECE_PTR
        STA POINTER1_HI         ; This block is to store a pointer to the
                                ; piece data for the current piece
        
        
        LDA CURRENT_PIECE_LOCATION_Y ; <--
        STA FAC1                     ;   |
        LDA #40                      ;   |
        STA FAC2                     ;   |
        JSR MUL8                     ;   |  -> Calculate the Y offset of the first
        ; A - Y Offset hi            ;   |     part of the piece and store it in
        ; X - Y Offset lo            ;   |     TEMP. The same offset is used for
                                     ;   |     the screen buffer and the color.
        STX OFFSET_LO                ;   |
        STA OFFSET_HI                ; <--
        
        TAY                     ; Store A (offset HI) in Y
        TXA                     ; Pull in X (offset LO) so we can add it to
                                ; the screen buffer
                             
        CLC
        ADC BUFFER_SCREEN_CURRENT
        STA POINTER2_LO             ; Calculate LO byte.
        TYA                         ; Pull back the hi byte of OFFSET
        ADC 1+BUFFER_SCREEN_CURRENT ; Add the temp offset to the current screen 
        STA POINTER2_HI             ; buffer. Store in pointer2  

        
                                     
        CLC
        LDA #<COLOR_MEMORY
        ADC OFFSET_LO
        STA POINTER3_LO
        LDA #>COLOR_MEMORY
        ADC OFFSET_HI                   ; Add the temp offset to the coller
        STA POINTER3_HI                 ; buffer, store in pointer3

        LDA CURRENT_PIECE_LOCATION_X 
        TAY                          
        LDA #$02                     
        STA (POINTER2_LO),Y
        LDA COLOR
        STA (POINTER3_LO),Y

        LDY #$00
        LDA (POINTER1_LO),Y
        ADC CURRENT_PIECE_LOCATION_X
        TAY
        LDA #$02
        STA (POINTER2_LO),Y
        LDA COLOR
        STA (POINTER3_LO),Y

        LDY #$01
        LDA (POINTER1_LO),Y
        ADC CURRENT_PIECE_LOCATION_X
        TAY
        LDA #$02
        STA (POINTER2_LO),Y
        LDA COLOR
        STA (POINTER3_LO),Y

        LDY #$02
        LDA (POINTER1_LO),Y
        ADC CURRENT_PIECE_LOCATION_X
        TAY
        LDA #$02
        STA (POINTER2_LO),Y
        LDA COLOR
        STA (POINTER3_LO),Y


        RTS



;-----------------------------------------------------------------------
;                                                     Store peice color
;-----------------------------------------------------------------------
; Stores the color data behind a piece location before a piece is placed
; there.
; GEN_PIECE_PTR - points to the peice data structure used to gather the
;               - color data.
; COLOR_DATA_PTR - points to a color data struction location where the
;                - color data will be placed.
; TEMPX - X location of the piece
; TEMPY - Y location of the piece

; Multiply y location of the piece by the screen width (40)
        LDA TEMPY
        STA FAC1
        LDA #40
        STA FAC2        ; A -> Offset hi
        JSR MUL8        ; x -> Offset lo
        
; Store the y location offset in POINTER1
        STX POINTER1_LO       ; lo byte wont change when adding $D800
        TXA
        ADC #>COLOR_MEMORY
        STA POINTER1_HI       ; OFFSET_HI -> Y Offset in screen memory
        
; Get the color behind the first piece part (pointer1 + x )
        LDY TEMPX
        LDA (POINTER1_LO),Y      ; get the color
        LDY #$00
        STA (COLOR_DATA_PTR),Y   ; store it in pos0 of color data

; Get the color behind the second piece part (pointer1[0],(GEN_PIECE_PTR[0] + X))
        LDY #$00
        LDA (GEN_PIECE_PTR),Y   ; get GEN_PIECE_PR[0]
        ADC TEMPX               ; add X
        TAY                     ; Set as index
        LDA (POINTER1_LO),Y     ; get color
        LDY #$01               
        STA (COLOR_DATA_PTR),Y  ; Store it in pos1 of color data

; Get the color behind the third piece (pointer1[0],(GEN_PIECE_PTR[1] + X))
        LDY #$01
        LDA (GEN_PIECE_PTR),Y   ; get GEN_PIECE_PR[1]
        ADC TEMPX               ; add X
        TAY                     ; Set as index
        LDA (POINTER1_LO),Y     ; get color
        LDY #$02               
        STA (COLOR_DATA_PTR),Y  ; Store it in pos2 of color data

; Get the colore behind the fourth piece (pointer1[0],(GEN_PIECE_PTR[2] + X))
        LDY #$02
        LDA (GEN_PIECE_PTR),Y   ; get GEN_PIECE_PR[0]
        ADC TEMPX               ; add X
        TAY                     ; Set as index
        LDA (POINTER1_LO),Y     ; get color
        LDY #$03             
        STA (COLOR_DATA_PTR),Y  ; Store it in pos3 of color data
        
        rts
        


;***********************************************************************
;                                                        CHARACTER DATA
;-----------------------------------------------------------------------

CUSTOM_CHARACTER_DATA
        BYTE    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; CHARACTER 0
        BYTE    $00,$7E,$42,$5A,$5A,$42,$7E,$00 ; CHARACTER 1
        BYTE    $00,$7E,$42,$5A,$5A,$42,$7E,$00 ; CHARACTER 2
        BYTE    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; CHARACTER 3
        BYTE    $3E,$1F,$0B,$0D,$07,$01,$00,$00 ; CHARACTER 4
        BYTE    $00,$00,$80,$C0,$B0,$D0,$F8,$7C ; CHARACTER 5
        BYTE    $00,$00,$01,$03,$0F,$05,$1F,$3E ; CHARACTER 6
        BYTE    $7C,$E8,$B0,$D0,$C0,$80,$00,$00 ; CHARACTER 7
        BYTE    $00,$00,$81,$EF,$F7,$FF,$FF,$00 ; CHARACTER 8
        BYTE    $3E,$1E,$1E,$16,$0E,$1E,$1E,$3E ; CHARACTER 9
        BYTE    $00,$FF,$FF,$EF,$F7,$81,$00,$00 ; CHARACTER 10
        BYTE    $7C,$78,$78,$70,$68,$78,$78,$7C ; CHARACTER 11
        BYTE    $7E,$7E,$7E,$7E,$7E,$7E,$7E,$7E ; CHARACTER 12
        BYTE    $3E,$5F,$5B,$65,$7B,$69,$7C,$7E ; CHARACTER 13
        BYTE    $7E,$74,$65,$63,$4F,$05,$1F,$3E ; CHARACTER 14

;-----------------------------------------------------------------------
;                                                           PIECE DATA
;-----------------------------------------------------------------------

CURRENT_PIECE_LOCATION_X
        BYTE $00
CURRENT_PIECE_LOCATION_Y
        BYTE $01

PREVIOUS1_PIECE_LOCATION_X
        BYTE $00
PREVIOUS1_PIECE_LOCATION_Y
        BYTE $00

PREVIOUS2_PIECE_LOCATION_X
        BYTE $00
PREVIOUS2_PIECE_LOCATION_Y
        BYTE $00



; Piece data is stored as offsets from the first brick. i.e.
; the first brick is implied so the first byte in PIECE_DATA is the offset
; (in screen space) from the first brick.

; The 4 byte is the width-1 of the entire piece and the 5th byte is the
; height-1 of the piece.

ALIGN
PIECE_DATA
            ;/O1/ /02/ /03/  |MW|  |MH|
        BYTE $01, $02, $03,  $02,  $FD
        BYTE $01, $28, $29,  $01,  $01
        BYTE $01, $02, $24,  $02,  $01
        BYTE $01, $02, $30,  $02,  $01
        BYTE $01, $02, $28,  $02,  $01

; used to store the color data under the current piece as it moves around
CURR_COLOR
        BYTE $00, $00, $00, $00
PREV_COLOR
        BYTE $00, $00, $00, $00
PREV2_COLOR
        BYTE $00, $00, $00, $00

; One byte of color data used to pass a color between routines
COLOR
        BYTE $00

TEMP_LO
        BYTE $00
TEMP_HI
        BYTE $00

;-----------------------------------------------------------------------
;                                                                 BITS
;-----------------------------------------------------------------------

BITS
        BYTE $00, $01, $02, $04, $08, $10, $20, $40, $80
        
;-----------------------------------------------------------------------
;                                                                 MISC.
;-----------------------------------------------------------------------
SCREEN1
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$06,$08,$08,$08,$08,$08,$08,$08,$08,$05,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0D,$08,$08,$08,$08,$05,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0C,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0C,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0C,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0C,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0E,$0A,$0A,$0A,$0A,$07,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$09,$40,$40,$40,$40,$40,$40,$40,$40,$0B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$04,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$07,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        BYTE    $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

        BYTE    $00 ; $D021 Colour
        BYTE    $00 ; $D022
        BYTE    $02 ; $D023
        BYTE    $05 ; $D024
SCREEN1_COLOR
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        BYTE    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00



OFFSET_LO
        BYTE $00
OFFSET_HI
        BYTE $00