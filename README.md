# JTCOP FPGA Clone of DEC0 Hardware by Jose Tejada (@topapate)

You can show your appreciation through
* Patreon: https://patreon.com/topapate
* Paypal: https://paypal.me/topapate

Yes, you always wanted to have a Robocop arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

What you get with this is an extremely accurate (allegedly 100% accurate) clone of the original hardware.

I hope you will have as much fun with it as I had it while making it!

# The Cores

There are two core flavours:

* jtcop, for Robocop and the other games using the HuC processor
* jtninja, for Bad Dudes and the rest using the i8751 MCU

The correct core is selected by the MRA files (MiSTer) or ARC files (MiST)

# The Games

Game                            | Protection | Popularity
--------------------------------|------------|--
Bad Dudes vs. Dragonninja       | i8751      | 700
Robocop                         | HuC6280    | 691
Midnight Resistance             | HuC6280    | 198
Hippodrome / Fighting Fantasy   | i8751      | 138
Heavy Barrel                    | HuC6280    |  42
Sly Spy                         | HuC6280    |  13
Bandit                          | i8751      |   1
Boulder Dash                    | HuC6280    |   1
Birdie Try                      | i8751      |   0

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
B1     |   4  |  SDRAM   | VRAM
B2     |   4  |  SDRAM   | VRAM
OBJ    |   1  |   BRAM   | line buffer*
OBJ    |   2  |   BRAM   | obj RAM
OBJ    |   2  |   BRAM   | obj table buffer
Main   |  16  |  SDRAM   | M68000 RAM
6502   |   2  |   BRAM   | 6502A RAM
HuC6280|  10  |   BRAM   | protection
HuC6280|   1  |   BRAM   | firmware
i8751  |   4  |   BRAM   | firmware
i8751  |   1  |   BRAM   | on-chip RAM
JT03   |  12  |   BRAM   |
JTOPL  |   9  |   BRAM   |
FX68K  |   6  |   BRAM   | microcode
Scan2x |   2  |   BRAM   |
OSD    |   2  |   BRAM   |
Credits|   1  |   BRAM   |

Model   |  BRAM
--------|---------
Huc6280 |  53
I8751   |  47


* the line buffer is not in the schematics,
there is a signal changing each frame that
could be used for a frame buffer. But there
is no frame buffer memory either.
Maybe the MXC-06 chip had internal memory
for line buffers