#!/bin/bash
mkdir -p mra/_alt

cd $JTUTIL/src
make mame2mra || exit
cp mame2mra ../bin
cd -
mame2mra -def $CORES/cop/hdl/jtcop.def -toml cop.toml -outdir mra $*
