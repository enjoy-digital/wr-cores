###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
action = "simulation"
target = "xilinx"
files = "main.sv"
syn_device = "xc6slx45t"
syn_grade = "-3"
syn_package = "fgg484"
#fetchto = "../../ip_cores"
#sim_tool = "modelsim"
sim_tool = "riviera"
top_module = "main"

include_dirs = [ "../../sim" ]

vlog_opt="+incdir+../../sim"

modules ={"local" : ["../../ip_cores/general-cores",
                     "../../modules/wr_endpoint", 
                     "../../modules/wr_mini_nic" ] };
