###############################################################################
## SPDX-FileCopyrightText: 2026 Missing Link Electronics(missinglinkelectronics.com)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
fetchto = "../../ip_cores"

files = [ "zc706_ref_top.vhd", ]

modules = {
    "local" : [
        "../../",
    ],
    "git" : [
        "git://gitlab.com/ohwr/project/general-cores.git",
        "git://gitlab.com/ohwr/project/etherbone-core.git",
        "git://gitlab.com/ohwr/project/urv-core.git",
    ],
}
