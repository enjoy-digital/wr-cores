-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2011 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : Dual-port RAM for WR core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wrc_dpram.vhd
-- Author     : Grzegorz Daniluk
-- Company    : CERN
-- Created    : 2011-02-15
-- Last update: 2021-06-19
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
--
-- Dual port RAM with wishbone interface
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-02-15  1.0      greg.d          Created
-- 2011-06-09  1.01     twlostow        Removed unnecessary generics
-- 2011-21-09  1.02     twlostow        Struct-ized version
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library work;
use work.genram_pkg.all;
use work.wishbone_pkg.all;

entity wrc_diags_dpram is
  generic(
    g_size                  : natural := 256
    );
  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- R/O slave except CTRL (word 1, byte offset 0x04); VER is word 0.
    slave_user_i : in  t_wishbone_slave_in;
    slave_user_o : out t_wishbone_slave_out;
    -- R/W slave
    slave_wrc_i : in  t_wishbone_slave_in;
    slave_wrc_o : out t_wishbone_slave_out
    );
end wrc_diags_dpram;

architecture struct of wrc_diags_dpram is
  signal s_is_control_word : std_logic;
  signal s_we_wrc  : std_logic;
  signal s_we_user : std_logic;
begin

  U_DPRAM : generic_dpram
    generic map(
      -- standard parameters
      g_data_width               => 32,
      g_size                     => g_size,
      g_with_byte_enable         => false,
      g_addr_conflict_resolution => "dont_care",
      g_init_file                => "",
      g_dual_clock               => false
      )
    port map(
      rst_n_i => rst_n_i,
      -- Port A
      clka_i  => clk_sys_i,
      wea_i   => s_we_wrc,
      aa_i    => slave_wrc_i.adr(f_log2_size(g_size)+1 downto 2),
      da_i    => slave_wrc_i.dat,
      qa_o    => slave_wrc_o.dat,
      -- Port B
      clkb_i  => clk_sys_i,
      web_i   => s_we_user,
      ab_i    => slave_user_i.adr(f_log2_size(g_size)+1 downto 2),
      db_i    => slave_user_i.dat,
      qb_o    => slave_user_o.dat
      );


  s_is_control_word <= '1' when unsigned(slave_user_i.adr(f_log2_size(g_size)+1 downto 2) ) = 1 else '0';

  s_we_user <= s_is_control_word and slave_user_i.we and slave_user_i.stb and slave_user_i.cyc;
  s_we_wrc <= slave_wrc_i.we and slave_wrc_i.stb and slave_wrc_i.cyc;

  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        slave_user_o.ack <= '0';
        slave_wrc_o.ack <= '0';
      else
        slave_user_o.ack <= slave_user_i.cyc and slave_user_i.stb;
        slave_wrc_o.ack <= slave_wrc_i.cyc and slave_wrc_i.stb;
      end if;
    end if;
  end process;

  slave_wrc_o.stall <= '0';
  slave_user_o.stall <= '0';
  slave_wrc_o.err   <= '0';
  slave_user_o.err   <= '0';
  slave_wrc_o.rty   <= '0';
  slave_user_o.rty   <= '0';
  
end struct;

