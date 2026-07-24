-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.gencores_pkg.all;
use work.disparity_gen_pkg.all;

entity wr_gthe4_adapter is
  port (
    -- Dedicated reference 125 MHz clock for the GTX transceiver
    -- clk_gth_i     : in std_logic;
    -- clk_freerun_i : in std_logic;

    -- TX path, synchronous to tx_out_clk_o (62.5 MHz):
    -- tx_out_clk_o : out std_logic;
    tx_locked_o  : out std_logic;

    -- data input (8 bits, not 8b10b-encoded)
    tx_data_i : in std_logic_vector(15 downto 0);

    -- 1 when tx_data_i contains a control code, 0 when it's a data byte
    tx_k_i : in std_logic_vector(1 downto 0);

    -- disparity of the currently transmitted 8b10b code (1 = plus, 0 = minus).
    -- Necessary for the PCS to generate proper frame termination sequences.
    -- Generated for the 2nd byte (LSB) of tx_data_i.
    tx_disparity_o : out std_logic;

    -- Encoding error indication (1 = error, 0 = no error)
    tx_enc_err_o : out std_logic;

    -- RX path, synchronous to ch0_rx_rbclk_o.

    -- RX recovered clock
    -- rx_rbclk_o : out std_logic;

    -- 8b10b-decoded data output. The data output must be kept invalid before
    -- the transceiver is locked on the incoming signal to prevent the EP from
    -- detecting a false carrier.
    rx_data_o : out std_logic_vector(15 downto 0);

    -- 1 when the byte on rx_data_o is a control code
    rx_k_o : out std_logic_vector(1 downto 0);

    -- encoding error indication
    rx_enc_err_o : out std_logic;

    -- RX bitslide indication, indicating the delay of the RX path of the
    -- transceiver (in UIs). Must be valid when ch0_rx_data_o is valid.
    rx_bitslide_o : out std_logic_vector(4 downto 0);

    rx_bitslide_pcs_reset : out std_logic;


    -- reset input, active hi
    rst_i    : in std_logic;
    loopen_i : in std_logic_vector(2 downto 0);

    rdy_o : out std_logic;
    
    --  Interface to gthe4
    gtwiz_userclk_tx_reset_o : out std_logic;
    gtwiz_userclk_tx_active_i : in std_logic;
    gtwiz_userclk_rx_reset_o : out std_logic;
    gtwiz_userclk_rx_active_i : in std_logic;
    gtwiz_buffbypass_tx_reset_o : out std_logic;
    gtwiz_buffbypass_tx_done_i : in std_logic;
    gtwiz_buffbypass_tx_error_i : in std_logic;
    gtwiz_buffbypass_rx_reset_o : out std_logic;
    gtwiz_buffbypass_rx_start_user_o : out std_logic;
    gtwiz_buffbypass_rx_done_i : in std_logic;
    gtwiz_buffbypass_rx_error_i : in std_logic;
    gtwiz_reset_all_o : out std_logic;
    gtwiz_reset_tx_done_i : in std_logic;
    gtwiz_reset_rx_done_i : in std_logic;

    gth_rx_data_i : in std_logic_vector(15 downto 0);
    gth_tx_data_o : out std_logic_vector(15 downto 0);
    gth_rx_slide_o : out std_logic;
    gth_rx_k_i : in std_logic_vector(1 downto 0);
    gth_tx_k_o : out std_logic_vector(1 downto 0);
    gth_rx_byte_aligned_i : in std_logic;
    gth_rx_comma_det_i : in std_logic;
    gth_rx_pma_reset_done_i : in std_logic;
    gth_tx_pma_reset_done_i : in std_logic;

    gth_rx_clk_i : in std_logic;
    gth_tx_clk_i : in std_logic
   );
end wr_gthe4_adapter;

architecture rtl of wr_gthe4_adapter is
  signal serdes_ready_a, serdes_ready_txclk, serdes_ready_rxclk : std_logic;
  signal rx_synced, rst_rxclk                                     : std_logic;

  signal cur_disp : t_8b10b_disparity;

  signal rst_n : std_logic;
  signal gtwiz_buffbypass_tx_reset_pre, gtwiz_buffbypass_rx_reset_pre : std_logic;
