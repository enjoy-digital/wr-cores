-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2023 Missing Link Electronics(missinglinkelectronics.com)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : WRPC Wrapper for ZCU102 and ZCU106 board
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : xwrc_board_zcu10x.vhd
-- Author(s)  : David Epping <david.epping@missinglinkelectronics.com> (based
--              on work by Greg Daniluk <grzegorz.daniluk@cern.ch>)
-- Company    : Missing Link Electronics
--              CERN (BE-CO-HT)
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level wrapper for WR PTP core including all the modules
-- needed to operate the core on the Xilinx ZCU102 and ZCU106 board.
-- ZCU102: https://www.xilinx.com/products/boards-and-kits/ek-u1-zcu102-g.html
-- ZCU106: https://www.xilinx.com/products/boards-and-kits/zcu106.html
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;
use work.wrcore_pkg.all;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.endpoint_pkg.all;
use work.streamers_pkg.all;
use work.wr_xilinx_pkg.all;
use work.wr_board_pkg.all;
use work.si570_wbgen2_pkg.all;
use work.wr_timecode_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity xwrc_board_zcu10x is
  generic(
    -- set to 1 to speed up some initialization processes during simulation
    g_simulation                : integer              := 0;
    -- Select whether to include external ref clock input
    g_with_external_clock_input : boolean              := TRUE;
    -- Number of aux clocks syntonized by WRPC to WR timebase
    g_aux_clks                  : integer              := 0;
    -- memory initialisation file for embedded CPU
    g_dpram_initf               : string               := "default_xilinx";
    -- identification (id and ver) of the layout of words in the generic diag interface
    g_diag_id                   : integer              := 0;
    g_diag_ver                  : integer              := 0;
    -- size the generic diag interface
    g_diag_ro_size              : integer              := 0;
    g_diag_rw_size              : integer              := 0;
    g_dac_bits                  : integer              := 16;
    -- Both ZCU102 and ZCU106 are currently supported
    g_board_name                : string               := "X10x";
    g_num_fmc_enable            : integer              := 2;
    g_aux_timing_config         : t_wr_timecode_config := c_WR_TIMECODE_NONE
    );
  port (
    ---------------------------------------------------------------------------
    -- Clocks/resets
    ---------------------------------------------------------------------------
    -- Reset input (active low, can be async)
    areset_n_i          : in  std_logic;
    -- Optional reset input active low with rising edge detection. Does not
    -- reset PLLs.
    areset_edge_n_i        : in  std_logic := '1';
    -- Clock inputs from the board
    wr_clk_helper_125m_p_i : in  std_logic;
    wr_clk_helper_125m_n_i : in  std_logic;
    wr_clk_main_125m_p_i   : in  std_logic;
    wr_clk_main_125m_n_i   : in  std_logic;
    wr_clk_sfp_125m_p_i    : in  std_logic;
    wr_clk_sfp_125m_n_i    : in  std_logic;
    -- Aux clocks, which can be disciplined by the WR Core
    clk_aux_i              : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
    -- 10MHz ext ref clock input (g_with_external_clock_input = TRUE)
    clk_10m_ext_i       : in  std_logic                               := '0';
    -- External PPS input (g_with_external_clock_input = TRUE)
    pps_ext_i           : in  std_logic                               := '0';
    -- 62.5MHz sys clock output
    clk_sys_62m5_o      : out std_logic;
    -- 125MHz ref clock output
    clk_ref_125m_o      : out std_logic;
    -- active low reset outputs, synchronous to 62m5 and 125m clocks
    rst_sys_62m5_n_o    : out std_logic;
    rst_ref_125m_n_o    : out std_logic;

    ---------------------------------------------------------------------------
    -- Dummy GTH channel required for QPLL SDM
    ---------------------------------------------------------------------------
    dummy_gthtxp_o        : out std_logic_vector(1 downto 0);
    dummy_gthtxn_o        : out std_logic_vector(1 downto 0);
    dummy_gthrxp_i        : in  std_logic_vector(1 downto 0);
    dummy_gthrxn_i        : in  std_logic_vector(1 downto 0);

    ---------------------------------------------------------------------------
    -- Shared SPI interface to DACs
    ---------------------------------------------------------------------------
    plldac_sclk_o   : out std_logic;
    plldac_din_o    : out std_logic;
    pll25dac_cs_n_o : out std_logic;
    pll20dac_cs_n_o : out std_logic;

    ---------------------------------------------------------------------------
    -- SFP I/O for transceiver and SFP management info
    ---------------------------------------------------------------------------
    sfp_txp_o         : out std_logic;
    sfp_txn_o         : out std_logic;
    sfp_rxp_i         : in  std_logic;
    sfp_rxn_i         : in  std_logic;
    sfp_det_i         : in  std_logic := '1';
    sfp_sda_i         : in  std_logic;
    sfp_sda_o         : out std_logic;
    sfp_scl_i         : in  std_logic;
    sfp_scl_o         : out std_logic;
    sfp_rate_select_o : out std_logic;
    sfp_tx_fault_i    : in  std_logic := '0';
    sfp_tx_disable_o  : out std_logic;
    sfp_los_i         : in  std_logic := '0';

    ---------------------------------------------------------------------------
    -- I2C EEPROM
    ---------------------------------------------------------------------------
    eeprom_sda_i : in  std_logic;
    eeprom_sda_o : out std_logic;
    eeprom_scl_i : in  std_logic;
    eeprom_scl_o : out std_logic;

    -----------------------------------------
    -- Si570 I2C interface
    -----------------------------------------
    si570_scl_oen_o  : out std_logic;
    si570_scl_i      : in  std_logic := '1';
    si570_sda_oen_o  : out std_logic;
    si570_sda_i      : in  std_logic := '1';

    -----------------------------------------
    -- FMC SW enable interface
    -----------------------------------------
    fmc_enable_o : out std_logic_vector(g_num_fmc_enable-1 downto 0);

    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------
    uart0_rxd_i : in  std_logic;
    uart0_txd_o : out std_logic;
    uart1_rxd_i : in  std_logic := '0';
    uart1_txd_o : out std_logic;

    ---------------------------------------------------------------------------
    -- External WB interface
    ---------------------------------------------------------------------------
    wb_slave_o : out t_wishbone_slave_out;
    wb_slave_i : in  t_wishbone_slave_in := cc_dummy_slave_in;

    ---------------------------------------------------------------------------
    -- WR fabric interface (when g_fabric_iface = "plainfbrc")
    ---------------------------------------------------------------------------
    wrf_src_o : out t_wrf_source_out;
    wrf_src_i : in  t_wrf_source_in := c_dummy_src_in;
    wrf_snk_o : out t_wrf_sink_out;
    wrf_snk_i : in  t_wrf_sink_in   := c_dummy_snk_in;

    ---------------------------------------------------------------------------
    -- Generic diagnostics interface (access from WRPC via SNMP or uart console
    ---------------------------------------------------------------------------
    aux_diag_i : in  t_generic_word_array(g_diag_ro_size-1 downto 0) := (others => (others => '0'));
    aux_diag_o : out t_generic_word_array(g_diag_rw_size-1 downto 0);

    ---------------------------------------------------------------------------
    -- Aux clocks control
    ---------------------------------------------------------------------------
    tm_dac_value_o       : out std_logic_vector(31 downto 0);
    tm_dac_wr_o          : out std_logic_vector(g_aux_clks-1 downto 0);
    tm_clk_aux_lock_en_i : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
    tm_clk_aux_locked_o  : out std_logic_vector(g_aux_clks-1 downto 0);

    ---------------------------------------------------------------------------
    -- External Tx Timestamping I/F
    ---------------------------------------------------------------------------
    timestamps_o     : out t_txtsu_timestamp;
    timestamps_ack_i : in  std_logic := '1';

    -----------------------------------------
    -- Timestamp helper signals, used for Absolute Calibration
    -----------------------------------------
    abscal_txts_o    : out std_logic;
    abscal_rxts_o    : out std_logic;

    ---------------------------------------------------------------------------
    -- Timecode I/F
    ---------------------------------------------------------------------------
    tm_link_up_o     : out std_logic;
    tm_time_valid_o  : out std_logic;
    tm_tai_o         : out std_logic_vector(39 downto 0);
    tm_cycles_o      : out std_logic_vector(27 downto 0);

    ---------------------------------------------------------------------------
    -- Buttons, LEDs and PPS output
    ---------------------------------------------------------------------------
    led_act_o  : out std_logic;
    led_link_o : out std_logic;
    -- 1PPS output
    pps_p_o     : out std_logic;
    pps_valid_o : out std_logic;
    pps_led_o   : out std_logic;
    --
    utc_o         : out t_utc_out;
    aux_timing_o  : out t_aux_timing_out;
    -- Link ok indication
    link_ok_o   : out std_logic
    );

end entity xwrc_board_zcu10x;


architecture struct of xwrc_board_zcu10x is

  -- PLLs, clocks
  signal wr_clk_main_125m     : std_logic;
  signal wr_clk_main_125m_buf : std_logic;
  signal wr_clk_main_62m5     : std_logic;
  signal wr_clk_helper_125m   : std_logic;
  signal wr_clk_ref_125m      : std_logic;
  signal clk_pll_dmtd         : std_logic;
  signal pll_locked           : std_logic;
  signal clk_10m_ext          : std_logic;


  -- Reset logic
  signal areset_edge_ppulse : std_logic;
  signal rst_62m5_n         : std_logic;
  signal rstlogic_arst      : std_logic;
  signal rstlogic_clk_in    : std_logic_vector(1 downto 0);
  signal rstlogic_rst_out   : std_logic_vector(1 downto 0);

  -- PLL DAC ARB
  signal dac_hpll_load_p1 : std_logic;
  signal dac_hpll_data    : std_logic_vector(g_dac_bits-1 downto 0);
  signal dac_dpll_load_p1 : std_logic;
  signal dac_dpll_data    : std_logic_vector(g_dac_bits-1 downto 0);

  -- PHY
  signal phy16_to_wrc   : t_phy_16bits_to_wrc;
  signal phy16_from_wrc : t_phy_16bits_from_wrc;

  signal sfp_tx_disable_n : std_logic;

  -- Initialize the SDM interface to the center of our 19 bit tuning range.
  -- This allows to use almost the entire allowed +/- 200 ppm range around
  -- 125 MHz with 124.975605 MHz refclock and integral part of 80 for N.
  signal sdm_data_h : std_logic_vector(24 downto 0) :=
      std_logic_vector(to_unsigned(262143, 25));
  signal sdm_data_d : std_logic_vector(24 downto 0) :=
      std_logic_vector(to_unsigned(262143, 25));
  signal sdm_toggle_d : std_logic := '0';

  -- External reference
  signal ext_ref_mul         : std_logic;
  signal ext_ref_mul_locked  : std_logic;
  signal ext_ref_mul_stopped : std_logic;
  signal ext_ref_rst         : std_logic;

  -- Si570
  signal si570_wb_in  : t_wishbone_slave_in;
  signal si570_wb_out : t_wishbone_slave_out;

  -- GPIO for FMC enable
  signal enfmc_wb_in  : t_wishbone_slave_in;
  signal enfmc_wb_out : t_wishbone_slave_out;

  -- GPS Uart
  signal gps_uart_wb_in  : t_wishbone_slave_in;
  signal gps_uart_wb_out : t_wishbone_slave_out;

  -- aux wishbone
  signal aux_master_out : t_wishbone_master_out;
  signal aux_master_in : t_wishbone_master_in := cc_dummy_master_in;

  -- Auxclock serdes word
  signal aux_timing_serdes_locked : std_logic;
  signal aux_timing_out : t_aux_timing_out;
  signal serdes_out     : std_logic;
  signal pll_arst            : std_logic := '0';

begin  -- architecture struct

  -----------------------------------------------------------------------------
  -- Platform-dependent part (PHY, PLLs, buffers, etc)
  -----------------------------------------------------------------------------

  cmp_ibufgds_pllmain : IBUFDS
    generic map (
      DQS_BIAS     => "FALSE")
    port map (
      O  => wr_clk_main_125m,
      I  => wr_clk_main_125m_p_i,
      IB => wr_clk_main_125m_n_i);

  -- explicit BUFG is required because wr_clk_main_125m_p_i is in a HDIO bank,
  -- preventing Vivado from automatically adding it.
  cmp_bufg_pllmain: BUFG
    port map (
      I => wr_clk_main_125m,
      O => wr_clk_main_125m_buf);

  cmp_ibufds_gte4_dmtd : IBUFDS_GTE4
    generic map (
      -- drive ODIV2 with constant zero
      REFCLK_HROW_CK_SEL => "10")
    port map (
      CEB  => '0',
      I  => wr_clk_helper_125m_p_i,
      IB => wr_clk_helper_125m_n_i,
      O  => wr_clk_helper_125m,
      ODIV2  => open);

  clk_ref_125m_o <= wr_clk_ref_125m;
  clk_sys_62m5_o <= wr_clk_main_62m5;

  ---------------------------------------------------------------------------
  --   Zynq US+ PHY + DMTD QPLLs with SDM tuning
  ---------------------------------------------------------------------------
  gen_zynqus_sdm_qplls: if (g_board_name = "X102" or g_board_name = "X106") generate
    signal sdm_toggle_shift_h : std_logic_vector(31 downto 0) := (others => '0');
    signal sdm_toggle_shift_d : std_logic_vector(31 downto 0) := (others => '0');
    signal sdm_toggle_h : std_logic := '0';

    signal clk_125m_gth_buf  : std_logic;

    signal txoutclk_dmtd : std_logic;
  begin

    -- DAC to SDM control data
    tm_dac_h_to_sdm : process(wr_clk_main_62m5)
    begin
      if (rising_edge(wr_clk_main_62m5)) then
        sdm_toggle_shift_h <=
            sdm_toggle_shift_h(sdm_toggle_shift_h'left - 1 downto 0) &
            dac_hpll_load_p1;

        if (sdm_toggle_shift_h(0) = '1') then
          -- FIXME we should check that the softpll really only uses 16 bits
          sdm_data_h <= (sdm_data_h'left downto (16 + 3) => '0') &
              dac_hpll_data(15 downto 0) &
              "011";
        end if;

        if (sdm_toggle_shift_h(23 downto 8) /= x"0000") then
          sdm_toggle_h <= '1';
        else
          sdm_toggle_h <= '0';
        end if;
      end if;
    end process;

    tm_dac_d_to_sdm : process(wr_clk_main_62m5)
    begin
      if (rising_edge(wr_clk_main_62m5)) then
        sdm_toggle_shift_d <=
            sdm_toggle_shift_d(sdm_toggle_shift_d'left - 1 downto 0) &
            dac_dpll_load_p1;

        if (sdm_toggle_shift_d(0) = '1') then
          -- FIXME we should check that the softpll really only uses 16 bits
          sdm_data_d <= (sdm_data_d'left downto (16 + 3) => '0') &
              dac_dpll_data(15 downto 0) &
              "011";
        end if;

        if (sdm_toggle_shift_d(23 downto 8) /= x"0000") then
          sdm_toggle_d <= '1';
        else
          sdm_toggle_d <= '0';
        end if;
      end if;
    end process;

    U_Ref_Clock_Buffer : IBUFDS_GTE4
      generic map (
        REFCLK_EN_TX_PATH  => '0',
        REFCLK_HROW_CK_SEL => "00",
        REFCLK_ICNTL_RX    => "00")
      port map (
        O     => clk_125m_gth_buf,
        ODIV2 => open,
        CEB   => '0',
        I     => wr_clk_sfp_125m_p_i,
        IB    => wr_clk_sfp_125m_n_i);

    cmp_clk_freerun_buf_o : BUFGCE_DIV
    generic map (
      BUFGCE_DIVIDE => 2)
      port map (
        I => wr_clk_main_125m_buf,
        CLR => '0',
        CE => '1',
        O => wr_clk_main_62m5);

    -- PHY
    cmp_gth: wr_gthe4_phy_family7_xilinx_ip
      generic map (
        g_simulation         => g_simulation,
        g_use_qpll_sdm       => true,
        g_use_gclk_as_refclk => false)
      port map (
        clk_gth_i      => clk_125m_gth_buf,
        clk_freerun_i  => wr_clk_main_62m5,
        tx_out_clk_o   => wr_clk_ref_125m,
        tx_locked_o    => open,
        tx_sdm_data_i  => sdm_data_d,
        tx_sdm_toggle_i => sdm_toggle_d,
        tx_data_i      => phy16_from_wrc.tx_data,
        tx_k_i         => phy16_from_wrc.tx_k,
        tx_disparity_o => phy16_to_wrc.tx_disparity,
        tx_enc_err_o   => phy16_to_wrc.tx_enc_err,
        rx_rbclk_o     => phy16_to_wrc.rx_clk,
        rx_data_o      => phy16_to_wrc.rx_data,
        rx_k_o         => phy16_to_wrc.rx_k,
        rx_enc_err_o   => phy16_to_wrc.rx_enc_err,
        rx_bitslide_o  => phy16_to_wrc.rx_bitslide,
        rst_i          => phy16_from_wrc.rst,
        loopen_i       => "000",
        debug_i        => x"0000",
        debug_o        => open,
        pad_txn_o      => sfp_txn_o,
        pad_txp_o      => sfp_txp_o,
        pad_rxn_i      => sfp_rxn_i,
        pad_rxp_i      => sfp_rxp_i,
        rdy_o          => phy16_to_wrc.rdy);

    phy16_to_wrc.ref_clk      <= wr_clk_ref_125m;
    phy16_to_wrc.sfp_tx_fault <= sfp_tx_fault_i;
    phy16_to_wrc.sfp_los      <= sfp_los_i;

    --  the board invert the tx_disable signal.
    sfp_tx_disable_o     <= not phy16_from_wrc.sfp_tx_disable;

    -- DMTD
    cmp_clk_dmtd_bufg_gt_o : BUFG_GT
      port map (
        CE => '1',
        CEMASK => '0',
        CLR => '0',
        CLRMASK => '0',
        DIV => "000",
        O => clk_pll_dmtd,
        I => txoutclk_dmtd);

    gtwizard_dmtd_inst : gtwizard_v1_7_gthe4_sdm_dmtd
      port map (
        gtwiz_userclk_tx_reset_in => "0",
        gtwiz_userclk_tx_srcclk_out => open,
        gtwiz_userclk_tx_usrclk_out => open,
        gtwiz_userclk_tx_usrclk2_out => open,
        gtwiz_userclk_tx_active_out => open,
        gtwiz_userclk_rx_reset_in => "0",
        gtwiz_userclk_rx_srcclk_out => open,
        gtwiz_userclk_rx_usrclk_out => open,
        gtwiz_userclk_rx_usrclk2_out => open,
        gtwiz_userclk_rx_active_out => open,
        gtwiz_reset_clk_freerun_in => (0 => wr_clk_main_62m5),
        gtwiz_reset_all_in => (0 => phy16_from_wrc.rst),
        gtwiz_reset_tx_pll_and_datapath_in => "0",
        gtwiz_reset_tx_datapath_in => "0",
        gtwiz_reset_rx_pll_and_datapath_in => "0",
        gtwiz_reset_rx_datapath_in => "0",
        gtwiz_reset_rx_cdr_stable_out => open,
        gtwiz_reset_tx_done_out => open,
        gtwiz_reset_rx_done_out => open,
        gtwiz_userdata_tx_in => (31 downto 0 => '0'),
        gtwiz_userdata_rx_out => open,
        gtrefclk00_in => (0 => wr_clk_helper_125m),
        sdm0data_in => sdm_data_h,
        sdm0toggle_in => (0 => sdm_toggle_h),
        sdm1data_in => sdm_data_d,
        sdm1toggle_in => (0 => sdm_toggle_d),
        qpll0outclk_out => open,
        qpll0outrefclk_out => open,
        drpclk_in => (0 => wr_clk_main_62m5, 1 => wr_clk_main_62m5),
        gthrxn_in => dummy_gthrxn_i(1 downto 0),
        gthrxp_in => dummy_gthrxp_i(1 downto 0),
        gtrefclk0_in => (0 => wr_clk_helper_125m, 1 => wr_clk_helper_125m),
        rx8b10ben_in => "11",
        rxbufreset_in => "00",
        rxcommadeten_in => "00",
        rxmcommaalignen_in => "00",
        rxpcommaalignen_in => "00",
        tx8b10ben_in => "11",
        txctrl0_in => (31 downto 0 => '0'),
        txctrl1_in => (31 downto 0 => '0'),
        txctrl2_in => (15 downto 0 => '0'),
        -- txoutclk0 is sourced by QPLL0, and txoutclk1 is sourced by QPLL1
        txpllclksel_in => "1011",
        gthtxn_out => dummy_gthtxn_o(1 downto 0),
        gthtxp_out => dummy_gthtxp_o(1 downto 0),
        gtpowergood_out => open,
        rxbufstatus_out => open,
        rxbyteisaligned_out => open,
        rxbyterealign_out => open,
        rxclkcorcnt_out => open,
        rxcommadet_out => open,
        rxctrl0_out => open,
        rxctrl1_out => open,
        rxctrl2_out => open,
        rxctrl3_out => open,
        rxpmaresetdone_out => open,
        txoutclk_out(0) => txoutclk_dmtd,
        txoutclk_out(1) => open,
        txpmaresetdone_out => open,
        txprgdivresetdone_out => open);

    pll_locked <= '1'; -- txprgdivresetdone(0) and txprgdivresetdone(1);
  end generate gen_zynqus_sdm_qplls;

  ---------------------------------------------------------------------------
  --   Zynq US+ External 10MHz reference PLL
  ---------------------------------------------------------------------------
  gen_zynqus_ext_ref_pll: if (g_with_external_clock_input = TRUE) generate
      signal clk_ext_fbi : std_logic;
      signal clk_ext_fbo : std_logic;
      signal clk_ext_buf : std_logic;
      signal clk_ext_mul : std_logic;
      signal pll_ext_rst : std_logic;
  begin
    ext_ref_pll : MMCME4_ADV
      generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLKOUT4_CASCADE      => "FALSE",
        COMPENSATION         => "AUTO",
        STARTUP_WAIT         => "FALSE",
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT_F      => 118.750,
        CLKFBOUT_PHASE       => 0.000,
        CLKFBOUT_USE_FINE_PS => "FALSE",
        CLKIN1_PERIOD        => 100.000,

        CLKOUT0_DIVIDE_F     => 19.000,
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKOUT0_USE_FINE_PS  => "FALSE"
        )
      port map (
        CLKFBOUT     => clk_ext_fbo,
        CLKOUT0      => clk_ext_mul,
        CLKFBIN      => clk_ext_fbi,
        CLKIN1       => clk_ext_buf,
        CLKIN2       => '0',
        CLKINSEL     => '1',
        DADDR        => (others => '0'),
        DCLK         => '0',
        DEN          => '0',
        DI           => (others => '0'),
        DWE          => '0',
        CDDCREQ      => '0',
        PSCLK        => '0',
        PSEN         => '0',
        PSINCDEC     => '0',
        LOCKED       => ext_ref_mul_locked,
        CLKINSTOPPED => ext_ref_mul_stopped,
        PWRDWN       => '0',
        RST          => pll_ext_rst);

    -- External reference input buffer
    cmp_clk_ext_buf_i : BUFG
      port map (
        O => clk_ext_buf,
        I => clk_10m_ext_i);

    clk_10m_ext <= clk_ext_buf;

    -- External reference feedback buffer
    cmp_clk_ext_buf_fb : BUFG
      port map (
        O => clk_ext_fbi,
        I => clk_ext_fbo);

    -- External reference output buffer
    cmp_clk_ext_buf_o : BUFG
      port map (
        O => ext_ref_mul,
        I => clk_ext_mul);

    cmp_extend_ext_reset : gc_extend_pulse
      generic map (
        g_width => 1000)
      port map (
        clk_i      => wr_clk_main_62m5,
        rst_n_i    => '1',
        pulse_i    => ext_ref_rst,
        extended_o => pll_ext_rst);

  end generate gen_zynqus_ext_ref_pll;

  gen_no_ext_ref_pll : if (g_with_external_clock_input = FALSE) generate
    clk_10m_ext         <= '0';
    ext_ref_mul         <= '0';
    ext_ref_mul_locked  <= '1';
    ext_ref_mul_stopped <= '1';
  end generate gen_no_ext_ref_pll;


  -----------------------------------------------------------------------------
  -- Reset logic
  -----------------------------------------------------------------------------
  -- Detect when areset_edge_n_i goes high (end of reset) and use this edge to
  -- generate rstlogic_arst. This is needed to connect optional reset like PCIe
  -- reset. When baord runs standalone, we need to ignore PCIe reset being
  -- constantly low.
  cmp_arst_edge: gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => wr_clk_main_62m5,
      rst_n_i  => '1',
      data_i   => areset_edge_n_i,
      ppulse_o => areset_edge_ppulse);

  -- logic OR of all async reset sources (active high)
  rstlogic_arst <= (not pll_locked) or (not areset_n_i) or areset_edge_ppulse;

  -- concatenation of all clocks required to have synced resets
  rstlogic_clk_in(0)          <= wr_clk_main_62m5;
  rstlogic_clk_in(1)          <= wr_clk_ref_125m;

  cmp_rstlogic_reset : gc_reset_multi_aasd
    generic map (
      g_CLOCKS  => 2,   -- 62.5MHz, 125MHz
      g_RST_LEN => 16)  -- 16 clock cycles
    port map (
      arst_i  => rstlogic_arst,
      clks_i  => rstlogic_clk_in,
      rst_n_o => rstlogic_rst_out);

  -- distribution of resets (already synchronized to their clock domains)
  rst_62m5_n <= rstlogic_rst_out(0);

  rst_sys_62m5_n_o <= rst_62m5_n;
  rst_ref_125m_n_o <= rstlogic_rst_out(1);

  -----------------------------------------------------------------------------
  -- The WR PTP Core
  -----------------------------------------------------------------------------

  cmp_board_common : entity work.xwrc_board_common
    generic map (
      g_simulation                => g_simulation,
      g_verbose                   => TRUE,
      g_with_external_clock_input => g_with_external_clock_input,
      g_board_name                => g_board_name,
      g_phys_uart                 => TRUE,
      g_virtual_uart              => TRUE,
      g_aux_clks                  => g_aux_clks,
      g_ep_rxbuf_size             => 1024,
      g_tx_runt_padding           => TRUE,
      g_dpram_initf               => g_dpram_initf,
      g_dpram_size                => 262144/4,
      g_interface_mode            => PIPELINED,
      g_address_granularity       => BYTE,
      g_aux_sdb                   => c_wrc_periph3_sdb,
      g_softpll_enable_debugger   => FALSE,
      g_vuart_fifo_size           => 1024,
      g_pcs_16bit                 => TRUE,
      g_diag_id                   => g_diag_id,
      g_diag_ver                  => g_diag_ver,
      g_diag_ro_size              => g_diag_ro_size,
      g_diag_rw_size              => g_diag_rw_size,
      g_fabric_iface              => plain,
      g_dac_bits                  => g_dac_bits,
      g_aux_timing_config         => g_aux_timing_config)
    port map (
      clk_sys_i            => wr_clk_main_62m5,
      clk_dmtd_i           => clk_pll_dmtd,
      clk_ref_i            => wr_clk_ref_125m,
      clk_10m_ext_i        => clk_10m_ext,
      clk_ext_mul_i        => ext_ref_mul,
      clk_ext_mul_locked_i => ext_ref_mul_locked,
      clk_ext_stopped_i    => ext_ref_mul_stopped,
      clk_ext_rst_o        => ext_ref_rst,
      pps_ext_i            => pps_ext_i,
      rst_n_i              => rst_62m5_n,
      dac_hpll_load_p1_o   => dac_hpll_load_p1,
      dac_hpll_data_o      => dac_hpll_data,
      dac_dpll_load_p1_o   => dac_dpll_load_p1,
      dac_dpll_data_o      => dac_dpll_data,
      phy16_o              => phy16_from_wrc,
      phy16_i              => phy16_to_wrc,
      scl_o                => eeprom_scl_o,
      scl_i                => eeprom_scl_i,
      sda_o                => eeprom_sda_o,
      sda_i                => eeprom_sda_i,
      sfp_scl_o            => sfp_scl_o,
      sfp_scl_i            => sfp_scl_i,
      sfp_sda_o            => sfp_sda_o,
      sfp_sda_i            => sfp_sda_i,
      sfp_det_i            => sfp_det_i,
      uart_rxd_i           => uart0_rxd_i,
      uart_txd_o           => uart0_txd_o,
      wb_slave_i           => wb_slave_i,
      wb_slave_o           => wb_slave_o,
      aux_master_o         => aux_master_out,
      aux_master_i         => aux_master_in,
      wrf_src_o            => wrf_src_o,
      wrf_src_i            => wrf_src_i,
      wrf_snk_o            => wrf_snk_o,
      wrf_snk_i            => wrf_snk_i,
      -- Generic diagnostics i/f
      aux_diag_i           => aux_diag_i,
      aux_diag_o           => aux_diag_o,
      -- Aux clocks control
      tm_dac_value_o       => tm_dac_value_o,
      tm_dac_wr_o          => tm_dac_wr_o,
      tm_clk_aux_lock_en_i => tm_clk_aux_lock_en_i,
      tm_clk_aux_locked_o  => tm_clk_aux_locked_o,
      -- External Tx Timestamping i/f
      timestamps_o         => timestamps_o,
      timestamps_ack_i     => timestamps_ack_i,
      -- Abscal signals
      abscal_txts_o        => abscal_txts_o,
      abscal_rxts_o        => abscal_rxts_o,
      tm_link_up_o         => tm_link_up_o,
      tm_time_valid_o      => tm_time_valid_o,
      tm_tai_o             => tm_tai_o,
      tm_cycles_o          => tm_cycles_o,
      led_act_o            => led_act_o,
      led_link_o           => led_link_o,
      pps_p_o              => pps_p_o,
      pps_valid_o          => pps_valid_o,
      pps_led_o            => pps_led_o,
      link_ok_o            => link_ok_o,
      aux_timing_serdes_locked_i  => aux_timing_serdes_locked,
      utc_o                => utc_o,
      aux_timing_o         => aux_timing_out);

  cmp_board_crossbar : entity work.board_zcu10x_bus_wb
    port map(
      clk_i      => wr_clk_main_62m5,
      rst_n_i    => rst_62m5_n,
      -- Master connections (INTERCON is a slave)
      wb_i       => aux_master_out,
      wb_o       => aux_master_in,
      -- Slave connections (INTERCON is a master)
      fmc_enable_o   => enfmc_wb_in,
      fmc_enable_i   => enfmc_wb_out,

      gnss_uart_o    => gps_uart_wb_in,
      gnss_uart_i    => gps_uart_wb_out,

      si5xx_o        => si570_wb_in,
      si5xx_i        => si570_wb_out
      );

  -----------------------------------------------------------------------------
  -- Enable FMC pins
  -----------------------------------------------------------------------------
  cmp_board_enfmc: entity work.xwb_gpio_port
    generic map(
      g_interface_mode         => PIPELINED,
      g_address_granularity    => BYTE,
      g_num_pins               => g_num_fmc_enable,
      g_with_builtin_tristates => false)
    port map(
      clk_sys_i         => wr_clk_main_62m5,
      rst_n_i           => rst_62m5_n,

      gpio_out_o        => fmc_enable_o,
      gpio_in_i         => (others => '0'),
      gpio_b            => open,

      slave_i           => enfmc_wb_in,
      slave_o           => enfmc_wb_out
    );

  -----------------------------------------------------------------------------
  -- Si570
  -----------------------------------------------------------------------------
  cmp_board_si570: entity work.xwr_si57x_interface
    generic map(
      g_simulation      => g_simulation)
    port map(
      clk_sys_i         => wr_clk_main_62m5,
      rst_n_i           => rst_62m5_n,

      scl_pad_oen_o     => si570_scl_oen_o,
      sda_pad_oen_o     => si570_sda_oen_o,
      scl_pad_i         => si570_scl_i,
      sda_pad_i         => si570_sda_i,

      slave_i           => si570_wb_in,
      slave_o           => si570_wb_out
    );

  -----------------------------------------------------------------------------
  -- GPS Uart device
  -----------------------------------------------------------------------------
  cmp_gps_uart : xwb_simple_uart
    generic map(
      g_with_virtual_uart   => FALSE,
      g_with_physical_uart  => TRUE,
      g_interface_mode      => PIPELINED,
      g_address_granularity => BYTE,
      g_vuart_fifo_size     => 1024,
      g_WITH_PHYSICAL_UART_FIFO => TRUE,
      g_TX_FIFO_SIZE => 1024,
      g_RX_FIFO_SIZE => 1024
    )
    port map(
      clk_sys_i => wr_clk_main_62m5,
      rst_n_i   => rst_62m5_n,

      -- Wishbone
      slave_i => gps_uart_wb_in,
      slave_o => gps_uart_wb_out,
      desc_o  => open,

      uart_rxd_i => uart1_rxd_i,
      uart_txd_o => uart1_txd_o
    );

  sfp_rate_select_o <= '1';
  ------------------------------------------------------------------------------
  cmp_serdes: entity work.xoserdes_8_to_1_ultrascale
    port map
    (
      clk_i     => wr_clk_ref_125m,
      rst_i     => pll_arst,
      serdes_i  => aux_timing_out.serdes_in,
      serdes_o  => serdes_out,
      pll_serdes_locked_o => aux_timing_serdes_locked
    );
  aux_timing_o <= f_aux_timing_assign_serdes_out(aux_timing_out, serdes_out);

  -- active high async reset for PLLs
  pll_arst <= not areset_n_i;

end architecture struct;
