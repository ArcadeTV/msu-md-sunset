        include "_macros.asm"

; SETTINGS
PRODUCTION = 1
CHEAT = 0

; I/O
HW_version      equ $A10001                 ; hardware version in low nibble
                                            ; bit 6 is PAL (50Hz) if set, NTSC (60Hz) if clear
                                            ; region flags in bits 7 and 6:
                                            ;         USA NTSC = $80
                                            ;         Asia PAL = $C0
                                            ;         Japan NTSC = $00
                                            ;         Europe PAL = $C0

; MSU-MD vars
MCD_STAT        equ $A12020                 ; 0-ready, 1-init, 2-cmd busy
MCD_CMD         equ $A12010
MCD_ARG         equ $A12011
MCD_CMD_CK      equ $A1201F

IO_Z80BUS       equ $A11100
sID_Z80         equ $A01B03

sID_RAM         equ $FFB099

TOTAL_TRACKS    equ 27

; LABLES: ------------------------------------------------------------------------------------------

        org     $208                            ; Original ENTRY POINT
Game


; OVERWRITES: --------------------------------------------------------------------------------------

        org $4
        dc.l    ENTRY_POINT                     ; custom entry point for redirecting


        org     $100
        dc.b    'SEGA MEGASD     '              ; Make it compatible with MegaSD and GenesisPlusGX

        org     $1A4                            ; ROM_END
        dc.l    $000FFFFF                       ; Overwrite with 8 MBIT size

        org     $33A                            ; Wrong Checksum Bypass
        bra.s   ContinueAfterWrongChecksum

        org     $35E
ContinueAfterWrongChecksum


        org     $73E
        ;jmp     MSU_Play_Sega
MSU_Play_Sega_return

        org     $154E                           ; Sound Hijack
        jmp     playSound

        org     $E1E6                           ; Pause off
        jsr     MSU_PauseOff

        ifne    CHEAT

        endif

; PADDED SPACE: ------------------------------------------------------------------------------------

        org     $80000

MSU_Play_Sega
        lea     ($0000E71C),a6
        move.w  #$2300,sr
        MCD_WAIT
        move.w  #($1100|26),MCD_CMD             ; Send MSU-MD command: Play Track 26
        addq.b  #1,MCD_CMD_CK                   ; Increment command clock
        jmp     MSU_Play_Sega_return


; TABLES: ------------------------------------------------------------------------------------------
    align 2

AUDIO_TBL     ;cmd;code                         ; #Track Name                                         #No.
        dc.w    $1190                           ; Konami Logo                                          01
        dc.w    $1194                           ; Escape (Title)                                       02
        dc.w    $1292                           ; Time to Set Off (Player Select)                      03
        dc.w    $1280                           ; Gunfight at the Sunset Corral (Town Stage 1)         04
        dc.w    $118D                           ; Yuppie! (Stage Clear)                                05
        dc.w    $1193                           ; Wanted! (Boss Introduction)                          06
        dc.w    $1283                           ; Face With Courage (Town Stage 2, Forest Stage 1)     07
        dc.w    $1285                           ; It's Time to Pay (Simon Greedwell)                   08
        dc.w    $1284                           ; Quick Draw (Bonus Stage)                             09
        dc.w    $1281                           ; Butch Cassidy and Sunset Riders (Train Stage 1)      10
        dc.w    $1299                           ; *Train Stage 2                                       11
        dc.w    $128B                           ; Ay, Chihuahua (Paco Loco)                            12
        dc.w    $1282                           ; The Rosy Setting Sun (Mountain Stage 1)              13
        dc.w    $1298                           ; *Mountain Stage 2                                    14
        dc.w    $128A                           ; Me Ready for Pow-Wow (Chief Scalpen)                 15
        dc.w    $1196                           ; Please Help my Friends (Chief Scalpen Clear)         16
        dc.w    $1286                           ; Draw Your Gun! (Forest Stage 2)                      17
        dc.w    $128C                           ; The Great Petal (Sir Richard Rose)                   18
        dc.w    $1297                           ; The Magnificent Four (Sir Richard Rose Part 2)       19
        dc.w    $128E                           ; Continue of Sorrow (Continue)                        20
        dc.w    $1195                           ; Hic Jacet (Game Over)                                21
        dc.w    $129A                           ; Dance Over Night (Easy Game Clear)                   22
        dc.w    $118F                           ; The Big Win (Staff Roll)                             23
        dc.w    $1291                           ; Looking Up at the Stars (Name Entry)                 24
        dc.w    $1288                           ; You and He, Big Trouble (Versus Mode: Round 1)       25
        dc.w    $1289                           ; Adios, Amigo (Versus Mode: Round 2)                  26
        dc.w    $1287                           ; We're Gonna Blow You Away!  (Versus Mode: Round 3)   27
        ; COMMANDS:
        ; E0 - FADEOUT
        ; FE - STOP

; MSU-MD INIT: -------------------------------------------------------------------------------------

        align   2
audio_init
        jsr     MSUDRV
        nop
        
        if      PRODUCTION
        tst.b   d0                          ; if 1: no CD Hardware found
        bne     audio_init_fail             ; Return without setting CD enabled
        endif

ready_init
        MCD_WAIT
        move.w  #($1600|1),MCD_CMD          ; seek time emulation switch
                                            ; 0-on(default state), 1-off(no seek delays)
        addq.b  #1,MCD_CMD_CK               ; Increment command clock
        MCD_WAIT
        move.w  #($1500|255),MCD_CMD        ; Set CD Volume to MAX
        addq.b  #1,MCD_CMD_CK               ; Increment command clock
        rts
