-------------------------------------------------------------------------------
-- tb_fir_branch_parallel.vhd
-- Unit testbench for fir_branch_parallel.vhd (Haifuraiya parallel-MAC branch)
-------------------------------------------------------------------------------
-- Open Research Institute
-- Project: Polyphase Channelizer (Haifuraiya configuration)
-- Tools:   Vivado 2022.2+ xsim, VHDL-2008
--
-- Adapted from mdt_sic/sim/tb_fir_branch.vhd. Two differences vs. the
-- serial-MAC branch:
--   1. Coefficients are read from a hex file at elaboration (not a
--      runtime port). To exercise both positive-only and mixed-sign
--      coefficients we instantiate two DUTs against the same small
--      hex file using BRANCH_INDEX=0 and BRANCH_INDEX=1.
--   2. Latency is ~3 clocks from sample_valid to result_valid (parallel
--      MAC with two pipelined 12-tap halves + final-add), vs. M+2 for
--      the serial MAC. Test 3 observes the latency and asserts a 2-4
--      cycle range to catch gross pipeline regressions.
--
-- Coefficient file layouts:
--   tb_fir_branch_parallel_coeffs.hex (4-tap, two branches):
--     Lines 0..3 = branch 0: [+1, +2, +3, +4]
--     Lines 4..7 = branch 1: [+1, -1, +1, -1]
--   tb_fir_branch_parallel_24tap_coeffs.hex (production 24-tap):
--     Lines 0..23 = branch 0: [+1, +2, +3, ..., +24]
--
-- Test plan:
--   Test 1: Feed [10,20,30,40] to 4-tap branch 0  -> expect 200
--   Test 2: Feed +50 to 4-tap branch 0             -> expect 300
--   Test 3: Verify latency (range, not exact)
--   Test 4: Feed [10,20,30,40] to 4-tap branch 1  -> expect 20 (mixed-sign)
--   Test 5: 24-tap impulse response — verifies every tap position and
--           every coefficient slot in a single pass. With coeffs
--           [1, 2, ..., 24], feeding [1, 0, 0, ..., 0] should produce
--           successive results 1, 2, 3, ..., 24 as the impulse walks
--           through the delay line. Catches off-by-ones in both tap
--           addressing and coefficient indexing that 4-tap tests miss.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fir_branch_parallel is
end entity tb_fir_branch_parallel;

architecture sim of tb_fir_branch_parallel is

    constant TAPS_PER_BRANCH       : positive := 4;     -- small for hand-verification
    constant TAPS_PER_BRANCH_24    : positive := 24;    -- production size
    constant DATA_WIDTH            : positive := 16;
    constant COEFF_WIDTH           : positive := 16;
    constant ACCUM_WIDTH           : positive := 40;
    constant COEFF_FILE            : string   := "tb_fir_branch_parallel_coeffs.hex";
    constant COEFF_FILE_24         : string   := "tb_fir_branch_parallel_24tap_coeffs.hex";
    constant CLK_PERIOD            : time     := 10 ns;

    signal clk             : std_logic := '0';
    signal reset           : std_logic := '1';

    -- Branch 0 ports (coeffs [1, 2, 3, 4])
    signal sample_in_0     : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal sample_valid_0  : std_logic := '0';
    signal result_0        : std_logic_vector(ACCUM_WIDTH - 1 downto 0);
    signal result_valid_0  : std_logic;

    -- Branch 1 ports (coeffs [1, -1, 1, -1])
    signal sample_in_1     : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal sample_valid_1  : std_logic := '0';
    signal result_1        : std_logic_vector(ACCUM_WIDTH - 1 downto 0);
    signal result_valid_1  : std_logic;

    -- 24-tap branch ports (coeffs [1, 2, 3, ..., 24])
    signal sample_in_24    : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal sample_valid_24 : std_logic := '0';
    signal result_24       : std_logic_vector(ACCUM_WIDTH - 1 downto 0);
    signal result_valid_24 : std_logic;

    signal running         : boolean := true;

