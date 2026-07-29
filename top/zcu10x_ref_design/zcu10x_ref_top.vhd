-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2023 Missing Link Electronics(missinglinkelectronics.com)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : WRPC reference design for ZCU102 and ZCU106 board
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : zcu10x_ref_top.vhd
-- Author(s)  : David Epping <david.epping@missinglinkelectronics.com> (based
--              on work by Greg Daniluk <grzegorz.daniluk@cern.ch>)
-- Company    : Missing Link Electronics
--              CERN (BE-CO-HT)
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level file for the WRPC reference design on the ZCU102
-- and ZCU106 board.
-- An optional XM105 can be added on FMC HPC0 for SMA clock and PPS output.
--
-- This is a reference top HDL that instanciates the WR PTP Core together with
-- its peripherals to be run on a ZCU102 and ZCU106 board.
--
-- There are two main usecases for this HDL file:
-- * let new users easily synthesize a WR PTP Core bitstream that can be run on
--   reference hardware
-- * provide a reference top HDL file showing how the WRPC can be instantiated
--   in HDL projects.
--
-- ZCU102: https://www.xilinx.com/products/boards-and-kits/ek-u1-zcu102-g.html
-- ZCU106: https://www.xilinx.com/products/boards-and-kits/zcu106.html
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wr_timecode_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity zcu10x_ref_top is
  generic (
    -- Simulation-mode enable parameter. Set by default (synthesis) to 0, and
    -- changed to non-zero in the instantiation of the top level DUT in the testbench.
    -- Its purpose is to reduce some internal counters/timeouts to speed up simulations.
    g_SIMULATION        : integer := 0;
    -- Both ZCU102 and ZCU106 are currently supported
    g_BOARD_NAME        : string                := "X10x";
    g_aux_timing_config : t_wr_timecode_config := (c_WITH_AUXCLK_IDX=>TRUE, c_WITH_IRIG_IDX=>FALSE, c_WITH_NMEA_IDX=>FALSE)
    );
  port (
    ---------------------------------------------------------------------------
    -- Clocks/resets
    ---------------------------------------------------------------------------
    ps_por_i               : in std_logic;
    wr_clk_helper_125m_p_i : in  std_logic;
    wr_clk_helper_125m_n_i : in  std_logic;
    wr_clk_main_125m_p_i   : in  std_logic;
    wr_clk_main_125m_n_i   : in  std_logic;
    wr_clk_sfp_125m_p_i    : in  std_logic;
    wr_clk_sfp_125m_n_i    : in  std_logic;

    clk_ref_125m_o       : out std_logic;
    clk_hpc0_xm105_sma_o : out std_logic;
    clk_hpc1_xm105_sma_o : out std_logic;

    -- GPSDO clock and pps
    clk_10m_ext_i : in std_logic;
    pps_ext_i : in std_logic;

    ---------------------------------------------------------------------------
    -- Dummy GTH channel required for QPLL SDM
    ---------------------------------------------------------------------------
    dummy_gthtxp_o        : out std_logic_vector(1 downto 0);
    dummy_gthtxn_o        : out std_logic_vector(1 downto 0);
    dummy_gthrxp_i        : in  std_logic_vector(1 downto 0);
    dummy_gthrxn_i        : in  std_logic_vector(1 downto 0);

    ---------------------------------------------------------------------------
    -- SFP I/Os for transceiver
    ---------------------------------------------------------------------------
    sfp_txp_o         : out std_logic;
    sfp_txn_o         : out std_logic;
    sfp_rxp_i         : in  std_logic;
    sfp_rxn_i         : in  std_logic;
    sfp_sda_b         : inout std_logic;
    sfp_scl_b         : inout std_logic;
    sfp_tx_disable_o  : out std_logic;

    ---------------------------------------------------------------------------
    -- EEPROM I2C interface for storing configuration and accessing unique ID
    ---------------------------------------------------------------------------
    eeprom_sda_b  : inout std_logic;
    eeprom_scl_b  : inout std_logic;
    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------
    uart0_rxd_i    : in  std_logic;
    uart0_txd_o    : out std_logic;
    uart1_rxd_i    : in  std_logic;
    uart1_txd_o    : out std_logic;

    ---------------------------------------------------------------------------
    -- DIP Switch
    ---------------------------------------------------------------------------
    gpio_dip_sw_i : in std_logic_vector(0 downto 0);

    ---------------------------------------------------------------------------
    -- LEDs
    ---------------------------------------------------------------------------
    user_led_o           : out std_logic_vector(3 downto 0);
    pps_p_o              : out std_logic;
    pps_hpc0_xm105_sma_o : out std_logic;
    pps_hpc1_xm105_sma_o : out std_logic
  );
end entity zcu10x_ref_top;

