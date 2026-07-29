###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
fetchto = "../../ip_cores"

files = [
    "vxs_wr_ref_top.vhd",
    "vxs_wr_ref_top.ucf"
]

modules = {
    "local" : [
        "../../",
        "../../board/vxs",
    ],
    "git" : [
        "git://gitlab.com/ohwr/project/general-cores.git",
        "git://gitlab.com/ohwr/project/urv-core.git",
        # "https://gitlab.com/ohwr/project/etherbone-core.git@@035fee323b5bafc8f06de0ac9cabb5892c33134e",
    ],
}
