 macro   NOPx3
     nop
     nop
     nop
 endm

* Wait for driver ready macro
	macro	MCD_WAIT
.\@
		tst.b	MCD_STAT
		bne.s	.\@
	endm


; macro: checkMuicID
; \1.b:  id         value of the musicID to check   (hexadecimal value)
; \2.b:  register   register to check               (register)
; \3.w:  jmpTo      label to branch to if eqal      (string)
    macro   checkMusicID id,register,jmpTo
        cmp.b   \1,\2       
        beq     \3
    endm


; macro: msuPlayTrack   Play track once and stop
; \1.b:  track          no of the track to play (decimal)
    macro   msuPlayTrack track
        MCD_WAIT
        move.w  #($1100|\1),MCD_CMD          ; send msu cmd
        addq.b  #1,MCD_CMD_CK                ; Increment command clock
    endm


; macro: msuLoopTrack   Play track once and loop
; \1.b:  track          no of the track to play (decimal)
    macro   msuLoopTrack track
        MCD_WAIT
        move.w  #($1200|\1),MCD_CMD          ; send msu cmd
        addq.b  #1,MCD_CMD_CK                ; Increment command clock
    endm


; macro: msuLoopTrackSL Play track once and loop seemlessly
; \1.b:  track      no of the track to play                     (decimal)
; \2.l:  seekTo     no of frames (1s/75) to seek to (seemless)  (decimal)
    macro   msuLoopTrackSL track,seekTo
        MCD_WAIT
        move.w  #($1A00|\1),MCD_CMD          ; send msu cmd
        move.l  #($00000000|\2),MCD_SEEK	 ; seek to audio frame when complete
        addq.b  #1,MCD_CMD_CK                ; Increment command clock
    endm
