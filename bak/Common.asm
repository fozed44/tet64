

;-----------------------------------------------------------------------
;                   C-64 - T-E-T-R-I-S - C-L-O-N-E
;-----------------------------------------------------------------------

;-----------------------------------------------------------------------
;                                              KERNAL ROUTINE ADDRESSES
;-----------------------------------------------------------------------

SCAN_KEY = $FF9F
GET_CHAR = $FFCF

;-----------------------------------------------------------------------
;                                                      MEMORY ADDRESSES
;-----------------------------------------------------------------------

; The MEMORY_SCREEN_BASE address is the address of the bank that the vic
; chip is pointed to.

; The bank values represent one of the 16 banks within the 16k main bank
; of the vic-ii.
; If the base address is $0000 then the banks are:
; $0000
; $0400
; $0800
; $0B00 ... etc

; In other words the screen memory pointers (BUFFER_SCREEN_FRONT) and
; (BUFFER_SCREEN_BACK) are calculated 
; MEMORY_SCREEN_BASE + MEMORY_SCREEN_BANK_X * $0400

MEMORY_SCREEN_BASE   = $0000      ; VIC-II BASE ADDRESS
MEMORY_SCREEN_BANK_A = 14         ; SCREEN ADDRESS BANK 
MEMORY_SCREEN_BANK_B = 15         ; SCREEN ADDRESS BANK

; The MEMORY_CHAR_BANK defines the bank where the character data should 
; be located. 
; Character sets take up 2k, so the 16k available to the vic is divided
; into 8 banks:
; 0 - $0000   4 - $2000
; 1 - $0800   5 - $2800
; 2 - $1000   6 - $3000
; 3 - $1800   7 - $3800

; The init character buffer sub calculates this address based on MEMORY_SCREEN_BASE
; MEMORY_CHAR_BANK, sets up the vic chip, copies the character rom to the new ram
; location, and sets the BUFFER_CHARACTER pointer to point to the ram buffer

MEMORY_CHAR_BANK = 6

; Memory location of color memory
COLOR_MEMORY = $D800

POINTER1_LO = $FD
POINTER1_HI = $FE

POINTER2_LO  = $FB
POINTER2_HI  = $FC

POINTER3_LO  = $02
POINTER3_HI  = $03

;-----------------------------------------------------------------------


*= $2000

;-----------------------------------------------------------------------
;                                                                MEMCPY
;-----------------------------------------------------------------------
; POINTER1 - SOURCE ADDRESS
; POINTER2 - DESTINATION ADDRESS
; X - COUNT HI
; Y - COUNT LO

MEMCPY

        STY TEMPY

        CPY #$00
        BEQ .Y0
        
        CPX #$00
        BEQ .X0

.Y>0-X>0
        
        JMP .Y_START
        
.Y0
        CPX #$00
        BEQ .DONE
        

.Y_START
        LDY #$00
.Y_LOOP
        LDA (POINTER1_LO),Y
        STA (POINTER2_LO),Y

        INY
        CPY #$00
        BNE .Y_LOOP

.X
        INC POINTER1_HI
        INC POINTER2_HI
        DEX        
        CPX #$00
        BNE .Y_START
        

        LDY TEMPY
        CPY #$00
        BEQ .DONE

.X0        
        DEY

        LDA (POINTER1_LO),Y
        STA (POINTER2_LO),Y

        CPY #$00
        BNE .X0

.DONE
        RTS

;-----------------------------------------------------------------------
;                                                           MUL8
;-----------------------------------------------------------------------


        ; A*256 + X = FAC1 * FAC2
MUL8
        lda #$00
        ldx #$08
        clc
m0      bcc m1
        clc
        adc FAC2
m1      ror
        ror FAC1
        dex
        bpl m0
        ldx FAC1
        rts     

;-----------------------------------------------------------------------
;                                                            basic off
;-----------------------------------------------------------------------

BASIC_OFF
        
        LDA $01
        AND #$FE
        STA $01
        RTS

;-----------------------------------------------------------------------
;                                               SET EXTENDED COLOR MODE
;-----------------------------------------------------------------------

; Set extended color mode by setting bit 6 of $D011

SET_EXTENDED_COLOR_MODE

        LDA $D011
        ORA #$40
        STA $D011

        RTS
        
;-----------------------------------------------------------------------
;                                        SET EXTENDED COLOR MODE COLORS
;-----------------------------------------------------------------------
; A - COLOR 2
; X - COLOR 3
; Y - COLOR 4
; BORDER AND COLOR 1 ARE SET AT NORMAL ADDRESSES (D020, D021)

SET_EXTENDED_COLORS
        
        STA $D022
        STY $D023
        STX $D024
        RTS

;-------------------------------------------------------------------------------
;                                            INITIALIZE_SCREEN_BUFFER_POINTERS
;-------------------------------------------------------------------------------

; Initialize the buffer pointers BUFFER_SCREEN_FRONT and BUFFER_SCREEN_BACK.
; The pointers are calculated based on the the values of MEMORY_SCREEN_BANK_A
; and MEMORY_SCREEN_BANK_B, which describe a bank as an integer from 1 through
; 15.

