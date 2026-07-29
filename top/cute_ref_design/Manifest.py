###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
fetchto = "../../ip_cores"

files = [
    "cute_wr_ref_top.vhd",
    "cute_wr_ref_top.ucf",
]

modules = {
    "local" : [
        "../../",
        "../../board/cute",
    ],
    "git" : [
        "git://gitlab.com/ohwr/project/general-cores.git",
        "git://gitlab.com/ohwr/project/urv-core.git",
        "https://gitlab.com/ohwr/project/gn4124-core.git@@4eb317d1c226c6fa06baa65d6835bb5d02c3f9a3",
    ],
}
