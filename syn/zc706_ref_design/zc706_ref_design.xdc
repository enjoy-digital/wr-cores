# Shared I2C infrastructure
set_property IOSTANDARD LVCMOS25 [get_ports iic_sda_b]
set_property PACKAGE_PIN AJ18 [get_ports iic_sda_b]
set_property PACKAGE_PIN AJ14 [get_ports iic_scl_b]
set_property IOSTANDARD LVCMOS25 [get_ports iic_scl_b]
set_property OFFCHIP_TERM NONE [get_ports iic_s??_b]

# SFP0 (det, los and tx_fault not available on ZC706)
set_property PACKAGE_PIN Y6 [get_ports sfp_rxp_i]
set_property PACKAGE_PIN W4 [get_ports sfp_txp_o]
set_property PACKAGE_PIN AA18 [get_ports sfp_tx_disable_o]
set_property IOSTANDARD LVCMOS25 [get_ports sfp_tx_disable_o]
set_property OFFCHIP_TERM NONE [get_ports sfp_tx_disable_o]

# USER_SMA_CLK
set_property PACKAGE_PIN AD18 [get_ports clk_usr_clk_sma_o]
set_property IOSTANDARD LVCMOS25 [get_ports clk_usr_clk_sma_o]
set_property DIFF_TERM TRUE [get_ports clk_usr_clk_sma_o]

set_property PACKAGE_PIN AD19 [get_ports pps_p_o]
set_property IOSTANDARD LVCMOS25 [get_ports pps_p_o]
set_property DIFF_TERM TRUE [get_ports pps_p_o]

# DIP Switches
set_property PACKAGE_PIN AB17 [get_ports gpio_dip_sw_i[0]]
set_property IOSTANDARD LVCMOS25 [get_ports gpio_dip_sw_i[0]]
set_property PACKAGE_PIN AC16 [get_ports gpio_dip_sw_i[1]]
set_property IOSTANDARD LVCMOS25 [get_ports gpio_dip_sw_i[1]]
set_property PACKAGE_PIN AC17 [get_ports gpio_dip_sw_i[2]]
set_property IOSTANDARD LVCMOS25 [get_ports gpio_dip_sw_i[2]]
set_property PACKAGE_PIN AJ13 [get_ports gpio_dip_sw_i[3]]
set_property IOSTANDARD LVCMOS25 [get_ports gpio_dip_sw_i[3]]

# PMOD
## PMOD1_2_LS
set_property PACKAGE_PIN AB21 [get_ports pps_ext_i]
set_property IOSTANDARD LVCMOS25 [get_ports pps_ext_i]

## PMOD1_3_LS
set_property PACKAGE_PIN AB16 [get_ports clk_ref_125m_o]
set_property IOSTANDARD LVCMOS25 [get_ports clk_ref_125m_o]

## PMOD1_4_LS
set_property PACKAGE_PIN Y20 [get_ports clk_sys_62m5_o]
set_property IOSTANDARD LVCMOS25 [get_ports clk_sys_62m5_o]

## PMOD1_6_LS
set_property PACKAGE_PIN AC18 [get_ports clk_30m72_ext_i]
set_property IOSTANDARD LVCMOS25 [get_ports clk_30m72_ext_i]


# LEDs 0=DS8, 1=DS9, 2=DS10, and 3=DS35
set_property PACKAGE_PIN Y21 [get_ports led_act_o]
set_property IOSTANDARD LVCMOS25 [get_ports led_act_o]
set_property OFFCHIP_TERM NONE [get_ports led_act_o]
set_property PACKAGE_PIN G2 [get_ports led_link_o]
set_property IOSTANDARD LVCMOS15 [get_ports led_link_o]
set_property OFFCHIP_TERM NONE [get_ports led_link_o]
set_property PACKAGE_PIN W21 [get_ports pps_led_o]
set_property IOSTANDARD LVCMOS25 [get_ports pps_led_o]
set_property OFFCHIP_TERM NONE [get_ports pps_led_o]
set_property PACKAGE_PIN A17 [get_ports link_ok_o]
set_property IOSTANDARD LVCMOS15 [get_ports link_ok_o]
set_property OFFCHIP_TERM NONE [get_ports link_ok_o]

# Clocks
set_property PACKAGE_PIN AD20 [get_ports clk_125m_main_p_o]
set_property IOSTANDARD LVDS_25 [get_ports clk_125m_main_p_o]
set_property DIFF_TERM TRUE [get_ports clk_125m_main_p_o]
set_property PACKAGE_PIN AC8 [get_ports clk_125m_gtp_p_i]

set_property PACKAGE_PIN AF14 [get_ports clk_125m_si570_p_i]
set_property IOSTANDARD LVDS_25 [get_ports clk_125m_si570_p_i]
set_property DIFF_TERM TRUE [get_ports clk_125m_si570_p_i]

set_property PACKAGE_PIN H9 [get_ports clk_200m_sit9102_p_i]
set_property IOSTANDARD LVDS [get_ports clk_200m_sit9102_p_i]
set_property DIFF_TERM TRUE [get_ports clk_200m_sit9102_p_i]

