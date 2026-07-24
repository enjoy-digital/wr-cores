###############################################################################
## SPDX-FileCopyrightText: 2026 CERN (home.cern)
##
## SPDX-License-Identifier: LGPL-2.1-or-later
###############################################################################
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name gthe4_sdm

set_property CONFIG.preset {GTH-Gigabit_Ethernet} [get_ips gthe4_sdm]
set_property -dict [list \
  CONFIG.CHANNEL_ENABLE {X0Y6} \
  CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
  CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
  CONFIG.RX_MASTER_CHANNEL {X0Y6} \
  CONFIG.RX_PLL_TYPE {QPLL0} \
  CONFIG.RX_QPLL_FRACN_NUMERATOR {6871} \
  CONFIG.RX_REFCLK_SOURCE {} \
  CONFIG.RX_SLIDE_MODE {PCS} \
  CONFIG.TX_MASTER_CHANNEL {X0Y6} \
  CONFIG.TX_OUTCLK_SOURCE {TXPROGDIVCLK} \
  CONFIG.TX_PLL_TYPE {QPLL0} \
  CONFIG.TX_QPLL_FRACN_NUMERATOR {6871} \
  CONFIG.TX_REFCLK_SOURCE {} \
  CONFIG.RX_BUFFER_MODE {0} \
  CONFIG.TX_BUFFER_MODE {0} \
  CONFIG.RX_REFCLK_FREQUENCY {156.2495001} \
  CONFIG.TX_REFCLK_FREQUENCY {156.2495001} \
  CONFIG.SECONDARY_QPLL_ENABLE {true} \
  CONFIG.SECONDARY_QPLL_FRACN_NUMERATOR {6871} \
  CONFIG.SECONDARY_QPLL_LINE_RATE {1.25} \
  CONFIG.LOCATE_COMMON {EXAMPLE_DESIGN} \
  CONFIG.ENABLE_OPTIONAL_PORTS {drpaddr_in drpclk_in drpdi_in drpen_in drpwe_in rxpcsreset_in  txpippmen_in txpippmovrden_in txpippmpd_in txpippmsel_in txpippmstepsize_in txpllclksel_in drpdo_out drprdy_out} \
] [get_ips gthe4_sdm]
generate_target {instantiation_template} [get_files gthe4_sdm.xci]
