-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2024 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Title      : WRPC reference design for KR260 board
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- Company    : CERN (BE-CO-HT)
-- Standard   : VHDL'93
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4_pkg.all;
--use work.gencores_pkg.all;
use work.wishbone_pkg.all;
use work.endpoint_pkg.all;
--use work.wr_board_pkg.all;
--use work.wr_pxie_fmc_pkg.all;
use work.wr_timecode_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity kr260_ref_top is
  generic(
    g_AUX_TIMING_CONFIG : t_wr_timecode_config := (c_WITH_AUXCLK_IDX=>TRUE, c_WITH_IRIG_IDX=>FALSE, c_WITH_NMEA_IDX=>FALSE)
    );
  port (
    refclk0_n_i : in std_logic;
    refclk0_p_i : in std_logic;

    clk_25m_i   : in std_logic;

    pad_txn_o : out std_logic;
    pad_txp_o : out std_logic;
    pad_rxn_i : in std_logic;
    pad_rxp_i : in std_logic;

    helper_txn_o : out std_logic;
    helper_txp_o : out std_logic;
    helper_rxn_i : in std_logic;
    helper_rxp_i : in std_logic;

    led1_o : out std_logic;
    led2_o : out std_logic;
    sfp_led1_o : out std_logic;
    sfp_led2_o : out std_logic;

    sfp_tx_fault_i : in std_logic;
    sfp_tx_disable_o : out std_logic;
    sfp_mod_abs_i : in std_logic;
    sfp_sda_b : inout std_logic;
    sfp_scl_b : inout std_logic;

    pmod1_7_t : out std_logic; -- pps
    pmod2_7_t : out std_logic; -- 10MHz

    pmod4_2_b : out std_logic;
    pmod4_4_b : out std_logic;
    pmod4_6_b : out std_logic
  );
end;