audio_init_fail
        jmp     lockout



; ENTRY POINT: -------------------------------------------------------------------------------------

        align   2
ENTRY_POINT
        tst.w   $00A10008                   ; Test mystery reset (expansion port reset?)
        bne Main                            ; Branch if Not Equal (to zero) - to Main
        tst.w   $00A1000C                   ; Test reset button
        bne Main                            ; Branch if Not Equal (to zero) - to Main
Main
        move.b  $00A10001,d0                ; Move Megadrive hardware version to d0
        andi.b  #$0F,d0                     ; The version is stored in last four bits, so mask it with 0F
        beq     Skip                        ; If version is equal to 0, skip TMSS signature
        move.l  #'SEGA',$00A14000           ; Move the string "SEGA" to 0xA14000
Skip
        btst    #$6,(HW_version).l          ; Check for PAL or NTSC, 0=60Hz, 1=50Hz
        bne     jump_lockout                ; branch if != 0
        jsr     audio_init
        jmp     Game
jump_lockout
        jmp     lockout


; Sound: -------------------------------------------------------------------------------------

playSound:
        move    sr,-(sp)
        movem.l d0-d4/a0-a1,-(sp)

        move.b  ($FFB066).l,d0

        cmpi.b  #$FE,d0
        beq.w   MSU_Stop
        cmpi.b  #$E0,d0
        beq.w   MSU_Fade
        cmpi.b  #$F0,d0
        beq.w   MSU_PauseOn

        move.l  #$00,d2                         ; Set d2 to 0 as counter (track number)
        move.l  #$00,d3                         ; Set d3 to 0 as counter (table index)
        lea     AUDIO_TBL,a1                    ; Load audio table address into a1
loop
        move.w  (a1,d3),d4                      ; Load table entry into d4
        cmp.b   d4,d0                           ; Compare given sound ID in d0 to table entry loaded into d4
        beq.s   ready                           ; If given sound ID matches the entry, d2 is our track number, so we branch to .ready
                                                ; sound ID did not match:
        addi    #1,d2                           ; Increment d2 (track number)
        addi    #2,d3                           ; Increment d3 by word-size (table index)
        cmp.b   #TOTAL_TRACKS+1,d2              ; If we reached the total number of tracks, abort. (plus 1 for loop-breaking)
        beq.s   passthrough                     ; If d2 equals TOTAL_TRACKS+1, no match found, branch to .passthrough, break loop
        bra.s   loop                            ; Branch to .loop
        
ready
        addi    #1,d2                           ; Increment d2 (skipped in the last repetition of the loop)
        move.b  d2,d4                           ; Set play command, compose by setting byte from track-counter into word-sized command:
                                                ; given: [cmd][sID] -> after: [cmd][trackNo]
        MCD_WAIT
        move.w  d4,MCD_CMD                      ; Send MSU-MD command
        addq.b  #1,MCD_CMD_CK                   ; Increment command clock

        move.b  #$FF,($FFB066).l                ; mute

passthrough:
        ori     #$700,sr
        move.w  #$100,(IO_Z80BUS).l
TEST_IO_Z80BUS:
        btst    #0,(IO_Z80BUS).l
        bne.s   TEST_IO_Z80BUS
        nop
        jsr     $15D2
        tst.b   ($FFB066).l
        beq.s   playSound_exit
        move.b  ($FFB066).l,($A01B03).l
        clr.b   ($FFB066).l

playSound_exit:
        move.b  ($FFB067).l,($A01B00).l
        move.b  ($FFB068).l,($A01B01).l
        move.b  ($FFB069).l,($A01B02).l
        move.b  ($FFB06A).l,($FFB067).l
        move.b  ($FFB06B).l,($FFB068).l
        clr.b   ($FFB069).l
        clr.b   ($FFB06A).l
        clr.b   ($FFB06B).l
        move.w  #0,(IO_Z80BUS).l
        movem.l (sp)+,d0-d4/a0-a1
        move    (sp)+,sr
        rts

MSU_Stop
        MCD_WAIT
        move.w  #($1300|0),MCD_CMD              ; send cmd: pause track, no fade
        addq.b  #1,MCD_CMD_CK                   ; Increment command clock
        bra.w   passthrough
MSU_Fade
        MCD_WAIT
        move.w  #($1300|40),MCD_CMD             ; send cmd: pause track, no fade
        addq.b  #1,MCD_CMD_CK                   ; Increment command clock
        bra.w   passthrough

MSU_PauseOn
        MCD_WAIT
        move.w  #($1300|0),MCD_CMD              ; send cmd: pause track, no fade
        addq.b  #1,MCD_CMD_CK                   ; Increment command clock
        move.w  #1,($FFC012).l                  ; adopt original instruction: set Pause flag
        bra.w   passthrough
MSU_PauseOff
        MCD_WAIT
        move.w  #($1400|0),MCD_CMD              ; send cmd: pause track, no fade
        addq.b  #1,MCD_CMD_CK                   ; Increment command clock
        clr.w   ($FFC000).l                     ; adopt original instruction: clear Pause flag
        rts

; MSU-MD DRIVER: -----------------------------------------------------------------------------------

        align 4
MSUDRV
        incbin  "msu-drv.bin"


; LOCKOUT SCREEN: ----------------------------------------------------------------------------------

        align   4
lockout
        incbin  "msuLockout.bin"

