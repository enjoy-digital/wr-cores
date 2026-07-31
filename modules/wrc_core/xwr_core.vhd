-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2011 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : xwr_core.vhd
-- Author     : Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : CERN (BE-CO-HT)
-- Created    : 2011-02-02
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- WR PTP Core is a HDL module implementing a complete gigabit Ethernet
-- interface (MAC + PCS + PHY) with integrated PTP slave ordinary clock
-- compatible with White Rabbit protocol. It performs subnanosecond clock
-- synchronization via WR protocol and also acts as an Ethernet "gateway",
-- providing access to TX/RX interfaces of the built-in WR MAC.
--
-- Starting from version 2.0 all modules are interconnected with pipelined
-- wishbone interface (using wb crossbar and bus fanout). Separate pipelined
-- wishbone bus is used for passing packets between Endpoint, Mini-NIC
-- and External MAC interface.
--
-- The Core is composed of the CPU (which runs the software) and the
-- subsystem (which contains devices, endpoint, softpll, minic).
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

use work.wrcore_pkg.all;
use work.wishbone_pkg.all;
use work.endpoint_pkg.all;
use work.wr_fabric_pkg.all;
use work.softpll_pkg.all;
use work.wr_timecode_pkg.all;

entity xwr_core is
  generic(
    --if set to 1, then blocks in PCS use smaller calibration counter to speed
    --up simulation
    g_simulation                : integer                        := 0;
    -- set to false to reduce the number of information printed during simulation
    g_verbose                   : boolean                        := true;
    g_with_external_clock_input : boolean                        := true;
    g_ram_address_space_size_kb : integer                        := 128;        --  UNUSED
    g_board_name                : string                         := "NA  ";
    g_flash_secsz_kb            : integer                        := 256;        -- default for SVEC (M25P128)
    g_flash_sdbfs_baddr         : integer                        := 16#600000#; -- default for SVEC (M25P128)
    g_phys_uart                 : boolean                        := true;
    g_with_phys_uart_fifo       : boolean                        := false;
    g_phys_uart_tx_fifo_size    : integer                        := 1024;
    g_phys_uart_rx_fifo_size    : integer                        := 1024;
    g_virtual_uart              : boolean                        := true;
    g_aux_clks                  : integer                        := 0;
    g_ep_rxbuf_size            : integer                        := 1024;
    g_tx_runt_padding           : boolean                        := true;
    g_dpram_initf               : string                         := "";
    g_dpram_use_bram_macro      : boolean                        := false;
    g_dpram_size                : integer                        := 131072/4;  --in 32-bit words
    g_use_platform_specific_dpram        : boolean := FALSE;
    g_interface_mode            : t_wishbone_interface_mode      := PIPELINED;
    g_address_granularity       : t_wishbone_address_granularity := BYTE;
    g_aux_sdb                   : t_sdb_device                   := c_wrc_periph3_sdb;
    g_softpll_enable_debugger   : boolean                        := false;
    g_softpll_use_sampled_ref_clocks : boolean := false;
    g_softpll_reverse_dmtds : boolean := false;
    g_vuart_fifo_size           : integer                        := 1024;
    g_pcs_16bit                 : boolean                        := false;
    g_records_for_phy           : boolean                        := false;
    g_diag_id                   : integer                        := 0;
    g_diag_ver                  : integer                        := 0;
    g_diag_ro_size              : integer                        := 0;
    g_diag_rw_size              : integer                        := 0;
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
    -- Leave default if LockSweep is not implemented.
    -- When LockSweep is implemented, these signals are connected to one
    -- of the reference clock phase sampler modules found in directory
    -- wr_locksweep/. LockSweep signals are directly forwarded to the PPS
    -- generator memory map registers where they are read by wrpc-sw (with
    -- enabled LockSweep option).
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
    slave_i : in  t_wishbone_slave_in := cc_dummy_slave_in;
    slave_o : out t_wishbone_slave_out;

    aux_master_o : out t_wishbone_master_out;
    aux_master_i : in  t_wishbone_master_in := cc_dummy_master_in;

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
end xwr_core;

architecture struct of xwr_core is

  constant c_firmware_loaded : boolean := g_dpram_initf /= "" and g_dpram_initf /= "none";

  signal cpu_csr_wb_in  : t_wishbone_slave_in;
  signal cpu_csr_wb_out : t_wishbone_slave_out;

  -----------------------------------------------------------------------------
  --External WB interface
  -----------------------------------------------------------------------------
  signal ext_wb_in  : t_wishbone_slave_in;
  signal ext_wb_out : t_wishbone_slave_out;

  -- CPU
  signal softpll_irq : std_logic;

  signal cpu_dwb_out : t_wishbone_master_out;
  signal cpu_dwb_in : t_wishbone_master_in;
begin
  inst_subsystem: entity work.xwr_subsystem
    generic map (
      g_simulation => g_simulation,
      g_with_external_clock_input => g_with_external_clock_input,
      g_board_name => g_board_name,
      g_flash_secsz_kb => g_flash_secsz_kb,
      g_flash_sdbfs_baddr => g_flash_sdbfs_baddr,
      g_phys_uart => g_phys_uart,
      g_with_phys_uart_fifo => g_with_phys_uart_fifo,
      g_phys_uart_tx_fifo_size => g_phys_uart_tx_fifo_size,
      g_phys_uart_rx_fifo_size => g_phys_uart_rx_fifo_size,
      g_virtual_uart => g_virtual_uart,
      g_aux_clks => g_aux_clks,
      g_ep_rxbuf_size => g_ep_rxbuf_size,
      g_tx_runt_padding => g_tx_runt_padding,
      g_dpram_size => g_dpram_size,
      g_softpll_enable_debugger => g_softpll_enable_debugger,
      g_softpll_use_sampled_ref_clocks => g_softpll_use_sampled_ref_clocks,
      g_softpll_reverse_dmtds => g_softpll_reverse_dmtds,
      g_vuart_fifo_size => g_vuart_fifo_size,
      g_pcs_16bit => g_pcs_16bit,
      g_records_for_phy => g_records_for_phy,
      g_diag_id => g_diag_id,
      g_diag_ver => g_diag_ver,
      g_diag_ro_size => g_diag_ro_size,
      g_diag_rw_size => g_diag_rw_size,
      g_dac_bits => g_dac_bits,
      g_softpll_aux_channel_config => g_softpll_aux_channel_config,
      g_with_clock_freq_monitor => g_with_clock_freq_monitor,
      g_hwbld_date => g_hwbld_date,
      g_direct_tag => g_direct_tag,
      g_aux_timing_config => g_aux_timing_config
      )
    port map (
      clk_sys_i => clk_sys_i,
      clk_dmtd_i => clk_dmtd_i,
      clk_dmtd_over_i => clk_dmtd_over_i,
      clk_ref_i => clk_ref_i,
      clk_aux_i => clk_aux_i,
      clk_ext_i => clk_ext_i,
      clk_ext_mul_i => clk_ext_mul_i,
      clk_ext_mul_locked_i => clk_ext_mul_locked_i,
      clk_ext_stopped_i => clk_ext_stopped_i,
      clk_ext_rst_o => clk_ext_rst_o,
      lock_sweep_i => lock_sweep_i,
      lock_sweep_phase_i => lock_sweep_phase_i,
      pps_ext_i => pps_ext_i,
      rst_n_i => rst_n_i,
      direct_tag0_i => direct_tag0_i,
      direct_tag0_valid_i => direct_tag0_valid_i,
      dac_hpll_load_p1_o => dac_hpll_load_p1_o,
      dac_hpll_data_o => dac_hpll_data_o,
      dac_dpll_load_p1_o => dac_dpll_load_p1_o,
      dac_dpll_data_o => dac_dpll_data_o,
      phy_ref_clk_i => phy_ref_clk_i,
      phy_tx_data_o => phy_tx_data_o,
      phy_tx_k_o => phy_tx_k_o,
      phy_tx_disparity_i => phy_tx_disparity_i,
      phy_tx_enc_err_i => phy_tx_enc_err_i,
      phy_rx_data_i => phy_rx_data_i,
      phy_rx_rbclk_i => phy_rx_rbclk_i,
      phy_rx_rbclk_sampled_i => phy_rx_rbclk_sampled_i,
      phy_rx_k_i => phy_rx_k_i,
      phy_rx_enc_err_i => phy_rx_enc_err_i,
      phy_rx_bitslide_i => phy_rx_bitslide_i,
      phy_mdio_master_o => phy_mdio_master_o,
      phy_mdio_master_i => phy_mdio_master_i,
      phy_rst_o => phy_rst_o,
      phy_rdy_i => phy_rdy_i,
      phy_loopen_o => phy_loopen_o,
      phy_loopen_vec_o => phy_loopen_vec_o,
      phy_tx_prbs_sel_o => phy_tx_prbs_sel_o,
      phy_sfp_tx_fault_i => phy_sfp_tx_fault_i,
      phy_sfp_los_i => phy_sfp_los_i,
      phy_sfp_tx_disable_o => phy_sfp_tx_disable_o,
      phy8_o => phy8_o,
      phy8_i => phy8_i,
      phy16_o => phy16_o,
      phy16_i => phy16_i,
      led_act_o => led_act_o,
      led_link_o => led_link_o,
      scl_o => scl_o,
      scl_i => scl_i,
      sda_o => sda_o,
      sda_i => sda_i,
      sfp_scl_o => sfp_scl_o,
      sfp_scl_i => sfp_scl_i,
      sfp_sda_o => sfp_sda_o,
      sfp_sda_i => sfp_sda_i,
      sfp_det_i => sfp_det_i,
      btn1_i => btn1_i,
      btn2_i => btn2_i,
      spi_sclk_o => spi_sclk_o,
      spi_ncs_o => spi_ncs_o,
      spi_mosi_o => spi_mosi_o,
      spi_miso_i => spi_miso_i,
      uart_rxd_i => uart_rxd_i,
      uart_txd_o => uart_txd_o,
      owr_pwren_o => owr_pwren_o,
      owr_en_o => owr_en_o,
      owr_i => owr_i,
      wb_host_i => ext_wb_in,
      wb_host_o => ext_wb_out,
      wb_aux_master_o => aux_master_o,
      wb_aux_master_i => aux_master_i,
      wb_cpu_o => cpu_dwb_in,
      wb_cpu_i => cpu_dwb_out,
      softpll_irq_o => softpll_irq,
      wb_cpu_csr_i => cpu_csr_wb_out,
      wb_cpu_csr_o => cpu_csr_wb_in,
      wrf_src_o => wrf_src_o,
      wrf_src_i => wrf_src_i,
      wrf_snk_o => wrf_snk_o,
      wrf_snk_i => wrf_snk_i,
      timestamps_o => timestamps_o,
      timestamps_ack_i => timestamps_ack_i,
      abscal_txts_o => abscal_txts_o,
      abscal_rxts_o => abscal_rxts_o,
      fc_tx_pause_req_i => fc_tx_pause_req_i,
      fc_tx_pause_delay_i => fc_tx_pause_delay_i,
      fc_tx_pause_ready_o => fc_tx_pause_ready_o,
      tm_link_up_o => tm_link_up_o,
      tm_dac_value_o => tm_dac_value_o,
      tm_dac_wr_o => tm_dac_wr_o,
      tm_clk_aux_lock_en_i => tm_clk_aux_lock_en_i,
      tm_clk_aux_locked_o => tm_clk_aux_locked_o,
      tm_time_valid_o => tm_time_valid_o,
      tm_tai_o => tm_tai_o,
      tm_cycles_o => tm_cycles_o,
      pps_csync_o => pps_csync_o,
      pps_valid_o => pps_valid_o,
      pps_p_o => pps_p_o,
      pps_led_o => pps_led_o,
      rst_aux_n_o => rst_aux_n_o,
      aux_timing_serdes_locked_i => aux_timing_serdes_locked_i,
      utc_o => utc_o,
      aux_timing_o => aux_timing_o,
      aux_diag_i => aux_diag_i,
      aux_diag_o => aux_diag_o,
      link_ok_o => link_ok_o
      );

  U_CPU: entity work.wrc_urv_wrapper
    generic map (
      g_IRAM_SIZE => g_dpram_size,
      g_USE_BRAM_MACROS => g_dpram_use_bram_macro,
      g_IRAM_INIT => g_dpram_initf,
      g_CPU_ID => 0
      )
    port map (
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rst_n_i,
      irq_i        => softpll_irq,
      dwb_o        => cpu_dwb_out,
      dwb_i        => cpu_dwb_in,
      host_slave_i => cpu_csr_wb_in,
      host_slave_o => cpu_csr_wb_out
      );

  U_Adapter : entity work.wb_slave_adapter
    generic map(
      g_master_use_struct  => true,
      g_master_mode        => PIPELINED,
      g_master_granularity => BYTE,
      g_slave_use_struct   => true,
      g_slave_mode         => g_interface_mode,
      g_slave_granularity  => g_address_granularity)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      master_i   => ext_wb_out,
      master_o   => ext_wb_in,
      slave_i    => slave_i,
      slave_o    => slave_o);
end struct;