architecture top of zcu10x_ref_top is

  signal rst_n : std_logic;

  signal clkfbout_clk_wiz_0 : std_logic;
  signal clkfbout_buf_clk_wiz_0 : std_logic;
  signal clk_sys_62m5 : std_logic;
  signal clk_ref_125m : std_logic;
  signal pps_p : std_logic;

  signal sfp_scl_out, sfp_scl_in : std_logic;
  signal sfp_sda_out, sfp_sda_in : std_logic;
  signal eeprom_scl_out, eeprom_scl_in : std_logic;
  signal eeprom_sda_out, eeprom_sda_in : std_logic;
  signal si570_scl_oen, si570_scl_in : std_logic;
  signal si570_sda_oen, si570_sda_in : std_logic;

  signal fmc_enable : std_logic_vector(1 downto 0);
  signal utc_out        : t_utc_out;
  signal aux_timing_out : t_aux_timing_out;
begin

  -- do not use PS_POR for now
  rst_n <= '1'; --not ps_por_i;

  cmp_xwrc_board_zcu10x : entity work.xwrc_board_zcu10x
    generic map (
      g_simulation     => g_SIMULATION,
      g_board_name     => g_BOARD_NAME,
      g_num_fmc_enable => 2,
      g_dpram_initf    => "../../bin/wrpc/wrc_amd_devboard.bram",
      g_aux_timing_config         => g_AUX_TIMING_CONFIG,
      g_with_external_clock_input => TRUE)
    port map (
      areset_n_i             => rst_n,
      wr_clk_helper_125m_p_i => wr_clk_helper_125m_p_i,
      wr_clk_helper_125m_n_i => wr_clk_helper_125m_n_i, 
      wr_clk_main_125m_p_i   => wr_clk_main_125m_p_i, 
      wr_clk_main_125m_n_i   => wr_clk_main_125m_n_i, 
      wr_clk_sfp_125m_p_i    => wr_clk_sfp_125m_p_i, 
      wr_clk_sfp_125m_n_i    => wr_clk_sfp_125m_n_i, 
      clk_sys_62m5_o         => clk_sys_62m5,
      clk_ref_125m_o         => clk_ref_125m,
      clk_10m_ext_i          => clk_10m_ext_i,
      pps_ext_i              => pps_ext_i,

      dummy_gthtxp_o        => dummy_gthtxp_o,
      dummy_gthtxn_o        => dummy_gthtxn_o,
      dummy_gthrxp_i        => dummy_gthrxp_i,
      dummy_gthrxn_i        => dummy_gthrxn_i,

      sfp_txp_o       => sfp_txp_o,
      sfp_txn_o       => sfp_txn_o,
      sfp_rxp_i       => sfp_rxp_i,
      sfp_rxn_i       => sfp_rxn_i,
      sfp_det_i       => '0', --  Force presence
      sfp_sda_i       => sfp_sda_in,
      sfp_sda_o       => sfp_sda_out,
      sfp_scl_i       => sfp_scl_in,
      sfp_scl_o       => sfp_scl_out,
      sfp_tx_disable_o => sfp_tx_disable_o,
      sfp_los_i        => '0', -- Normal operation
  
      eeprom_sda_i => eeprom_sda_in, 
      eeprom_sda_o => eeprom_sda_out, 
      eeprom_scl_i => eeprom_scl_in, 
      eeprom_scl_o => eeprom_scl_out, 
      uart0_rxd_i   => uart0_rxd_i,
      uart0_txd_o   => uart0_txd_o,
      uart1_rxd_i   => uart1_rxd_i,
      uart1_txd_o   => uart1_txd_o,
      si570_scl_oen_o => si570_scl_oen,
      si570_scl_i  => si570_scl_in,
      si570_sda_oen_o => si570_sda_oen,
      si570_sda_i  => si570_sda_in,
      fmc_enable_o => fmc_enable,

      led_act_o  => user_led_o(1),
      led_link_o => user_led_o(0),
      utc_o         => utc_out,
      aux_timing_o  => aux_timing_out,
      pps_valid_o => user_led_o(2),
      pps_led_o => user_led_o(3),
      pps_p_o    => pps_p);

  clk_hpc0_xm105_sma_o <= aux_timing_out.serdes_out; -- default 10 MHz
  pps_hpc0_xm105_sma_o <= pps_p when fmc_enable(0) = '1' else 'Z';
  clk_hpc1_xm105_sma_o <= clk_sys_62m5 when fmc_enable(1) = '1' else 'Z';
  pps_hpc1_xm105_sma_o <= pps_p when fmc_enable(1) = '1' else 'Z';

  clk_ref_125m_o <= clk_ref_125m;
  pps_p_o <= pps_p;

  sfp_scl_b <= '0' when (sfp_scl_out = '0' or si570_scl_oen = '0') else 'Z';
  sfp_sda_b <= '0' when (sfp_sda_out = '0' or si570_sda_oen = '0') else 'Z';
  sfp_scl_in <= sfp_scl_b;
  sfp_sda_in <= sfp_sda_b;
  si570_scl_in <= sfp_scl_b;
  si570_sda_in <= sfp_sda_b;

  eeprom_scl_b <= '0' when eeprom_scl_out = '0' else 'Z';
  eeprom_sda_b <= '0' when eeprom_sda_out = '0' else 'Z';
  eeprom_scl_in <= eeprom_scl_b;
  eeprom_sda_in <= eeprom_sda_b;

end top;
