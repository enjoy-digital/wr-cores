-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2011 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core peripherials
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wrc_syscon.vhd
-- Author     : Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : CERN (BE-CO-HT)
-- Created    : 2011-04-04
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wrcore_pkg.all;
use work.wishbone_pkg.all;
use work.wrc_syscon_map_pkg.all;

entity wrc_syscon is
  generic(
    g_board_name        : std_logic_vector(31 downto 0);
    g_flash_secsz_kb    : integer := 256;        -- default for SVEC (M25P128)
    g_flash_sdbfs_baddr : integer := 16#600000#; -- default for SVEC (M25P128)
    g_cntr_period       : integer := 62500;
    g_memsize           : std_logic_vector(3 downto 0);
    g_diag_id           : integer := 0;
    g_diag_ver          : integer := 0;
    g_diag_ro_size      : integer := 0;
    g_diag_rw_size      : integer := 0;
    g_hwbld_date        : std_logic_vector(31 downto 0));
  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    syscon_wb_i : in  t_wishbone_slave_in;
    syscon_wb_o : out t_wishbone_slave_out;

    rst_net_n_o : out std_logic;

    --  GPIOs
    scl_o       : out std_logic;
    scl_i       : in  std_logic;
    sda_o       : out std_logic;
    sda_i       : in  std_logic;
    sfp_scl_o   : out std_logic;
    sfp_scl_i   : in  std_logic;
    sfp_sda_o   : out std_logic;
    sfp_sda_i   : in  std_logic;
    sfp_det_i   : in  std_logic;
    btn1_i      : in  std_logic;
    btn2_i      : in  std_logic;
    spi_sclk_o  : out std_logic;
    spi_ncs_o   : out std_logic;
    spi_mosi_o  : out std_logic;
    spi_miso_i  : in  std_logic;

    -- optional diagnostics from external HDL modules
    diag_array_in  : in  t_generic_word_array(g_diag_ro_size-1 downto 0) := (others=>(others=>'0'));
    diag_array_out : out t_generic_word_array(g_diag_rw_size-1 downto 0)
    );
end wrc_syscon;

architecture struct of wrc_syscon is
  signal sysc_regs_i : t_sysc_regs_master_in;
  signal sysc_regs_o : t_sysc_regs_master_out;

  signal cntr_div      : unsigned(23 downto 0);
  signal cntr_tics     : unsigned(31 downto 0);
  signal cntr_overflow : std_logic;

  signal diag_dat : std_logic_vector(31 downto 0);
  signal diag_out_regs : t_generic_word_array(g_diag_rw_size - 1 downto 0);
  signal diag_in       : t_generic_word_array(g_diag_ro_size + g_diag_rw_size-1 downto 0);

  constant c_RESET_CHAIN_LENGTH : integer := 3;

  signal rst_net_n : std_logic;
  signal rst_net_n_chain : std_logic_vector(c_RESET_CHAIN_LENGTH -1 downto 0);

