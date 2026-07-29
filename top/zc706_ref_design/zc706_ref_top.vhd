-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2023 Missing Link Electronics(missinglinkelectronics.com)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : WRPC reference design for ZC706 board
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : zc706_ref_top.vhd
-- Author(s)  : Frederik Pfautsch <frederik.pfautsch@missinglinkelectronics.com>
-- Company    : Missing Link Electronics
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level file for the WRPC reference design on the ZC706
-- board.
--
-- This is a reference top HDL that instanciates the WR PTP Core together with
-- its peripherals to be run on a ZC706 board.
--
-- There are two main usecases for this HDL file:
-- * let new users easily synthesize a WR PTP Core bitstream that can be run on
--   reference hardware
-- * provide a reference top HDL file showing how the WRPC can be instantiated
--   in HDL projects.
--
-- ZC706: https://www.xilinx.com/products/boards-and-kits/ek-z7-zc706-g.html
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity zc706_ref_top is
  generic (
    -- Replace external VXCOs with in-fabric tuning:
    --   * "mmcm": use the phase shift feature of MMCMs
    --   * "picxo": use the phase interpolator of GTX transceivers
    -- This generic is set by the corresponding tcl-build-scripts in
    -- syn/zc706_ref_design (MMCM) and syn/zc706_picxo (PICXO)
    g_fabric_tuning_type: string := "mmcm";
    -- Simulation-mode enable parameter. Set by default (synthesis) to 0, and
    -- changed to non-zero in the instantiation of the top level DUT in the testbench.
    -- Its purpose is to reduce some internal counters/timeouts to speed up simulations.
    g_SIMULATION: integer := 0);
  port (
    ---------------------------------------------------------------------------
    -- Clocks/resets
    ---------------------------------------------------------------------------
    -- GPSDO clock and pps
    clk_30m72_ext_i : in std_logic;
    pps_ext_i : in std_logic;
    -- Clock inputs from the board
    clk_125m_si570_p_i   : in  std_logic;
    clk_125m_si570_n_i   : in  std_logic;
    clk_200m_sit9102_p_i : in  std_logic;
    clk_200m_sit9102_n_i : in  std_logic;
    clk_125m_gtp_n_i     : in  std_logic;
    clk_125m_gtp_p_i     : in  std_logic;
    -- 125MHz tuned board clock output for transceivers
    clk_125m_main_n_o    : out  std_logic;
    clk_125m_main_p_o    : out  std_logic;
    -- 62.5MHz sys clock output
    clk_sys_62m5_o       : out std_logic;
    -- 125MHz ref clock output
    clk_ref_125m_o       : out std_logic;
    -- 10MHz or 62.5MHz tuned clock output derived from main
    clk_usr_clk_sma_o    : out std_logic;
    clk_hpc_xm105_sma_o  : out std_logic;
    clk_lpc_xm105_sma_o  : out std_logic;

    -- Active low reset for iic mux
    rst_si5324_n_o       : out std_logic;

    ---------------------------------------------------------------------------
    -- SFP I/O for transceiver and SFP management info
    ---------------------------------------------------------------------------
    sfp_txp_o         : out std_logic;
    sfp_txn_o         : out std_logic;
    sfp_rxp_i         : in  std_logic;
    sfp_rxn_i         : in  std_logic;
    sfp_tx_disable_o  : out std_logic;

    ---------------------------------------------------------------------------
    -- I2C
    ---------------------------------------------------------------------------
    iic_sda_b : inout  std_logic;
    iic_scl_b : inout  std_logic;

    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------
    uart0_rxd_i : in  std_logic;
    uart0_txd_o : out std_logic;
    uart1_rxd_i : in  std_logic;
    uart1_txd_o : out std_logic;

    ---------------------------------------------------------------------------
    -- Buttons, LEDs and PPS output
    ---------------------------------------------------------------------------
    -- DIP switches
    gpio_dip_sw_i       : in std_logic_vector(3 downto 0);
    -- LEDs
    led_act_o           : out std_logic;
    led_link_o          : out std_logic;
    -- 1PPS output
    pps_p_o             : out std_logic;
    pps_led_o           : out std_logic;
    pps_hpc_xm105_sma_o : out std_logic;
    pps_lpc_xm105_sma_o : out std_logic;
    -- Link ok indication
    link_ok_o           : out std_logic
    );
end entity zc706_ref_top;