; To calculate a buffer address based on the bank number and the base address,
; multiply the bank number by 4... this is the hi byte of the final address
; for that bank. After the multiply, add the screen memory base address.

INITIALIZE_SCREEN_BUFFER_POINTERS

        LDA #$00
        STA BUFFER_SCREEN_FRONT         ; Zero lo byte of front buffer pointer
        STA BUFFER_SCREEN_BACK          ; Zero lo byte of back buffer pointer

        LDX #$00
        CLC

; Multiply MEMORY_SCREEN_BANK_A by 4
.BANKA  
        CPX #MEMORY_SCREEN_BANK_A
        BEQ .ADONE
        ADC #$04
        INX
        JMP .BANKA
.ADONE
        STA 1+BUFFER_SCREEN_FRONT       ; Store result in hi byte of front addr.


        LDX #$00          ; Reset X
        LDA #$00          ; Reset A

; Multiply MEMORY_SCREEN_BANK_B by 4
.BANKB
        CPX #MEMORY_SCREEN_BANK_B
        BEQ .BDONE
        ADC #$04
        INX 
        JMP .BANKB
        
.BDONE
        STA 1+BUFFER_SCREEN_BACK        ; Store result in hi byte of back addr.

; Add BUFFER_SCREEN_FRONT to MEMORY_SCREEN_BASE       
        CLC
        LDA BUFFER_SCREEN_FRONT
        ADC #<MEMORY_SCREEN_BASE
        STA BUFFER_SCREEN_FRONT         ; Store lo byte of front buffer addr.
          
        LDA 1+BUFFER_SCREEN_FRONT
        ADC #>MEMORY_SCREEN_BASE
        STA 1+BUFFER_SCREEN_FRONT       ; Store hi byte of front buffer addr.
 
; Add BUFFER_SCREEN_BACK to MEMORY_SCREEN_BASE       
        CLC
        LDA BUFFER_SCREEN_BACK
        ADC #<MEMORY_SCREEN_BASE
        STA BUFFER_SCREEN_BACK          ; Store lo byte of back buffer addr.
        
        LDA 1+BUFFER_SCREEN_BACK
        ADC #>MEMORY_SCREEN_BASE
        STA 1+BUFFER_SCREEN_BACK        ; Store hi byte of back buffer addr.
        
        RTS
          
;-----------------------------------------------------------------------
;                                                 INIT_CHARACTER_BUFFER
;-----------------------------------------------------------------------

INIT_CHARACTER_BUFFER
        
        LDA #0
        STA BUFFER_CHARACTER            ; Clear lo byte of buffer ptr.
        STA 1+BUFFER_CHARACTER          ; Clear hi byte of buffer ptr.
        
        LDX #0
        CLC
          
.CALC
        CPX #MEMORY_CHAR_BANK
        BEQ .CALC_DONE
        ADC #$08
        INX
        JMP .CALC
          
.CALC_DONE
        CLC
        ADC #>MEMORY_SCREEN_BASE
        STA 1+BUFFER_CHARACTER
        
        LDA #MEMORY_CHAR_BANK     ; $D018 NEED THE BANK IN BITS 2,3,4
        ASL                       ; GET THE BANK AND MOVE IT TO THOSE BITS
        STA TEMP
        
        LDA $DC0E
        AND #$FE
        STA $DC0E                 ; TURN OFF INTURRUPTS
        
        LDA #$00
        STA POINTER1_LO
        LDA #$D0
        STA POINTER1_HI
        
        LDA #$00
        STA POINTER2_LO
        LDA 1+BUFFER_CHARACTER
        STA POINTER2_HI
                
          
        LDA $01
        AND #251
        STA $01
        
        LDX #$08
        LDY #$00
        JSR MEMCPY
        
        LDA 1
        ORA #4
        STA 1
        
        LDA $D018
        AND #$F9                  ; MASK OFF BITS 2,3,4                  
        ORA TEMP                  ; PLUG IN THE CHAR BANK
        STA $D018                 ; CHAR BANK SET
        
        LDA $DC0E
        ORA #$01
        STA $DC0E                 ; TURN INTURRUPTS BACK ON
        RTS
          
;-----------------------------------------------------------------------
;                                              INITIALIZE_SCREEN_MEMORY
;-----------------------------------------------------------------------
          

INITIALIZE_SCREEN_MEMORY

          
        JSR INITIALIZE_SCREEN_BUFFER_POINTERS
        JSR INIT_CHARACTER_BUFFER

        LDA #MEMORY_SCREEN_BANK_A
        ASL
        ASL
        ASL
        ASL
        STA TEMP
        
        LDA $D018
        AND #$0F
        ORA TEMP
        STA $D018
        
        LDA BUFFER_SCREEN_BACK
        STA BUFFER_SCREEN_CURRENT
        LDA 1+BUFFER_SCREEN_BACK
        STA 1+BUFFER_SCREEN_CURRENT
        RTS
          

          
;-----------------------------------------------------------------------
;                                                   FLIP_SCREEN_BUFFERS
;-----------------------------------------------------------------------

