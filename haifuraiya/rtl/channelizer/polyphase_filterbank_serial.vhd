-------------------------------------------------------------------------------
-- polyphase_filterbank_serial.vhd
-- Polyphase Filterbank using serial-MAC branches (resource-friendly path)
-------------------------------------------------------------------------------
-- Open Research Institute
-- Project: Polyphase Channelizer (Haifuraiya configuration)
-- Target:  Xilinx Zynq UltraScale+ MPSoC (ZCU102, xczu9eg-ffvb1156-2-e)
--
-------------------------------------------------------------------------------
-- WHAT IS DIFFERENT FROM polyphase_filterbank_parallel.vhd
-------------------------------------------------------------------------------
-- 1. Each branch is fir_branch_serial (1 multiplier, time-multiplexed
--    across TAPS_PER_BRANCH taps) instead of fir_branch_parallel
--    (TAPS_PER_BRANCH parallel multipliers). DSP cost per branch drops
--    from TAPS_PER_BRANCH to 1.
--
-- 2. The frame-complete pipeline scales with the serial branch latency
--    (TAPS_PER_BRANCH + 2 stages) so outputs_valid still fires exactly
--    when the last branch's MAC has registered its result. The parallel
--    version used a fixed 3-stage pipeline (d0/d1/d2).
--
-- Output interface (branch_outputs packed bus + outputs_valid pulse) is
-- identical to polyphase_filterbank_parallel, so the downstream P2S
-- adapter and FFT need no changes. Drop-in replacement.
--
-------------------------------------------------------------------------------
-- TIMING
-------------------------------------------------------------------------------
-- Each serial branch needs TAPS_PER_BRANCH + 1 clocks from sample_valid
-- to result_valid (one to enter S_COMPUTE, TAPS_PER_BRANCH MAC cycles,
-- shifted into the final register on the next edge). For Haifuraiya at
-- 100 MHz / 10 Msps / N=64 the budget per branch is N * 10 = 640 clocks
-- per sample, comfortably accommodating the 26-clock branch latency.
--
-- Frame-complete-to-outputs_valid delay: TAPS_PER_BRANCH + 1 clocks
-- (the pipeline has depth TAPS_PER_BRANCH + 2; stage 0 is asserted on
-- the M-th sample edge, stage TAPS_PER_BRANCH + 1 fires when the
-- branch's result_r register has just latched).
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity polyphase_filterbank_serial is
    generic (
        N_CHANNELS       : positive := 64;
        M_DECIMATION     : positive := 64;
        TAPS_PER_BRANCH  : positive := 24;
        DATA_WIDTH       : positive := 16;
        COEFF_WIDTH      : positive := 16;
        ACCUM_WIDTH      : positive := 40;
        COEFF_FILE       : string   := "haifuraiya_coeffs.hex"
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;

        sample_in       : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        sample_valid    : in  std_logic;

        branch_outputs  : out std_logic_vector(N_CHANNELS * ACCUM_WIDTH - 1 downto 0);
        outputs_valid   : out std_logic
    );

    function clog2(n : positive) return positive is
        variable r : positive := 1;
        variable v : positive := 2;
    begin
        while v < n loop
            r := r + 1;
            v := v * 2;
        end loop;
        return r;
    end function;

end entity polyphase_filterbank_serial;

architecture rtl of polyphase_filterbank_serial is

    constant BRANCH_IDX_WIDTH : positive := clog2(N_CHANNELS);
    constant M_IDX_WIDTH      : positive := clog2(M_DECIMATION);

    -- fir_branch_serial result_valid pulses TAPS_PER_BRANCH + 2 clocks
    -- after its sample arrives (the MAC has a registered-operand pipeline
    -- stage ahead of the DSP for timing closure). To align outputs_valid
    -- with the LAST branch's result register, the wrap-detect pulse must
    -- propagate through TAPS_PER_BRANCH + 3 pipeline stages (stage 0 set on
    -- the M-th sample's edge, stage N-1 the cycle the branch latches).
    constant FRAME_PIPE_DEPTH : positive := TAPS_PER_BRANCH + 3;

    type result_array_t is array (0 to N_CHANNELS - 1) of
        std_logic_vector(ACCUM_WIDTH - 1 downto 0);

    signal branch_results       : result_array_t;
    signal branch_sample_valid  : std_logic_vector(N_CHANNELS - 1 downto 0);
    signal branch_select        : unsigned(BRANCH_IDX_WIDTH - 1 downto 0)
                                  := (others => '0');
    signal samples_since_fc     : unsigned(M_IDX_WIDTH - 1 downto 0)
                                  := (others => '0');
    -- Parameterized frame-complete pipeline (depth scales with branch
    -- latency). frame_complete_pipe(0) is asserted on the M-th sample
    -- edge; the highest index drives outputs_valid.
    signal frame_complete_pipe  : std_logic_vector(FRAME_PIPE_DEPTH - 1 downto 0)
                                  := (others => '0');

begin

    ---------------------------------------------------------------------------
    -- Commutator: route sample_valid to the currently-selected branch.
    ---------------------------------------------------------------------------
    p_commutator : process(branch_select, sample_valid)
    begin
        branch_sample_valid <= (others => '0');
        if sample_valid = '1' then
            branch_sample_valid(to_integer(branch_select)) <= '1';
        end if;
    end process p_commutator;

    ---------------------------------------------------------------------------
    -- Branch instances: fir_branch_serial (one multiplier per branch).
    ---------------------------------------------------------------------------
    gen_branches : for i in 0 to N_CHANNELS - 1 generate
        u_branch : entity work.fir_branch_serial
            generic map (
                TAPS_PER_BRANCH => TAPS_PER_BRANCH,
                DATA_WIDTH      => DATA_WIDTH,
                COEFF_WIDTH     => COEFF_WIDTH,
                ACCUM_WIDTH     => ACCUM_WIDTH,
                COEFF_FILE      => COEFF_FILE,
                BRANCH_INDEX    => i
            )
            port map (
                clk          => clk,
                reset        => reset,
                sample_in    => sample_in,
                sample_valid => branch_sample_valid(i),
                result       => branch_results(i),
                result_valid => open
            );
    end generate gen_branches;

    ---------------------------------------------------------------------------
    -- Counters and frame-complete pipeline.
    --
    --   branch_select   : free-runs 0..N-1, wraps independently of M.
    --   samples_since_fc: counts 0..M-1, wraps and asserts pipe(0).
    --   frame_complete_pipe : shift register; depth = TAPS_PER_BRANCH+2.
    ---------------------------------------------------------------------------
    p_select : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                branch_select       <= (others => '0');
                samples_since_fc    <= (others => '0');
                frame_complete_pipe <= (others => '0');
            else
                -- Default deassertion at stage 0 (gets overridden on wrap)
                frame_complete_pipe(0) <= '0';

                if sample_valid = '1' then
                    -- Commutator wheel
                    if branch_select = N_CHANNELS - 1 then
                        branch_select <= (others => '0');
                    else
                        branch_select <= branch_select + 1;
                    end if;

                    -- Frame counter
                    if samples_since_fc = M_DECIMATION - 1 then
                        samples_since_fc       <= (others => '0');
                        frame_complete_pipe(0) <= '1';
                    else
                        samples_since_fc <= samples_since_fc + 1;
                    end if;
                end if;

                -- Shift the rest of the pipeline. The read of stage (i-1)
                -- here returns the value from the previous delta, which
                -- is the correct upstream-delayed value.
                for i in 1 to FRAME_PIPE_DEPTH - 1 loop
                    frame_complete_pipe(i) <= frame_complete_pipe(i - 1);
                end loop;
            end if;
        end if;
    end process p_select;

    ---------------------------------------------------------------------------
    -- Pack branch outputs into a single bus (LSB = branch 0)
    ---------------------------------------------------------------------------
    gen_pack : for i in 0 to N_CHANNELS - 1 generate
        branch_outputs((i + 1) * ACCUM_WIDTH - 1 downto i * ACCUM_WIDTH)
            <= branch_results(i);
    end generate gen_pack;

    outputs_valid <= frame_complete_pipe(FRAME_PIPE_DEPTH - 1);

end architecture rtl;