architecture top of zc706_ref_top is
  signal rst_n : std_logic;

  signal clk_sys_62m5 : std_logic;

  signal clk_30m72_ext_buf : std_logic;
  signal clk_30m72_fb : std_logic;
  signal clk_30m72_fb_f : std_logic;
  signal clk_10m_gps : std_logic;

  signal clk_200m_sit9102_buf : std_logic;
  signal clk_125m_si570_buf : std_logic;

  signal clk_ref_125m : std_logic;
  signal clk_125m_main_tuned : std_logic;
  signal clk_10m : std_logic;
  signal clk_usr_clk_sma : std_logic;

  signal pps_p : std_logic;
  signal clk_xm105_sma_oddr : std_logic_vector(1 downto 0);

  signal eeprom_sda_i, eeprom_sda_o, eeprom_sda_t : std_logic;
  signal eeprom_scl_i, eeprom_scl_o, eeprom_scl_t : std_logic;
  signal si570_sda_i, si570_sda_o, si570_sda_t : std_logic;
  signal si570_scl_i, si570_scl_o, si570_scl_t : std_logic;
  signal sfp_sda_i, sfp_sda_o, sfp_sda_t : std_logic;
  signal sfp_scl_i, sfp_scl_o, sfp_scl_t : std_logic;
  signal comb_sda_o, comb_sda_t : std_logic;
  signal comb_scl_o, comb_scl_t : std_logic;

  signal fmc_enable : std_logic_vector(1 downto 0);
