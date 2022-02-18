#!/bin/bash
if [ -z "$1" ]; then
    echo "Use cpmame.sh <scene number>"
    exit 1
fi

mkdir -p $1
mv ba?_{map,scr}.bin pal.bin obj.bin simwr.csv $1
