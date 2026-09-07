###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
files = ["spec_top.vhd", "spec_top.ucf", "timestamp_adder.vhd"  ]

modules = { "local" : ["../../../", "../../../platform/xilinx/6Series",
                       "../../../board/spec/"] }