create_clock -period 8 -name clk_si570_125m -waveform {0.000 4.000} [get_ports clk_125m_si570_p_i]
create_clock -period 5 -name clk_sit9102_200m -waveform {0.000 2.500} [get_ports clk_200m_sit9102_p_i]
create_clock -period 8 -name clk_si5324_125m -waveform {0.000 4.000} [get_ports clk_125m_gtp_p_i]
create_clock -period 32.552 -name clk_30m72_ext -waveform {0.000 16.276} [get_ports clk_30m72_ext_i]
create_clock -period 16.000 -name clk_gtx_rx -waveform {0.000 8.000} [get_pins cmp_xwrc_board_zc706/gen_mmcm_7series_tuning_pll.cmp_xwrc_platform/gen_phy_kintex7.cmp_gtx/U_GTX_INST/gtxe2_i/RXOUTCLK]
create_clock -period 16.000 -name clk_gtx_tx -waveform {0.000 8.000} [get_pins cmp_xwrc_board_zc706/gen_mmcm_7series_tuning_pll.cmp_xwrc_platform/gen_phy_kintex7.cmp_gtx/U_GTX_INST/gtxe2_i/TXOUTCLK]

set_clock_groups -asynchronous -group [get_clocks clk_gtx_rx] -group [get_clocks clk_pll_dmtd]
set_clock_groups -asynchronous -group [get_clocks clk_gtx_tx] -group [get_clocks clk_pll_dmtd]
set_clock_groups -asynchronous -group [get_clocks clk_pll_62m5_pll] -group [get_clocks clk_pll_dmtd]
set_clock_groups -asynchronous -group [get_clocks {*.clk_ext_mul}] -group [get_clocks clk_pll_dmtd]

set_clock_groups -asynchronous -group [get_clocks clk_pll_62m5_pll] -group [get_clocks clk_gtx_rx]
set_clock_groups -asynchronous -group [get_clocks clk_pll_62m5_pll] -group [get_clocks clk_10m_gps]
set_clock_groups -asynchronous -group [get_clocks clk_gtx_tx] -group [get_clocks clk_10m_gps]
set_clock_groups -asynchronous -group [get_clocks clk_pll_62m5_pll] -group [get_clocks clk_sit9102_200m]

# Set BUFGMUX to use faster clock for analysis
set_case_analysis 1 [get_pins clk_mux/CE0]
set_case_analysis 1 [get_pins clk_mux/CE1]

# Resets
set_property PACKAGE_PIN W23 [get_ports rst_si5324_n_o]
set_property IOSTANDARD LVCMOS25 [get_ports rst_si5324_n_o]
set_property OFFCHIP_TERM NONE [get_ports rst_si5324_n_o]

# Uart
#GPIO PMOD1_7_LS
set_property PACKAGE_PIN AC19 [get_ports uart0_txd_o]
set_property IOSTANDARD LVCMOS25 [get_ports uart0_txd_o]
set_property OFFCHIP_TERM NONE [get_ports uart0_txd_o]

#GPIO PMOD1_5_LS
set_property PACKAGE_PIN AA20 [get_ports uart0_rxd_i]
set_property IOSTANDARD LVCMOS25 [get_ports uart0_rxd_i]
set_property OFFCHIP_TERM NONE [get_ports uart0_rxd_i]

#GPIO PMOD1_1_LS
set_property PACKAGE_PIN AK21 [get_ports uart1_txd_o]
set_property IOSTANDARD LVCMOS25 [get_ports uart1_txd_o]
set_property OFFCHIP_TERM NONE [get_ports uart1_txd_o]

#GPIO PMOD1_0_LS
set_property PACKAGE_PIN AJ21 [get_ports uart1_rxd_i]
set_property IOSTANDARD LVCMOS25 [get_ports uart1_rxd_i]
set_property OFFCHIP_TERM NONE [get_ports uart1_rxd_i]

# SMA on XM105 on FMC HPC
set_property PACKAGE_PIN U26 [get_ports clk_hpc_xm105_sma_o]
set_property PACKAGE_PIN U27 [get_ports pps_hpc_xm105_sma_o]
set_property IOSTANDARD LVCMOS25 [get_ports clk_hpc_xm105_sma_o]
set_property IOSTANDARD LVCMOS25 [get_ports pps_hpc_xm105_sma_o]
set_property OFFCHIP_TERM NONE [get_ports clk_hpc_xm105_sma_o]
set_property OFFCHIP_TERM NONE [get_ports pps_hpc_xm105_sma_o]

# SMA on XM105 on FMC LPC
set_property PACKAGE_PIN AC28 [get_ports clk_lpc_xm105_sma_o]
set_property PACKAGE_PIN AD28 [get_ports pps_lpc_xm105_sma_o]
set_property IOSTANDARD LVCMOS25 [get_ports clk_lpc_xm105_sma_o]
set_property IOSTANDARD LVCMOS25 [get_ports pps_lpc_xm105_sma_o]
set_property OFFCHIP_TERM NONE [get_ports clk_lpc_xm105_sma_o]
set_property OFFCHIP_TERM NONE [get_ports pps_lpc_xm105_sma_o]

# compress bitstream for faster loading
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
