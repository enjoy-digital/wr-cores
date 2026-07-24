# KR260 Reference design
This is a reference design for the implementation of White Rabbit which utilizes fractional PLLs on a AMD Kria KR260 starter kit.
The board is equipped with 1 SFP+ cage for the link with a WR switch (or another WR device), but it is missing coax outputs for PPS and 10MHz. The latter are routed to the PMOD connectors (1 and 2) and can be read either with an adapter board or using a oscilloscope probe.

The communication with the MPSOC linux OS can be performed either directly attaching a monitor and keyboard,  or via the use of the PS RJ45 connectors (eth0/eth1), or via the on-board serial UART https://xilinx.github.io/kria-apps-docs/kr260/linux_boot/ubuntu_22_04/build/html/docs/uart.html.


# How to build the Vivado project and synthesize the bitstream
This project has been synthesized with Vivado 2024.2

	   $ hdlmake
	    
	   $ make
	   
	   # to clean the project
	   $ make clean
	

This will generate *kr260_ref_top.bit*

# How to load Linux Ubuntu onto the PS
All instructions for the creation of the SD card are detailed here:
[https://xilinx.github.io/kria-apps-docs/kr260/build/html/docs/linux_boot.html](https://xilinx.github.io/kria-apps-docs/kr260/build/html/docs/linux_boot.html)
It's recommended to use LTS 22.04

# How load GW and uRV SW in the PL
After logging into ubuntu, the GW can be loaded:
	`sudo fpgautil -b kr260_ref_top.bit`
	
Then wrpc-sw should be git cloned into the KRIA, and the wrpc tool compiled.
Using wrpc we can confirm the memsize

    sudo wrpc-sw/tools/wrpc info -b host -b 0x80000000  
    hwfr=0100100b: memsize:  192kB, storage:  0, storage sector size:  256kB hwir=4b523236: KR26

Then the PTPCore software can be configured on another PC with installed the RISC-V gcc compiler v11.x
remember to use: 

 - Architecture -> riscV
 - Target platform -> Generic WR Node with 16-bit PCS/PHY
 - Ram size -> 196608
 - Other parameters are discretionary to the use

Finally the PTPCore SW can be loaded and the vuart can be accessed

    sudo wrpc-sw/tools/wrpc load -b host -b 0x80000000 wrc.elf 
    sudo wrpc-sw/tools/wrpc vuart -b host -b 0x80000000