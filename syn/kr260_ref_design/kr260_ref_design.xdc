##-----------------------------------------------------------------------------
## SPDX-FileCopyrightText: 2026 CERN (home.cern)
##
## SPDX-License-Identifier: CERN-OHL-W-2.0+
##-----------------------------------------------------------------------------
##################
# Clocks
##################

create_clock -period 13.400 -name clk [get_ports {refclk1_p_i}]

#create_clock -period 8.000 -name wr_clk_helper_125m -waveform {0.000  4.000} [get_ports {wr_clk_helper_125m_p_i}]
#create_clock -period 8.000 -name wr_clk_main_125m   -waveform {0.000  4.000} [get_ports {wr_clk_main_125m_p_i}]
#create_clock -period 8.000 -name wr_clk_sfp_125m    -waveform {0.000  4.000} [get_ports {wr_clk_sfp_125m_p_i}]
#create_clock -period 16.000 -name gth_txclk         -waveform {0.000 8.000} [get_nets cmp_xwrc_board_pxie_fmc/cmp_xwrc_platform/gen_phy_zynqus.cmp_gth/tx_out_clk_o]
#create_clock -period 16.000 -name gth_rxclk         -waveform {0.000 8.000} [get_nets cmp_xwrc_board_pxie_fmc/cmp_xwrc_platform/gen_phy_zynqus.cmp_gth/rx_rbclk_o]

#create_generated_clock -name clk_dmtd -source [get_ports {wr_clk_helper_125m_p_i}] -divide_by 2 [get_pins cmp_xwrc_board_pxie_fmc/cmp_xwrc_platform/gen_default_plls.gen_zynqus_default_plls.cmp_clk_dmtd_buf_o/O]

#set_clock_groups -asynchronous -group {wr_clk_main_125m wr_clk_sfp_125m} -group {wr_clk_helper_125m clk_dmtd} -group {gth_txclk} -group {gth_rxclk}


##################
# I/O constraints
##################

#set_property PACKAGE_PIN V6 [get_ports {refclk1_p_i}]
#set_property PACKAGE_PIN V7 [get_ports {refclk1_n_i}]

set_property PACKAGE_PIN Y6 [get_ports {refclk0_p_i}]
set_property PACKAGE_PIN Y5 [get_ports {refclk0_n_i}]

set_property PACKAGE_PIN T2 [get_ports {pad_rxp_i}]
set_property PACKAGE_PIN T1 [get_ports {pad_rxn_i}]
set_property PACKAGE_PIN R4 [get_ports {pad_txp_o}]
set_property PACKAGE_PIN R3 [get_ports {pad_txn_o}]

set_property PACKAGE_PIN P2 [get_ports {helper_rxp_i}]
set_property PACKAGE_PIN P1 [get_ports {helper_rxn_i}]
set_property PACKAGE_PIN N4 [get_ports {helper_txp_o}]
set_property PACKAGE_PIN N3 [get_ports {helper_txn_o}]

set_property PACKAGE_PIN F8 [get_ports {led1_o}]
set_property PACKAGE_PIN E8 [get_ports {led2_o}]
set_property IOSTANDARD LVCMOS18 [get_ports led1_o]
set_property IOSTANDARD LVCMOS18 [get_ports led2_o]

set_property PACKAGE_PIN G8 [get_ports {sfp_led1_o}]
set_property PACKAGE_PIN F7 [get_ports {sfp_led2_o}]
set_property IOSTANDARD LVCMOS18 [get_ports sfp_led1_o]
set_property IOSTANDARD LVCMOS18 [get_ports sfp_led2_o]

set_property PACKAGE_PIN L3 [get_ports {clk_25m_i}]
set_property IOSTANDARD LVCMOS18 [get_ports {clk_25m_i}]

#J2_PMOD1_PIN7
set_property PACKAGE_PIN C11 [get_ports pmod1_7_t] 
set_property IOSTANDARD LVCMOS33 [get_ports pmod1_7_t]

#J18_PMOD2_PIN7
set_property PACKAGE_PIN K12 [get_ports pmod2_7_t] 
set_property IOSTANDARD LVCMOS33 [get_ports pmod2_7_t]

set_property PACKAGE_PIN AD11 [get_ports pmod4_2_b]
set_property IOSTANDARD LVCMOS33 [get_ports pmod4_2_b]

set_property PACKAGE_PIN AD10 [get_ports pmod4_4_b]
set_property IOSTANDARD LVCMOS33 [get_ports pmod4_4_b]

set_property PACKAGE_PIN AA11 [get_ports pmod4_6_b]
set_property IOSTANDARD LVCMOS33 [get_ports pmod4_6_b]

set_property PACKAGE_PIN A10 [get_ports sfp_tx_fault_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_tx_fault_i]

set_property PACKAGE_PIN Y10 [get_ports sfp_tx_disable_o]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_tx_disable_o]

set_property PACKAGE_PIN W10 [get_ports sfp_mod_abs_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_abs_i]

set_property PACKAGE_PIN AC11 [get_ports sfp_sda_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_sda_b]

set_property PACKAGE_PIN AB11 [get_ports sfp_scl_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_scl_b]


# Very important: use POSTPI
set_property TX_PROGCLK_SEL POSTPI [get_cells {inst_gth/inst/gen_gtwizard_gthe4_top.gthe4_sdm_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[1].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[0].GTHE4_CHANNEL_PRIM_INST} ]
set_property TXPI_SYNFREQ_PPM "110" [get_cells {inst_gth/inst/gen_gtwizard_gthe4_top.gthe4_sdm_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[1].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[0].GTHE4_CHANNEL_PRIM_INST} ]
