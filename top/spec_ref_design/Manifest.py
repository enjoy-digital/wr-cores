###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
fetchto = "../../ip_cores"

files = [
    "spec_wr_ref_top.vhd",
]

modules = {
    "local" : [
        "../../",
    ],
    "git" : [
        "https://gitlab.com/ohwr/project/general-cores.git",
        "https://gitlab.com/ohwr/project/urv-core.git",
        "https://gitlab.com/ohwr/project/gn4124-core.git@@4eb317d1c226c6fa06baa65d6835bb5d02c3f9a3",
        # "https://gitlab.com/ohwr/project/etherbone-core.git@@035fee323b5bafc8f06de0ac9cabb5892c33134e",
    ],
}
