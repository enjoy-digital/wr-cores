-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2017 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : Common WRPC Wrapper package
-- Project    : WR PTP Core
-- URL        : https://gitlab.com/ohwr/project/wr-cores/-/wikis/wrpc-core
-------------------------------------------------------------------------------
-- File       : xwrc_board_common.vhd
-- Company    : CERN (BE-CO-HT)
-- Standard   : VHDL'93
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.endpoint_pkg.all;
use work.wrcore_pkg.all;
use work.streamers_pkg.all;
use work.wr_timecode_pkg.all;

package wr_board_pkg is

  type t_board_fabric_iface is (PLAIN, STREAMERS, ETHERBONE, LOOPBACK, always_last_invalid);

  -- TODO: using these default paths requires absolute path. If relative path is used,
  --       they work only for reference designs by chance. Once we figure out how to
  --       automatically figure out absolute path of <wr-cores location>/bin/wrpc, we
  --       will be able to use this concept in f_find_default_lm32_firmware()
  constant dpram_initf_default_altera_phy8     : string := "";
  constant dpram_initf_default_xilinx_phy8     : string := "";
  constant dpram_initf_default_altera_phy8_sim : string := "";
  constant dpram_initf_default_xilinx_phy8_sim : string := "";

  procedure f_check_fabric_iface_type (
    constant iface_type : in t_board_fabric_iface);

  procedure f_check_diag_id (
    constant diag_id, diag_ver : in integer);

  function f_str2iface_type (
    constant iface_str : string(1 to 9))
    return t_board_fabric_iface;

  function f_pick_diag_val (
    iface           : t_board_fabric_iface;
    streamers_val   : integer;
    application_val : integer
    ) return integer;

  function f_pick_diag_size (
    iface            : t_board_fabric_iface;
    streamers_size   : integer;
    application_size : integer
    ) return integer;

  function f_pick_clk_ref_rate (
    pcs_16bit_in : boolean
    ) return integer;

  function f_vectorize_diag (
    diag_in          : t_generic_word_array;
    diag_vector_size : integer)
    return std_logic_vector;

  function f_de_vectorize_diag (
    diag_in          : std_logic_vector;
    diag_vector_size : integer)
    return t_generic_word_array;

  function f_find_default_lm32_firmware (
    dpram_initf : string;
    simulation  : integer;
    pcs_16_bit  : boolean;
    verbose     : boolean := TRUE)
    return string;

  component eb_ethernet_slave is
    generic (
      g_sdb_address    : std_logic_vector(63 downto 0) := x"0000000000000000";
      g_timeout_cycles : natural := 0;
      g_mtu            : natural := 0);
    port (
      clk_i       : in  std_logic;
      nRst_i      : in  std_logic;
      snk_i       : in  t_wrf_sink_in;
      snk_o       : out t_wrf_sink_out;
      src_o       : out t_wrf_source_out;
      src_i       : in  t_wrf_source_in;
      cfg_slave_o : out t_wishbone_slave_out;
      cfg_slave_i : in  t_wishbone_slave_in;
      master_o    : out t_wishbone_master_out;
      master_i    : in  t_wishbone_master_in);
  end component eb_ethernet_slave;
  
end wr_board_pkg;

