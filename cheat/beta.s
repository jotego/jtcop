; use "cheatzip" script to assemble and send to MiSTer

; The LED will blink if the cheat bits 7:0 are enabled
; CPSx work RAM offset = 30'0000h

; Register use
; SB = LED

constant LED,      6
constant VRAM_COL, 8
constant VRAM_ROW, 9
constant VRAM_DATA,A
constant VRAM_CTRL,B
constant ST_ADDR,  C
constant ST_DATA,  D
constant DEBUG_BUS,F
constant FLAGS,    10
constant BOARD_ST0,14
constant BOARD_ST1,15
constant BOARD_ST2,16
constant BOARD_ST3,17
constant ANA1RX,   1C
constant ANA1RY,   1D
constant FRAMECNT, 2c
constant KEYS,     30
constant WATCHDOG, 40
constant ANA2RX,   4C
constant ANA2RY,   4D
constant STATUS,   80

    ; wait for a few seconds. This prevents
    ; the CLS call from happening during ROM
    ; download
    load s0,120'd
bootloop:
    input s1,FRAMECNT
    compare s1,0
    jump nz,bootloop
    sub s0,1
    jump nz,bootloop

    load sb,0
    outputk 0,VRAM_CTRL ; disable display


    input s0,STATUS
    test s0,1
    jump z, UNLOCKED   ; unlocked, do nothing

    outputk 3,VRAM_CTRL ; enable display
    call CLS


BEGIN:
    output s0,WATCHDOG

    ; Detect blanking
    input s0,STATUS
    and   s0,0x20;   test for blanking
    jump z,.inblank
    jump .notblank
.inblank:
    fetch s1,0
    test s1,0x20
    jump z,.notblank
    store s0,0  ; stores last LVBL
    call ISR ; do blank procedure
    jump BEGIN
.notblank:
    store s0,0
    jump BEGIN

ISR:
    input s0,FRAMECNT     ; frame counter
    compare s0,0
    jump nz,SCREEN
    ; invert LED signal
    add sb,1

SCREEN:

    outputk 3,VRAM_ROW
    load s4,msg0'upper
    load s3,msg0'lower
    call write_string
    outputk 4,VRAM_ROW
    load s4,msg1'upper
    load s3,msg1'lower
    call write_string
    outputk 5,VRAM_ROW
    load s4,msg2'upper
    load s3,msg2'lower
    call write_string
    outputk 6,VRAM_ROW
    load s4,msg3'upper
    load s3,msg3'lower
    call write_string

    ; show the expired message if needed
    input s6,STATUS
    test s6,2
    jump z,not_expired
    outputk 8,VRAM_ROW
    load s4,expired'upper
    load s3,expired'lower
    call write_string
not_expired:
    outputk 8,VRAM_ROW
    load s4,msg4'upper
    load s3,msg4'lower
    call write_string
    outputk 9,VRAM_ROW
    load s4,msg5'upper
    load s3,msg5'lower
    call write_string

CLOSE_FRAME:
    output sb,LED
    return

write_string:
    load s0,0
.loop:
    call@ (s4,s3)
    sub s2,20
    output s0,VRAM_COL
    output s2,A
    add s0,1
    compare s0,20
    return z
    add s3,1
    addcy s4,0
    jump .loop

    ; s0 screen row address
    ; s1 number to write
    ; modifies s2
    ; s0 updated to point to the next column
WRITE_HEX:
    output s0,VRAM_COL
    load s2,s1
    sr0 s2
    sr0 s2
    sr0 s2
    sr0 s2
    call WRITE_HEX4
    add s0,1
    output s0,VRAM_COL
    load s2,s1
    call WRITE_HEX4
    add s0,1    ; leave the cursor at the next column
    return

    ; s2 number to write
    ; modifies s2
WRITE_HEX4:
    and s2,f
    compare s2,a
    jump nc,.over10
    jump z,.over10
    add s2,16'd
    jump .write
.over10:
    add s2,23'd
.write:
    output s2,VRAM_DATA
    return

    ; clear screen
    ; modifies s0,s1,s2
CLS:
    load s0,31
    load s1,31
    load s2,0
.loop_row:
    load s1,31
    output s0,VRAM_COL
.loop_col:
    output s1,VRAM_ROW
    output s2,a
    sub s1,1
    jump nc,.loop_col
    sub s0,1
    jump nc,.loop_row
    return

