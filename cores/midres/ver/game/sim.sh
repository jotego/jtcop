#!/bin/bash

SYSNAME=midres
GAME=midres
SCENE=
OTHER=
HEXDUMP=-nohex
SIMULATOR=-verilator
SDRAM_SNAP=

eval `jtcfgstr -output=bash -core $SYSNAME`

while [ $# -gt 0 ]; do
    case $1 in
        -g)
            shift
            GAME=$1
            if [ ! -e $ROM/$GAME.rom ]; then
                echo "Cannot find ROM file $ROM/$GAME.rom"
                exit 1
            fi
            ;;
        -s|-scene)
            shift
            SCENE=$1;;
        *)
            OTHER="$OTHER $1";;
    esac
    shift
done

ln -sf $ROM/$GAME.rom rom.bin

if [ -n "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo "Scene folder $SCENE not found"
        exit 1
    fi
    # only support for pal + objects
    cat $SCENE/pal.bin | drop1 -l > pal_hi.bin
    cat $SCENE/pal.bin | drop1    > pal_lo.bin
    cat $SCENE/obj.bin | drop1 -l > obj_hi.bin
    cat $SCENE/obj.bin | drop1    > obj_lo.bin
    cp $SCENE/simwr.csv .
    jtpatch -dst sdram_bank0.bin -src $SCENE/ba0_scr.bin -offset16 0x102000 -swab || exit $?
    jtpatch -dst sdram_bank0.bin -src $SCENE/ba0_map.bin -offset16 0x103000 -swab || exit $?
    jtpatch -dst sdram_bank0.bin -src $SCENE/ba1_scr.bin -offset16 0x104000 -swab || exit $?
    jtpatch -dst sdram_bank0.bin -src $SCENE/ba1_map.bin -offset16 0x104400 -swab || exit $?
    jtpatch -dst sdram_bank0.bin -src $SCENE/ba2_scr.bin -offset16 0x106000 -swab || exit $?
    jtpatch -dst sdram_bank0.bin -src $SCENE/ba2_map.bin -offset16 0x106400 -swab || exit $?
    OTHER="$OTHER -d NOSOUND -d NOMAIN -d GRAY -w -video 2"
else
    # export YM2203=1
    # export YM3812=1
    # export MC6502=1
    # export I8051=1
    # export MSM6295=1
    rm -f char_*.bin pal_*.bin obj_*.bin scr.bin
fi

if which ncverilog >/dev/null; then
    # Options for non-verilator simulation
    SIMULATOR=
    HEXDUMP=
fi

# Cannot use jtsim_sdram because of gfx
# address changes during load
# rm -f sdram_bank?.*
# jtsim_sdram $HEXDUMP  \
#     -banks $BA1_START $BA2_START $BA3_START \
#     -stop $MCU_START \
#     $SDRAM_SNAP || exit $?


jtsim -mist -sysname $SYSNAME $SIMULATOR \
    -videow 256 -videoh 240 -d JTFRAME_DWNLD_PROM_ONLY \
    -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER || exit $?

if [[ ! -z "$SCENE" && -e frame_1.jpg ]]; then
    eom frame_1.jpg 2> /dev/null
fi