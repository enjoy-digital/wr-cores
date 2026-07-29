-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2023 Missing Link Electronics(missinglinkelectronics.com) - CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : WRPC Wrapper for ZC706
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : xwrc_board_zc706.vhd
-- Author(s)  : Frederik Pfautsch <frederik.pfautsch@missinglinkelectronics.com>
--              Oskar Szakinnis <oskar.szakinnis@missinglinkelectronics.com>
--              (based on work by Grzegorz Daniluk <grzegorz.daniluk@cern.ch>)
-- Company    : Missing Link Electronics
--              CERN (BE-CO-HT)
-- Created    : 2023-08-01
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level wrapper for WR PTP core including all the modules
-- needed to operate the core on the Xilinx ZC706 board.
-- ZC706: https://www.xilinx.com/products/boards-and-kits/ek-z7-zc706-g.html
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.gencores_pkg.all;
use work.wrcore_pkg.all;
use work.wishbone_pkg.all;
use work.etherbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.endpoint_pkg.all;
use work.streamers_pkg.all;
use work.wr_xilinx_pkg.all;
use work.wr_board_pkg.all;
use work.axi4_pkg.all;
use work.si570_wbgen2_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity xwrc_board_zc706 is
  generic(
    -- set to 1 to speed up some initialization processes during simulation
    g_simulation                : integer              := 0;
    -- Select whether to include external ref clock input
    g_with_external_clock_input : boolean              := TRUE;
    -- Replace external VXCOs with in-fabric tuning:
    --   * "mmcm": use the phase shift feature of MMCMs
    --   * "picxo": use the phase interpolator of GTX transceivers
    g_fabric_tuning_type        : string               := "mmcm";
    -- Number of aux clocks syntonized by WRPC to WR timebase
    g_aux_clks                  : integer              := 0;
    -- plain     = expose WRC fabric interface
    -- streamers = attach WRC streamers to fabric interface
    -- etherbone = attach Etherbone slave to fabric interface
    g_fabric_iface              : t_board_fabric_iface := plain;
    -- parameters configuration when g_fabric_iface = "streamers" (otherwise ignored)
    g_streamers_op_mode        : t_streamers_op_mode  := TX_AND_RX;
    g_tx_streamer_params       : t_tx_streamer_params := c_tx_streamer_params_defaut;
    g_rx_streamer_params       : t_rx_streamer_params := c_rx_streamer_params_defaut;
    -- memory initialisation file for embedded CPU
    g_dpram_initf               : string               := "default_xilinx";
    -- identification (id and ver) of the layout of words in the generic diag interface
    g_diag_id                   : integer              := 0;
    g_diag_ver                  : integer              := 0;
    -- size the generic diag interface
    g_diag_ro_size              : integer              := 0;
    g_diag_rw_size              : integer              := 0;
    g_dac_bits                  : integer              := 16;
    g_num_fmc_enable            : integer              := 2
    );
  port (
    ---------------------------------------------------------------------------
    -- Clocks/resets
    ---------------------------------------------------------------------------
    -- Reset input (active low, can be async)
    areset_n_i          : in  std_logic;
    -- Optional reset input active low with rising edge detection. Does not
    -- reset PLLs.
    areset_edge_n_i     : in  std_logic := '1';
    -- Clock inputs from the board
    clk_125m_gtp_n_i    : in  std_logic;
    clk_125m_gtp_p_i    : in  std_logic;
    -- Aux clocks, which can be disciplined by the WR Core
    clk_aux_i           : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
    -- 10MHz ext ref clock input (g_with_external_clock_input = TRUE)
    clk_10m_ext_i       : in  std_logic                               := '0';
    -- External PPS input (g_with_external_clock_input = TRUE)
    pps_ext_i           : in  std_logic                               := '0';
    -- 62.5MHz sys clock output
    clk_sys_62m5_o      : out std_logic;
    -- 125MHz ref clock output
    clk_ref_125m_o      : out std_logic;
    -- 125MHz main clock output
    clk_125m_main_o     : out std_logic;
    -- 10MHz clock output, derived from main 125 MHz
    clk_10m_o           : out std_logic;
    -- 200MHz clock input, for sys
    clk_200m_sit9102_i  : in std_logic;
    -- 200MHz clock input, for main reference
    clk_125m_si570_i    : in std_logic;
    -- active low reset outputs, synchronous to 62m5 and 125m clocks
    rst_sys_62m5_n_o    : out std_logic;
    rst_ref_125m_n_o    : out std_logic;
    
    ---------------------------------------------------------------------------
    -- SFP I/O for transceiver and SFP management info
    ---------------------------------------------------------------------------
    sfp_txp_o         : out std_logic;
    sfp_txn_o         : out std_logic;
    sfp_rxp_i         : in  std_logic;
    sfp_rxn_i         : in  std_logic;
    sfp_det_i         : in  std_logic := '1';
    sfp_sda_i         : in  std_logic := '0';
    sfp_sda_o         : out std_logic;
    sfp_sda_t         : out std_logic;
    sfp_scl_i         : in  std_logic := '0';
    sfp_scl_o         : out std_logic;
    sfp_scl_t         : out std_logic;
    sfp_rate_select_o : out std_logic;
    sfp_tx_fault_i    : in  std_logic := '0';
    sfp_tx_disable_o  : out std_logic;
    sfp_los_i         : in  std_logic := '0';

    ---------------------------------------------------------------------------
    -- I2C EEPROM
    ---------------------------------------------------------------------------
    eeprom_sda_i : in  std_logic := '0';
    eeprom_sda_o : out std_logic;
    eeprom_sda_t : out std_logic;
    eeprom_scl_i : in  std_logic := '0';
    eeprom_scl_o : out std_logic;
    eeprom_scl_t : out std_logic;

    ---------------------------------------------------------------------------
    -- Onewire interface
    ---------------------------------------------------------------------------
    thermo_id_i : in  std_logic := '0';
    thermo_id_o : out std_logic;
    thermo_id_t : out std_logic;

    -----------------------------------------
    -- FMC SW enable interface
    -----------------------------------------
    fmc_enable_o : out std_logic_vector(g_num_fmc_enable-1 downto 0);

   -----------------------------------------
    -- Si570 I2C interface
    -----------------------------------------
    si570_scl_t  : out std_logic;
    si570_scl_o  : out std_logic;
    si570_scl_i  : in  std_logic := '1';
    si570_sda_t  : out std_logic;
    si570_sda_o  : out std_logic;
    si570_sda_i  : in  std_logic := '1';

    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------
    uart0_rxd_i : in  std_logic := '0';
    uart0_txd_o : out std_logic;
    uart1_rxd_i : in  std_logic := '0';
    uart1_txd_o : out std_logic;

    ---------------------------------------------------------------------------
    -- Flash memory SPI interface
    ---------------------------------------------------------------------------
    flash_sclk_o : out std_logic;
    flash_ncs_o  : out std_logic;
    flash_mosi_o : out std_logic;
    flash_miso_i : in  std_logic := '0';

    ------------------------------------------
    -- Axi Slave Bus Interface S00_AXI
    ------------------------------------------
    -- aclk provided by this IP, wire to master!
    s00_axi_aclk_o  : out std_logic;
    s00_axi_aresetn : in  std_logic;
    s00_axi_awaddr  : in std_logic_vector(31 downto 0);
    s00_axi_awprot  : in  std_logic_vector(2 downto 0);
    s00_axi_awvalid : in  std_logic;
    s00_axi_awready : out std_logic;
    s00_axi_wdata   : in std_logic_vector(31 downto 0);
    s00_axi_wstrb   : in std_logic_vector(3 downto 0);
    s00_axi_wvalid  : in  std_logic;
    s00_axi_wready  : out std_logic;
    s00_axi_bresp   : out std_logic_vector(1 downto 0);
    s00_axi_bvalid  : out std_logic;
    s00_axi_bready  : in std_logic;
    s00_axi_araddr  : in std_logic_vector(31 downto 0);
    s00_axi_arprot  : in std_logic_vector(2 downto 0);
    s00_axi_arvalid : in std_logic;
    s00_axi_arready : out std_logic;
    s00_axi_rdata   : out std_logic_vector(31 downto 0);
    s00_axi_rresp   : out std_logic_vector(1 downto 0);
    s00_axi_rvalid  : out std_logic;
    s00_axi_rready  : in std_logic;
    s00_axi_rlast   : out std_logic;

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
    abscal_txts_o       : out std_logic;
    abscal_rxts_o       : out std_logic;

    ---------------------------------------------------------------------------
    -- Pause Frame Control
    ---------------------------------------------------------------------------
    fc_tx_pause_req_i   : in  std_logic                     := '0';
    fc_tx_pause_delay_i : in  std_logic_vector(15 downto 0) := x"0000";
    fc_tx_pause_ready_o : out std_logic;

    ---------------------------------------------------------------------------
    -- Timecode I/F
    ---------------------------------------------------------------------------
    tm_link_up_o    : out std_logic;
    tm_time_valid_o : out std_logic;
    tm_tai_o        : out std_logic_vector(39 downto 0);
    tm_cycles_o     : out std_logic_vector(27 downto 0);

    ---------------------------------------------------------------------------
    -- Buttons, LEDs and PPS output
    ---------------------------------------------------------------------------
    led_act_o  : out std_logic;
    led_link_o : out std_logic;
    btn1_i     : in  std_logic := '1';
    btn2_i     : in  std_logic := '1';
    -- 1PPS output
    pps_p_o    : out std_logic;
    pps_led_o  : out std_logic;
    -- Link ok indication
    link_ok_o  : out std_logic
    );