UNLOCKED:
    output s0,WATCHDOG

    ; Detect blanking
    input s0,STATUS
    and   s0,0x20;   test for blanking
    jump z,.inblank
    jump .notblank
.inblank:
    fetch s1,0
    test s1,20
    jump z,.notblank
    store s0,0  ; stores last LVBL
    call ISR_UNLOCKED ; do blank procedure
    jump UNLOCKED
.notblank:
    store s0,0
    jump UNLOCKED

ISR_UNLOCKED:
    ; Check game. Heavy Barrel starts with 0024 41 00
    ;             Dragon Ninja starts with 00FF C0 00
    load s2,00
    load s1,00
    load s0,00
    call READ_SDRAM
    compare s6,24
    jump nz,NO_ANALOGUE_STICK

    ; Process Heavy Barrel input 1P
    input s2,ANA1RX
    input s3,ANA1RY
    call PROCESS_JOY
    ; FF8066=orientation
    load s2,10
    load s1,00
    load s0,33
    fetch s4,10
    compare s4,ff
    jump z,.else4
    load s5,1
    call WRITE_SDRAM
.else4:

    ; Process Heavy Barrel input 2P
    input s2,ANA2RX
    input s3,ANA2RY
    call PROCESS_JOY
    ; FF80AA=orientation
    load s2,10
    load s1,00
    load s0,55
    fetch s4,10
    compare s4,ff
    jump z,.else5
    load s5,1
    call WRITE_SDRAM
.else5:
NO_ANALOGUE_STICK:
    return

; strings
string beta0$,  "    JTNINJA (c) Jotego 2021     "
string beta1$,  "    This core is in beta phase  "
string beta2$,  "    Join the beta test team at  "
string beta3$,  "    https://patreon.com/topapate"
string beta4$,  "    Place the file jtbeta.zip   "
string beta5$,  "    in the folder games/mame    "
string expired$,"    This beta RBF has expired   "
msg0:
    load&return s2, beta0$
msg1:
    load&return s2, beta1$
msg2:
    load&return s2, beta2$
msg3:
    load&return s2, beta3$
msg4:
    load&return s2, beta4$
msg5:
    load&return s2, beta5$
expired:
    load&return s2, expired$

    ; SDRAM address in s2-s0
    ; SDRAM data out in s4-s3
    ; SDRAM data mask in s5
    ; Modifies sf
WRITE_SDRAM:
    output s5, 5
    output s4, 4
    output s3, 3
    output s2, 2
    output s1, 1
    output s0, 0
    output s1, 0xC0   ; s1 value doesn't matter
.loop:
    input  sf, 0x80
    test sf, 0xC0
    return z
    jump .loop

    ; Modifies sf
    ; Read data in s7,s6
READ_SDRAM:
    output s2, 2
    output s1, 1
    output s0, 0
    output s1, 0x80   ; s1 value doesn't matter
.loop:
    input  sf, 0x80
    test sf, 0xC0
    jump nz,.loop
    input s6,6
    input s7,7
    return

;-----------------------------------------------------------------
    ; s2 = X (input)
    ; s3 = Y (input)
    ; s0 = position or FF if no new position
PROCESS_JOY:
    ; is it up?
    load s0,s2     ; check that c0>X<40
    and s0,80
    jump nz,.cleft
    load s0,s2
    compare s0,40
    jump nc,.right
    jump .centre
.cleft:
    load s0,s2
    compare s0,c0
    jump c,.left
.centre:
    load s0,s3
    compare s0,c0       ; check that y<c0
    jump nc,keep_ret
    and s0,80
    jump z,.down
    load s0,0           ; looking up
    jump st_ret
.down:
    load s0,s3
    compare s0,40
    jump c,keep_ret
    load s0,10
    jump st_ret

.right:
    load s0,s3
    and s0,80
    jump nz,.rup
    load s0,s3
    compare s0,40
    jump c,.fullright
    load s0,c
    jump st_ret
.fullright:
    load s0,8
    jump st_ret
.rup:
    load s0,4
    jump st_ret

.left:
    load s0,s3
    and s0,80
    jump nz,.lup
    load s0,s3
    compare s0,40
    jump c,.fullleft
    load s0,14
    jump st_ret
.fullleft:
    load s0,18
    jump st_ret
.lup:
    load s0,1c
    jump st_ret

keep_ret:
    load s0,ff
    store s0,10
    return
st_ret:
    store s0,10
    return


default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR
