-------------------------------------------------------------------------------
-- tb_fir_branch_equivalence.vhd
-- Side-by-side equivalence testbench:
--   fir_branch_parallel  vs  fir_branch_serial
-------------------------------------------------------------------------------
-- Open Research Institute
-- Project: Polyphase Channelizer (Haifuraiya configuration)
-- Tools:   Vivado xsim, VHDL-2008
--
-- Both DUTs are instantiated with identical generics (production 24-tap
-- config, BRANCH_INDEX=0, coeffs [1,2,3,...,24] loaded from
-- tb_fir_branch_parallel_24tap_coeffs.hex) and driven by the same sample
-- stream. After every result_valid pulse from the SLOWER branch (serial,
-- ~26 cycles), we assert result_parallel = result_serial bit-exactly.
--
-- The parallel branch is already covered by tb_fir_branch_parallel.vhd
-- (5/5 PASS). If this equivalence TB passes, the serial branch is
-- bit-exactly equivalent for the patterns tested.
--
-- Patterns:
--   1. Impulse (24 samples: one nonzero followed by 23 zeros) — walks
--      the impulse through every tap position.
--   2. Mixed input [1, 2, ..., 24] — steady-state stream so consecutive
--      results exercise the full MAC sum, not just one coefficient.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fir_branch_equivalence is
end entity tb_fir_branch_equivalence;

architecture sim of tb_fir_branch_equivalence is

    constant TAPS_PER_BRANCH : positive := 24;
    constant DATA_WIDTH      : positive := 16;
    constant COEFF_WIDTH     : positive := 16;
    constant ACCUM_WIDTH     : positive := 40;
    constant COEFF_FILE      : string   := "tb_fir_branch_parallel_24tap_coeffs.hex";
    constant CLK_PERIOD      : time     := 10 ns;

    signal clk             : std_logic := '0';
    signal reset           : std_logic := '1';
    signal sample_in       : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal sample_valid    : std_logic := '0';

    -- Parallel-branch outputs
    signal result_p        : std_logic_vector(ACCUM_WIDTH - 1 downto 0);
    signal result_valid_p  : std_logic;

    -- Serial-branch outputs
    signal result_s        : std_logic_vector(ACCUM_WIDTH - 1 downto 0);
    signal result_valid_s  : std_logic;

    signal running         : boolean := true;
    signal mismatch_count  : natural := 0;
    signal compare_count   : natural := 0;

begin

    clk <= not clk after CLK_PERIOD / 2 when running else '0';

    u_parallel : entity work.fir_branch_parallel
        generic map (
            TAPS_PER_BRANCH => TAPS_PER_BRANCH,
            DATA_WIDTH      => DATA_WIDTH,
            COEFF_WIDTH     => COEFF_WIDTH,
            ACCUM_WIDTH     => ACCUM_WIDTH,
            COEFF_FILE      => COEFF_FILE,
            BRANCH_INDEX    => 0
        )
        port map (
            clk          => clk,
            reset        => reset,
            sample_in    => sample_in,
            sample_valid => sample_valid,
            result       => result_p,
            result_valid => result_valid_p
        );

    u_serial : entity work.fir_branch_serial
        generic map (
            TAPS_PER_BRANCH => TAPS_PER_BRANCH,
            DATA_WIDTH      => DATA_WIDTH,
            COEFF_WIDTH     => COEFF_WIDTH,
            ACCUM_WIDTH     => ACCUM_WIDTH,
            COEFF_FILE      => COEFF_FILE,
            BRANCH_INDEX    => 0
        )
        port map (
            clk          => clk,
            reset        => reset,
            sample_in    => sample_in,
            sample_valid => sample_valid,
            result       => result_s,
            result_valid => result_valid_s
        );

    stim_proc : process

        -----------------------------------------------------------------
        -- Drive one sample to both branches, then wait until the slower
        -- branch (serial) has produced its result. At that point both
        -- result_p and result_s reflect the same MAC of the same tap
        -- window: mac_reg in the parallel branch only updates when taps
        -- update (i.e., on sample_valid), and the serial branch has
        -- just registered its result. Compare bit-exactly.
        -----------------------------------------------------------------
        procedure feed_and_compare(val : integer; tag : string) is
            variable p_val : integer;
            variable s_val : integer;
        begin
            sample_in    <= std_logic_vector(to_signed(val, DATA_WIDTH));
            sample_valid <= '1';
            wait for CLK_PERIOD;
            sample_valid <= '0';

            wait until result_valid_s = '1';
            wait for CLK_PERIOD;  -- let signals settle past the rising edge

            p_val := to_integer(signed(result_p));
            s_val := to_integer(signed(result_s));

            compare_count <= compare_count + 1;

            if p_val /= s_val then
                mismatch_count <= mismatch_count + 1;
                report "MISMATCH (" & tag & ", val=" & integer'image(val) &
                       "): parallel=" & integer'image(p_val) &
                       " serial="    & integer'image(s_val)
                    severity failure;
            end if;
        end procedure;

    begin
        report "=== FIR Branch Equivalence Testbench ===" severity note;
        report "  parallel vs serial, TAPS=" & integer'image(TAPS_PER_BRANCH) &
               ", coeffs from " & COEFF_FILE severity note;

        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------
        -- Pattern 1: impulse (1 then 23 zeros).
        --   After sample k: taps[k]=1, others 0, so result = coeff[k].
        --   This exercises every tap position with a known expected
        --   value and forces every coefficient through the MAC exactly
        --   once. Bit-exact match here means the serial branch's
        --   tap-walking and coefficient-indexing are correct.
        -----------------------------------------------------------------
        report "--- Pattern 1: 24-tap impulse response ---" severity note;
        for k in 0 to TAPS_PER_BRANCH - 1 loop
            if k = 0 then
                feed_and_compare(1, "impulse");
            else
                feed_and_compare(0, "impulse");
            end if;
        end loop;
        report "  Pattern 1: 24 comparisons matched" severity note;

        -----------------------------------------------------------------
        -- Pattern 2: ramp 1..24, full delay line steady state.
        --   After the 24th sample taps = [24, 23, ..., 1] and
        --   result = 1*24 + 2*23 + 3*22 + ... + 24*1
        --          = sum_{i=1..24} i * (25 - i)
        --          = 25*sum(i) - sum(i^2)
        --          = 25*300 - 4900 = 2600
        --   We assert equality at every step, not just the last one.
        -----------------------------------------------------------------
        report "--- Pattern 2: ramp [1, 2, ..., 24] ---" severity note;
        for k in 1 to TAPS_PER_BRANCH loop
            feed_and_compare(k, "ramp");
        end loop;
        report "  Pattern 2: 24 comparisons matched" severity note;

        report "" severity note;
        report "=== EQUIVALENCE PASS: " &
               integer'image(compare_count) &
               " comparisons, " &
               integer'image(mismatch_count) &
               " mismatches ===" severity note;

        assert mismatch_count = 0
            report "EQUIVALENCE FAIL: " & integer'image(mismatch_count) &
                   " mismatches" severity failure;

        running <= false;
        wait;
    end process;

end architecture sim;
