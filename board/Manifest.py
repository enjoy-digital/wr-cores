###############################################################################
## SPDX-FileCopyrightText: 2025 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
try:
    if board in ["spec", "svec", "vfchd", "clbv2", "clbv3", "clbv4", "pxie-fmc", "diot-sb", "fasec", "zcu10x", "zc706", "common"]:
        modules = {"local" : [ board ] }
except NameError:
    # board is not defined
    pass
