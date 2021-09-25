#!/bin/bash
mkdir -p mra/_alt

mame2mra -def $CORES/cop/hdl/jtcop.def -toml cop.toml -outdir mra $*
