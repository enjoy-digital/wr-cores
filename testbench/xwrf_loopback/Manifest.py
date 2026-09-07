###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
action = "simulation"
target = "xilinx"
syn_device = "xc6slx45t"
syn_grade = "-3"
syn_package = "fgg484"
#sim_tool = "modelsim"
sim_tool = "riviera"
top_module = "main"
fetchto = "../../ip_cores"
vlog_opt = "+incdir+../../sim"

include_dirs = [ "../../sim" ]

files = [ "main.sv" ]

modules = {
    "local" : [ 
    	"../../",
	"../../modules/fabric",
	],
    "git" : [
        "https://gitlab.com/ohwr/project/general-cores.git",
        "https://gitlab.com/ohwr/project/urv-core.git",
        "https://gitlab.com/ohwr/project/gn4124-core.git@@4eb317d1c226c6fa06baa65d6835bb5d02c3f9a3",
        "https://gitlab.com/ohwr/project/etherbone-core.git@@035fee323b5bafc8f06de0ac9cabb5892c33134e",
    ],
}