begin

  -- async assert, sync de-assert reset.
  process(clk_sys_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      rst_net_n_chain <= (others => '0');
    elsif rising_edge(clk_sys_i) then
      rst_net_n_chain <= rst_net_n & rst_net_n_chain(c_RESET_CHAIN_LENGTH-1 downto 1);
    end if;
  end process;

  rst_net_n_o <= rst_net_n_chain(0);

  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        rst_net_n <= '0';
      elsif sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_net_rst = '1' then
        rst_net_n <= '0';
      else
        rst_net_n <= '1';
      end if;
    end if;
  end process;

  -------------------------------------
  -- buttons
  -------------------------------------
  sysc_regs_i.gpsr_btn1 <= btn1_i;
  sysc_regs_i.gpsr_btn2 <= btn2_i;

  -------------------------------------
  -- MEMSIZE
  -------------------------------------
  sysc_regs_i.hwfr_memsize <= g_memsize;

  -------------------------------------
  -- BOARD NAME and Flash info
  -------------------------------------
  sysc_regs_i.hwir_name         <= g_board_name;
  sysc_regs_i.hwfr_storage_sec  <= std_logic_vector(to_unsigned(g_flash_secsz_kb, 16));
  sysc_regs_i.hwfr_storage_type <= "00";  -- for now these parameters are only for Flash
  sysc_regs_i.sdbfs_baddr       <= std_logic_vector(to_unsigned(g_flash_sdbfs_baddr, 32));

  -------------------------------------
  -- TIMER
  -------------------------------------
  sysc_regs_i.tvr      <= std_logic_vector(cntr_tics);

  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        cntr_div      <= (others => '0');
        cntr_overflow <= '0';
      elsif sysc_regs_o.tcr_enable = '1' then
        if(cntr_div = g_cntr_period-1) then
          cntr_div      <= (others => '0');
          cntr_overflow <= '1';
        else
          cntr_div      <= cntr_div + 1;
          cntr_overflow <= '0';
        end if;
      end if;
    end if;
  end process;

  --msec counter
  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        cntr_tics <= (others => '0');
      elsif(cntr_overflow = '1') then
        cntr_tics <= cntr_tics + 1;
      end if;
    end if;
  end process;

  -------------------------------------
  -- I2C - FMC
  -------------------------------------
  p_drive_i2c : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        scl_o <= '1';
        sda_o <= '1';
      else
        if sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_fmc_sda = '1' then
          sda_o <= '1';
        elsif sysc_regs_o.gpcr_wr = '1' and sysc_regs_o.gpcr_fmc_sda = '1' then
          sda_o <= '0';
        end if;

        if sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_fmc_scl = '1' then
          scl_o <= '1';
        elsif sysc_regs_o.gpcr_wr = '1' and sysc_regs_o.gpcr_fmc_scl = '1' then
          scl_o <= '0';
        end if;
      end if;
    end if;
  end process;

  sysc_regs_i.gpsr_fmc_sda <= sda_i;
  sysc_regs_i.gpsr_fmc_scl <= scl_i;

  -------------------------------------
  -- I2C - SFP
  -------------------------------------
  p_drive_sfp1_i2c : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        sfp_scl_o <= '1';
        sfp_sda_o <= '1';
      else
        if sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_sfp1_sda = '1' then
          sfp_sda_o <= '1';
        elsif sysc_regs_o.gpcr_wr = '1' and sysc_regs_o.gpcr_sfp1_sda = '1' then
          sfp_sda_o <= '0';
        end if;

        if sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_sfp1_scl = '1' then
          sfp_scl_o <= '1';
        elsif sysc_regs_o.gpcr_wr = '1' and sysc_regs_o.gpcr_sfp1_scl = '1' then
          sfp_scl_o <= '0';
        end if;
      end if;
    end if;
  end process;

  sysc_regs_i.gpsr_sfp1_sda <= sfp_sda_i;
  sysc_regs_i.gpsr_sfp1_scl <= sfp_scl_i;

  sysc_regs_i.gpsr_sfp1_det <= sfp_det_i;

  -------------------------------------
  -- SPI - Flash
  -------------------------------------
  p_drive_spi: process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        spi_sclk_o  <= '0';
        spi_mosi_o  <= '0';
        spi_ncs_o   <= '1';
      else
        if sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_spi_sclk = '1' then
          spi_sclk_o <= '1';
        elsif sysc_regs_o.gpcr_wr = '1' and sysc_regs_o.gpcr_spi_sclk = '1' then
          spi_sclk_o <= '0';
        end if;

        if sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_spi_ncs = '1' then
          spi_ncs_o <= '1';
        elsif sysc_regs_o.gpcr_wr = '1' and sysc_regs_o.gpcr_spi_cs = '1' then
          spi_ncs_o <= '0';
        end if;

        if sysc_regs_o.gpsr_wr = '1' and sysc_regs_o.gpsr_spi_mosi = '1' then
          spi_mosi_o <= '1';
        elsif sysc_regs_o.gpcr_wr = '1' and sysc_regs_o.gpcr_spi_mosi = '1' then
          spi_mosi_o <= '0';
        end if;
      end if;
    end if;
  end process;

  sysc_regs_i.gpsr_spi_sclk <= '0';
  sysc_regs_i.gpsr_spi_ncs  <= '0';
  sysc_regs_i.gpsr_spi_mosi <= '0';
  sysc_regs_i.gpsr_spi_miso <= spi_miso_i;

  sysc_regs_i.hwbld <= g_hwbld_date;

  -------------------------------------
  -- DIAG to/from external modules
  -------------------------------------
  -- first, provide all the constants
  sysc_regs_i.diag_info_id  <= std_logic_vector(to_unsigned(g_diag_id, 16));
  sysc_regs_i.diag_info_ver <= std_logic_vector(to_unsigned(g_diag_ver, 16));
  sysc_regs_i.diag_nw_ro <= std_logic_vector(to_unsigned(g_diag_ro_size, 16));
  sysc_regs_i.diag_nw_rw <= std_logic_vector(to_unsigned(g_diag_rw_size, 16));

  diag_array_out <= diag_out_regs;
  -- r/w registers can be also read
  diag_in(g_diag_rw_size - 1 downto 0) <= diag_out_regs;
  -- r/o array after r/w registers for reading
  diag_in(g_diag_ro_size + g_diag_rw_size-1 downto g_diag_rw_size) <= diag_array_in;

  p_diag_rw: process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        diag_dat <= (others=>'0');
      else
        if sysc_regs_o.diag_dat_wr = '1' then
          diag_dat <= sysc_regs_o.diag_dat;
        end if;
      end if;
    end if;
  end process;

  GEN_DIAG_NODAT: if g_diag_rw_size = 0 and g_diag_ro_size = 0 generate
    sysc_regs_i.diag_dat <= (others=>'0');
  end generate;
  GEN_DIAG_DAT: if g_diag_rw_size /= 0 or g_diag_ro_size /= 0 generate
    sysc_regs_i.diag_dat <= diag_in(to_integer(unsigned(sysc_regs_o.diag_cr_adr)));
  end generate;

  -- Write request for each r/w register
  GEN_LOOP: for I in 0 to g_diag_rw_size-1 generate
    process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          diag_out_regs(I) <= (others=>'0');
        elsif sysc_regs_o.diag_cr_wr = '1' and sysc_regs_o.diag_cr_rw = '1'
          and to_integer(unsigned(sysc_regs_o.diag_cr_adr)) = I
        then
          diag_out_regs(I) <= diag_dat;
        end if;
      end if;
    end process;
  end generate;

  ----------------------------------------
  -- SYSCON
  ----------------------------------------
  inst_wrc_syscon_map: entity work.wrc_syscon_map
    port map (
      rst_n_i => rst_n_i,
      clk_i => clk_sys_i,
      wb_i => syscon_wb_i,
      wb_o => syscon_wb_o,
      sysc_regs_i => sysc_regs_i,
      sysc_regs_o => sysc_regs_o
      );
end struct;