package body wr_board_pkg is

  procedure f_check_fabric_iface_type (
    constant iface_type : in t_board_fabric_iface) is
  begin
    if iface_type >= always_last_invalid then
      assert FALSE
        report "WR PTP core fabric interface [" & t_board_fabric_iface'image(iface_type) & "] is not supported"
        severity FAILURE;
    end if;
  end procedure f_check_fabric_iface_type;

  procedure f_check_diag_id (
    constant diag_id, diag_ver : in integer) is
  begin
    assert (diag_id /= 1) report
      "g_diag_id=1 is reserved for wr_streamers and cannot be set by users"
      severity FAILURE;

    assert (not (diag_id /= 0 and diag_ver = 0)) report
      "If diag_id is set by the user (diag_id > 1), g_diag_ver must be at least 1"
      severity FAILURE;
  end procedure f_check_diag_id;

  function f_str2iface_type (
    constant iface_str : string(1 to 9))
    return t_board_fabric_iface is
    variable result : t_board_fabric_iface;
  begin
    case iface_str is
      when "PLAINFBRC" => result := PLAIN;
      when "STREAMERS" => result := STREAMERS;
      when "ETHERBONE" => result := ETHERBONE;
      when others      => result := always_last_invalid;
    end case;
    return result;
  end function f_str2iface_type;

  -- this function decides what is the diag_id/ver used in the WRPC and MIB for access
  -- via SNMP
  function f_pick_diag_val (
    iface           : t_board_fabric_iface;
    streamers_val   : integer;
    application_val : integer
    ) return integer is
  begin
    -- streamers are enabled and application/user does nto use diags (no vector specified),
    -- use default streamer's id/ver
    if(iface = STREAMERS and application_val = 0) then
      return streamers_val;
    else  -- otherwise, use id/ver specified by the user/application. This is the case also
      -- when streamers are used.
      return application_val;
    end if;
  end f_pick_diag_val;

  -- provide the size of the final diag array.
  function f_pick_diag_size (
    iface            : t_board_fabric_iface;
    streamers_size   : integer;
    application_size : integer
    ) return integer is
  begin
    -- when streamers are used, concatenate the array of streamers and application/user
    if(iface = STREAMERS) then
      return (streamers_size+application_size);
    else  -- otherwise, only the size provided by the application/user
      return application_size;
    end if;
  end f_pick_diag_size;

  -- guess clk_ref (WR reference Clock) rate based on PCS word width
  function f_pick_clk_ref_rate (
    pcs_16bit_in : boolean
    ) return integer is
  begin
    if(pcs_16bit_in = TRUE) then
      return 62500000;
    else
      return 125000000;
    end if;
  end f_pick_clk_ref_rate;

  function f_vectorize_diag (
    diag_in          : t_generic_word_array;
    diag_vector_size : integer)
    return std_logic_vector is
    variable result : std_logic_vector(diag_vector_size-1 downto 0);
  begin
    assert (diag_vector_size mod 32 = 0) report
      "g_diag_ro/w_vector_width must have value that is a mutiple of 32"
      severity FAILURE;
    for i in 0 to diag_vector_size/32-1 loop
      result(i*32+31 downto i*32) := diag_in(i);
    end loop;
    return result;
  end function f_vectorize_diag;

  function f_de_vectorize_diag (
    diag_in          : std_logic_vector;
    diag_vector_size : integer)
    return t_generic_word_array is
    variable result : t_generic_word_array(diag_vector_size/32-1 downto 0);
  begin
    assert (diag_vector_size mod 32 = 0) report
      "g_diag_ro/w_vector_width must have value that is a mutiple of 32"
      severity FAILURE;
    for i in 0 to diag_vector_size/32-1 loop
      result(i) := diag_in(i*32+31 downto i*32);
    end loop;
    return result;
  end function f_de_vectorize_diag;

  function f_find_default_lm32_firmware (
    dpram_initf : string;
    simulation  : integer;
    pcs_16_bit  : boolean;
    verbose     : boolean := TRUE)
    return string is
  begin
    if((dpram_initf = "default_altera" or dpram_initf = "default_xilinx") and
       pcs_16_bit = TRUE) then
      assert FALSE
        report "[Board:Software for LM32 in WR Core] No release binary for " &
        "pcs_16_bit." severity FAILURE;
      return "";
    elsif (dpram_initf /= "default_altera" and dpram_initf /= "default_xilinx") then
      if verbose = TRUE then
        report "[Board:Software for LM32 in WR Core]  Using user-provided LM32 " &
          "firmware ("&dpram_initf&")." severity NOTE;
      end if;
      return dpram_initf;
    elsif (simulation = 0 and dpram_initf = "default_altera" and pcs_16_bit = FALSE and
           dpram_initf_default_altera_phy8 /= "") then
      if verbose = TRUE then
        report "[Board:Software for LM32 in WR Core] Using release LM32 firmware " &
          "(altera, phy8)." severity NOTE;
      end if;
      return dpram_initf_default_altera_phy8;
    elsif (simulation = 0 and dpram_initf = "default_xilinx" and pcs_16_bit = FALSE and
           dpram_initf_default_xilinx_phy8 /= "") then
      if verbose = TRUE then
        report "[Board:Software for LM32 in WR Core] Using release LM32 firmware " &
          "(xilnix, phy8)" severity NOTE;
      end if;
      return dpram_initf_default_xilinx_phy8;
    elsif (simulation = 1 and dpram_initf = "default_altera" and pcs_16_bit = FALSE and
           dpram_initf_default_altera_phy8_sim /= "") then
      if verbose = TRUE then
        report "Board:[Software for LM32 in WR Core] Using release LM32 firmware " &
          "(altera, phy8, sim)." severity NOTE;
      end if;
      return dpram_initf_default_altera_phy8_sim;
    elsif (simulation = 1 and dpram_initf = "default_xilinx" and pcs_16_bit = FALSE and
           dpram_initf_default_xilinx_phy8_sim /= "") then
      if verbose = TRUE then
        report "[Board:Software for LM32 in WR Core] Using release LM32 firmware " &
          "(xilinx, phy8, sim)." severity NOTE;
      end if;
      return dpram_initf_default_xilinx_phy8_sim;
    else
      assert FALSE
        report "[Board:Software for LM32 in WR Core] Default inclussion of LM32" &
        "binary with software is not supported yet. In your instantiation" &
        "of the board (xwrc_board_{spec,svec,vfchd} set g_dpram_initf to the" &
        "correct path, i.e." &
        "<your wr-cores location>/bin/wrpc/wrc_phy8_sim.{bram, mif} " severity FAILURE;
      return "";
    end if;
  end function;

end package body wr_board_pkg;