end entity xwrc_board_zc706;


architecture struct of xwrc_board_zc706 is

  impure function f_get_board_name
  return string is
    variable ret : string := "?706";
  begin
    case g_fabric_tuning_type is
      when "mmcm"  => ret := "X706";
      when "picxo" => ret := "P706";
    end case;
    return ret;
  end f_get_board_name;

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  -- PLLs, clocks
  signal clk_pll_62m5 : std_logic;
  signal clk_pll_125m : std_logic;
  signal clk_pll_dmtd : std_logic;
  signal pll_locked   : std_logic;
  signal clk_125m_62m5_locked : std_logic;
  signal clk_10m_main : std_logic;
  signal clk_pll_62m5_pll : std_logic;

  signal clk_200m_fb, clk_200m_fb_f : std_logic;
  signal clk_10m_fb, clk_10m_fb_f : std_logic;

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

  -- OneWire
  signal onewire_in : std_logic_vector(1 downto 0);
  signal onewire_en : std_logic_vector(1 downto 0);

  -- PHY
  signal phy16_to_wrc   : t_phy_16bits_to_wrc;
  signal phy16_from_wrc : t_phy_16bits_from_wrc;

  -- External reference
  signal ext_ref_mul         : std_logic;
  signal ext_ref_mul_locked  : std_logic;
  signal ext_ref_mul_stopped : std_logic;
  signal ext_ref_rst         : std_logic;

  -- GPIO for FMC enable
  signal enfmc_wb_in  : t_wishbone_slave_in;
  signal enfmc_wb_out : t_wishbone_slave_out;

  -- Si570
  signal si570_wb_in  : t_wishbone_slave_in;
  signal si570_wb_out : t_wishbone_slave_out;

  constant c_xwb_si5xx_sdb : t_sdb_device := (
    abi_class     => x"0000",              -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"01",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",
    sdb_component => (
    addr_first  => x"0000000000000000",
    addr_last   => x"00000000000000ff",
    product     => (
    vendor_id => x"000000000000CE42",  -- CERN TODO
    device_id => x"deadbee0",          -- TODO
    version   => x"00000001",
    date      => x"20240604",
    name      => "Si5xx              ")));

  -- Tertiary crossbar for board peripherals
  signal aux_master_out : t_wishbone_master_out;
  signal aux_master_in : t_wishbone_master_in := cc_dummy_master_in;

  signal tertbar_master_i : t_wishbone_master_in_array(1 downto 0);
  signal tertbar_master_o : t_wishbone_master_out_array(1 downto 0);

  constant c_tertbar_layout : t_sdb_record_array(1 downto 0) :=
    (0  => f_sdb_embed_device(c_xwb_gpio_port_sdb, x"00000000"),
     1  => f_sdb_embed_device(c_xwb_si5xx_sdb, x"00000100")
     --                     tertbar sdb            x"00000200"
   );

  constant c_tertbar_sdb_address : t_wishbone_address := x"00000200";
  constant c_tertbar_bridge_sdb  : t_sdb_bridge       :=
    f_xwb_bridge_layout_sdb(true, c_tertbar_layout, c_tertbar_sdb_address);

  -- WRC WB Slave interface
  signal wb_slave_out : t_wishbone_slave_out;
  signal wb_slave_in  : t_wishbone_slave_in;

  signal sfp_tx_disable_n : std_logic;
begin  -- architecture struct


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
      clk_i    => clk_pll_62m5,
      rst_n_i  => '1',
      data_i   => areset_edge_n_i,
      ppulse_o => areset_edge_ppulse);

  -- logic OR of all async reset sources (active high)
  rstlogic_arst <= (not pll_locked) or (not areset_n_i) or areset_edge_ppulse;

  -- concatenation of all clocks required to have synced resets
  rstlogic_clk_in(0)          <= clk_pll_62m5;
  rstlogic_clk_in(1)          <= clk_pll_125m;

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
  -- The WR PTP core with optional fabric interface attached
  -----------------------------------------------------------------------------
  cmp_board_common : entity work.xwrc_board_common
    generic map (
      g_simulation                => g_simulation,
      g_with_external_clock_input => g_with_external_clock_input,
      g_board_name                => f_get_board_name,
      g_phys_uart                 => TRUE,
      g_virtual_uart              => TRUE,
      g_aux_clks                  => g_aux_clks,
      g_ep_rxbuf_size             => 1024,
      g_tx_runt_padding           => TRUE,
      g_dpram_initf               => g_dpram_initf,
      g_dpram_use_bram_macro      => TRUE,
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
      g_streamers_op_mode         => g_streamers_op_mode,
      g_tx_streamer_params        => g_tx_streamer_params,
      g_rx_streamer_params        => g_rx_streamer_params,
      g_fabric_iface              => g_fabric_iface,
      g_dac_bits                  => g_dac_bits
      )
    port map (
      clk_sys_i            => clk_pll_62m5,
      clk_dmtd_i           => clk_pll_dmtd,
      clk_ref_i            => clk_pll_125m,
      clk_aux_i            => clk_aux_i,
      clk_10m_ext_i        => clk_10m_ext_i,
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
      scl_o                => eeprom_scl_t,
      scl_i                => eeprom_scl_i,
      sda_o                => eeprom_sda_t,
      sda_i                => eeprom_sda_i,
      sfp_scl_o            => sfp_scl_t,
      sfp_scl_i            => sfp_scl_i,
      sfp_sda_o            => sfp_sda_t,
      sfp_sda_i            => sfp_sda_i,
      sfp_det_i            => sfp_det_i,
      spi_sclk_o           => flash_sclk_o,
      spi_ncs_o            => flash_ncs_o,
      spi_mosi_o           => flash_mosi_o,
      spi_miso_i           => flash_miso_i,
      uart_rxd_i           => uart0_rxd_i,
      uart_txd_o           => uart0_txd_o,
      -- Onewire
      owr_pwren_o          => open,
      owr_en_o             => onewire_en,
      owr_i                => onewire_in,
      -- Wishbone interface
      wb_slave_i           => wb_slave_in,
      wb_slave_o           => wb_slave_out,
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
      fc_tx_pause_req_i    => fc_tx_pause_req_i,
      fc_tx_pause_delay_i  => fc_tx_pause_delay_i,
      fc_tx_pause_ready_o  => fc_tx_pause_ready_o,
      tm_link_up_o         => tm_link_up_o,
      tm_time_valid_o      => tm_time_valid_o,
      tm_tai_o             => tm_tai_o,
      tm_cycles_o          => tm_cycles_o,
      led_act_o            => led_act_o,
      led_link_o           => led_link_o,
      btn1_i               => btn1_i,
      btn2_i               => btn2_i,
      pps_p_o              => pps_p_o,
      pps_led_o            => pps_led_o,
      link_ok_o            => link_ok_o);

  cmp_board_crossbar : xwb_sdb_crossbar
    generic map(
      g_verbose     => TRUE,
      g_num_masters => 1,
      g_num_slaves  => 2,
      g_registered  => true,
      g_wraparound  => true,
      g_layout      => c_tertbar_layout,
      g_sdb_addr    => c_tertbar_sdb_address
      )
    port map(
      clk_sys_i  => clk_pll_62m5,
      rst_n_i    => rst_62m5_n,
      -- Master connections (INTERCON is a slave)
      slave_i(0) => aux_master_out,
      slave_o(0) => aux_master_in,
      -- Slave connections (INTERCON is a master)
      master_i   => tertbar_master_i,
      master_o   => tertbar_master_o
      );

  tertbar_master_i(0) <= enfmc_wb_out;
  enfmc_wb_in         <= tertbar_master_o(0);
  tertbar_master_i(1) <= si570_wb_out;
  si570_wb_in         <= tertbar_master_o(1);

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
      clk_sys_i         => clk_pll_62m5,
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
      clk_sys_i         => clk_pll_62m5,
      rst_n_i           => rst_62m5_n,

      scl_pad_oen_o     => si570_scl_t,
      sda_pad_oen_o     => si570_sda_t,
      scl_pad_i         => si570_scl_i,
      sda_pad_i         => si570_sda_i,

      slave_i           => si570_wb_in,
      slave_o           => si570_wb_out
    );

  sfp_rate_select_o <= '1';

  thermo_id_t <= '0' when onewire_en(0) = '1' else '1';
  thermo_id_o <= '0';
  onewire_in(0) <= thermo_id_i;
  onewire_in(1) <= '1';

  eeprom_sda_o <= '0';
  eeprom_scl_o <= '0';
  sfp_sda_o    <= '0';
  sfp_scl_o    <= '0';
  si570_sda_o  <= '0';
  si570_scl_o  <= '0';

  s00_axi_aclk_o <= clk_pll_62m5;
  clk_sys_62m5_o <= clk_pll_62m5;
  clk_ref_125m_o <= clk_pll_125m;

  --  the board invert the tx_disable signal.
  sfp_tx_disable_o <= not sfp_tx_disable_n;

  cmp_axi4lite_wbm: wb_axi4lite_bridge
    port map (
      clk_sys_i => clk_pll_62m5,
      rst_n_i   => s00_axi_aresetn,

      AWADDR  => s00_axi_awaddr, 
      AWVALID => s00_axi_awvalid,
      AWREADY => s00_axi_awready,
      WDATA   => s00_axi_wdata,
      WSTRB   => s00_axi_wstrb,
      WVALID  => s00_axi_wvalid,
      WREADY  => s00_axi_wready,
      WLAST   => '0',
      BRESP   => s00_axi_bresp,
      BVALID  => s00_axi_bvalid,
      BREADY  => s00_axi_bready,
      ARADDR  => s00_axi_araddr,
      ARVALID => s00_axi_arvalid,
      ARREADY => s00_axi_arready,
      RDATA   => s00_axi_rdata,
      RRESP   => s00_axi_rresp,
      RVALID  => s00_axi_rvalid,
      RREADY  => s00_axi_rready,
      RLAST   => s00_axi_rlast,

      wb_adr  => wb_slave_in.adr,
      wb_dat_m2s => wb_slave_in.dat,
      wb_sel => wb_slave_in.sel,
      wb_cyc => wb_slave_in.cyc,
      wb_stb => wb_slave_in.stb,
      wb_we  => wb_slave_in.we,

      wb_dat_s2m => wb_slave_out.dat,
      wb_err     => wb_slave_out.err,
      wb_rty     => wb_slave_out.rty,
      wb_ack     => wb_slave_out.ack,
      wb_stall   => wb_slave_out.stall
    );

  -- 200MHz clock of SiT9102 to 62.5MHz
  cmp_200m_clk_pll : MMCME2_ADV
    generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLKOUT4_CASCADE      => false,
        STARTUP_WAIT         => false,
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT_F      => 5.000,      -- 200.00 MHz -> 1 GHz
        CLKFBOUT_PHASE       => 0.000,
        CLKFBOUT_USE_FINE_PS => false,
        CLKOUT0_DIVIDE_F     => 16.000,     -- 1 GHz/16 -> 62.5 MHz
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKOUT0_USE_FINE_PS  => false,
        CLKIN1_PERIOD        => 5.000,     -- 5.000 ns for 200.00 MHz
        REF_JITTER1          => 0.005)
    port map (
        -- Output clocks
        CLKFBOUT     => clk_200m_fb,
        CLKOUT0      => clk_pll_62m5_pll,
        -- Input clock control
        CLKFBIN      => clk_200m_fb_f,
        CLKIN1       => clk_200m_sit9102_i,
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
        LOCKED       => clk_125m_62m5_locked,
        CLKINSTOPPED => open,
        CLKFBSTOPPED => open,
        PWRDWN       => '0',
        RST          => not areset_n_i);

  cmp_200m_clk_pll_fb : BUFG
    port map (
        O => clk_200m_fb_f,
        I => clk_200m_fb);

  -- 10MHz output clock buffer
  cmp_clk_main10_buf : BUFG
    port map (
      O => clk_10m_o,
      I => clk_10m_main);

  -- 62.5MHz sys clock buffer
  cmp_clk_sys_buf : BUFG
    port map (
      O => clk_pll_62m5,
      I => clk_pll_62m5_pll);

  cmp_10m_clk_pll : PLLE2_ADV
    generic map (
      BANDWIDTH            => "OPTIMIZED",
      STARTUP_WAIT         => "FALSE",
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT        => 16,
      CLKFBOUT_PHASE       => 0.000,
      CLKOUT0_DIVIDE       => 100,
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKIN1_PERIOD        => 16.000)    -- 16ns for 62.5 MHz
    port map (
      -- Output clocks
      CLKFBOUT     => clk_10m_fb,
      CLKOUT0      => clk_10m_main,
      -- Input clock control
      CLKFBIN      => clk_10m_fb_f,
      CLKIN1       => clk_pll_125m,
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
      -- Other control and status signals
      LOCKED       => open,
      PWRDWN       => '0',
      RST          => rstlogic_rst_out(1));

  -- feedback clock buffer
  cmp_clk_ref_picxo_buf : BUFG
    port map (
      O => clk_10m_fb_f,
      I => clk_10m_fb);

  gen_mmcm_7series_tuning_pll : if (g_fabric_tuning_type = "mmcm") generate
    signal clk_125m_dmtd_tuning_fb     : std_logic;
    signal clk_125m_dmtd_tuning_fb_f   : std_logic;
    signal clk_125m_dmtd_tuned         : std_logic;
    signal pll_dmtd_tuning_locked      : std_logic;

    signal clk_125m_main_tuning_fb     : std_logic;
    signal clk_125m_main_tuning_fb_f   : std_logic;
    signal clk_125m_main               : std_logic;
    signal pll_main_tuning_locked      : std_logic;

    signal dmtd_psdone                 : std_logic;
    signal dmtd_psen                   : std_logic;
    signal dmtd_psincdec               : std_logic;

    signal main_psdone                 : std_logic;
    signal main_psen                   : std_logic;
    signal main_psincdec               : std_logic;

    signal clk_62m5_dmtd_cleaning_fb   : std_logic;
    signal pll_dmtd_cleaning_locked    : std_logic;

    signal clk_200m_sit9102            : std_logic;
  begin
    -----------------------------------------------------------------------------
    -- Platform-dependent part (PHY, PLLs, buffers, etc)
    -----------------------------------------------------------------------------
    cmp_xwrc_platform : entity work.xwrc_platform_xilinx
      generic map (
        g_fpga_family               => "kintex7",
        g_with_external_clock_input => g_with_external_clock_input,
        g_use_default_plls          => FALSE,
        g_simulation                => g_simulation)
      port map (
        areset_n_i            => areset_n_i,
        clk_10m_ext_i         => clk_10m_ext_i,
        clk_125m_gtp_p_i      => clk_125m_gtp_p_i,
        clk_125m_gtp_n_i      => clk_125m_gtp_n_i,
        clk_62m5_sys_i        => clk_pll_62m5,
        clk_sys_locked_i      => clk_125m_62m5_locked,
        sfp_txn_o             => sfp_txn_o,
        sfp_txp_o             => sfp_txp_o,
        sfp_rxn_i             => sfp_rxn_i,
        sfp_rxp_i             => sfp_rxp_i,
        sfp_tx_fault_i        => sfp_tx_fault_i,
        sfp_los_i             => sfp_los_i,
        sfp_tx_disable_o      => sfp_tx_disable_n,
        clk_125m_ref_o        => clk_pll_125m,
        pll_locked_o          => open,
        phy16_o               => phy16_to_wrc,
        phy16_i               => phy16_from_wrc,
        ext_ref_rst_i         => ext_ref_rst);

    -- We need sys_clk (and thus the processor) to run uninterrupted to
    -- set the GT ref clk properly. Thus resetting the core because some
    -- stuff happened (e.g. dmtd mmcm losing lock) does not help here.
    -- The sys clk tree must be independent of the phys in the platform.
    pll_locked <= '1';

    -- 200MHz input clock buffer
    cmp_clk_200m_buf : BUFG
      port map (
        O => clk_200m_sit9102,
        I => clk_200m_sit9102_i);

    -- DAC to Dynamic Phase Shift converter for dmtd clock
    -- Scales down MMCM pulling range of ~297 ppm to ~+-114 ppm
    cmp_dmtd_ps_gen : entity work.ps_gen
      generic map(
        WIDTH => g_dac_bits,
        DIV   => 16,
        MULT  => 7)
      port map (
        pswidth => dac_hpll_data,
        pswidth_set => dac_hpll_load_p1,
        pswidth_clk => clk_pll_62m5,

        psclk => clk_200m_sit9102,
        psdone => dmtd_psdone,
        psen => dmtd_psen,
        psincdec => dmtd_psincdec);

    -- DAC to Dynamic Phase Shift converter for main clock
    -- Scales down MMCM pulling range of ~297 ppm to ~+-114 ppm
    cmp_main_ps_gen : entity work.ps_gen
      generic map(
        WIDTH => g_dac_bits,
        DIV   => 16,
        MULT  => 7)
      port map (
        pswidth => dac_dpll_data,
        pswidth_set => dac_dpll_load_p1,
        pswidth_clk => clk_pll_62m5,

        psclk => clk_200m_sit9102,
        psdone => main_psdone,
        psen => main_psen,
        psincdec => main_psincdec);

    -- DMTD tuning PLL (125MHz)
    cmp_dmtd_tuning_clk_pll : MMCME2_ADV
      generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLKOUT4_CASCADE      => false,
        STARTUP_WAIT         => false,
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT_F      => 8.000,      -- 125 MHz -> 1 GHz
        CLKFBOUT_PHASE       => 0.000,
        CLKFBOUT_USE_FINE_PS => false,
        CLKOUT0_DIVIDE_F     => 8.000,      -- 1GHz/8 -> 125 MHz
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKOUT0_USE_FINE_PS  => true,
        CLKIN1_PERIOD        => 8.000)      -- 8.0ns for 125 MHz
      port map (
        -- Output clocks
        CLKFBOUT     => clk_125m_dmtd_tuning_fb,
        CLKOUT0      => clk_125m_dmtd_tuned,
        -- Input clock control
        CLKFBIN      => clk_125m_dmtd_tuning_fb_f,
        CLKIN1       => clk_125m_si570_i,
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
        PSCLK        => clk_200m_sit9102,
        PSEN         => dmtd_psen,
        PSINCDEC     => dmtd_psincdec,
        PSDONE       => dmtd_psdone,
        -- Other control and status signals
        LOCKED       => pll_dmtd_tuning_locked,
        CLKINSTOPPED => open,
        CLKFBSTOPPED => open,
        PWRDWN       => '0',
        RST          => phy16_from_wrc.rst);

    cmp_dmtd_tuning_clk_pll_fb : BUFG
      port map (
        O => clk_125m_dmtd_tuning_fb_f,
        I => clk_125m_dmtd_tuning_fb);

    -- DMTD cleaning PLL (62.5MHz)
    -- Also divide by 2 for DMTD clock
    cmp_dmtd_cleaning_clk_pll : PLLE2_ADV
      generic map (
        BANDWIDTH            => "OPTIMIZED",
        STARTUP_WAIT         => "FALSE",
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT        => 7,
        CLKFBOUT_PHASE       => 0.000,
        CLKOUT0_DIVIDE       => 14,
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKIN1_PERIOD        => 8.000)    -- 8ns for 125 MHz
      port map (
        -- Output clocks
        CLKFBOUT     => clk_62m5_dmtd_cleaning_fb,
        CLKOUT0      => clk_pll_dmtd,
        -- Input clock control
        CLKFBIN      => clk_62m5_dmtd_cleaning_fb,
        CLKIN1       => clk_125m_dmtd_tuned,
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
        -- Other control and status signals
        LOCKED       => pll_dmtd_cleaning_locked,
        PWRDWN       => '0',
        RST          => not pll_dmtd_tuning_locked);

    -- Main tuning PLL (125MHz)
    cmp_main_tuning_clk_pll : MMCME2_ADV
      generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLKOUT4_CASCADE      => false,
        STARTUP_WAIT         => false,
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT_F      => 8.000,      -- 125 MHz -> 1 GHz
        CLKFBOUT_PHASE       => 0.000,
        CLKFBOUT_USE_FINE_PS => false,
        CLKOUT0_DIVIDE_F     => 8.000,      -- 1GHz/8 -> 125 MHz
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKOUT0_USE_FINE_PS  => true,
        CLKIN1_PERIOD        => 8.000)      -- 8.0ns for 125 MHz
      port map (
        -- Output clocks
        CLKFBOUT     => clk_125m_main_tuning_fb,
        CLKOUT0      => clk_125m_main,
        -- Input clock control
        CLKFBIN      => clk_125m_main_tuning_fb_f,
        CLKIN1       => clk_125m_si570_i,
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
        PSCLK        => clk_200m_sit9102,
        PSEN         => main_psen,
        PSINCDEC     => main_psincdec,
        PSDONE       => main_psdone,
        -- Other control and status signals
        LOCKED       => pll_main_tuning_locked,
        CLKINSTOPPED => open,
        CLKFBSTOPPED => open,
        PWRDWN       => '0',
        RST          => '0');

    cmp_main_tuning_clk_pll_fb : BUFG
      port map (
        O => clk_125m_main_tuning_fb_f,
        I => clk_125m_main_tuning_fb);

    -- Tuned & cleaned Main PLL 125 MHz output clock buffer
    cmp_clk_main_tuned_cleaned_buf : BUFG
      port map (
        O => clk_125m_main_o,
        I => clk_125m_main);

    -- External 10MHz reference PLL for Kintex7
    gen_kintex7_artix7_ext_ref_pll : if (g_with_external_clock_input = TRUE) generate

      signal clk_ext_fbi : std_logic;
      signal clk_ext_fbo : std_logic;
      signal clk_ext_buf : std_logic;
      signal clk_ext_mul : std_logic;
      signal pll_ext_rst : std_logic;

    begin
      mmcm_adv_inst : MMCME2_ADV
        generic map (
          BANDWIDTH            => "OPTIMIZED",
          CLKOUT4_CASCADE      => FALSE,
          STARTUP_WAIT         => FALSE,
          DIVCLK_DIVIDE        => 1,
          CLKFBOUT_MULT_F      => 62.500,
          CLKFBOUT_PHASE       => 0.000,
          CLKFBOUT_USE_FINE_PS => FALSE,
          CLKOUT0_DIVIDE_F     => 10.000,
          CLKOUT0_PHASE        => 0.000,
          CLKOUT0_DUTY_CYCLE   => 0.500,
          CLKOUT0_USE_FINE_PS  => FALSE,
          CLKIN1_PERIOD        => 100.000,
          REF_JITTER1          => 0.005)
        port map (
          -- Output clocks
          CLKFBOUT  => clk_ext_fbo,
          CLKOUT0   => clk_ext_mul,
          -- Input clock control
          CLKFBIN   => clk_ext_fbi,
          CLKIN1    => clk_ext_buf,
          CLKIN2    => '0',
          -- Tied to always select the primary input clock
          CLKINSEL  => '1',
          -- Ports for dynamic reconfiguration
          DADDR     => (others => '0'),
          DCLK      => '0',
          DEN       => '0',
          DI        => (others => '0'),
          DO        => open,
          DRDY      => open,
          DWE       => '0',
          -- Ports for dynamic phase shift
          PSCLK     => '0',
          PSEN      => '0',
          PSINCDEC  => '0',
          PSDONE    => open, -- Other control and status signals
          LOCKED    => ext_ref_mul_locked,
          CLKINSTOPPED => ext_ref_mul_stopped,
          CLKFBSTOPPED => open,
          PWRDWN   => '0',
          RST      => pll_ext_rst);

      -- External reference feedback buffer
      cmp_clk_ext_buf_fb : BUFG
        port map (
          O => clk_ext_fbi,
          I => clk_ext_fbo);

      -- External reference input buffer
      cmp_clk_ext_buf_i : BUFG
        port map (
          O => clk_ext_buf,
          I => clk_10m_ext_i);

      -- External reference output buffer
      cmp_clk_ext_buf_o : BUFG
        port map (
          O => ext_ref_mul,
          I => clk_ext_mul);

      cmp_extend_ext_reset : gc_extend_pulse
        generic map (
          g_width => 1000)
        port map (
          clk_i      => clk_pll_62m5,
          rst_n_i    => clk_125m_62m5_locked,
          pulse_i    => ext_ref_rst,
          extended_o => pll_ext_rst);

    end generate gen_kintex7_artix7_ext_ref_pll;

  end generate gen_mmcm_7series_tuning_pll;

end architecture struct;