begin

  rst_n <= not rst_i;

  --  Reset TX buffbypass on active tx_clk
  gtwiz_buffbypass_tx_reset_pre <= not gtwiz_userclk_tx_active_i;
  
  U_Sync1 : entity work.gc_sync
    port map (
      clk_i    => gth_tx_clk_i,
      rst_n_a_i  => rst_n,
      d_i   => gtwiz_buffbypass_tx_reset_pre,
      q_o => gtwiz_buffbypass_tx_reset_o);

  --  Reset RX buffbypass on active tx_clk
  gtwiz_buffbypass_rx_reset_pre <= not gtwiz_userclk_rx_active_i or not gtwiz_buffbypass_tx_done_i;
  
  U_Sync2 : entity work.gc_sync
    port map (
      clk_i    => gth_rx_clk_i,
      rst_n_a_i => rst_n,
      d_i   => gtwiz_buffbypass_rx_reset_pre,
      q_o => gtwiz_buffbypass_rx_reset_o);

  gtwiz_userclk_tx_reset_o <= not gth_tx_pma_reset_done_i;
  gtwiz_userclk_rx_reset_o <= not gth_rx_pma_reset_done_i;

  U_Sync_Reset : entity work.gc_sync
    port map (
      clk_i     => gth_rx_clk_i,
      rst_n_a_i => '1',
      d_i       => rst_i,
      q_o       => rst_rxclk);

  U_Bitslide : entity work.gtp_bitslide
    generic map (
      g_simulation => 0,
      g_target     => "ultrascale",
      g_use_rx_byte_is_aligned => true)
    port map (
      gtp_rst_i                => rst_i,
      gtp_rx_clk_i             => gth_rx_clk_i,
      gtp_rx_comma_det_i       => gth_rx_comma_det_i,
      gtp_rx_byte_is_aligned_i => gth_rx_byte_aligned_i,
      serdes_ready_i           => serdes_ready_rxclk,
      gtp_rx_slide_o           => gth_rx_slide_o,
      gtp_rx_cdr_rst_o         => rx_bitslide_pcs_reset,
      bitslide_o               => rx_bitslide_o,
      synced_o                 => rx_synced);

  gth_tx_k_o <= tx_k_i(0) & tx_k_i(1);
  gth_tx_data_o <= tx_data_i(7 downto 0) & tx_data_i(15 downto 8);

  gtwiz_reset_all_o <= rst_i;


  serdes_ready_a <= not rst_i
     and gtwiz_reset_rx_done_i
     and gtwiz_buffbypass_rx_done_i and gtwiz_buffbypass_tx_done_i;

  U_Sync_Serdes_RDY1 : entity work.gc_sync
    port map (
      clk_i      => gth_rx_clk_i,
      rst_n_a_i  => '1',
      d_i        => serdes_ready_a,
      q_o        => serdes_ready_rxclk);

  U_Sync_Serdes_RDY2 : entity work.gc_sync
    port map (
      clk_i      => gth_tx_clk_i,
      rst_n_a_i  => '1',
      d_i        => serdes_ready_a,
      q_o        => serdes_ready_txclk);
  
  p_gen_rx_outputs : process(gth_rx_clk_i, rst_rxclk)
  begin
    if(rst_rxclk = '1') then
      rx_data_o    <= (others => '0');
      rx_k_o       <= (others => '0');
      rx_enc_err_o <= '0';
    elsif rising_edge(gth_rx_clk_i) then
      if(serdes_ready_rxclk = '1' and rx_synced = '1') then
        rx_data_o    <= gth_rx_data_i(7 downto 0) & gth_rx_data_i(15 downto 8);
        rx_k_o       <= gth_rx_k_i(0) & gth_rx_k_i(1);
        rx_enc_err_o <= '0';  --rx_disp_err(0) or rx_disp_err(1) or rx_code_err(0) or rx_code_err(1);
      else
        rx_data_o    <= (others => '1');
        rx_k_o       <= (others => '1');
        rx_enc_err_o <= '1';
      end if;
    end if;
  end process;

  p_gen_tx_disparity : process(gth_tx_clk_i)
  begin
    if rising_edge(gth_tx_clk_i) then
      if serdes_ready_txclk = '0' then
        cur_disp <= RD_MINUS;
      else
        cur_disp <= f_next_8b10b_disparity16(cur_disp, tx_k_i, tx_data_i);
      end if;
    end if;
  end process;

  tx_disparity_o <= to_std_logic(cur_disp);

  rdy_o        <= serdes_ready_rxclk and rx_synced;
  tx_locked_o  <= '1';
  tx_enc_err_o <= '0';
end rtl;


