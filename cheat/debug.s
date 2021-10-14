; use "cheatzip" script to assemble and send to MiSTer

; Shows the scroll settings and the debug bus

constant LED, 6
constant FRAMECNT, 0x2c
constant WATCHDOG, 0x40
constant STATUS, 0x80
constant VRAM_CTRL, 0xB
constant VRAM_COL, 8
constant VRAM_ROW, 9
constant VRAM_DATA, A
constant ST_ADDR, C
constant ST_DATA, D
constant DEBUG_BUS, F
constant GAMERAM, 12
constant KEYS, 30
constant FLAGS, 10

; RAM usage
; 0 = last LVBL
; 1 = enable invincibility

; Register use
; SB = LED

    ; enable interrupt
    load sb,0
    load s0,1
    output s0,VRAM_CTRL ; enable display
    call CLS
    ; Disable invincibility
    load s0,0
    store s0,1
BEGIN:
    output s0,0x40

    ; Detect blanking
    input s0,0x80
    and   s0,0x20;   test for blanking
    jump z,inblank
    jump notblank
inblank:
    fetch s1,0
    test s1,0x20
    jump z,notblank
    store s0,0  ; stores last LVBL
    call ISR ; do blank procedure
    jump BEGIN
notblank:
    store s0,0
    jump BEGIN

ISR:
    load sa,FRAMECNT
    compare sa,0
    jump nz,SCREEN
    ; invert LED signal
    add sb,1

SCREEN:
    ; Show scroll data
    ; Scroll 1 pages
    outputk 3, VRAM_ROW
    load    s7, 0       ; BA0
    call    PRINT_BADATA

    outputk 4, VRAM_ROW
    load    s7, 8       ; BA1
    call    PRINT_BADATA

    outputk 5, VRAM_ROW
    load    s7, 10      ; BA2
    call    PRINT_BADATA


    ; Debug byte
    ; load s0,5
    ; output s0,9 ; row
    ; load s0,2
    ; input  s1, DEBUG_BUS ; debug bus
    ; call PRINT_HEX

    ; Invincibility
    input sa,FRAMECNT
    compare sa,30
    jump nz,.else
    fetch sa,1
    compare sa,4
    jump z,.else
    add sa,1
    store sa,1
.else:

    fetch sa,1
    compare sa,4
    jump nz,.else2
    ; FFA386=10
    load s2,10
    load s1,11
    load s0,c3
    load s4,10
    load s3,10
    load s5,2
    call WRITE_SDRAM
.else2:

    ; Next level flag
    input sa,FLAGS
    fetch sb,2
    compare sb,sa
    jump z,.else3
    store sa,2
    compare sa,1
    jump nz,.else3
    ; FF8216=FF
    load s2,10
    load s1,01
    load s0,0b
    load s4,ff
    load s3,ff
    load s5,0
    call WRITE_SDRAM
    outputk 6, VRAM_ROW
    load s0,2
    input s1,FRAMECNT
    call    PRINT_HEX
.else3:

CLOSE_FRAME:
    output sb,6     ; LED
    return

;-----------------------------------------------------------------

    ; s7 base status address (st_addr signal)
PRINT_BADATA:
    load  s0,2      ; Column cursor
    load  s3,5      ; BA0 H scroll
    add   s3,s7
    call  PRINT_ST16

    add   s0,2
    load  s3,7      ; BA0 V scroll
    add   s3,s7
    call  PRINT_ST16

    add   s0,4
    load  s3,0      ; Mode register 0
    add   s3,s7
    CALL  PRINT_ST8

    add   s0,1
    load  s3,1      ; Mode register 1
    add   s3,s7
    CALL  PRINT_ST8

    add   s0,1
    load  s3,2      ; Mode register 2
    add   s3,s7
    CALL  PRINT_ST8

    add   s0,1
    load  s3,3      ; Mode register 3
    add   s3,s7
    CALL  PRINT_ST8

    return


    ; writes 16-bit status data
    ; s3 points to the MSB st_addr, the LSB is meant to be in s3-1
    ; s2 is modified
    ; s0 is updated to point to the next column
PRINT_ST16:
    output s3,ST_ADDR
    add s3,0   ; nop
    add s3,0   ; nop
    input s1,ST_DATA
    call PRINT_HEX
    sub s3,1
    output s3,ST_ADDR
    add s3,0   ; nop
    add s3,0   ; nop
    input s1,ST_DATA
    call PRINT_HEX
    return

    ; writes 16-bit status data
    ; s3 sets st_addr
    ; s2 is modified
    ; s0 is updated to point to the next column
PRINT_ST8:
    output s3,ST_ADDR
    add s3,0   ; nop
    add s3,0   ; nop
    input s1,ST_DATA
    call PRINT_HEX
    return


    ; s0 screen col address
    ; s1 number to write
    ; modifies s2
    ; s0 updated to point to the next column
PRINT_HEX:
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
    output s2,a
    return

    ; clear screen
    ; modifies s0,s1,s2
CLS:
    load s0,31
    load s1,31
    load s2,0
.loop_row:
    load s1,31
    output s0,8
.loop_col:
    output s1,9
    output s2,a
    sub s1,1
    jump nc,.loop_col
    sub s0,1
    jump nc,.loop_row
    return


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

default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR