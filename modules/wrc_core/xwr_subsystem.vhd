-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2011 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : xwr_subsystem.vhd
-- Author     : Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : CERN (BE-CO-HT)
-- Created    : 2011-02-02
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
--
-- The subsystem contains all the HDL block of the WR PTP Core except the
-- CPU.  They are interconnected through a wishbone bus.
-------------------------------------------------------------------------------
-- Memory map:
--      0x000: Minic
--      0x100: Endpoint
--      0x200: Softpll
--      0x300: PPS gen
--      0x400: Syscon  (periph 0)
--      0x500: UART    (periph 1)
--      0x600: OneWire (periph 2)
--      0x800: WRPC diagnostics registers (for user)     (periph 3)
--      0x900: WRPC diagnostics registers (for firmware) (periph 4)
--      0xa00: freq monitor
--      0xb00: cpu csr
--      0xc00: SDB
--      0x8000: Auxillary space (Etherbone config, etc)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wrcore_pkg.all;
use work.genram_pkg.all;
use work.wishbone_pkg.all;
use work.endpoint_pkg.all;
use work.wr_fabric_pkg.all;
use work.softpll_pkg.all;
use work.wr_timecode_pkg.all;
use work.gencores_pkg.all;

entity xwr_subsystem is
  generic(
    --if set to 1, then blocks in PCS use smaller calibration counter to speed 
    --up simulation
    g_simulation                : integer                        := 0;
    g_with_external_clock_input : boolean                        := true;
    g_board_name                : string                         := "NA  ";
    g_flash_secsz_kb            : integer                        := 256;        -- default for SVEC (M25P128)
    g_flash_sdbfs_baddr         : integer                        := 16#600000#; -- default for SVEC (M25P128)
    g_phys_uart                 : boolean                        := true;
    g_with_phys_uart_fifo       : boolean                        := false;
    g_phys_uart_tx_fifo_size    : integer                        := 1024;
    g_phys_uart_rx_fifo_size    : integer                        := 1024;
    g_virtual_uart              : boolean                        := true;
    g_aux_clks                  : integer                        := 0;
    g_ep_rxbuf_size             : integer                        := 1024;
    g_tx_runt_padding           : boolean                        := true;
    g_dpram_size                : integer                        := 131072/4;  --in 32-bit words
    g_softpll_enable_debugger   : boolean                        := false;
    g_softpll_use_sampled_ref_clocks : boolean := false;
    g_softpll_reverse_dmtds : boolean := false;
    g_vuart_fifo_size           : integer                        := 1024;
    g_pcs_16bit                 : boolean                        := false;
    g_records_for_phy           : boolean                        := false;
    g_keep_crc                  : boolean                        := false;
    g_diag_id                   : integer                        := 0;
    g_diag_ver                  : integer                        := 0;
    g_diag_ro_size              : integer                        := 0;
    g_diag_rw_size              : integer                        := 0;
    g_wdiags_num_words          : integer := 64;
    g_dac_bits                  : integer                        := 16;
    g_softpll_aux_channel_config : t_softpll_channels_config_array := c_softpll_default_channels_config;
    g_with_clock_freq_monitor   : boolean                        := true;
    g_hwbld_date                : std_logic_vector(31 downto 0)  := (others => 'X');
    g_direct_tag                : boolean                        := false;
    g_aux_timing_config         : t_wr_timecode_config           := c_WR_TIMECODE_NONE
    );
  port(
    ---------------------------------------------------------------------------
    -- Clocks/resets
    ---------------------------------------------------------------------------

    -- system reference clock (any frequency <= f(clk_ref_i))
    clk_sys_i : in std_logic;

    -- DDMTD offset clock (125.x MHz)
    clk_dmtd_i : in std_logic;
    clk_dmtd_over_i : in std_logic := '0';

    -- Timing reference (125 MHz)
    clk_ref_i : in std_logic;

    -- Aux clock (i.e. the FMC clock), which can be disciplined by the WR Core
    clk_aux_i : in std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');

    -- External 10 MHz reference (cesium, GPSDO, etc.), used in Grandmaster mode
    clk_ext_i : in std_logic := '0';

    --  External clocks (multipled to 125Mhz), only if g_with_external_clock_input
    --  This clock (ideally the 10Mhz multiplied through a PLL) is used to
    --  discipline the main clock in grand master mode.
    clk_ext_mul_i : in std_logic := '0';
    --  Status of the external clocks (for software, not used in HDL)
    clk_ext_mul_locked_i : in std_logic := '1';
    clk_ext_stopped_i    : in  std_logic := '0';
    --  Reset external clock
    clk_ext_rst_o        : out std_logic;

    -- LockSweep signals
    lock_sweep_i         : in std_logic := '0';
    lock_sweep_phase_i   : in std_logic_vector(15 downto 0) := (others => '0');

    -- External PPS input (cesium, GPSDO, etc.), used in Grandmaster mode
    pps_ext_i : in std_logic := '0';

    rst_n_i : in std_logic;

    --  Direct tag.
    --  Used only if g_direct_tag is true
    direct_tag0_i       : in std_logic_vector(23 downto 0) := (others => '0');
    direct_tag0_valid_i : in std_logic := '0';

    -----------------------------------------
    -- Timing system
    -- Set helper pll and main pll DAC values
    -----------------------------------------
    dac_hpll_load_p1_o : out std_logic;
    dac_hpll_data_o    : out std_logic_vector(g_dac_bits-1 downto 0);

    dac_dpll_load_p1_o : out std_logic;
    dac_dpll_data_o    : out std_logic_vector(g_dac_bits-1 downto 0);

    -----------------------------------------
    -- PHY I/f
    -----------------------------------------
    phy_ref_clk_i        : in std_logic := '0';

    phy_tx_data_o        : out std_logic_vector(f_pcs_data_width(g_pcs_16bit)-1 downto 0);
    phy_tx_k_o           : out std_logic_vector(f_pcs_k_width(g_pcs_16bit)-1 downto 0);
    phy_tx_disparity_i   : in  std_logic := '0';
    phy_tx_enc_err_i     : in  std_logic := '0';

    phy_rx_data_i        : in std_logic_vector(f_pcs_data_width(g_pcs_16bit)-1 downto 0) := (others => '0');
    phy_rx_rbclk_i       : in std_logic := '0';
    phy_rx_rbclk_sampled_i : in std_logic := '0';
    phy_rx_k_i           : in std_logic_vector(f_pcs_k_width(g_pcs_16bit)-1 downto 0) := (others => '0');
    phy_rx_enc_err_i     : in std_logic := '0';
    phy_rx_bitslide_i    : in std_logic_vector(f_pcs_bts_width(g_pcs_16bit)-1 downto 0) := (others => '0');

    phy_mdio_master_o : out t_wishbone_master_out;
    phy_mdio_master_i : in t_wishbone_master_in := cc_dummy_slave_out; 

    phy_rst_o            : out std_logic;
    phy_rdy_i            : in  std_logic := '1';
    phy_loopen_o         : out std_logic;
    phy_loopen_vec_o     : out std_logic_vector(2 downto 0);
    phy_tx_prbs_sel_o    : out std_logic_vector(2 downto 0);
    phy_sfp_tx_fault_i   : in std_logic := '0';
    phy_sfp_los_i        : in std_logic := '0';
    phy_sfp_tx_disable_o : out std_logic;
    -----------------------------------------
    -- PHY I/f - record-based
    -- selection done with g_records_for_phy
    -----------------------------------------
    phy8_o               : out t_phy_8bits_from_wrc;
    phy8_i               : in  t_phy_8bits_to_wrc  := c_dummy_phy8_to_wrc;
    phy16_o              : out t_phy_16bits_from_wrc;
    phy16_i              : in  t_phy_16bits_to_wrc := c_dummy_phy16_to_wrc;
   
    -----------------------------------------
    --GPIO
    -----------------------------------------
    led_act_o  : out std_logic;
    led_link_o : out std_logic;
    scl_o      : out std_logic;
    scl_i      : in  std_logic := '1';
    sda_o      : out std_logic;
    sda_i      : in  std_logic := '1';
    sfp_scl_o  : out std_logic;
    sfp_scl_i  : in  std_logic := '1';
    sfp_sda_o  : out std_logic;
    sfp_sda_i  : in  std_logic := '1';
    sfp_det_i  : in  std_logic;
    btn1_i     : in  std_logic := '1';
    btn2_i     : in  std_logic := '1';
    spi_sclk_o : out std_logic;
    spi_ncs_o  : out std_logic;
    spi_mosi_o : out std_logic;
    spi_miso_i : in  std_logic := '0';

    -----------------------------------------
    --UART
    -----------------------------------------
    uart_rxd_i : in  std_logic := '0';
    uart_txd_o : out std_logic;

    -----------------------------------------
    -- 1-wire
    -----------------------------------------
    owr_pwren_o : out std_logic_vector(1 downto 0);
    owr_en_o    : out std_logic_vector(1 downto 0);
    owr_i       : in  std_logic_vector(1 downto 0) := (others => '1');

    -----------------------------------------
    -- External WB interface (use clk_sys)
    -- The slave port allows an external master to access WR-core registers
    -- The aux_master port allows adding peripherals to the WR-core. You will
    --  need to also modify the software to handle them.
    -----------------------------------------
    wb_host_i : in  t_wishbone_slave_in := cc_dummy_slave_in;
    wb_host_o : out t_wishbone_slave_out;

    wb_aux_master_o : out t_wishbone_master_out;
    wb_aux_master_i : in  t_wishbone_master_in := cc_dummy_master_in;

    --  Bus for CPU
    wb_cpu_o : out t_wishbone_slave_out;
    wb_cpu_i : in  t_wishbone_slave_in;

    --  IRQ line for CPU
    softpll_irq_o : out std_logic;

    --  Debug interface for uRV
    wb_cpu_csr_i : in  t_wishbone_master_in;
    wb_cpu_csr_o : out t_wishbone_master_out;

    -----------------------------------------
    -- External Fabric I/F (use clk_sys)
    -----------------------------------------
    wrf_src_o : out t_wrf_source_out;
    wrf_src_i : in  t_wrf_source_in := c_dummy_src_in;
    wrf_snk_o : out t_wrf_sink_out;
    wrf_snk_i : in  t_wrf_sink_in   := c_dummy_snk_in;

    -----------------------------------------
    -- External Tx Timestamping I/F
    -----------------------------------------
    timestamps_o     : out t_txtsu_timestamp;
    timestamps_ack_i : in  std_logic := '1';

    -----------------------------------------
    -- Timestamp helper signals, used for Absolute Calibration
    -----------------------------------------
    abscal_txts_o       : out std_logic;
    abscal_rxts_o       : out std_logic;

    -----------------------------------------
    -- Pause Frame Control
    -----------------------------------------
    fc_tx_pause_req_i   : in  std_logic                     := '0';
    fc_tx_pause_delay_i : in  std_logic_vector(15 downto 0) := x"0000";
    fc_tx_pause_ready_o : out std_logic;

    -----------------------------------------
    -- Timecode/Servo Control (clk_sys)
    -----------------------------------------
    tm_link_up_o         : out std_logic;
    -- DAC Control (for auxilliary clocks)
    tm_dac_value_o       : out std_logic_vector(31 downto 0);
    tm_dac_wr_o          : out std_logic_vector(g_aux_clks-1 downto 0);
    -- Aux clock lock enable
    tm_clk_aux_lock_en_i : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
    -- Aux clock locked flag
    tm_clk_aux_locked_o  : out std_logic_vector(g_aux_clks-1 downto 0);

    -- Timecode output (clk_ref)
    tm_time_valid_o      : out std_logic;
    tm_tai_o             : out std_logic_vector(39 downto 0);
    tm_cycles_o          : out std_logic_vector(27 downto 0);

    -- 1PPS output (clk_ref)
    pps_csync_o          : out std_logic;
    pps_valid_o          : out std_logic;
    pps_p_o              : out std_logic;
    pps_led_o            : out std_logic;

    --  Resynchronized reset (clk_sys)
    rst_aux_n_o : out std_logic;

    -- Auxiliary Timing (clk_ref)
    aux_timing_serdes_locked_i  : in std_logic := '0';    --pll locked indicator from pll for platform specific serdes.  can be left unconnected if aux timing is not used
    utc_o                       : out t_utc_out;
    aux_timing_o                : out t_aux_timing_out;

    --  Auxillary diagnostics (used by snmp, clk_sys)
    aux_diag_i    : in  t_generic_word_array(g_diag_ro_size-1 downto 0) := (others =>(others=>'0'));
    aux_diag_o    : out t_generic_word_array(g_diag_rw_size-1 downto 0);

    link_ok_o : out std_logic
    );
