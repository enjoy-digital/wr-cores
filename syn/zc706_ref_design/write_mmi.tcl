#Created by stephenm@xilinx.com. This is not supported by WTS
#The cell_name is the name of the Block RAM in the BD.
#This has been tested with a memory range 0K - 1M
#This only supports data width of 32 bits.
#Adjusted by frederik.pfautsch@missinglinkelectronics.com for WhiteRabbit (wr-cores)

proc write_mmi {cell_name {part ""}} {
	if {$part == ""} {
		set part [get_property PART [current_project]]
	}
	set proj [current_project]
	set filename "${cell_name}.mmi"
	set fileout [open $filename "w"]
	set brams [split [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.bram.* }] " "]
	#isolate all BRAMs identified by cell_name
	set cell_name_bram ""
	for {set i 0} {$i < [llength $brams]} {incr i} {
		if { [regexp -nocase ".*$cell_name.*" [lindex $brams $i]] } {
			lappend cell_name_bram [lindex $brams $i]
		}
	}
	puts $cell_name_bram
	set proc_found 0
	set inst_path [split [get_cells -hierarchical -filter { NAME =~  "*microblaze*" } ] " "]
	if {$inst_path == ""} {
		puts "Warning: No Processor found"
		set inst_path "dummy"
	} else {
		set proc_found 1
		set inst_path [lindex $inst_path 0]
	}

	puts $fileout "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
	puts $fileout "<MemInfo Version=\"1\" Minor=\"0\">"
	set inst_temp [lindex $brams 0]
	set loc_temp [string first $cell_name $inst_temp]
	set inst [string range $inst_temp 0 $loc_temp]
	set new_inst [string last "/" $inst]
	set new_inst [string range $inst 0 $new_inst-1]
	puts $fileout "  <Processor Endianness=\"Little\" InstPath=\"$inst_path\">"
	set bram_range 0
	for {set i 0} {$i < [llength $cell_name_bram]} {incr i} {
		set bram_type [get_property REF_NAME [get_cells [lindex $cell_name_bram $i]]]
		if {$bram_type == "RAMB36E1"} {
			set bram_range [expr {$bram_range + 4096}]
		}
	}
	puts $fileout "  <AddressSpace Name=\"$cell_name\" Begin=\"0\" End=\"[expr {$bram_range - 1}]\">"

	# Set to constant values for WhiteRabbit
	set bram [llength $cell_name_bram]
	set sequence "31"
	set sequence [split $sequence ","]
	set bus_blocks [expr {$bram / [llength $sequence]}]

	for {set b 0} {$b < $bus_blocks} {incr b} {
		puts $fileout "      <BusBlock>"
		for {set i 0} {$i < [llength $sequence]} {incr i} {
			for {set j 0} {$j < [llength $cell_name_bram]} {incr j} {
				set block_start [expr {1024 * $b}]
				set bmm_width [bram_info [lindex $cell_name_bram $j] "bit_lane"]
				set bmm_width [split $bmm_width ":"]
				set bmm_msb [lindex $bmm_width 0]
				set bmm_lsb [lindex $bmm_width 1]
				set bmm_range [bram_info [lindex $cell_name_bram $j] "range"]
				set split_ranges [split $bmm_range ":"]
				set MSB [lindex $sequence $i]
				if {$MSB == $bmm_msb && $block_start == [lindex $split_ranges 0]} {
					set bram_type [get_property REF_NAME [get_cells [lindex $cell_name_bram $j]]]
					set status [get_property STATUS [get_cells [lindex $cell_name_bram $j]]]

					if {$status == "UNPLACED"} {
						set placed "X0Y0"
					} else {
						set placed [get_property LOC [get_cells [lindex $cell_name_bram $j]]]
						set placed_list [split $placed "_"]
						set placed [lindex $placed_list 1]
					}
					set bram_type [get_property REF_NAME [get_cells [lindex $cell_name_bram $j]]]
					if {$bram_type == "RAMB36E1"} {
						set bram_type "RAMB32"
					}

					puts $fileout "        <BitLane MemType=\"$bram_type\" Placement=\"$placed\">"
					puts $fileout "          <DataWidth MSB=\"$bmm_msb\" LSB=\"$bmm_lsb\"/>"
					puts $fileout "          <AddressRange Begin=\"[lindex $split_ranges 0]\" End=\"[lindex $split_ranges 1]\"/>"
					puts $fileout "          <Parity ON=\"false\" NumBits=\"0\"/>"
					puts $fileout "        </BitLane>"
				}
			}
		}
		puts $fileout "      </BusBlock>"
	}
	puts $fileout "    </AddressSpace>"
	puts $fileout "  </Processor>"
	puts $fileout "<Config>"
	puts $fileout "  <Option Name=\"Part\" Val=\"$part\"/>"
	puts $fileout "</Config>"
	puts $fileout "</MemInfo>"
	close $fileout
	puts "MMI file ($filename) created successfully."
	puts "To run Updatemem, use the command line below after write_bitstream:"
	puts "updatemem -force --meminfo $filename --data <path to data file>.elf/mem --bit <path to bit file>.bit --proc $inst_path --out <output bit file>.bit"
}

proc bram_info {bram type} {
	# decode information from name for whiterabbit
	# regexp {\/ram(.+)_reg_(.+)_(.+)} $bram all 1 2 3
	regexp {\/gen_RAM\[(.+)\]\.RAM} $bram all 1
	#set lane_upper [expr {$1 * 8 + 7}]
	#set lane_lower [expr {$1 * 8}]
	#set ind_lower [expr {($2 * 10 + $3) * 4096}]
	#set ind_upper [expr {($2 * 10 + $3 + 1) * 4096 - 1}]
	set lane_upper 31
	set lane_lower 0
	set ind_lower [expr {$1 * 1024}]
	set ind_upper [expr {$1 * 1024 + 1023}]
	set temp "[$lane_upper:$lane_lower][$ind_lower:$ind_upper]"
	set bmm_info_memory_device [regexp {\[(.+)\]\[(.+)\]} $temp all 1 2]
	if {$type == "bit_lane"} {
		return $1
	} elseif {$type == "range"} {
		return $2
	} else {
		return $all
	}
}