FLIP_SCREEN_BUFFERS

        LDA 1+BUFFER_SCREEN_CURRENT
        CMP 1+BUFFER_SCREEN_BACK
        BEQ .SET_BACK
          
.SET_FRONT
; Set the vic to read from the front buffer, set the buffer pointer to the back buffer         
        LDA BUFFER_SCREEN_BACK
        STA BUFFER_SCREEN_CURRENT
        LDA 1+BUFFER_SCREEN_BACK
        STA 1+BUFFER_SCREEN_CURRENT

        LDA #MEMORY_SCREEN_BANK_A
        JMP .SET

.SET_BACK
; Set the vic to read from the back buffer, set the buffer pointer to the front buffer
        LDA BUFFER_SCREEN_FRONT
        STA BUFFER_SCREEN_CURRENT
        LDA 1+BUFFER_SCREEN_FRONT
        STA 1+BUFFER_SCREEN_CURRENT

        LDA #MEMORY_SCREEN_BANK_B

.SET
        ASL
        ASL
        ASL
        ASL
        STA TEMP
        
        LDA $D018
        AND #$0F 
        ORA TEMP
        STA $D018
        
        RTS

;-----------------------------------------------------------------------
;                                                       WAIT_FOR_RASTER
;-----------------------------------------------------------------------

WAIT_FOR_RASTER

.HIGH_BITA
        LDA $D011
        BIT 8+BITS
        BEQ .HIGH_BITA

.HIGH_BITB
        LDA $D011
        BIT 8+BITS
        BNE .HIGH_BITB
        RTS

;-----------------------------------------------------------------------
;                                                          WAIT FOR KEY
;-----------------------------------------------------------------------

WAIT_FOR_KEY

        JSR SCAN_KEY            ; Kernal: scan key
        JSR GET_CHAR            ; Kernal: read key queue
        CMP #$00                ; Is queue empty?
        BEQ WAIT_FOR_KEY        ; If empty, rescan
        RTS                     ; KEY DETECTED: exit
                                ; ACCUMULATOR: KEY CODE

;-----------------------------------------------------------------------
;                                                                 DELAY
;-----------------------------------------------------------------------
; A -> DELAY STEPS

DELAY
        CLC
        SBC #$01
        CMP #$00
        BNE DELAY
        RTS
        
;-----------------------------------------------------------------------
;                                                   CHARACTER TO SCREEN
;-----------------------------------------------------------------------
; A -> CHARACTER
; X -> X LOCATION
; Y -> Y LOCATION

CHARACTER_TO_SCREEN
        
        STA TEMPA

        LDA #0 ;#>MEMORY_SCREEN     ; COPY THE START OF SCREEN MEMORY
        STA POINTER2_HI        ; TO THE SCRATCH POINTER IN ZERO-PAGE

        TYA                     ; MOVE Y --> A FOR MULTIPLICATION X40
        STA TEMP
        ASL 
        ASL 
        ADC TEMP
        
        ASL 
        ASL
        ROL POINTER2_HI
        ASL
        ROL POINTER2_HI
        
        STA POINTER2_LO
        
        LDA POINTER2_HI
        ADC POINTER1_HI
        STA POINTER2_HI

        TXA
        TAY
        LDA TEMPA

        STA (POINTER2_LO),Y
        RTS
        
;-----------------------------------------------------------------------
;                                                            SET SCREEN
;-----------------------------------------------------------------------
; A -> CHARACTER

SET_SCREEN
        
        TAX 
        
        LDA 1+BUFFER_SCREEN_CURRENT
        STA POINTER2_HI
        LDA BUFFER_SCREEN_CURRENT
        STA POINTER2_LO
        
        TXA
        LDY #0
@LOOP
        STA (POINTER2_LO),Y
        INY
        CPY #0
        BNE @LOOP
        
        INC POINTER2_HI

.LOOP2
        STA (POINTER2_LO),Y
        INY
        CPY #0
        BNE .LOOP2
        
        INC POINTER2_HI
        
.LOOP3
        STA (POINTER2_LO),Y
        INY
        CPY #0
        BNE .LOOP3
        
        INC POINTER2_HI
        
.LOOP4
        STA (POINTER2_LO),Y
        INY 
        CPY #$E8
        BNE .LOOP4
        
        RTS

;***********************************************************************
;                                                        SCREEN BUFFERS
;-----------------------------------------------------------------------
        
BUFFER_SCREEN_FRONT
        BYTE $00, $00
BUFFER_SCREEN_BACK
        BYTE $00, $00
BUFFER_SCREEN_CURRENT
        BYTE $00, $00
BUFFER_CHARACTER
        BYTE $00, $00
        
;-----------------------------------------------------------------------
;                                                                 MISC.
;-----------------------------------------------------------------------
FAC1    
        BYTE $00
FAC2   
        BYTE $00
SCRATCH_LO
        BYTE $00
SCRATCH_HI
        BYTE $00
TEMP  
        BYTE $00
TEMPA  
        BYTE $00
TEMPX   
        BYTE $00
TEMPY
        BYTE $00
R16
        BYTE $00, $00