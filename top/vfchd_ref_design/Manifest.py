###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
fetchto = "../../ip_cores"

files = [
    "vfchd_wr_ref_top.vhd",
    "vfchd_i2cmux/vfchd_i2cmux_pkg.vhd",
    "vfchd_i2cmux/I2cMuxAndExpReqArbiter.v",
    "vfchd_i2cmux/I2cMuxAndExpMaster.v",
    "vfchd_i2cmux/SfpIdReader.v",
]

modules = {
    "local" : [
        "../../",
    ],
    "git" : [
        "https://gitlab.com/ohwr/project/general-cores.git",
        "https://gitlab.com/ohwr/project/urv-core.git",
        "https://gitlab.com/ohwr/project/vme64x-core.git@@eb94737813045eb2a42094e61417e7ab33d78306",
        # "https://gitlab.com/ohwr/project/etherbone-core.git@@035fee323b5bafc8f06de0ac9cabb5892c33134e",
    ],
}
