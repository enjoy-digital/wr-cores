set projDir [file dirname [info script]]

set_param general.maxThreads 8
get_param general.maxThreads

# Xilinx speed grades: 1,2,3: 1 = slowest, 3 = fastest
set speed   2
set fpga xc7z045-ffg900-${speed}
set device  ${fpga}

set top     zc706_ref_top

# Check if firmware can be built
if {[file exists ../../build_fw.tcl]} {
    source ../../build_fw.tcl
} else {
    puts "File: ../../build_fw.tcl not found, skipping building firmware"
}

# Check hdlmake has generated file dependencies
if {![file exists files.tcl]} {
    puts "File: files.tcl not found, please check hdlmake has generated the file dependencies."
    exit 1
}

source files.tcl

# constraint files
read_xdc $projDir/zc706_ref_design.xdc

set start_time [clock seconds]

# enable fabric tuning by MMCM/PLL
if { [catch {synth_design -top ${top} -part ${device} -generic g_fabric_tuning_type="mmcm" > ${top}_synth.log} ] } {
  puts "synth_design failed."
  exit 1
}
write_checkpoint -force ${top}_synth

if { [catch {opt_design -directive Explore -verbose > ${top}_opt.log} ] } {
  puts "opt_design failed."
  exit 1
}
write_checkpoint -force ${top}_opt

if { [catch {place_design -directive Explore > ${top}_place.log} ] } {
  puts "place_design failed."
  exit 1
}
write_checkpoint -force ${projDir}/${top}_place

phys_opt_design -directive Explore > ${top}_phys_opt.log
write_checkpoint -force ${projDir}/${top}_phys_opt

if { [catch {route_design -directive Explore > ${top}_route.log} ] } {
  puts "route_design failed."
  exit 1
}
write_checkpoint -force ${projDir}/${top}_route

report_timing_summary -file ${top}_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type full -file ${top}_timing.rpt
report_utilization -hierarchical -file ${top}_utilization.rpt
report_io -file ${top}_pin.rpt

# bitstream configuration...
if { [catch {write_bitstream -force ${projDir}/${top}.bit} ] } {
  puts "write_bitstream failed."
  exit 1
}
write_debug_probes -force ${projDir}/${top}.ltx

# Write mmi file
source ./write_mmi.tcl
write_mmi U_iram ${device}

set end_time [clock seconds]
set total_time [ expr { $end_time - $start_time} ]
set absolute_time [clock format $total_time -format {%H:%M:%S} -gmt true ]
puts "\ntotal build time: $absolute_time\n"

set hold_slack [get_property SLACK [get_timing_paths -hold]]
set setup_slack [get_property SLACK [get_timing_paths -setup]]
if {$hold_slack < 0 || $setup_slack < 0} {
	puts "Setup or Hold violations: WNS=$setup_slack, WHS=$hold_slack\n"
	exit 1
} else {
	puts "No timing violations (WNS=$setup_slack, WHS=$hold_slack)\n"
}

exit 0