begin

    clk <= not clk after CLK_PERIOD / 2 when running else '0';

    ---------------------------------------------------------------------------
    -- DUT 0: BRANCH_INDEX=0, coeffs [1, 2, 3, 4]
    ---------------------------------------------------------------------------
    dut0 : entity work.fir_branch_parallel
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
            sample_in    => sample_in_0,
            sample_valid => sample_valid_0,
            result       => result_0,
            result_valid => result_valid_0
        );

    ---------------------------------------------------------------------------
    -- DUT 1: BRANCH_INDEX=1, coeffs [1, -1, 1, -1]
    ---------------------------------------------------------------------------
    dut1 : entity work.fir_branch_parallel
        generic map (
            TAPS_PER_BRANCH => TAPS_PER_BRANCH,
            DATA_WIDTH      => DATA_WIDTH,
            COEFF_WIDTH     => COEFF_WIDTH,
            ACCUM_WIDTH     => ACCUM_WIDTH,
            COEFF_FILE      => COEFF_FILE,
            BRANCH_INDEX    => 1
        )
        port map (
            clk          => clk,
            reset        => reset,
            sample_in    => sample_in_1,
            sample_valid => sample_valid_1,
            result       => result_1,
            result_valid => result_valid_1
        );

    ---------------------------------------------------------------------------
    -- DUT 24: TAPS_PER_BRANCH=24, BRANCH_INDEX=0, coeffs [1, 2, ..., 24]
    -- Production-size branch.
    ---------------------------------------------------------------------------
    dut24 : entity work.fir_branch_parallel
        generic map (
            TAPS_PER_BRANCH => TAPS_PER_BRANCH_24,
            DATA_WIDTH      => DATA_WIDTH,
            COEFF_WIDTH     => COEFF_WIDTH,
            ACCUM_WIDTH     => ACCUM_WIDTH,
            COEFF_FILE      => COEFF_FILE_24,
            BRANCH_INDEX    => 0
        )
        port map (
            clk          => clk,
            reset        => reset,
            sample_in    => sample_in_24,
            sample_valid => sample_valid_24,
            result       => result_24,
            result_valid => result_valid_24
        );

    stim_proc : process

        -----------------------------------------------------------------
        -- Pulse one sample into branch 0, then wait for its result_valid.
        -- After the procedure returns, result_0 holds the new filter sum.
        -----------------------------------------------------------------
        procedure pulse_sample_0(val : integer) is
        begin
            sample_in_0    <= std_logic_vector(to_signed(val, DATA_WIDTH));
            sample_valid_0 <= '1';
            wait for CLK_PERIOD;
            sample_valid_0 <= '0';
            wait until result_valid_0 = '1';
            wait for CLK_PERIOD;
        end procedure;

        procedure pulse_sample_1(val : integer) is
        begin
            sample_in_1    <= std_logic_vector(to_signed(val, DATA_WIDTH));
            sample_valid_1 <= '1';
            wait for CLK_PERIOD;
            sample_valid_1 <= '0';
            wait until result_valid_1 = '1';
            wait for CLK_PERIOD;
        end procedure;

        procedure pulse_sample_24(val : integer) is
        begin
            sample_in_24    <= std_logic_vector(to_signed(val, DATA_WIDTH));
            sample_valid_24 <= '1';
            wait for CLK_PERIOD;
            sample_valid_24 <= '0';
            wait until result_valid_24 = '1';
            wait for CLK_PERIOD;
        end procedure;

        variable result_int : integer;
        variable expected   : integer;
        variable start_time : time;
        variable latency    : time;

    begin
        report "=== FIR Branch Parallel Testbench ===" severity note;
        report "Configuration: TAPS=" & integer'image(TAPS_PER_BRANCH) &
               ", coeffs from " & COEFF_FILE severity note;

        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------
        -- Test 1: Branch 0, feed [10, 20, 30, 40]
        --   After 4 samples, taps = [40, 30, 20, 10]
        --   Expected = 1*40 + 2*30 + 3*20 + 4*10 = 200
        -----------------------------------------------------------------
        report "--- Test 1: Branch 0, samples [10, 20, 30, 40] ---" severity note;
        pulse_sample_0(10);
        pulse_sample_0(20);
        pulse_sample_0(30);
        pulse_sample_0(40);

        result_int := to_integer(signed(result_0));
        expected   := 200;
        report "  Result: "   & integer'image(result_int) &
               ", Expected: " & integer'image(expected) severity note;
        assert result_int = expected
            report "TEST 1 FAIL: got " & integer'image(result_int) &
                   ", expected " & integer'image(expected) severity failure;
        report "  TEST 1 PASS" severity note;

        wait for CLK_PERIOD * 2;

        -----------------------------------------------------------------
        -- Test 2: Branch 0, feed +50, oldest (10) shifts out
        --   taps = [50, 40, 30, 20]
        --   Expected = 1*50 + 2*40 + 3*30 + 4*20 = 300
        -----------------------------------------------------------------
        report "--- Test 2: Branch 0, +50 (10 shifts out) ---" severity note;
        pulse_sample_0(50);

        result_int := to_integer(signed(result_0));
        expected   := 300;
        report "  Result: "   & integer'image(result_int) &
               ", Expected: " & integer'image(expected) severity note;
        assert result_int = expected
            report "TEST 2 FAIL: got " & integer'image(result_int) &
                   ", expected " & integer'image(expected) severity failure;
        report "  TEST 2 PASS" severity note;

        wait for CLK_PERIOD * 2;

        -----------------------------------------------------------------
        -- Test 3: Latency observation
        --   Per fir_branch_parallel.vhd:32-50, ~3 clocks from
        --   sample_valid to result_valid. Allow 2-4 cycle range so the
        --   test stays valid across phase-alignment variations and
        --   minor pipeline tweaks, but flags gross regressions.
        -----------------------------------------------------------------
        report "--- Test 3: Latency check on branch 0 ---" severity note;
        sample_in_0    <= std_logic_vector(to_signed(60, DATA_WIDTH));
        sample_valid_0 <= '1';
        start_time     := now;
        wait for CLK_PERIOD;
        sample_valid_0 <= '0';
        wait until result_valid_0 = '1';
        latency := now - start_time;

        report "  sample_valid -> result_valid latency: " &
               time'image(latency) severity note;
        report "  Expected range: 2 to 4 cycles (" &
               time'image(CLK_PERIOD * 2) & " to " &
               time'image(CLK_PERIOD * 4) & ")" severity note;
        assert latency >= CLK_PERIOD * 2 and latency <= CLK_PERIOD * 4
            report "TEST 3 FAIL: latency = " & time'image(latency) &
                   " outside 2-4 cycle range" severity failure;
        report "  TEST 3 PASS" severity note;

        -- swallow this sample's result and let the pipeline quiesce
        wait for CLK_PERIOD * 3;

        -----------------------------------------------------------------
        -- Test 4: Branch 1, mixed-sign coeffs [1, -1, 1, -1]
        --   Feed [10, 20, 30, 40] -> taps = [40, 30, 20, 10]
        --   Expected = 1*40 + (-1)*30 + 1*20 + (-1)*10 = 20
        -----------------------------------------------------------------
        report "--- Test 4: Branch 1, mixed-sign coeffs [1,-1,1,-1] ---" severity note;
        pulse_sample_1(10);
        pulse_sample_1(20);
        pulse_sample_1(30);
        pulse_sample_1(40);

        result_int := to_integer(signed(result_1));
        expected   := 20;
        report "  Result: "   & integer'image(result_int) &
               ", Expected: " & integer'image(expected) severity note;
        assert result_int = expected
            report "TEST 4 FAIL: got " & integer'image(result_int) &
                   ", expected " & integer'image(expected) severity failure;
        report "  TEST 4 PASS" severity note;

        wait for CLK_PERIOD * 2;

        -----------------------------------------------------------------
        -- Test 5: Production-size 24-tap branch, impulse response.
        --   coeffs = [1, 2, 3, ..., 24]
        --   Feed [1, 0, 0, ..., 0] (24 samples; first is impulse).
        --   After sample k (0-indexed): taps[k]=1, others 0, so
        --     result = coeff[k] * 1 = k + 1.
        --   This walks the impulse through every tap position and
        --   exercises every coefficient slot — strong off-by-one catch.
        -----------------------------------------------------------------
        report "--- Test 5: 24-tap impulse response ---" severity note;
        for k in 0 to TAPS_PER_BRANCH_24 - 1 loop
            if k = 0 then
                pulse_sample_24(1);   -- the impulse
            else
                pulse_sample_24(0);
            end if;
            result_int := to_integer(signed(result_24));
            expected   := k + 1;       -- coeff[k] = k+1
            assert result_int = expected
                report "TEST 5 FAIL at k=" & integer'image(k) &
                       ": got " & integer'image(result_int) &
                       ", expected " & integer'image(expected) severity failure;
        end loop;
        report "  All 24 impulse-response samples matched coeffs 1..24" severity note;
        report "  TEST 5 PASS" severity note;

        report "" severity note;
        report "=== All FIR Branch Parallel Tests Complete ===" severity note;

        running <= false;
        wait;
    end process;

end architecture sim;