begin
  rst_n <= '1';
  rst_si5324_n_o <= rst_n;

  -- Combine I2C bus for eeprom and sfp
  sfp_sda_i <= iic_sda_b;
  eeprom_sda_i <= iic_sda_b;
  si570_sda_i <= iic_sda_b;
  sfp_scl_i <= iic_scl_b;
  eeprom_scl_i <= iic_scl_b;
  si570_scl_i <= iic_scl_b;

  comb_sda_o <= sfp_sda_o or eeprom_sda_o or si570_sda_o;
  comb_scl_o <= sfp_scl_o or eeprom_scl_o or si570_scl_o;
  comb_sda_t <= sfp_sda_t and eeprom_sda_t and si570_sda_t;
  comb_scl_t <= sfp_scl_t and eeprom_scl_t and si570_scl_t;

  iic_scl_b <= comb_scl_o when comb_scl_t = '0' else 'Z';
  iic_sda_b <= comb_sda_o when comb_sda_t = '0' else 'Z';

  -- 30.72MHz clock of UBX GNSS to 10MHz
  cmp_30m72_clk_pll : MMCME2_ADV
    generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLKOUT4_CASCADE      => false,
        STARTUP_WAIT         => false,
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT_F      => 31.250,     -- 30.72 MHz -> 960 MHz
        CLKFBOUT_PHASE       => 0.000,
        CLKFBOUT_USE_FINE_PS => false,
        CLKOUT0_DIVIDE_F     => 96.000,     -- 960 MHz/96 -> 10 MHz
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKOUT0_USE_FINE_PS  => false,
        CLKIN1_PERIOD        => 32.552,     -- 32.552 ns for 30.72 MHz
        REF_JITTER1          => 0.005)
    port map (
        -- Output clocks
        CLKFBOUT     => clk_30m72_fb,
        CLKOUT0      => clk_10m_gps,
        -- Input clock control
        CLKFBIN      => clk_30m72_fb_f,
        CLKIN1       => clk_30m72_ext_buf,
        CLKIN2       => '0',
        -- Tied to always select the primary input clock
        CLKINSEL     => '1',
        -- Ports for dynamic reconfiguration
        DADDR        => (others => '0'),
        DCLK         => '0',
        DEN          => '0',
        DI           => (others => '0'),
        DO           => open,
        DRDY         => open,
        DWE          => '0',
        -- Ports for dynamic phase shift
        PSCLK        => '0',
        PSEN         => '0',
        PSINCDEC     => '0',
        PSDONE       => open,
        -- Other control and status signals
        LOCKED       => open,
        CLKINSTOPPED => open,
        CLKFBSTOPPED => open,
        PWRDWN       => '0',
        RST          => not rst_n);

  cmp_30m72_clk_pll_fb : BUFG
    port map (
        O => clk_30m72_fb_f,
        I => clk_30m72_fb);

  cmp_clk_30m72_ext_buf : BUFG
    port map (
        O => clk_30m72_ext_buf,
        I => clk_30m72_ext_i);

  -- Clock buffer for SiT9102 output
  ibufds_200m_clk : IBUFDS
    generic map(
      DIFF_TERM => true)
    port map (
      O     => clk_200m_sit9102_buf,
      I     => clk_200m_sit9102_p_i,
      IB    => clk_200m_sit9102_n_i);

  -- Clock buffer for SI570 output
  ibufds_board_clk : IBUFDS
    generic map(
      DIFF_TERM => true)
    port map (
      O     => clk_125m_si570_buf,
      I     => clk_125m_si570_p_i,
      IB    => clk_125m_si570_n_i);

  cmp_xwrc_board_zc706 : entity work.xwrc_board_zc706
    generic map (
      g_simulation   => g_SIMULATION,
      g_dpram_initf  => "../../bin/wrpc/wrc_amd_devboard.bram",
      g_with_external_clock_input => TRUE,
      g_fabric_tuning_type => g_fabric_tuning_type)
    port map (
      areset_n_i         => rst_n,
      clk_125m_gtp_n_i   => clk_125m_gtp_n_i,
      clk_125m_gtp_p_i   => clk_125m_gtp_p_i,
      clk_aux_i          => (others => '0'),
      clk_10m_ext_i      => clk_10m_gps,
      pps_ext_i          => pps_ext_i,
      clk_sys_62m5_o     => clk_sys_62m5,
      clk_ref_125m_o     => clk_ref_125m, -- Note: 62.5Mhz
      clk_125m_main_o    => clk_125m_main_tuned,
      clk_10m_o          => clk_10m,
      clk_200m_sit9102_i => clk_200m_sit9102_buf,
      clk_125m_si570_i   => clk_125m_si570_buf,

      sfp_txp_o          => sfp_txp_o,
      sfp_txn_o          => sfp_txn_o,
      sfp_rxp_i          => sfp_rxp_i,
      sfp_rxn_i          => sfp_rxn_i,
      sfp_det_i          => '0',
      sfp_sda_i          => sfp_sda_i,
      sfp_sda_o          => sfp_sda_o,
      sfp_sda_t          => sfp_sda_t,
      sfp_scl_i          => sfp_scl_i,
      sfp_scl_o          => sfp_scl_o,
      sfp_scl_t          => sfp_scl_t,
      sfp_tx_fault_i     => '0',
      sfp_tx_disable_o   => sfp_tx_disable_o,
      sfp_los_i          => '0',

      eeprom_sda_i       => eeprom_sda_i,
      eeprom_sda_o       => eeprom_sda_o,
      eeprom_sda_t       => eeprom_sda_t,
      eeprom_scl_i       => eeprom_scl_i,
      eeprom_scl_o       => eeprom_scl_o,
      eeprom_scl_t       => eeprom_scl_t,

      uart0_rxd_i        => uart0_rxd_i,
      uart0_txd_o        => uart0_txd_o,
      uart1_rxd_i        => uart1_rxd_i,
      uart1_txd_o        => uart1_txd_o,
      fmc_enable_o       => fmc_enable,

      si570_scl_t        => si570_scl_t,
      si570_scl_o        => si570_scl_o,
      si570_scl_i        => si570_scl_i,
      si570_sda_t        => si570_sda_t,
      si570_sda_o        => si570_sda_o,
      si570_sda_i        => si570_sda_i,

      s00_axi_aclk_o     => open,
      s00_axi_aresetn    => '1',
      s00_axi_awaddr     => (others => '0'),
      s00_axi_awprot     => (others => '0'),
      s00_axi_awvalid    => '0',
      s00_axi_awready    => open,
      s00_axi_wdata      => (others => '0'),
      s00_axi_wstrb      => (others => '0'),
      s00_axi_wvalid     => '0',
      s00_axi_wready     => open,
      s00_axi_bresp      => open,
      s00_axi_bvalid     => open,
      s00_axi_bready     => '0',
      s00_axi_araddr     => (others => '0'),
      s00_axi_arprot     => (others => '0'),
      s00_axi_arvalid    => '0',
      s00_axi_arready    => open,
      s00_axi_rdata      => open,
      s00_axi_rresp      => open,
      s00_axi_rvalid     => open,
      s00_axi_rready     => '0',
      s00_axi_rlast      => open,

      led_act_o          => led_act_o,
      led_link_o         => led_link_o,
      pps_p_o            => pps_p,
      pps_led_o          => pps_led_o,
      link_ok_o          => link_ok_o);

  oddr_clk_sys_62m5 : ODDR
    port map  (
      Q => clk_sys_62m5_o,
      C => clk_sys_62m5,
      D1 => '1',
      D2 => '0',
      CE => '1');

  oddr_clk_ref_125m : ODDR
    port map  (
      Q => clk_ref_125m_o,
      C => clk_ref_125m,
      D1 => '1',
      D2 => '0',
      CE => '1');

  obufds_main_clk : OBUFDS
    port map (
      O => clk_125m_main_p_o,
      OB => clk_125m_main_n_o,
      I => clk_125m_main_tuned
    );

  clk_mux : BUFGMUX
    port map (
      O => clk_usr_clk_sma,
      I0 => clk_10m,
      I1 => clk_ref_125m,
      S => gpio_dip_sw_i(0));

  oddr_usr_sma_clk : ODDR
    port map (
      Q => clk_usr_clk_sma_o,
      C => clk_usr_clk_sma,
      D1 => '1',
      D2 => '0',
      CE => '1'
    );

   oddr_clk_xm105_sma0 : ODDR
    port map  (
      Q => clk_xm105_sma_oddr(0),
      C => clk_usr_clk_sma,
      D1 => '1',
      D2 => '0',
      CE => '1');

  oddr_clk_xm105_sma1 : ODDR
    port map  (
      Q => clk_xm105_sma_oddr(1),
      C => clk_usr_clk_sma,
      D1 => '1',
      D2 => '0',
      CE => '1');

  clk_hpc_xm105_sma_o <= clk_xm105_sma_oddr(0) when fmc_enable(0) = '1' else 'Z';
  pps_hpc_xm105_sma_o <= pps_p when fmc_enable(0) = '1' else 'Z';
  clk_lpc_xm105_sma_o <= clk_xm105_sma_oddr(1) when fmc_enable(1) = '1' else 'Z';
  pps_lpc_xm105_sma_o <= pps_p when fmc_enable(1) = '1' else 'Z';

  pps_p_o <= pps_p;
end top;
