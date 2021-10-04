-Wno-MULTIDRIVEN
-y $JTFRAME/hdl/video
-y $JTFRAME/hdl/ram
-y $JTFRAME/hdl/sound
-y $JTFRAME/hdl/clocking
-y $JTFRAME/hdl/sdram
-y $JTFRAME/hdl
-y $JTFRAME/hdl/cpu
-y $JTFRAME/hdl/cpu/mc6502
-y $MODULES/jt6295/hdl
-y $MODULES/jtopl/hdl
-y $MODULES/jt12/hdl
-y $MODULES/jt12/jt49/hdl
+define+BUTTONS=5
+define+VIDEO_HEIGHT=240
+define+JTFRAME_SDRAM_BANKS=1
+define+BA3_START='h198000
+define+SEPARATOR=
+define+CORENAME=JTCOP
+define+GAMETOP=jtcop_game
+define+VIDEO_WIDTH=384
+define+BA1_START='h80000
+define+BA2_START='hB0000
+define+GFX3_START='h158000
+define+MCU_START='h218000
+define+TARGET=mist
+define+DATE=211003
+define+COMMIT=nocommit
+define+CORE_OSD=
+define+COLORW=8
+define+JTFRAME_CLK24=1
+define+GFX2_START='hD8000
+define+PCM_START='h90000
+define+PROM_START='h230000
+define+JTFRAME_TIMESTAMP=1633256021
