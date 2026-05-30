-- =========================================================================
-- fft_n_pt_sdf.vhd
-- Streaming Radix-2 SDF (Single-path Delay Feedback) Decimation-in-Frequency
-- FFT. Port-compatible drop-in replacement for fft_n_pt.vhd.
--
-- WHY THIS EXISTS
-- ---------------
-- The iterative fft_n_pt takes N + LOG2_N*(N/2) + N = 320 cycles per
-- frame for N=64, which is why haifuraiya_channelizer_top instantiates
-- two of them to keep up at M_DECIMATION=16 (160-cycle frame period).
--
-- This SDF FFT is fully pipelined: it accepts 1 sample per clock and
-- produces 1 output per clock (once primed), so a single instance keeps
-- up with M=16 with margin to spare. Fixed pipeline latency = N - 1
-- cycles. Total throughput = 1 frame per N in_valid cycles.
--
-- ARCHITECTURE
-- ------------
--   sdf_stage instance 0 : FIFO depth 32, twiddle W_64^k       (k=0..31)
--   sdf_stage instance 1 : FIFO depth 16, twiddle W_32^k       (k=0..15)
--   sdf_stage instance 2 : FIFO depth  8, twiddle W_16^k       (k=0..7)
--   sdf_stage instance 3 : FIFO depth  4, twiddle W_8^k        (k=0..3)
--   sdf_stage instance 4 : FIFO depth  2, twiddle W_4^k        (k=0..1)
--   sdf_stage instance 5 : FIFO depth  1, twiddle W_2^0 = 1    (trivial)
--
-- All stages use the same butterfly + multiplier hardware described in
-- sdf_stage.vhd; the trivial twiddles at the last two stages just feed
-- 1.0 (and 0+j stride) into the multiplier — slight scaling loss vs. an
-- explicit multiplier-less path, identical to fft_n_pt's twiddle ROM
-- behavior at k=0.
--
-- OUTPUT ORDERING
-- ---------------
-- DIF FFT naturally produces outputs in bit-reversed order. Rather than
-- adding a final N-entry reorder buffer (which would add N cycles of
-- latency), we report out_idx = bit_reverse(time-order-counter) so the
-- downstream P2S->channel_idx pipeline routes each output sample to the
-- correct natural-order FFT bin. Matches the convention of fft_n_pt's
-- out_idx port.
--
-- License: CERN-OHL-S-2.0
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fft_pkg.all;

entity fft_n_pt_sdf is
    generic (
        N          : positive := 64;
        DATA_WIDTH : positive := 40
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        -- Streaming input: one sample per clock when x_valid='1'.
        x_re        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        x_im        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        x_idx       : in  std_logic_vector(clog2(N) - 1 downto 0);
        x_valid     : in  std_logic;
        x_last      : in  std_logic;

        -- Streaming output: emitted in bit-reversed natural order,
        -- with out_idx already bit-reversed so the consumer sees
        -- "this sample is FFT bin X" without doing the reorder itself.
        out_re      : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        out_im      : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        out_idx     : out std_logic_vector(clog2(N) - 1 downto 0);
        out_valid   : out std_logic;
        out_last    : out std_logic;

        busy        : out std_logic
    );
end entity fft_n_pt_sdf;

architecture rtl of fft_n_pt_sdf is

    constant LOG2_N : positive := clog2(N);

    -- Inter-stage signed buses. stage_re(0)/stage_im(0)/stage_valid(0)
    -- carry the entity-level input; stage_re(LOG2_N)/im(LOG2_N) carries
    -- the final stage's output.
    type sample_array_t is array (0 to LOG2_N) of
        signed(DATA_WIDTH - 1 downto 0);

    signal stage_re    : sample_array_t;
    signal stage_im    : sample_array_t;
    signal stage_valid : std_logic_vector(0 to LOG2_N);

    -- Sequential output counter: increments on each out_valid pulse,
    -- wraps at N-1. Used to compute the bit-reversed out_idx and to
    -- assert out_last on the 64th sample of each frame.
    signal out_cnt : unsigned(LOG2_N - 1 downto 0) := (others => '0');

begin

    ---------------------------------------------------------------------------
    -- Drive the first stage's input from the entity's streaming input.
    ---------------------------------------------------------------------------
    stage_re(0)    <= signed(x_re);
    stage_im(0)    <= signed(x_im);
    stage_valid(0) <= x_valid;

    ---------------------------------------------------------------------------
    -- LOG2_N pipelined SDF stages.
    ---------------------------------------------------------------------------
    gen_stages : for s in 0 to LOG2_N - 1 generate
        u_stage : entity work.sdf_stage
            generic map (
                N_TOTAL     => N,
                STAGE_INDEX => s,
                DATA_WIDTH  => DATA_WIDTH
            )
            port map (
                clk       => clk,
                reset     => reset,
                in_re     => stage_re(s),
                in_im     => stage_im(s),
                in_valid  => stage_valid(s),
                out_re    => stage_re(s + 1),
                out_im    => stage_im(s + 1),
                out_valid => stage_valid(s + 1)
            );
    end generate gen_stages;

    ---------------------------------------------------------------------------
    -- Output counter. Increments on every output sample, wraps at N-1.
    ---------------------------------------------------------------------------
    p_output_counter : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                out_cnt <= (others => '0');
            elsif stage_valid(LOG2_N) = '1' then
                if out_cnt = to_unsigned(N - 1, LOG2_N) then
                    out_cnt <= (others => '0');
                else
                    out_cnt <= out_cnt + 1;
                end if;
            end if;
        end if;
    end process p_output_counter;

    ---------------------------------------------------------------------------
    -- Drive the entity outputs.
    -- The SDF DIF pipeline emits FFT bins in REVERSE bit-reversed order:
    -- time t=0 -> bin N-1, time t=N-1 -> bin 0. This is because each stage
    -- pushes its BUTTERFLY-half output (the "high-half" of its result) to
    -- the next stage first, and the BYPASS-half (low-half) only second.
    -- Compose: out_idx = (N-1) - bit_reverse(out_cnt) to get the natural
    -- bin index that matches fft_n_pt's out_idx convention.
    ---------------------------------------------------------------------------
    out_re    <= std_logic_vector(stage_re(LOG2_N));
    out_im    <= std_logic_vector(stage_im(LOG2_N));
    out_idx   <= std_logic_vector(to_unsigned(
                     (N - 1) - bit_reverse(to_integer(out_cnt), LOG2_N),
                     LOG2_N));
    out_valid <= stage_valid(LOG2_N);
    out_last  <= '1' when (stage_valid(LOG2_N) = '1' and
                           out_cnt = to_unsigned(N - 1, LOG2_N))
                 else '0';

    -- Streaming pipeline is always ready to accept new input; busy is
    -- preserved as a port for compatibility with fft_n_pt consumers.
    busy <= '0';

end architecture rtl;
