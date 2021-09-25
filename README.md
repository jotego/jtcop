Game                            | Popularity
--------------------------------|-------------
Bad Dudes vs. Dragonninja       | 700
Robocop                         | 691 
Midnight Resistance             | 198
Hippodrome / Fighting Fantasy   | 138
Heavy Barrel                    |  42  
Sly Spy                         |  13
Bandit                          |   1
Boulder Dash                    |   1
Birdie Try                      |   0

# BAC06

Column scroll: 0x80 bytes -> 0x40 values
Row scroll: 0x400 bytes -> 0x200 values

BAC06 chip |   Region    | Total Size  |  MSFT
-----------|-------------|-------------|---------
 3A, main  |   B0/       |   16kB      |  Yes
 7A, main  |   B1/       |    4kB      |  Yes
 6E, second|   B2/       |    4kB      |  No

# FPGA Requirements

Block  |  kB  | Location | Use
-------|------|----------|-----------
B0     |  16  |  SDRAM   | VRAM + RAM?
B1     |   4  |   BRAM   | VRAM
B2     |   4  |   BRAM   | VRAM
OBJ    |   1  |   BRAM   | line buffer*
OBJ    |   2  |          | obj RAM
OBJ    |   2  |   BRAM   | obj table buffer
Main   |  16  |  SDRAM   | M68000 RAM
6502   |   2  |   BRAM   | 6502A RAM
HuC6280|  10  |  SDRAM   | protection
HuC6280|   1  |   BRAM   | firmware
i8751  |   4  |   BRAM   | firmware
i8751  |   1  |   BRAM   | on-chip RAM
JT03   |  12  |   BRAM   |
JTOPL  |   9  |   BRAM   |
FX68K  |   6  |   BRAM   | microcode

Model   | Total  |  BRAM
--------|--------|---------
Huc6280 | 85     |  43
I8751   | 79     |  37


* the line buffer is not in the schematics,
there is a signal changing each frame that
could be used for a frame buffer. But there
is no frame buffer memory either.
Maybe the MXC-06 chip had internal memory
for line buffers