architecture top of kr260_ref_top is
  --  In sources, select the mpsoc.bd file and right-click to view instantiation template
  component mpsoc is
    port (
      M_AXI_araddr : out STD_LOGIC_VECTOR ( 39 downto 0 );
      M_AXI_arprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
      M_AXI_arready : in STD_LOGIC;
      M_AXI_arvalid : out STD_LOGIC;
      M_AXI_awaddr : out STD_LOGIC_VECTOR ( 39 downto 0 );
      M_AXI_awprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
      M_AXI_awready : in STD_LOGIC;
      M_AXI_awvalid : out STD_LOGIC;
      M_AXI_bready : out STD_LOGIC;
      M_AXI_bresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
      M_AXI_bvalid : in STD_LOGIC;
      M_AXI_rdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
      M_AXI_rready : out STD_LOGIC;
      M_AXI_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
      M_AXI_rvalid : in STD_LOGIC;
      M_AXI_wdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
      M_AXI_wready : in STD_LOGIC;
      M_AXI_wstrb : out STD_LOGIC_VECTOR ( 3 downto 0 );
      M_AXI_wvalid : out STD_LOGIC;
      UART_0_0_rxd : in STD_LOGIC;
      UART_0_0_txd : out STD_LOGIC;
      clk_axi : in STD_LOGIC;
      rst_axi_n : in STD_LOGIC
    );
  end component mpsoc;

  COMPONENT gthe4_sdm
  PORT (
    gtwiz_userclk_tx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_start_user_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_error_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_start_user_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_error_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0lock_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0reset_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    gtwiz_userdata_rx_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpaddr_in : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    drpclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdi_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpwe_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxn_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxp_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0clk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0refclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1clk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1refclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rx8b10ben_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxcommadeten_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxmcommaalignen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpcommaalignen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxslide_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    tx8b10ben_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txctrl0_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    txctrl1_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    txctrl2_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    txpippmen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpippmovrden_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpippmpd_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpippmsel_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpippmstepsize_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txpllclksel_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    drpdo_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    drprdy_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxn_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxp_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxbyteisaligned_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxbyterealign_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxcommadet_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxctrl0_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    rxctrl1_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    rxctrl2_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    rxctrl3_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    rxpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpcsreset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txprgdivresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

  signal refclk_156m25, refclk_156m25_int : std_logic;
  signal rst_n, rst : std_logic := '0';
  signal rst_cnt : natural range 0 to 15 := 0;

  signal qpll_reset, qpll_lock, qpll0_lock, qpll1_lock : std_logic;
  signal qpll0_outclk, qpll0_outrefclk : std_logic;
  signal qpll1_outclk, qpll1_outrefclk : std_logic;
  signal clk_25m : std_logic;

  signal count : natural range 0 to 156_250_000 - 1;
  signal clk_156m25, clk_62m5 : std_logic;
  signal clk_fb, pll_locked : std_logic;
  signal clk_dmtd : std_logic;

  signal m_axi4_out : t_axi4_lite_master_out_32;
  signal m_axi4_in : t_axi4_lite_master_in_32;
  signal m_axi_araddr, m_axi_awaddr : std_logic_vector(39 downto 32);

  signal gth_rst, phy_rst : std_logic;
  signal uart_rx, uart_tx : std_logic;
  signal sfp_scl_out, sfp_sda_out : std_logic;

  signal wb_wrpc_in: t_wishbone_master_in;
  signal wb_wrpc_out: t_wishbone_master_out;

  signal phy16_out : t_phy_16bits_from_wrc;
  signal phy16_in : t_phy_16bits_to_wrc;

  signal gtwiz_userclk_tx_reset_out : std_logic;
  signal gtwiz_userclk_tx_active_in : std_logic;
  signal gtwiz_userclk_rx_reset_out : std_logic;
  signal gtwiz_userclk_rx_active_in : std_logic;
  signal gtwiz_buffbypass_tx_reset_out : std_logic;
  signal gtwiz_buffbypass_tx_done_in : std_logic;
  signal gtwiz_buffbypass_tx_error_in : std_logic;
  signal gtwiz_buffbypass_rx_reset_out : std_logic;
  signal gtwiz_buffbypass_rx_start_user_out : std_logic;
  signal gtwiz_buffbypass_rx_done_in : std_logic;
  signal gtwiz_buffbypass_rx_error_in : std_logic;
  signal gtwiz_reset_all_out : std_logic;
  signal gtwiz_reset_tx_done_in : std_logic;
  signal gtwiz_reset_rx_done_in : std_logic;

  signal gtwiz_reset_rx_cdr_stable_out : std_logic;

  signal gth_rx_data_in : std_logic_vector(15 downto 0);
  signal gth_tx_data_out : std_logic_vector(15 downto 0);
  signal gth_rx_slide_out : std_logic;
  signal gth_rx_k_in : std_logic_vector(15 downto 0);
  signal gth_tx_k_out : std_logic_vector(7 downto 0) := (others => '0');
  signal gth_rx_byte_aligned_in : std_logic;
  signal gth_rx_comma_det_in : std_logic;
  signal gth_rx_pma_reset_done_in : std_logic;
  signal gth_tx_pma_reset_done_in : std_logic;

  signal gth_powergood : std_logic;
  signal gth_tx_prg_div_reset_done : std_logic;

  signal hpll_data_out, mpll_data_out : std_logic_vector(15 downto 0);
  signal hpll_load, mpll_load : std_logic;

  signal hpll_data, mpll_data : std_logic_vector(24 downto 0);
  signal hpll_toggle, mpll_toggle : std_logic;
  signal hpll_cnt, mpll_cnt : unsigned(5 downto 0);

  -- Auxclock serdes word
  signal aux_timing_serdes_locked : std_logic;
  signal aux_timing_out : t_aux_timing_out;
  signal aux_timing_o   : t_aux_timing_out;
  signal serdes_out     : std_logic;
  signal pll_arst       : std_logic := '0';
  signal utc_o          : t_utc_out;

  signal clkfbout_clk_wiz_0 : std_logic;
  signal clkfbout_buf_clk_wiz_0 : std_logic;
  signal clk_10m : std_logic;

  signal rx_bitslide_pcs_reset : std_logic;



begin
  inst_ibufds_gt : IBUFDS_GTE4
      generic map (
        REFCLK_EN_TX_PATH  => '0',
        REFCLK_HROW_CK_SEL => "00",
        REFCLK_ICNTL_RX    => "00")
      port map (
        O     => refclk_156m25,
        ODIV2 => refclk_156m25_int,
        CEB   => '0',
        I     => refclk0_p_i,
        IB    => refclk0_n_i);

  inst_buf_gt : BUFG_GT
      port map (
        O => clk_156m25,
        CE => '1',
        CEMASK => '0',
        CLR => '0',
        CLRMASK => '0',
        DIV => "000",
        I => refclk_156m25_int);


  inst_bufg: BUFG
    port map (
      O => clk_25m,
      I => clk_25m_i);

  --  VCO: 800-1600Mhz
  --  input: 156.25 * 8 = 1250Mhz / 20 => 62.50
  --  input: 74.25 * 20 = 1485Mhz
  --         74.25 * 16 = 1188Mhz  / 19 => 62.52
  inst_mmcm: mmcme4_base
    generic map (
      BANDWIDTH => "OPTIMIZED",  -- Jitter programming
      CLKFBOUT_MULT_F => 8.0,   -- Multiply value for all CLKOUT
      CLKFBOUT_PHASE => 0.0,     -- Phase offset in degrees of CLKFB
      CLKIN1_PERIOD => 6.4,    -- Input clock period in ns to ps resolution (i.e., 33.333 is 30 MHz).
      CLKOUT0_DIVIDE_F => 20.0,  -- Divide amount for CLKOUT0
      CLKOUT0_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT0
      CLKOUT0_PHASE => 0.0,     -- Phase offset for CLKOUT0
      CLKOUT1_DIVIDE => 100,  -- Divide amount for CLKOUT (1-128)
      CLKOUT1_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT outputs (0.001-0.999).
      CLKOUT1_PHASE => 0.0,   -- Phase offset for CLKOUT outputs (-360.000-360.000).
      CLKOUT2_DIVIDE => 1,   -- Divide amount for CLKOUT (1-128)
      CLKOUT2_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT outputs (0.001-0.999).
      CLKOUT2_PHASE => 0.0,  -- Phase offset for CLKOUT outputs (-360.000-360.000).
      CLKOUT3_DIVIDE => 1,   -- Divide amount for CLKOUT (1-128)
      CLKOUT3_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT outputs (0.001-0.999).
      CLKOUT3_PHASE => 0.0, -- Phase offset for CLKOUT outputs (-360.000-360.000).
      CLKOUT4_CASCADE => "FALSE", -- Divide amount for CLKOUT (1-128)
      CLKOUT4_DIVIDE => 1, -- Divide amount for CLKOUT (1-128)
      CLKOUT4_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT outputs (0.001-0.999).
      CLKOUT4_PHASE => 0.0,  -- Phase offset for CLKOUT outputs (-360.000-360.000).
      CLKOUT5_DIVIDE => 1,  -- Divide amount for CLKOUT (1-128)
      CLKOUT5_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT outputs (0.001-0.999).
      CLKOUT5_PHASE => 0.0,   -- Phase offset for CLKOUT outputs (-360.000-360.000).
      CLKOUT6_DIVIDE => 1,   -- Divide amount for CLKOUT (1-128)
      CLKOUT6_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT outputs (0.001-0.999).
      CLKOUT6_PHASE => 0.0,    -- Phase offset for CLKOUT outputs (-360.000-360.000).
      DIVCLK_DIVIDE => 1,   -- Master division value
      IS_CLKFBIN_INVERTED => '0', -- Optional inversion for CLKFBIN
      IS_CLKIN1_INVERTED => '0', -- Optional inversion for CLKIN1
      IS_PWRDWN_INVERTED => '0', -- Optional inversion for PWRDWN
      IS_RST_INVERTED => '0',   -- Optional inversion for RST
      REF_JITTER1 => 0.0,   -- Reference input jitter in UI (0.000-0.999).
      STARTUP_WAIT => "FALSE" -- Delays DONE until MMCM is locked
      )
    port map (
      CLKFBOUT => clk_fb,  -- 1-bit output: Feedback clock pin to the MMCM
      CLKFBOUTB => open, -- 1-bit output: Inverted CLKFBOUT
      CLKOUT0 => clk_62m5, -- 1-bit output: CLKOUT0
      CLKOUT0B => open,  -- 1-bit output: Inverted CLKOUT0
      CLKOUT1 => pmod4_2_b,   -- 1-bit output: CLKOUT1
      CLKOUT1B => open,  -- 1-bit output: Inverted CLKOUT1
      CLKOUT2 => open,   -- 1-bit output: CLKOUT2
      CLKOUT2B => open,  -- 1-bit output: Inverted CLKOUT2
      CLKOUT3 => open,   -- 1-bit output: CLKOUT3
      CLKOUT3B => open,  -- 1-bit output: Inverted CLKOUT3
      CLKOUT4 => open,   -- 1-bit output: CLKOUT4
      CLKOUT5 => open,   -- 1-bit output: CLKOUT5
      CLKOUT6 => open,   -- 1-bit output: CLKOUT6
      LOCKED => pll_locked,  -- 1-bit output: LOCK
      CLKFBIN => clk_fb, -- 1-bit input: Feedback clock pin to the MMCM
      CLKIN1 => clk_156m25, -- 1-bit input: Primary clock
      PWRDWN => '0', -- 1-bit input: Power-down
      RST => '0'  -- 1-bit input: Reset
    );

  process(clk_62m5, pll_locked)
  begin
    if pll_locked = '0' then
      rst_n <= '0';
    elsif rising_edge(clk_62m5) then
      if rst_cnt = 15 then
        rst_n <= '1';
      else
        rst_n <= '0';
        rst_cnt <= rst_cnt + 1;
      end if;
    end if;
  end process;

  rst <= not rst_n;

  process(clk_25m)
  begin
    if rising_edge(clk_25m) then
      if rst_n = '0' then
        led1_o <= '0';
        led2_o <= '1';
        count <= 0;
      else
        if count = 12_500_000 - 1 then
          led1_o <= '1';
          led2_o <= '0';
          count <= count + 1;
        elsif count = 25_000_000 - 1 then
          led1_o <= '0';
          led2_o <= '1';
          count <= 0;
        else
          count <= count + 1;
        end if;
      end if;
    end if;
  end process;

  inst_mpsoc: mpsoc
    port map (
      M_AXI_awaddr(31 downto 0) => m_axi4_out.awaddr,
      M_AXI_awaddr(39 downto 32) => m_axi_awaddr,
      M_AXI_awprot => open,
      M_AXI_awvalid => m_axi4_out.awvalid,
      M_AXI_awready => m_axi4_in.awready,
      M_AXI_wdata => m_axi4_out.wdata,
      M_AXI_wstrb => m_axi4_out.wstrb,
      M_AXI_wvalid => m_axi4_out.wvalid,
      M_AXI_wready => m_axi4_in.wready,
      M_AXI_bresp => m_axi4_in.bresp,
      M_AXI_bvalid => m_axi4_in.bvalid,
      M_AXI_bready => m_axi4_out.bready,
      M_AXI_araddr(31 downto 0) => m_axi4_out.araddr,
      M_AXI_araddr(39 downto 32) => m_axi_araddr,
      M_AXI_arprot => open,
      M_AXI_arvalid => m_axi4_out.arvalid,
      M_AXI_arready => m_axi4_in.arready,
      M_AXI_rdata => m_axi4_in.rdata,
      M_AXI_rresp => m_axi4_in.rresp,
      M_AXI_rvalid => m_axi4_in.rvalid,
      M_AXI_rready => m_axi4_out.rready,
      UART_0_0_rxd => uart_rx,
      UART_0_0_txd => uart_tx,
      rst_axi_n => rst_n,
      clk_axi => clk_62m5
    );
  inst_mpsoc_map: entity work.mpsoc_map
  port map (
    aclk => clk_62m5,
    areset_n => rst_n,
    awaddr => m_axi4_out.awaddr(12 downto 2),
    awvalid => m_axi4_out.awvalid,
    awready => m_axi4_in.awready,
    awprot => "000",
    wvalid => m_axi4_out.wvalid,
    wready => m_axi4_in.wready,
    wdata => m_axi4_out.wdata,
    wstrb => m_axi4_out.wstrb,
    bvalid => m_axi4_in.bvalid,
    bready => m_axi4_out.bready,
    bresp => m_axi4_in.bresp,
    araddr => m_axi4_out.araddr(12 downto 2),
    arvalid => m_axi4_out.arvalid,
    arready => m_axi4_in.arready,
    arprot => "000",
    rvalid => m_axi4_in.rvalid,
    rready => m_axi4_out.rready,
    rdata => m_axi4_in.rdata,
    rresp => m_axi4_in.rresp,

    wrpc_i => wb_wrpc_in,
    wrpc_o => wb_wrpc_out,

    ctrl_led1_o => open,
    ctrl_led2_o => sfp_led2_o,
    ctrl_gth_rst_o => gth_rst
  );

  inst_wrcore : entity work.xwr_core
    generic map (
      g_board_name => "KR26",
--      g_dpram_initf => "../../../../bin/wrpc/wrc_phy16.bram",
      g_dpram_initf => "",
      g_dpram_size => 192 * 1024 / 4,
      g_pcs_16bit => true,
      g_records_for_phy => true,
      g_aux_timing_config => g_AUX_TIMING_CONFIG
    )
    port map (
      clk_sys_i => clk_62m5,
      rst_n_i => rst_n,

      clk_dmtd_i => clk_dmtd,
      clk_ref_i => phy16_in.ref_clk,

      clk_dmtd_over_i => open,
      clk_aux_i => open,
      clk_ext_i => open,
      clk_ext_mul_i => open,
      clk_ext_mul_locked_i => open,
      clk_ext_stopped_i => open,
      clk_ext_rst_o => open,
      pps_ext_i => open,

      dac_hpll_load_p1_o => hpll_load,
      dac_hpll_data_o => hpll_data_out,
      dac_dpll_load_p1_o => mpll_load,
      dac_dpll_data_o => mpll_data_out,

      phy_ref_clk_i => open,
      phy_tx_data_o => open,
      phy_tx_k_o => open,
      phy_tx_disparity_i => open,
      phy_tx_enc_err_i => open,
      phy_rx_data_i => open,
      phy_rx_rbclk_i => open,
      phy_rx_rbclk_sampled_i => open,
      phy_rx_k_i => open,
      phy_rx_enc_err_i => open,
      phy_rx_bitslide_i => open,
      phy_mdio_master_o => open,
      phy_mdio_master_i => open,
      phy_rst_o => open,
      phy_rdy_i => open,
      phy_loopen_o => open,
      phy_loopen_vec_o => open,
      phy_tx_prbs_sel_o => open,
      phy_sfp_tx_fault_i => open,
      phy_sfp_los_i => open,
      phy_sfp_tx_disable_o => open,
      phy8_i => open,
      phy8_o => open,

      phy16_o => phy16_out,
      phy16_i => phy16_in,

      led_act_o => open,
      scl_o => open,
      scl_i => open,
      sda_o => open,
      sda_i => open,

      sfp_det_i => sfp_mod_abs_i,
      sfp_scl_o => sfp_scl_out,
      sfp_scl_i => sfp_scl_b,
      sfp_sda_o => sfp_sda_out,
      sfp_sda_i => sfp_sda_b,

      spi_sclk_o => open,
      spi_ncs_o => open,
      spi_mosi_o => open,
      spi_miso_i => open,

      owr_pwren_o => open,
      owr_en_o => open,
      owr_i => open,

      uart_rxd_i => uart_tx,
      uart_txd_o => uart_rx,

      slave_i => wb_wrpc_out,
      slave_o => wb_wrpc_in,

      aux_master_i => open,
      aux_master_o => open,

      wrf_src_o => open,
      wrf_src_i => open,
      wrf_snk_o => open,
      wrf_snk_i => open,

      timestamps_o => open,
      timestamps_ack_i => open,

      abscal_txts_o => open,
      abscal_rxts_o => open,

      fc_tx_pause_req_i => open,
      fc_tx_pause_delay_i => open,
      fc_tx_pause_ready_o => open,

      tm_link_up_o => open,
      tm_time_valid_o => open,
      tm_tai_o => open,
      tm_cycles_o => open,
      tm_clk_aux_lock_en_i => open,
      tm_clk_aux_locked_o => open,

      tm_dac_value_o => open,
      tm_dac_wr_o => open,

      pps_csync_o => open,
      pps_valid_o => open,
      pps_p_o => pmod1_7_t,
      pps_led_o => open,

      rst_aux_n_o => open,

      led_link_o => open,
      link_ok_o => open,

      -- Auxiliary Timing (clk_ref)
      aux_timing_serdes_locked_i  => aux_timing_serdes_locked,
      utc_o                => utc_o,
      aux_timing_o         => aux_timing_out,

      aux_diag_i => open,
      aux_diag_o => open,

      btn1_i => open,
      btn2_i => open
    );
  -- uart_rx <= uart_tx;

  mmcme4_adv_10MHz_inst : MMCME4_ADV
  generic map (
    BANDWIDTH            => "OPTIMIZED",
    CLKOUT4_CASCADE      => "FALSE",
    COMPENSATION         => "AUTO",
    STARTUP_WAIT         => "FALSE",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT_F      => 16.000,
    CLKFBOUT_PHASE       => 0.000,
    CLKFBOUT_USE_FINE_PS => "FALSE",
    CLKOUT0_DIVIDE_F     => 100.000,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT0_USE_FINE_PS  => "FALSE",
    CLKIN1_PERIOD        => 16.000)
  port map (
    CLKFBOUT             => clkfbout_clk_wiz_0,
    CLKFBOUTB            => open,
    CLKOUT0              => clk_10m,
    CLKOUT0B             => open,
    CLKOUT1              => open,
    CLKOUT1B             => open,
    CLKOUT2              => open,
    CLKOUT2B             => open,
    CLKOUT3              => open,
    CLKOUT3B             => open,
    CLKOUT4              => open,
    CLKOUT5              => open,
    CLKOUT6              => open,
    CLKFBIN              => clkfbout_buf_clk_wiz_0,
    CLKIN1               => phy16_in.ref_clk, --62.5 MHz
    CLKIN2               => '0',
    CLKINSEL             => '1',
    DADDR                => "0000000",
    DCLK                 => '0',
    DEN                  => '0',
    DI                   => x"0000",
    DO                   => open,
    DRDY                 => open,
    DWE                  => '0',
    CDDCDONE             => open,
    CDDCREQ              => '0',
    PSCLK                => '0',
    PSEN                 => '0',
    PSINCDEC             => '0',
    PSDONE               => open,
    LOCKED               => open, --locked_int,
    CLKINSTOPPED         => open,
    CLKFBSTOPPED         => open,
    PWRDWN               => '0',
    RST                  => '0');

  clkf_buf : BUFG
    port map (
      O => clkfbout_buf_clk_wiz_0,
      I => clkfbout_clk_wiz_0);

  pmod2_7_t <= clk_10m;

  sfp_tx_disable_o <= phy16_out.sfp_tx_disable;
  phy16_in.sfp_tx_fault <= sfp_tx_fault_i;

  sfp_sda_b <= '0' when sfp_sda_out = '0' else 'Z';
  sfp_scl_b <= '0' when sfp_scl_out = '0' else 'Z';

  process(clk_62m5)
  begin
    if rising_edge(clk_62m5) then
      if rst_n = '0' then
        mpll_cnt <= (others => '0');
        hpll_cnt <= (others => '0');
        mpll_toggle <= '0';
        hpll_toggle <= '0';
      else
        if mpll_cnt = 0 then
          --  Idle, can accept a new value
          if mpll_load = '1' then
            --  Reformat.
            --  According to 73205, only LSB are significant.
            mpll_data <= (others => '0');
            mpll_data(15 downto 0) <= mpll_data_out;
            mpll_cnt <= (others => '1');
          end if;
        else
          --  FB CLK should be way higher than system clock
          if mpll_cnt(5 downto 4) = "00" then
            mpll_toggle <= '0';
          elsif mpll_cnt(5 downto 4) /= "11" then
            mpll_toggle <= '1';
          end if;
          mpll_cnt <= mpll_cnt - 1;
        end if;

        if hpll_cnt = 0 then
          --  Idle, can accept a new value
          if hpll_load = '1' then
            --  Reformat.
            --  According to 73205, only LSB are significant.
            hpll_data <= (others => '0');
            hpll_data(23 downto 0) <= b"1111_111" & hpll_data_out & '0';
            hpll_cnt <= (others => '1');
          end if;
        else
          --  FB CLK should be way higher than system clock
          if hpll_cnt(5 downto 4) = "00" then
            hpll_toggle <= '0';
          elsif hpll_cnt(5 downto 4) /= "11" then
            hpll_toggle <= '1';
          end if;
          hpll_cnt <= hpll_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  --  The common part of the gthe4.
  --  The values can be found in the top-level module generated when the common
  --  part is included.
  inst_common: gthe4_common
    generic map (
      AEN_QPLL0_FBDIV       =>          '1',
      AEN_QPLL1_FBDIV       =>          '1',
      AEN_SDM0TOGGLE        =>          '0',
      AEN_SDM1TOGGLE        =>          '0',
      A_SDM0TOGGLE          =>          '0',
      A_SDM1DATA_HIGH       =>          "000000000",
      A_SDM1DATA_LOW        =>          "0000000000000000",
      A_SDM1TOGGLE          =>          '0',
      BIAS_CFG0             =>          "0000000000000000",
      BIAS_CFG1             =>          "0000000000000000",
      BIAS_CFG2             =>          "0000000100100100",
      BIAS_CFG3             =>          "0000000001000001",
      BIAS_CFG4             =>          "0000000000010000",
      BIAS_CFG_RSVD         =>          "0000000000000000",
      COMMON_CFG0           =>          "0000000000000000",
      COMMON_CFG1           =>          "0000000000000000",
      POR_CFG               =>          "0000000000000000",
      PPF0_CFG              =>          "0000011000000000",
      PPF1_CFG              =>          "0000011000000000",
      QPLL0CLKOUT_RATE      =>          "HALF",
      QPLL0_CFG0            =>          "0011001100011100",
      QPLL0_CFG1            =>          "1101000000111000",
      QPLL0_CFG1_G3         =>          "1101000000111000",
      QPLL0_CFG2            =>          "0000111111000000",
      QPLL0_CFG2_G3         =>          "0000111111000000",
      QPLL0_CFG3            =>          "0000000100100000",
      QPLL0_CFG4            =>          "0000000000000011",
      QPLL0_CP              =>          "0011111111",
      QPLL0_CP_G3           =>          "0000001111",
      QPLL0_FBDIV           =>          64,
      QPLL0_FBDIV_G3        =>          160,
      QPLL0_INIT_CFG0       =>          "0000001010110010",
      QPLL0_INIT_CFG1       =>          "00000000",
      QPLL0_LOCK_CFG        =>          "0010010111101000",
      QPLL0_LOCK_CFG_G3     =>          "0010010111101000",
      QPLL0_LPF             =>          "1000111111",
      QPLL0_LPF_G3          =>          "0111010101",
      QPLL0_PCI_EN          =>          '0',
      QPLL0_RATE_SW_USE_DRP =>          '1',
      QPLL0_REFCLK_DIV      =>          1,
      QPLL0_SDM_CFG0        =>          "0000000000000000",
      QPLL0_SDM_CFG1        =>          "0000000000000000",
      QPLL0_SDM_CFG2        =>          "0000000000000000",
      QPLL1CLKOUT_RATE      =>          "HALF",
      QPLL1_CFG0            =>          "0011001100011100",
      QPLL1_CFG1            =>          "1101000000111000",
      QPLL1_CFG1_G3         =>          "1101000000111000",
      QPLL1_CFG2            =>          "0000111111000011",
      QPLL1_CFG2_G3         =>          "0000111111000011",
      QPLL1_CFG3            =>          "0000000100100000",
      QPLL1_CFG4            =>          "0000000000000011",
      QPLL1_CP              =>          "0011111111",
      QPLL1_CP_G3           =>          "0001111111",
      QPLL1_FBDIV           =>          63,
      QPLL1_FBDIV_G3        =>          80,
      QPLL1_INIT_CFG0       =>          "0000001010110010",
      QPLL1_INIT_CFG1       =>          "00000000",
      QPLL1_LOCK_CFG        =>          "0010010111101000",
      QPLL1_LOCK_CFG_G3     =>          "0010010111101000",
      QPLL1_LPF             =>          "1000011111",
      QPLL1_LPF_G3          =>          "0111010100",
      QPLL1_PCI_EN          =>          '0',
      QPLL1_RATE_SW_USE_DRP =>          '1',
      QPLL1_REFCLK_DIV      =>          1,
      QPLL1_SDM_CFG0        =>          "0000000000000000",
      QPLL1_SDM_CFG1        =>          "0000000000000000",
      QPLL1_SDM_CFG2        =>          "0000000000000000",
      RSVD_ATTR0            =>          "0000000000000000",
      RSVD_ATTR1            =>          "0000000000000000",
      RSVD_ATTR2            =>          "0000000000000000",
      RSVD_ATTR3            =>          "0000000000000000",
      RXRECCLKOUT0_SEL      =>          "00",
      RXRECCLKOUT1_SEL      =>          "00",
      SARC_ENB              =>          '0',
      SARC_SEL              =>          '0',
      SDM0INITSEED0_0       =>          "0000000100010001",
      SDM0INITSEED0_1       =>          "000010001",
      SIM_DEVICE            =>          "ULTRASCALE_PLUS",
      SIM_MODE              =>          "FAST",
      SIM_RESET_SPEEDUP     =>          "TRUE"
    )
    port map (
      BGBYPASSB => '1',
      BGMONITORENB => '1',
      BGPDB => '1',
      BGRCALOVRD => "11111",
      BGRCALOVRDENB => '1',

      DRPADDR => (others => '0'),
      DRPCLK => clk_62m5,
      DRPDI => (others => '0'),
      DRPEN => '0',
      DRPWE => '0',
      DRPDO => open,
      DRPRDY => open,

      GTGREFCLK0 => '0',
      GTGREFCLK1 => '0',
      GTNORTHREFCLK00 => '0',
      GTNORTHREFCLK01 => '0',
      GTNORTHREFCLK10 => '0',
      GTNORTHREFCLK11 => '0',
      GTREFCLK00 => refclk_156m25,
      GTREFCLK01 => refclk_156m25,
      GTREFCLK10 => '0',
      GTREFCLK11 => '0',
      GTSOUTHREFCLK00 => '0',
      GTSOUTHREFCLK01 => '0',
      GTSOUTHREFCLK10 => '0',
      GTSOUTHREFCLK11 => '0',

      PCIERATEQPLL0 => "000",
      PCIERATEQPLL1 => "000",
      PMARSVD0 => x"00",
      PMARSVD1 => x"00",

      QPLL0CLKRSVD0 => '0',
      QPLL0CLKRSVD1 => '0',
      QPLL0FBDIV => x"40",
      QPLL0LOCKDETCLK => '0',
      QPLL0LOCKEN => '1',
      QPLL0PD => '0',
      QPLL0REFCLKSEL => "001", -- gtrefclk0
      QPLL0RESET => qpll_reset,
      QPLL1CLKRSVD0 => '0',
      QPLL1CLKRSVD1 => '0',
      QPLL1FBDIV => x"40",
      QPLL1LOCKDETCLK => '0',
      QPLL1LOCKEN => '1',
      QPLL1PD => '0',
      QPLL1REFCLKSEL => "001",
      QPLL1RESET => qpll_reset,
      QPLLRSVD1 => x"00",
      QPLLRSVD2 => "00000",
      QPLLRSVD3 => "00000",
      QPLLRSVD4 => x"00",
      RCALENB => '1',
      SDM0DATA => mpll_data,
      SDM0RESET => '0',
      SDM0TOGGLE => mpll_toggle,
      SDM0WIDTH => "00",  -- 00:24b
      SDM1DATA => hpll_data,
      SDM1RESET => '0',
      SDM1TOGGLE => hpll_toggle,
      SDM1WIDTH => "00",  -- 00:24b
      TCONGPI => b"00_0000_0000",
      TCONPOWERUP => '0',
      TCONRESET => "00",
      TCONRSVDIN1 => "00",
      PMARSVDOUT0 => open,
      PMARSVDOUT1 => open,
      QPLL0FBCLKLOST => open,
      QPLL0LOCK => qpll0_lock,
      QPLL0OUTCLK => qpll0_outclk,
      QPLL0OUTREFCLK => qpll0_outrefclk,
      QPLL0REFCLKLOST => open,
      QPLL1FBCLKLOST => open,
      QPLL1LOCK => qpll1_lock,
      QPLL1OUTCLK => qpll1_outclk,
      QPLL1OUTREFCLK => qpll1_outrefclk,
      QPLL1REFCLKLOST => open,
      QPLLDMONITOR0 => open,
      QPLLDMONITOR1 => open,
      REFCLKOUTMONITOR0 => open,
      REFCLKOUTMONITOR1 => open,
      RXRECCLK0SEL => open,
      RXRECCLK1SEL => open,
      SDM0FINALOUT => open,
      SDM0TESTDATA => open,
      SDM1FINALOUT => open,
      SDM1TESTDATA => open,
      TCONGPO => open,
      TCONRSVDOUT0 => open
  );

  qpll_lock <= qpll0_lock; --  and qpll0_lock;

  inst_gth: gthe4_sdm
    port map (
      gthrxn_in(0)  => pad_rxn_i,
      gthrxp_in(0)  => pad_rxp_i,
      gthtxn_out(0) => pad_txn_o,
      gthtxp_out(0) => pad_txp_o,

      gtwiz_userclk_tx_reset_in(0) => gtwiz_userclk_tx_reset_out,
      gtwiz_userclk_tx_srcclk_out => open,
      gtwiz_userclk_tx_usrclk_out => open,
      gtwiz_userclk_tx_usrclk2_out(0) => phy16_in.ref_clk,
      gtwiz_userclk_tx_active_out(0) => gtwiz_userclk_tx_active_in,
      gtwiz_userclk_rx_reset_in(0) => gtwiz_userclk_rx_reset_out,
      gtwiz_userclk_rx_srcclk_out => open,
      gtwiz_userclk_rx_usrclk_out => open,
      gtwiz_userclk_rx_usrclk2_out(0) => phy16_in.rx_clk,
      gtwiz_userclk_rx_active_out(0) => gtwiz_userclk_rx_active_in,
      gtwiz_buffbypass_tx_reset_in(0) => gtwiz_buffbypass_tx_reset_out,
      gtwiz_buffbypass_tx_start_user_in(0) => '0',
      gtwiz_buffbypass_tx_done_out(0) => gtwiz_buffbypass_tx_done_in,
      gtwiz_buffbypass_tx_error_out(0) => gtwiz_buffbypass_tx_error_in,
      gtwiz_buffbypass_rx_reset_in(0) => gtwiz_buffbypass_rx_reset_out,
      gtwiz_buffbypass_rx_start_user_in(0) => gtwiz_buffbypass_rx_start_user_out,
      gtwiz_buffbypass_rx_done_out(0) => gtwiz_buffbypass_rx_done_in,
      gtwiz_buffbypass_rx_error_out(0) => gtwiz_buffbypass_rx_error_in,

      gtwiz_reset_qpll0reset_out(0) => qpll_reset,
      gtwiz_reset_qpll0lock_in(0) => qpll_lock,
      gtwiz_reset_clk_freerun_in(0) => clk_62m5,
      gtwiz_reset_all_in(0) => gtwiz_reset_all_out,
      gtwiz_reset_tx_pll_and_datapath_in(0) => '0',
      gtwiz_reset_tx_datapath_in(0) => '0',
      gtwiz_reset_rx_pll_and_datapath_in(0) => '0',
      gtwiz_reset_rx_datapath_in(0) => '0',
      gtwiz_reset_rx_cdr_stable_out(0) => gtwiz_reset_rx_cdr_stable_out, --gth_status_a(2),
      gtwiz_reset_tx_done_out(0) => gtwiz_reset_tx_done_in, --gth_status_a(3),
      gtwiz_reset_rx_done_out(0) => gtwiz_reset_rx_done_in, -- gth_status_a(4),
      gtwiz_userdata_tx_in => gth_tx_data_out,
      gtwiz_userdata_rx_out => gth_rx_data_in,

      qpll0clk_in(0) => qpll0_outclk,
      qpll0refclk_in(0) => qpll0_outrefclk,
      qpll1clk_in(0) => qpll1_outclk,
      qpll1refclk_in(0) => qpll1_outrefclk,

      txpllclksel_in => "11", --  11: QPLL0
      rx8b10ben_in(0) => '1',
      rxcommadeten_in(0) => '1',
      rxmcommaalignen_in(0) => '0',
      rxpcommaalignen_in(0) => '0',
      rxslide_in(0) => gth_rx_slide_out,
      tx8b10ben_in(0) => '1',
      txctrl0_in => x"0000",
      txctrl1_in => x"0000",
      txctrl2_in => gth_tx_k_out,
      gtpowergood_out(0) => gth_powergood,
      rxbyteisaligned_out(0) => gth_rx_byte_aligned_in,
      rxbyterealign_out => open,
      rxcommadet_out(0) => gth_rx_comma_det_in,
      rxctrl0_out => gth_rx_k_in,
      rxctrl1_out => open,
      rxctrl2_out => open,
      rxctrl3_out => open,
      rxpmaresetdone_out(0) => gth_rx_pma_reset_done_in,
      txpmaresetdone_out(0) => gth_tx_pma_reset_done_in,
      txprgdivresetdone_out(0) => gth_tx_prg_div_reset_done,
      rxpcsreset_in(0) => rx_bitslide_pcs_reset,

      txpippmen_in(0) => '1',
      txpippmovrden_in(0) => '0',
      txpippmsel_in(0) => '1',
      txpippmpd_in(0) => '0',
      txpippmstepsize_in => b"1_0001", -- txpippmstepsize, -- b"1_0000",

      drpaddr_in => (others => '0'),
      drpclk_in(0) => clk_62m5,
      drpdi_in => (others => '0'),
      drpdo_out   => open,
      drpen_in(0) => '0',
      drpwe_in(0) => '0',
      drprdy_out => open
  );

  phy_rst <= gth_rst or phy16_out.rst;
  inst_gthe4_adapter: entity work.wr_gthe4_adapter
    port map (
      tx_locked_o => open,
      tx_data_i => phy16_out.tx_data,
      tx_k_i => phy16_out.tx_k,
      tx_disparity_o => phy16_in.tx_disparity,
      tx_enc_err_o => phy16_in.tx_enc_err,
      rx_data_o => phy16_in.rx_data,
      rx_k_o => phy16_in.rx_k,
      rx_enc_err_o => phy16_in.rx_enc_err,
      rx_bitslide_o => phy16_in.rx_bitslide,
      rx_bitslide_pcs_reset => rx_bitslide_pcs_reset,
      rst_i => phy_rst,
      loopen_i => phy16_out.loopen_vec,
      rdy_o => phy16_in.rdy,
      gtwiz_userclk_tx_reset_o => gtwiz_userclk_tx_reset_out,
      gtwiz_userclk_tx_active_i => gtwiz_userclk_tx_active_in,
      gtwiz_userclk_rx_reset_o => gtwiz_userclk_rx_reset_out,
      gtwiz_userclk_rx_active_i => gtwiz_userclk_rx_active_in,
      gtwiz_buffbypass_tx_reset_o => gtwiz_buffbypass_tx_reset_out,
      gtwiz_buffbypass_tx_done_i => gtwiz_buffbypass_tx_done_in,
      gtwiz_buffbypass_tx_error_i => gtwiz_buffbypass_tx_error_in,
      gtwiz_buffbypass_rx_reset_o => gtwiz_buffbypass_rx_reset_out,
      gtwiz_buffbypass_rx_start_user_o => gtwiz_buffbypass_rx_start_user_out,
      gtwiz_buffbypass_rx_done_i => gtwiz_buffbypass_rx_done_in,
      gtwiz_buffbypass_rx_error_i => gtwiz_buffbypass_rx_error_in,
      gtwiz_reset_all_o => gtwiz_reset_all_out,
      gtwiz_reset_tx_done_i => gtwiz_reset_tx_done_in,
      gtwiz_reset_rx_done_i => gtwiz_reset_rx_done_in,
      gth_rx_data_i => gth_rx_data_in,
      gth_tx_data_o => gth_tx_data_out,
      gth_rx_slide_o => gth_rx_slide_out,
      gth_rx_k_i => gth_rx_k_in(1 downto 0),
      gth_tx_k_o => gth_tx_k_out(1 downto 0),
      gth_rx_byte_aligned_i => gth_rx_byte_aligned_in,
      gth_rx_comma_det_i => gth_rx_comma_det_in,
      gth_rx_pma_reset_done_i => gth_rx_pma_reset_done_in,
      gth_tx_pma_reset_done_i => gth_tx_pma_reset_done_in,
      gth_rx_clk_i => phy16_in.rx_clk,
      gth_tx_clk_i => phy16_in.ref_clk
    );

  inst_gth_helper: gthe4_sdm
    port map (
      gthrxn_in(0)  => helper_rxn_i,
      gthrxp_in(0)  => helper_rxp_i,
      gthtxn_out(0) => helper_txn_o,
      gthtxp_out(0) => helper_txp_o,

      gtwiz_userclk_tx_reset_in(0) => gtwiz_userclk_tx_reset_out,
      gtwiz_userclk_tx_srcclk_out => open,
      gtwiz_userclk_tx_usrclk_out => open,
      gtwiz_userclk_tx_usrclk2_out(0) => clk_dmtd,
      gtwiz_userclk_tx_active_out => open,
      gtwiz_userclk_rx_reset_in(0) => gtwiz_userclk_rx_reset_out,
      gtwiz_userclk_rx_srcclk_out => open,
      gtwiz_userclk_rx_usrclk_out => open,
      gtwiz_userclk_rx_usrclk2_out => open,
      gtwiz_userclk_rx_active_out => open,
      gtwiz_buffbypass_tx_reset_in(0) => gtwiz_buffbypass_tx_reset_out,
      gtwiz_buffbypass_tx_start_user_in(0) => '0',
      gtwiz_buffbypass_tx_done_out => open,
      gtwiz_buffbypass_tx_error_out => open,
      gtwiz_buffbypass_rx_reset_in(0) => gtwiz_buffbypass_rx_reset_out,
      gtwiz_buffbypass_rx_start_user_in => "0",
      gtwiz_buffbypass_rx_done_out => open,
      gtwiz_buffbypass_rx_error_out => open,

      gtwiz_reset_qpll0reset_out => open,
      gtwiz_reset_qpll0lock_in(0) => qpll_lock,
      gtwiz_reset_clk_freerun_in(0) => clk_62m5,
      gtwiz_reset_all_in(0) => gtwiz_reset_all_out,
      gtwiz_reset_tx_pll_and_datapath_in(0) => '0',
      gtwiz_reset_tx_datapath_in(0) => '0',
      gtwiz_reset_rx_pll_and_datapath_in(0) => '0',
      gtwiz_reset_rx_datapath_in(0) => '0',
      gtwiz_reset_rx_cdr_stable_out => open,
      gtwiz_reset_tx_done_out => open,
      gtwiz_reset_rx_done_out => open,
      gtwiz_userdata_tx_in => (others => '0'),
      gtwiz_userdata_rx_out => open,

      qpll0clk_in(0) => qpll0_outclk,
      qpll0refclk_in(0) => qpll0_outrefclk,
      qpll1clk_in(0) => qpll1_outclk,
      qpll1refclk_in(0) => qpll1_outrefclk,
      txpllclksel_in => "10", --  10: QPLL1

--      txsysclksel_in => "10", -- 10: QPLL0REFCLK 11:QPLL1REFCLK
--      txoutclkfabric_out(0) => clk_dmtd,
      rx8b10ben_in(0) => '1',
      rxcommadeten_in(0) => '1',
      rxmcommaalignen_in(0) => '0',
      rxpcommaalignen_in(0) => '0',
      rxslide_in(0) => '0',
      tx8b10ben_in(0) => '1',
      txctrl0_in => x"0000",
      txctrl1_in => x"0000",
      txctrl2_in => x"00",
      gtpowergood_out => open,
      rxbyteisaligned_out => open,
      rxbyterealign_out => open,
      rxcommadet_out => open,
      rxctrl0_out => open,
      rxctrl1_out => open,
      rxctrl2_out => open,
      rxctrl3_out => open,
      rxpmaresetdone_out => open,
      txpmaresetdone_out => open,
      txprgdivresetdone_out => open,
      rxpcsreset_in(0) => rx_bitslide_pcs_reset,

      txpippmen_in(0) => '0',
      txpippmovrden_in(0) => '0',
      txpippmpd_in(0) => '1',
      txpippmsel_in(0) => '0',
      txpippmstepsize_in => "00000",

      drpaddr_in  => (others => '0'),
      drpclk_in(0) => clk_62m5,
      drpdi_in    => (others => '0'),
      drpdo_out   => open,
      drpen_in(0) => '0',
      drpwe_in(0) => '0',
      drprdy_out  => open
  );

  phy16_in.sfp_los <= '0';
  phy16_in.rx_sampled_clk <= '0';

  --  Generate some outputs on PMOD

  process(phy16_in.ref_clk)
    variable cnt : natural range 0 to 4 := 0;
    variable v : std_logic := '0';
  begin
    if rising_edge(phy16_in.ref_clk) then
      if cnt = 4 then
        cnt := 0;
        pmod4_6_b <= v;
        v := not v;
      else
        cnt := cnt + 1;
      end if;
    end if;
  end process;

  process(phy16_in.rx_clk)
    variable cnt : natural range 0 to 4 := 0;
    variable v   : std_logic            := '0';
  begin
    if rising_edge(phy16_in.rx_clk) then
      if cnt = 4 then
        cnt := 0;
        pmod4_4_b <= v;
        v := not v;
      else
        cnt := cnt + 1;
      end if;
    end if;
  end process;
end top;