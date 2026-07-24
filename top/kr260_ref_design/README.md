KR260 demo board
================

Instructions on how to build the Vivado project and synthesize the bitstream: https://gitlab.com/ohwr/project/wr-cores/-/tree/kr260-wr/syn/kr260_ref_design

Notes
========

refclk0 is 156.25Mhz (*8 = 1250Mhz)<br>
&nbsp; SOM240_2 C3/C4 FPGA:Y6/Y5

refclk1 is 74.25Mhz<br>
&nbsp; SOM240_2 A7/A8 FPGA:V5/V6

sfp+ is connected to<br>
&nbsp; gth_dp2_*<br>
&nbsp; SOM240_2m JA2B B1/B2/B5/B6<br>
&nbsp; FPGA T2/T1/R4/R3<br>
&nbsp; MGTH 2_224

MGTH 0 and 1 connected to J22 connector.<br>
MGTH 3 is not connected.

sfp led:<br>
&nbsp; 1_a12 FPGA:G8<br>
&nbsp; 1_a13 FPGA:F7

sfp i2c:<br>
&nbsp; sda: 2_b50 FPGA:AC11<br>
&nbsp; scl: 2_b49 FPGA:AB11

sfp others:<br>
&nbsp; tx_fault:   hda19 1_c23  FPGA:A10<br>
&nbsp; tx_disable: hdb19 2_a47  FPGA:Y10<br>
&nbsp; mod_abs:    hdb18 2_a46  FPGA:W10<br>

clock: hpa_clk0p_clk 25_000_000 (1v8)<br>
&nbsp; 1_a6 FPGA:C3<br>
&nbsp; 2_d18 FPGA:L3

uart on the USB is UART1. Uboot and linux use 115200-8-n1

AXI bus at 0x8000_0000

PMOD4:         SOM2      FPGA (LVCMOS33)<br>
1-2  // HDB08-HDB12  //  C48-B44  // AC12-AD11<br>
3-4  // HDB09-HDB13  //  C50-B45  // AD12-AD10<br>
5-6  // HDB10-HDB14  //  C51-B46 //  AE10-AA11<br>
7-8  // HDB11-HDB15  //  C52-B48 //  AF10-AA10<br>
9-10 // GND  //-GNA<br>
11-12  //3V3  //-3V3<br>

Docs:
=====

Xilinx ds987
https://github.com/Xilinx/XilinxBoardStore/blob/035e9055a6a88989048b9a22b2a372035a4c2d1d/boards/Xilinx/kr260_som/1.1/part0_pins.xml
https://github.com/Xilinx/XilinxBoardStore/blob/2022.2/boards/Xilinx/kr260_carrier/1.0/board.xml


devmem2
=======

Play with leds:

$ sudo devmem2 0x80001000 w 2


loading bitstream
=================

'xmutil' is a wrapper, calls dfx-mgr-client for applications

echo top.bit.bin > /sys/class/fpga_manager/fpga0/firmware


QPLL
====

According to ug576 v1.7.1 p 51, both QPLL are fractional PLLs

QPLL0 is used for the main gthe4 while QPLL1 is used for the helper frequency (through a second gthe4).

As the fractional PLL can only increase the frequency, a negative offset is added to the frequency through TXPIPPM.