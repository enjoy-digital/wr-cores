###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
fetchto = "../../ip_cores"
vlog_opt = "+incdir+../../sim"

files = [ "main.sv" ]

include_dirs = [ "../../sim",
        "../../ip_cores/general-cores/modules/wishbone/wb_lm32/src" ]

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