end xwr_subsystem;

architecture struct of xwr_subsystem is
  function f_num_ext_clks return integer is
  begin
    if g_with_external_clock_input then
      return 1;
    else
      return 0;
    end if;
  end function;

  function f_board_name_conv(name : string(1 to 4)) return std_logic_vector is
    variable ret : std_logic_vector(31 downto 0);
  begin
    ret(31 downto 24) := std_logic_vector(to_unsigned(character'pos(name(1)), 8));
    ret(23 downto 16) := std_logic_vector(to_unsigned(character'pos(name(2)), 8));
    ret(15 downto  8) := std_logic_vector(to_unsigned(character'pos(name(3)), 8));
    ret( 7 downto  0) := std_logic_vector(to_unsigned(character'pos(name(4)), 8));
    return ret;
  end f_board_name_conv;

  constant c_board_name : std_logic_vector(31 downto 0) := f_board_name_conv(g_board_name);

  constant c_memsize : std_logic_vector(3 downto 0) :=
    std_logic_vector(to_unsigned(g_dpram_size * 4 / 1014 / 16 - 1, 4));
  -- *4     - to get size in bytes
  -- /1024  - to get size in kB
  -- /16 -1 - to get size in format of MEMSIZE@sysc_hwfr register

  constant c_storage_sec : std_logic_vector(15 downto 0) :=
    std_logic_vector(to_unsigned(g_flash_secsz_kb, 16));

  -----------------------------------------------------------------------------
  --Local resets for peripheral
  -----------------------------------------------------------------------------
  signal rst_net_n : std_logic;

  -----------------------------------------------------------------------------
  --Local resets (resynced)
  -----------------------------------------------------------------------------
  signal rst_net_resync_ref_n   : std_logic;
  signal rst_net_resync_ext_n   : std_logic;
  signal rst_net_resync_dmtd_n  : std_logic;
  signal rst_net_resync_rxclk_n : std_logic;
  signal rst_net_resync_txclk_n : std_logic;

  -----------------------------------------------------------------------------
  --PPS generator
  -----------------------------------------------------------------------------
  signal s_pps_csync : std_logic;
  signal pps_valid   : std_logic;
  signal ppsg_link_ok: std_logic;
  signal pps_pre     : std_logic;

  signal ppsg_wb_in  : t_wishbone_slave_in;
  signal ppsg_wb_out : t_wishbone_slave_out;

  -----------------------------------------------------------------------------
  --Timecode generator
  -----------------------------------------------------------------------------
  signal timecode_wb_in : t_wishbone_slave_in;
  signal timecode_wb_out : t_wishbone_slave_out;

  -----------------------------------------------------------------------------
  --Timing system
  -----------------------------------------------------------------------------
  signal phy_rx_clk  : std_logic;
  signal phy_tx_clk  : std_logic;
  signal clk_rx_sampled : std_logic;
  signal spll_wb_in  : t_wishbone_slave_in;
  signal spll_wb_out : t_wishbone_slave_out;

  -----------------------------------------------------------------------------
  --Endpoint
  -----------------------------------------------------------------------------
  signal ep_txtsu_port_id           : std_logic_vector(4 downto 0);
  signal ep_txtsu_frame_id          : std_logic_vector(15 downto 0);
  signal ep_txtsu_ts_value          : std_logic_vector(31 downto 0);
  signal ep_txtsu_ts_incorrect      : std_logic;
  signal ep_txtsu_stb, ep_txtsu_ack : std_logic;
  signal ep_led_link                : std_logic;
  signal my_mac_addr                : std_logic_vector(47 downto 0);

  signal phy_rst : std_logic;

  signal phy_loopen         : std_logic;
  signal phy_loopen_vec     : std_logic_vector(2 downto 0);
  signal phy_tx_data        : std_logic_vector(f_pcs_data_width(g_pcs_16bit)-1 downto 0);
  signal phy_tx_k           : std_logic_vector(f_pcs_k_width(g_pcs_16bit)-1 downto 0);
  signal phy_tx_prbs_sel    : std_logic_vector(2 downto 0);
  signal phy_sfp_tx_disable : std_logic;

  signal phy_tx_disparity : std_logic;
  signal phy_tx_enc_err   : std_logic;
  signal phy_rx_data      : std_logic_vector(f_pcs_data_width(g_pcs_16bit)-1 downto 0);
  signal phy_rx_k         : std_logic_vector(f_pcs_k_width(g_pcs_16bit)-1 downto 0);
  signal phy_rx_enc_err   : std_logic;
  signal phy_rx_bitslide  : std_logic_vector(f_pcs_bts_width(g_pcs_16bit)-1 downto 0);
  signal phy_rdy          : std_logic;
  signal phy_sfp_tx_fault : std_logic;
  signal phy_sfp_los      : std_logic;

  -----------------------------------------------------------------------------
  --Mini-NIC
  -----------------------------------------------------------------------------
  signal mnic_txtsu_ack  : std_logic;
  signal mnic_txtsu_stb  : std_logic;

  -----------------------------------------------------------------------------
  --WB Peripherials
  -----------------------------------------------------------------------------
  signal syscon_wb_in : t_wishbone_slave_in;
  signal syscon_wb_out : t_wishbone_slave_out;

  signal uart_wb_in : t_wishbone_slave_in;
  signal uart_wb_out : t_wishbone_slave_out;

  signal onewire_wb_in : t_wishbone_slave_in;
  signal onewire_wb_out : t_wishbone_slave_out;

  signal diags_cpu_wb_in : t_wishbone_slave_in;
  signal diags_cpu_wb_out : t_wishbone_slave_out;

  signal freqmon_wb_in : t_wishbone_slave_in;
  signal freqmon_wb_out : t_wishbone_slave_out;

  signal vuart_cpu_wb_in : t_wishbone_slave_in;
  signal vuart_cpu_wb_out : t_wishbone_slave_out;

  signal ep_wb_in  : t_wishbone_slave_in;
  signal ep_wb_out : t_wishbone_slave_out;

  signal minic_wb_in  : t_wishbone_slave_in;
  signal minic_wb_out : t_wishbone_slave_out;

  --attribute mark_debug : string;
  --attribute mark_debug of secbar_master_o : signal is "true";
  --attribute mark_debug of secbar_master_i : signal is "true";

  -----------------------------------------------------------------------------
  --External WB interface
  -----------------------------------------------------------------------------
  signal vuart_host_wb_in : t_wishbone_slave_in;
  signal vuart_host_wb_out : t_wishbone_slave_out;

  signal spll_host_wb_in : t_wishbone_slave_in;
  signal spll_host_wb_out : t_wishbone_slave_out;

  signal diags_usr_wb_in : t_wishbone_slave_in;
  signal diags_usr_wb_out : t_wishbone_slave_out;

  -----------------------------------------------------------------------------
  -- External Tx TSU interface
  -----------------------------------------------------------------------------

  signal ep_src_out, nic_src_out : t_wrf_source_out;
  signal ep_src_in,  nic_src_in  : t_wrf_source_in;
  signal ep_snk_out, nic_snk_out : t_wrf_sink_out;
  signal ep_snk_in,  nic_snk_in  : t_wrf_sink_in;

  signal spll_out_locked : std_logic_vector(g_aux_clks downto 0);

  signal dac_dpll_data    : std_logic_vector(g_dac_bits-1 downto 0);
  signal dac_dpll_sel     : std_logic_vector(3 downto 0);
  signal dac_dpll_load_p1 : std_logic;

  signal clk_out    : std_logic_vector(g_aux_clks downto 0);
  signal out_enable : std_logic_vector(g_aux_clks downto 0);
begin

  -----------------------------------------------------------------------------
  -- PHY TX/RX clock selection based on generics
  -----------------------------------------------------------------------------

  GEN_16BIT_PHY_IF: if g_pcs_16bit and g_records_for_phy generate
    phy16_o.rst            <= phy_rst;
    phy16_o.loopen         <= phy_loopen;
    phy16_o.loopen_vec     <= phy_loopen_vec;
    phy16_o.tx_data        <= phy_tx_data;
    phy16_o.tx_k           <= phy_tx_k;
    phy16_o.tx_prbs_sel    <= phy_tx_prbs_sel;
    phy16_o.sfp_tx_disable <= phy_sfp_tx_disable;

    phy_tx_clk       <= phy16_i.ref_clk;
    phy_tx_disparity <= phy16_i.tx_disparity;
    phy_tx_enc_err   <= phy16_i.tx_enc_err;
    phy_rx_data      <= phy16_i.rx_data;
    phy_rx_clk       <= phy16_i.rx_clk;
    clk_rx_sampled   <= phy16_i.rx_sampled_clk;
    phy_rx_k         <= phy16_i.rx_k;
    phy_rx_enc_err   <= phy16_i.rx_enc_err;
    phy_rx_bitslide  <= phy16_i.rx_bitslide;
    phy_rdy          <= phy16_i.rdy;
    phy_sfp_tx_fault <= phy16_i.sfp_tx_fault;
    phy_sfp_los      <= phy16_i.sfp_los;

    -- drive unused ports with dummy values
    phy8_o               <= c_dummy_phy8_from_wrc;
    phy_rst_o            <= '0';
    phy_loopen_o         <= '0';
    phy_tx_data_o        <= (others => '0');
    phy_tx_k_o           <= (others => '0');
    phy_loopen_vec_o     <= (others => '0');
    phy_tx_prbs_sel_o    <= (others => '0');
    phy_sfp_tx_disable_o <= '0';
  end generate;

  GEN_8BIT_PHY_IF: if not g_pcs_16bit and g_records_for_phy generate
    phy8_o.rst            <= phy_rst;
    phy8_o.loopen         <= phy_loopen;
    phy8_o.loopen_vec     <= phy_loopen_vec;
    phy8_o.tx_data        <= phy_tx_data;
    phy8_o.tx_k           <= phy_tx_k;
    phy8_o.tx_prbs_sel    <= phy_tx_prbs_sel;
    phy8_o.sfp_tx_disable <= phy_sfp_tx_disable;

    phy_tx_clk       <= phy8_i.ref_clk;
    clk_rx_sampled   <= phy8_i.rx_sampled_clk;
    phy_tx_disparity <= phy8_i.tx_disparity;
    phy_tx_enc_err   <= phy8_i.tx_enc_err;
    phy_rx_data      <= phy8_i.rx_data;
    phy_rx_clk       <= phy8_i.rx_clk;
    phy_rx_k         <= phy8_i.rx_k;
    phy_rx_enc_err   <= phy8_i.rx_enc_err;
    phy_rx_bitslide  <= phy8_i.rx_bitslide;
    phy_rdy          <= phy8_i.rdy;
    phy_sfp_tx_fault <= phy8_i.sfp_tx_fault;
    phy_sfp_los      <= phy8_i.sfp_los;

    -- drive unused ports with dummy values
    phy16_o              <= c_dummy_phy16_from_wrc;
    phy_rst_o            <= '0';
    phy_loopen_o         <= '0';
    phy_tx_data_o        <= (others => '0');
    phy_tx_k_o           <= (others => '0');
    phy_loopen_vec_o     <= (others => '0');
    phy_tx_prbs_sel_o    <= (others => '0');
    phy_sfp_tx_disable_o <= '0';
  end generate;

  GEN_STD_PHY_IF: if not g_records_for_phy generate
    phy_rst_o            <= phy_rst;
    phy_loopen_o         <= phy_loopen;
    phy_loopen_vec_o     <= phy_loopen_vec;
    phy_tx_data_o        <= phy_tx_data;
    phy_tx_k_o           <= phy_tx_k;
    phy_tx_prbs_sel_o    <= phy_tx_prbs_sel;
    phy_sfp_tx_disable_o <= phy_sfp_tx_disable;

    phy_tx_clk       <= phy_ref_clk_i;
    clk_rx_sampled   <= phy_rx_rbclk_sampled_i;
    phy_tx_disparity <= phy_tx_disparity_i;
    phy_tx_enc_err   <= phy_tx_enc_err_i;
    phy_rx_data      <= phy_rx_data_i;
    phy_rx_clk       <= phy_rx_rbclk_i;
    phy_rx_k         <= phy_rx_k_i;
    phy_rx_enc_err   <= phy_rx_enc_err_i;
    phy_rx_bitslide  <= phy_rx_bitslide_i;
    phy_rdy          <= phy_rdy_i;
    phy_sfp_tx_fault <= phy_sfp_tx_fault_i;
    phy_sfp_los      <= phy_sfp_los_i;

    -- drive unused ports with dummy values
    phy8_o  <= c_dummy_phy8_from_wrc;
    phy16_o <= c_dummy_phy16_from_wrc;
  end generate;

  -----------------------------------------------------------------------------
  -- Reset resync and distribution
  -----------------------------------------------------------------------------

  rst_aux_n_o <= rst_net_n;

  U_Sync_reset_refclk : entity work.gc_sync
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_ref_i,
      rst_n_a_i  => '1',
      d_i   => rst_net_n,
      q_o => rst_net_resync_ref_n);

  U_sync_reset_dmtd : entity work.gc_sync
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i     => clk_dmtd_i,
      rst_n_a_i => '1',
      d_i       => rst_net_n,
      q_o       => rst_net_resync_dmtd_n);

  U_sync_reset_ext : entity work.gc_sync
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i     => clk_ext_i,
      rst_n_a_i => '1',
      d_i       => rst_net_n,
      q_o       => rst_net_resync_ext_n);

  U_sync_reset_rxclk : entity work.gc_sync
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i     => phy_rx_clk,
      rst_n_a_i => '1',
      d_i       => rst_net_n,
      q_o       => rst_net_resync_rxclk_n);

  U_sync_reset_txclk : entity work.gc_sync
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i     => phy_tx_clk,
      rst_n_a_i => '1',
      d_i       => rst_net_n,
      q_o       => rst_net_resync_txclk_n);

  -----------------------------------------------------------------------------
  -- PPS generator
  -----------------------------------------------------------------------------
  PPS_GEN : entity work.xwr_pps_gen
    generic map(
      g_ref_clock_rate       => f_refclk_rate(g_pcs_16bit),
      g_ext_clock_rate       => 10000000,
      g_with_ext_clock_input => g_with_external_clock_input)
    port map(
      clk_ref_i => clk_ref_i,
      clk_sys_i => clk_sys_i,

      rst_sys_n_i => rst_net_n,
      rst_ref_n_i => rst_net_resync_ref_n,

      slave_i => ppsg_wb_in,
      slave_o => ppsg_wb_out,

      -- used for fast masking of PPS output when link goes down
      link_ok_i => ppsg_link_ok,

      -- Single-pulse PPS output for synchronizing endpoint to
      pps_in_i    => pps_ext_i,
      pps_csync_o => s_pps_csync,
      pps_out_o   => pps_p_o,
      pps_led_o   => pps_led_o,
      pps_pre_o   => pps_pre,
      pps_valid_o => pps_valid,

      ppsin_term_o => open,

      -- LockSweep signals
      lock_sweep_i       => lock_sweep_i,
      lock_sweep_phase_i => lock_sweep_phase_i,

      tm_utc_o        => tm_tai_o,
      tm_cycles_o     => tm_cycles_o,
      tm_time_valid_o => tm_time_valid_o
      );

  ppsg_link_ok <= ep_led_link;
  pps_csync_o  <= s_pps_csync;
  pps_valid_o  <= pps_valid;

  --------------------------------------
  -- Timecode generator
  --------------------------------------
  gen_aux_timing: if f_aux_timing_enabled(g_aux_timing_config) generate
  begin

    TIMECODE_GEN: entity work.wr_timecodes
      generic map (
        g_ref_clock_rate        => f_refclk_rate(g_pcs_16bit),
        g_serdes_data_width     => f_pcs_data_width(g_pcs_16bit)/2,
        g_timecode_config       => g_aux_timing_config
      )
      port map (

        clk_sys_i   => clk_sys_i,
        clk_ref_i   => clk_ref_i,
        rst_sys_n_i => rst_net_n,
        rst_ref_n_i => rst_net_resync_ref_n,

        wb_i        => timecode_wb_in,
        wb_o        => timecode_wb_out,

        pps_valid_i => pps_valid,
        pps_pre_i   => pps_pre,
        pps_i       => s_pps_csync,
        pll_serdes_locked_i => aux_timing_serdes_locked_i,

        utc_o        => utc_o,
        aux_timing_o => aux_timing_o
      );
  end generate gen_aux_timing;

  gen_without_aux_timing: if not f_aux_timing_enabled(g_aux_timing_config) generate

    timecode_wb_out <= (dat => (others => '0'),
                        stall => '0',
                        err => '0',
                        rty => '0',
                        ack => '1');

  end generate gen_without_aux_timing;

  -----------------------------------------------------------------------------
  -- Software PLL
  -----------------------------------------------------------------------------
  U_SOFTPLL : entity work.xwr_softpll_ng
    generic map(
      g_reverse_dmtds        => g_softpll_reverse_dmtds,
      g_divide_input_by_2    => not g_pcs_16bit and not g_softpll_reverse_dmtds,
      g_with_debug_fifo      => g_softpll_enable_debugger,
      g_tag_bits             => 22,
      g_dac_bits             => g_dac_bits,
      g_interface_mode       => PIPELINED,
      g_address_granularity  => BYTE,
      g_num_ref_inputs       => 1,
      g_num_outputs          => 1 + g_aux_clks,
      g_num_exts             => f_num_ext_clks,
      g_ref_clock_rate       => f_refclk_rate(g_pcs_16bit),
      g_use_sampled_ref_clocks => g_softpll_use_sampled_ref_clocks,
      g_direct_tag           => g_direct_tag,
      g_ext_clock_rate       => 10000000,
      g_aux_config => g_softpll_aux_channel_config)
    port map(
      clk_sys_i    => clk_sys_i,
      rst_sys_n_i  => rst_net_n,
      rst_ref_n_i  => rst_net_resync_ref_n,
      rst_ext_n_i  => rst_net_resync_ext_n,
      rst_dmtd_n_i => rst_net_resync_dmtd_n,

      -- Reference inputs (i.e. the RX clocks recovered by the PHYs)
      clk_ref_i(0) => phy_rx_clk,
      clk_ref_sampled_i(0) => clk_rx_sampled,
      -- Output clocks (i.e. main or aux oscillator)
      clk_out_i    => clk_out,
      -- DMTD Offset clock
      clk_dmtd_i   => clk_dmtd_i,
      clk_dmtd_over_i => clk_dmtd_over_i,

      clk_ext_i     => clk_ext_i,
      clk_ext_mul_i(0)     => clk_ext_mul_i,
      clk_ext_mul_locked_i => clk_ext_mul_locked_i,
      clk_ext_stopped_i    => clk_ext_stopped_i,
      clk_ext_rst_o        => clk_ext_rst_o,

      pps_csync_p1_i => s_pps_csync,
      pps_ext_a_i => pps_ext_i,

      direct_tag0_valid_i => direct_tag0_valid_i,
      direct_tag0_i       => direct_tag0_i,

      -- DMTD oscillator drive
      dac_dmtd_data_o => dac_hpll_data_o,
      dac_dmtd_load_o => dac_hpll_load_p1_o,

      -- Output channel DAC value
      dac_out_data_o => dac_dpll_data,  --: out std_logic_vector(15 downto 0);
      -- Output channel select (0 = channel 0, etc. )
      dac_out_sel_o  => dac_dpll_sel,   --for now use only one output
      dac_out_load_o => dac_dpll_load_p1,

      out_enable_i => out_enable,

      out_locked_o => spll_out_locked,

      slave_i => spll_wb_in,
      slave_o => spll_wb_out,

      int_o => softpll_irq_o,

      host_wb_i => spll_host_wb_in,
      host_wb_o => spll_host_wb_out,

      dbg_fifo_irq_o => open);

  clk_out(0)                      <= clk_ref_i;
  clk_out(g_aux_clks downto 1)    <= clk_aux_i;
  out_enable(0)                   <= '1';
  out_enable(g_aux_clks downto 1) <= tm_clk_aux_lock_en_i;

  dac_dpll_data_o    <= dac_dpll_data;
  dac_dpll_load_p1_o <= '1' when (dac_dpll_load_p1 = '1' and dac_dpll_sel = x"0") else '0';

  tm_dac_value_o <= (31 downto dac_dpll_data'length => '0') & dac_dpll_data;

  p_decode_dac_writes : process(dac_dpll_load_p1, dac_dpll_sel)
  begin
    for i in 0 to g_aux_clks-1 loop
      if dac_dpll_sel = std_logic_vector(to_unsigned(i+1, 4)) then
        tm_dac_wr_o(i) <= dac_dpll_load_p1;
      else
        tm_dac_wr_o(i) <= '0';
      end if;
    end loop;  -- i
  end process;

  locked_spll : if g_aux_clks > 0 generate
    tm_clk_aux_locked_o <= spll_out_locked(g_aux_clks downto 1);
  end generate;

  -----------------------------------------------------------------------------
  -- Endpoint
  -----------------------------------------------------------------------------
  U_Endpoint : entity work.xwr_endpoint
    generic map (
      g_interface_mode      => PIPELINED,
      g_address_granularity => BYTE,
      g_ep_idx              => 0,
      g_simulation          => f_int2bool(g_simulation),
      g_tx_runt_padding     => g_tx_runt_padding,
      g_pcs_16bit           => g_pcs_16bit,
      g_rx_buffer_size      => g_ep_rxbuf_size,
      g_keep_crc            => g_keep_crc,
      g_with_rx_buffer      => true,
      g_with_flow_control   => false,
      g_with_timestamper    => true,
      g_with_dpi_classifier => true,
      g_with_vlans          => false,
      g_with_rtu            => false,
      g_with_leds           => true,
      g_with_packet_injection => false,
      g_use_new_rxcrc       => true,
      g_use_new_txcrc       => false)
    port map (
      clk_ref_i      => clk_ref_i,
      clk_sys_i      => clk_sys_i,
      rst_sys_n_i    => rst_net_n,
      rst_ref_n_i    => rst_net_resync_ref_n,
      rst_txclk_n_i  => rst_net_resync_txclk_n,
      rst_rxclk_n_i  => rst_net_resync_rxclk_n,
      pps_csync_p1_i => s_pps_csync,
      pps_valid_i    => pps_valid,

      phy_rst_o            => phy_rst,
      phy_rdy_i            => phy_rdy,
      phy_loopen_o         => phy_loopen,
      phy_loopen_vec_o     => phy_loopen_vec,
      phy_tx_prbs_sel_o    => phy_tx_prbs_sel,
      phy_sfp_tx_fault_i   => phy_sfp_tx_fault,
      phy_sfp_los_i        => phy_sfp_los,
      phy_sfp_tx_disable_o => phy_sfp_tx_disable,
      phy_ref_clk_i        => phy_tx_clk,
      phy_tx_data_o        => phy_tx_data,
      phy_tx_k_o           => phy_tx_k,
      phy_tx_disparity_i   => phy_tx_disparity,
      phy_tx_enc_err_i     => phy_tx_enc_err,
      phy_rx_data_i        => phy_rx_data,
      phy_rx_clk_i         => phy_rx_clk,
      phy_rx_k_i           => phy_rx_k,
      phy_rx_enc_err_i     => phy_rx_enc_err,
      phy_rx_bitslide_i    => phy_rx_bitslide,

      phy_mdio_master_o => phy_mdio_master_o,
      phy_mdio_master_i => phy_mdio_master_i,

      src_o => ep_src_out,
      src_i => ep_src_in,
      snk_o => ep_snk_out,
      snk_i => ep_snk_in,

      txtsu_port_id_o      => ep_txtsu_port_id,
      txtsu_frame_id_o     => ep_txtsu_frame_id,
      txtsu_ts_value_o     => ep_txtsu_ts_value,
      txtsu_ts_incorrect_o => ep_txtsu_ts_incorrect,
      txtsu_stb_o          => ep_txtsu_stb,
      txtsu_ack_i          => ep_txtsu_ack,
      wb_i                 => ep_wb_in,
      wb_o                 => ep_wb_out,
      rmon_events_o        => open,
      txts_o               => abscal_txts_o,
      rxts_o               => abscal_rxts_o,
      fc_tx_pause_req_i    => fc_tx_pause_req_i,
      fc_tx_pause_delay_i  => fc_tx_pause_delay_i,
      fc_tx_pause_ready_o  => fc_tx_pause_ready_o,
      my_mac_addr_o        => my_mac_addr,
      led_link_o           => ep_led_link,
      led_act_o            => led_act_o,
      rtu_full_i           => open);

  led_link_o   <= ep_led_link;
  link_ok_o    <= ep_led_link;

  tm_link_up_o <= ep_led_link;

  -----------------------------------------------------------------------------
  -- Mini-NIC
  -----------------------------------------------------------------------------
  MINI_NIC : entity work.xwr_mini_nic
    generic map (
      g_tx_fifo_size         => 1024,
      g_rx_fifo_size         => 2048,
      g_buffer_little_endian => false)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_net_n,

      wb_i => minic_wb_in,
      wb_o => minic_wb_out,

      src_o => nic_snk_in,
      src_i => nic_snk_out,
      snk_o => nic_src_in,
      snk_i => nic_src_out,

      txtsu_port_id_i     => ep_txtsu_port_id,
      txtsu_frame_id_i    => ep_txtsu_frame_id,
      txtsu_tsval_i       => ep_txtsu_ts_value,
      txtsu_tsincorrect_i => ep_txtsu_ts_incorrect,
      txtsu_stb_i         => mnic_txtsu_stb,
      txtsu_ack_o         => mnic_txtsu_ack
    );

  -----------------------------------------------------------------------------
  -- WB Peripherials
  -----------------------------------------------------------------------------
  inst_syscon : entity work.wrc_syscon
    generic map(
      g_board_name      => c_board_name,
      g_flash_secsz_kb  => g_flash_secsz_kb,
      g_flash_sdbfs_baddr => g_flash_sdbfs_baddr,
      g_memsize         => c_memsize,
      g_diag_id         => g_diag_id,
      g_diag_ver        => g_diag_ver,
      g_diag_ro_size    => g_diag_ro_size,
      g_diag_rw_size    => g_diag_rw_size,
      g_hwbld_date      => g_hwbld_date)
    port map(
      clk_sys_i   => clk_sys_i,
      rst_n_i     => rst_n_i,

      syscon_wb_i => syscon_wb_in,
      syscon_wb_o => syscon_wb_out,

      rst_net_n_o => rst_net_n,

      scl_o       => scl_o,
      scl_i       => scl_i,
      sda_o       => sda_o,
      sda_i       => sda_i,
      sfp_scl_o   => sfp_scl_o,
      sfp_scl_i   => sfp_scl_i,
      sfp_sda_o   => sfp_sda_o,
      sfp_sda_i   => sfp_sda_i,
      sfp_det_i   => sfp_det_i,
      btn1_i      => btn1_i,
      btn2_i      => btn2_i,
      spi_sclk_o  => spi_sclk_o,
      spi_ncs_o   => spi_ncs_o,
      spi_mosi_o  => spi_mosi_o,
      spi_miso_i  => spi_miso_i,

      diag_array_in  => aux_diag_i,
      diag_array_out => aux_diag_o
      );


  --------------------------------------
  -- UART
  --------------------------------------
  UART : xwb_simple_uart
    generic map(
      g_with_virtual_uart   => g_virtual_uart,
      g_with_physical_uart  => g_phys_uart,
      g_interface_mode      => PIPELINED,
      g_address_granularity => BYTE,
      g_vuart_fifo_size     => g_vuart_fifo_size,
      g_WITH_PHYSICAL_UART_FIFO => g_with_phys_uart_fifo,
      g_TX_FIFO_SIZE => g_phys_uart_tx_fifo_size,
      g_RX_FIFO_SIZE => g_phys_uart_rx_fifo_size
      )
    port map(
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,

      -- Wishbone
      slave_i => uart_wb_in,
      slave_o => uart_wb_out,
      desc_o  => open,
      int_o   => open,

      uart_rxd_i => uart_rxd_i,
      uart_txd_o => uart_txd_o
      );

  inst_vuart: entity work.xwb_vuart
    generic map (
      g_fifo_size => g_vuart_fifo_size
    )
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i => rst_n_i,
      host_i => vuart_host_wb_in,
      host_o => vuart_host_wb_out,
      board_i => vuart_cpu_wb_in,
      board_o => vuart_cpu_wb_out
    );
  --------------------------------------
  -- 1-WIRE
  --------------------------------------
  ONEWIRE : xwb_onewire_master
    generic map(
      g_interface_mode      => PIPELINED,
      g_address_granularity => BYTE,
      g_num_ports           => 2,
      g_ow_btp_normal       => "5.0",
      g_ow_btp_overdrive    => "1.0"
      )
    port map(
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,

      -- Wishbone
      slave_i => onewire_wb_in,
      slave_o => onewire_wb_out,
      desc_o  => open,
      int_o   => open,

      owr_pwren_o => owr_pwren_o,
      owr_en_o => owr_en_o,
      owr_i    => owr_i
      );

  --------------------------------------
  -- WRPC Diags
  --------------------------------------

  -- access through WB (PCI/VME/application) to diagnostics of WRPC
  inst_diags_dpram: entity work.wrc_diags_dpram
    generic map(
      g_size => g_wdiags_num_words
    )
    port map(
      rst_n_i   => rst_n_i,
      clk_sys_i => clk_sys_i,

      slave_user_i   => diags_usr_wb_in,
      slave_user_o   => diags_usr_wb_out,

      slave_wrc_i    => diags_cpu_wb_in,
      slave_wrc_o    => diags_cpu_wb_out
    );

  inst_host_map: entity work.wrc_host_map
    port map (
      rst_n_i => rst_n_i,
      clk_i => clk_sys_i,
      wb_i => wb_host_i,
      wb_o => wb_host_o,
      endpoint_mach_i(31 downto 16) => x"0000",
      endpoint_mach_i(15 downto 0) => my_mac_addr(47 downto 32),
      endpoint_macl_i => my_mac_addr(31 downto 0),
      spll_i => spll_host_wb_out,
      spll_o => spll_host_wb_in,
      syscon_hwfr_memory_i => c_memsize,
      syscon_hwfr_STORAGE_SEC_i => c_storage_sec,
      syscon_hwir_i => c_board_name,
      vuart_i => vuart_host_wb_out,
      vuart_o => vuart_host_wb_in,
      wdiags_i => diags_usr_wb_out,
      wdiags_o => diags_usr_wb_in,
      cpu_i => wb_cpu_csr_i,
      cpu_o => wb_cpu_csr_o
      );

  -----------------------------------------------------------------------------
  -- WB Secondary Crossbar
  -----------------------------------------------------------------------------
  inst_wrc_map: entity work.wrc_devices_map
    port map (
      rst_n_i => rst_n_i,
      clk_i => clk_sys_i,
      wb_i => wb_cpu_i,
      wb_o => wb_cpu_o,
      minic_i => minic_wb_out,
      minic_o => minic_wb_in,
      endpoint_i => ep_wb_out,
      endpoint_o => ep_wb_in,
      softpll_i => spll_wb_out,
      softpll_o => spll_wb_in,
      ppsgen_i => ppsg_wb_out,
      ppsgen_o => ppsg_wb_in,
      syscon_i => syscon_wb_out,
      syscon_o => syscon_wb_in,
      uart_i => uart_wb_out,
      uart_o => uart_wb_in,
      vuart_i => vuart_cpu_wb_out,
      vuart_o => vuart_cpu_wb_in,
      onewire_i => onewire_wb_out,
      onewire_o => onewire_wb_in,
      timing_i => timecode_wb_out,
      timing_o => timecode_wb_in,
      wdiag_i => diags_cpu_wb_out,
      wdiag_o => diags_cpu_wb_in,
      freqmon_i => freqmon_wb_out,
      freqmon_o => freqmon_wb_in,
      aux_i     => wb_aux_master_i,
      aux_o     => wb_aux_master_o
    );

  -----------------------------------------------------------------------------
  -- WBP MUX
  -----------------------------------------------------------------------------
  U_WBP_Mux : entity work.xwrf_mux
    generic map(
      g_muxed_ports => 2)
    port map (
      clk_sys_i   => clk_sys_i,
      rst_n_i     => rst_net_n,
      ep_src_o    => ep_snk_in,
      ep_src_i    => ep_snk_out,
      ep_snk_o    => ep_src_in,
      ep_snk_i    => ep_src_out,
      mux_src_o(0) => nic_src_out,
      mux_src_o(1) => wrf_src_o,
      mux_src_i(0) => nic_src_in,
      mux_src_i(1) => wrf_src_i,
      mux_snk_o(0) => nic_snk_out,
      mux_snk_o(1) => wrf_snk_o,
      mux_snk_i(0) => nic_snk_in,
      mux_snk_i(1) => wrf_snk_i,
      mux_class_i(0) => x"0f",
      mux_class_i(1) => x"f0");

  -----------------------------------------------------------------------------
  -- External Tx Timestamping I/F
  -----------------------------------------------------------------------------
  timestamps_o.port_id(4 downto 0) <= ep_txtsu_port_id;
  timestamps_o.port_id(5) <= '0';
  timestamps_o.frame_id  <= ep_txtsu_frame_id;
  timestamps_o.tsval     <= ep_txtsu_ts_value;
  timestamps_o.incorrect <= ep_txtsu_ts_incorrect;

  -- ts goes to external I/F
  timestamps_o.stb       <= '1' when (ep_txtsu_stb = '1' and (ep_txtsu_frame_id /= x"0000")) else
                          '0';
  -- ts goes to minic
  mnic_txtsu_stb      <=  '1' when (ep_txtsu_stb = '1' and (ep_txtsu_frame_id  = x"0000")) else
                          '0';

  ep_txtsu_ack <= timestamps_ack_i or mnic_txtsu_ack;

  gen_with_clock_monitor : if g_with_clock_freq_monitor generate
    function f_count_freqmon_clocks return integer is
      variable cnt : integer;
    begin
      -- SYS + DMTD + REF + PHY RX Clock;
      cnt := 1 + 1 + 1 + 1;

      -- All Aux Clocks
      cnt := cnt + g_aux_clks;

      -- Ext clock input, if need be.
      if( g_with_external_clock_input ) then
        cnt := cnt + 1;
      end if;

      return cnt;
    end f_count_freqmon_clocks;

    constant c_NUM_FREQMON_CLOCKS: integer := f_count_freqmon_clocks;

    signal freqmon_in : std_logic_vector(c_NUM_FREQMON_CLOCKS - 1 downto 0);
  begin
    inst_clock_monitor: entity work.xwb_clock_monitor
      generic map (
        g_NUM_CLOCKS             => c_NUM_FREQMON_CLOCKS,
        g_CLK_SYS_FREQ           => c_WR_CORE_SYSTEM_CLOCK_FREQ_HZ,
        g_WITH_INTERNAL_TIMEBASE => true)
      port map (
        rst_n_i   => rst_n_i,
        clk_sys_i => clk_sys_i,
        clk_in_i  => freqmon_in,
        pps_p1_i  => '0',
        slave_i   => freqmon_wb_in,
        slave_o   => freqmon_wb_out);

    freqmon_in(0) <= clk_sys_i;
    freqmon_in(1) <= clk_dmtd_i;
    freqmon_in(2) <= clk_ref_i;
    freqmon_in(3) <= phy_rx_clk;

    gen_with_aux_clocks : if g_aux_clks > 0 generate
      freqmon_in( g_aux_clks + 4 - 1 downto 4 ) <= clk_aux_i(g_aux_clks-1 downto 0);
    end generate gen_with_aux_clocks;

    gen_with_ext_clock : if g_with_external_clock_input generate
      freqmon_in( g_aux_clks + 4 ) <= clk_ext_i;
    end generate gen_with_ext_clock;

  end generate gen_with_clock_monitor;

  gen_without_clock_monitor : if not g_with_clock_freq_monitor generate
    freqmon_wb_out <= (dat => (others => '0'),
                       stall => '0',
                       err => '0',
                       rty => '0',
                       ack => '1' );
  end generate gen_without_clock_monitor;
end struct;
