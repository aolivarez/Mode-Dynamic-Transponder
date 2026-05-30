-- =========================================================================
-- tb_fft_n_pt_sdf.vhd
-- Side-by-side equivalence testbench:
--   fft_n_pt (iterative)   vs   fft_n_pt_sdf (streaming pipelined)
--
-- Both FFTs receive the same input stream and the same x_idx/x_last
-- framing. After both have fully output a frame, each frame's bins are
-- compared by FFT-bin index (out_idx). The two implementations have
-- different latencies (~320 cycles vs ~131 cycles) and emit samples in
-- different time orders, but the per-bin VALUE should match within a
-- small rounding tolerance (different multiplication orders cause
-- different Q1.14 rounding noise).
--
-- Frame timing trick:
--   - 64 actual frame samples drive both FFTs.
--   - 68 zero "flush" samples push the SDF's pipelined frame outputs
--     through (the iterative FFT ignores these since it's in COMPUTING).
--   - x_valid=0 idle period lets the iterative FFT finish OUTPUTTING.
--   - Both bin arrays are then stable and snapshot-comparable.
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.fft_pkg.all;

entity tb_fft_n_pt_sdf is
end entity tb_fft_n_pt_sdf;

architecture sim of tb_fft_n_pt_sdf is

    constant N              : positive := 64;
    constant DATA_WIDTH     : positive := 40;
    constant LOG2_N         : positive := clog2(N);
    constant CLK_PERIOD     : time     := 10 ns;
    constant FLUSH_SAMPLES  : positive := 63;     -- 64 + 63 = 127 in_valids → exactly 64 stage-5 outputs (one frame)
    constant SETTLE_CYCLES  : positive := 350;    -- iterative FFT: 320c per frame + margin
    constant TOLERANCE      : natural  := 64;     -- per-bin LSB tolerance

    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';

    -- Shared streaming input
    signal x_re     : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal x_im     : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal x_idx    : std_logic_vector(LOG2_N - 1 downto 0)     := (others => '0');
    signal x_valid  : std_logic := '0';
    signal x_last   : std_logic := '0';

    -- Iterative FFT outputs
    signal i_out_re    : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal i_out_im    : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal i_out_idx   : std_logic_vector(LOG2_N - 1 downto 0);
    signal i_out_valid : std_logic;
    signal i_out_last  : std_logic;
    signal i_busy      : std_logic;

    -- SDF FFT outputs
    signal s_out_re    : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal s_out_im    : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal s_out_idx   : std_logic_vector(LOG2_N - 1 downto 0);
    signal s_out_valid : std_logic;
    signal s_out_last  : std_logic;
    signal s_busy      : std_logic;

    -- Per-bin capture arrays
    type bin_array_t is array (0 to N - 1) of signed(DATA_WIDTH - 1 downto 0);
    signal i_re_bins : bin_array_t := (others => (others => '0'));
    signal i_im_bins : bin_array_t := (others => (others => '0'));
    signal s_re_bins : bin_array_t := (others => (others => '0'));
    signal s_im_bins : bin_array_t := (others => (others => '0'));

    signal running : boolean := true;

begin

    clk <= not clk after CLK_PERIOD / 2 when running else '0';

    ---------------------------------------------------------------------------
    -- DUT instances
    ---------------------------------------------------------------------------
    u_iter : entity work.fft_n_pt
        generic map (
            N          => N,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk       => clk,
            reset     => reset,
            x_re      => x_re,
            x_im      => x_im,
            x_idx     => x_idx,
            x_valid   => x_valid,
            x_last    => x_last,
            out_re    => i_out_re,
            out_im    => i_out_im,
            out_idx   => i_out_idx,
            out_valid => i_out_valid,
            out_last  => i_out_last,
            busy      => i_busy
        );

    u_sdf : entity work.fft_n_pt_sdf
        generic map (
            N          => N,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk       => clk,
            reset     => reset,
            x_re      => x_re,
            x_im      => x_im,
            x_idx     => x_idx,
            x_valid   => x_valid,
            x_last    => x_last,
            out_re    => s_out_re,
            out_im    => s_out_im,
            out_idx   => s_out_idx,
            out_valid => s_out_valid,
            out_last  => s_out_last,
            busy      => s_busy
        );

    ---------------------------------------------------------------------------
    -- Capture iterative FFT outputs into bins (indexed by out_idx).
    ---------------------------------------------------------------------------
    p_capture_iter : process(clk)
    begin
        if rising_edge(clk) then
            if i_out_valid = '1' then
                i_re_bins(to_integer(unsigned(i_out_idx))) <= signed(i_out_re);
                i_im_bins(to_integer(unsigned(i_out_idx))) <= signed(i_out_im);
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Capture SDF FFT outputs into bins (also indexed by out_idx).
    ---------------------------------------------------------------------------
    p_capture_sdf : process(clk)
    begin
        if rising_edge(clk) then
            if s_out_valid = '1' then
                s_re_bins(to_integer(unsigned(s_out_idx))) <= signed(s_out_re);
                s_im_bins(to_integer(unsigned(s_out_idx))) <= signed(s_out_im);
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stimulus + verification
    ---------------------------------------------------------------------------
    stim_proc : process

        procedure send_frame(
            samples_re : in integer_vector(0 to N - 1);
            samples_im : in integer_vector(0 to N - 1)
        ) is
        begin
            -- Pulse reset before each frame so both DUTs start with
            -- phase counters / FIFOs cleared. Without this, the SDF's
            -- phase counters drift across tests (132-input frame % 64
            -- = 4-sample shift), producing a -k*pi/8 phase rotation on
            -- the *next* impulse test that masquerades as a real bug.
            reset <= '1';
            wait for CLK_PERIOD * 3;
            reset <= '0';
            wait for CLK_PERIOD;

            -- Real frame samples
            for k in 0 to N - 1 loop
                x_re    <= std_logic_vector(to_signed(samples_re(k), DATA_WIDTH));
                x_im    <= std_logic_vector(to_signed(samples_im(k), DATA_WIDTH));
                x_idx   <= std_logic_vector(to_unsigned(k, LOG2_N));
                x_valid <= '1';
                if k = N - 1 then
                    x_last <= '1';
                else
                    x_last <= '0';
                end if;
                wait for CLK_PERIOD;
            end loop;

            -- Zero flush: push SDF pipeline through. Iterative FFT is in
            -- COMPUTING and ignores these.
            for k in 0 to FLUSH_SAMPLES - 1 loop
                x_re    <= (others => '0');
                x_im    <= (others => '0');
                x_idx   <= std_logic_vector(to_unsigned(k mod N, LOG2_N));
                x_valid <= '1';
                x_last  <= '0';
                wait for CLK_PERIOD;
            end loop;

            x_valid <= '0';
            x_last  <= '0';

            -- Let iterative FFT finish OUTPUTTING.
            wait for CLK_PERIOD * SETTLE_CYCLES;
        end procedure;

        procedure compare_bins(test_name : string) is
            variable diff_re      : integer;
            variable diff_im      : integer;
            variable mismatches   : natural := 0;
            variable peak_diff    : natural := 0;
            variable iter_int_re  : integer;
            variable iter_int_im  : integer;
            variable sdf_int_re   : integer;
            variable sdf_int_im   : integer;
        begin
            for k in 0 to N - 1 loop
                iter_int_re := to_integer(i_re_bins(k));
                iter_int_im := to_integer(i_im_bins(k));
                sdf_int_re  := to_integer(s_re_bins(k));
                sdf_int_im  := to_integer(s_im_bins(k));

                diff_re := abs(iter_int_re - sdf_int_re);
                diff_im := abs(iter_int_im - sdf_int_im);

                if diff_re > peak_diff then peak_diff := diff_re; end if;
                if diff_im > peak_diff then peak_diff := diff_im; end if;

                if diff_re > TOLERANCE or diff_im > TOLERANCE then
                    mismatches := mismatches + 1;
                    if mismatches <= 5 then
                        report "  " & test_name & " MISMATCH bin " & integer'image(k) &
                               ": iter=(" & integer'image(iter_int_re) &
                               ", "       & integer'image(iter_int_im) &
                               "), sdf=(" & integer'image(sdf_int_re) &
                               ", "       & integer'image(sdf_int_im) &
                               "), |d_re|=" & integer'image(diff_re) &
                               " |d_im|=" & integer'image(diff_im)
                            severity warning;
                    end if;
                end if;
            end loop;

            report "  " & test_name & ": peak per-bin diff = " &
                   integer'image(peak_diff) & " LSBs (tolerance " &
                   integer'image(TOLERANCE) & ")" severity note;

            assert mismatches = 0
                report test_name & " FAIL: " & integer'image(mismatches) &
                       " of " & integer'image(N) & " bins differ by > " &
                       integer'image(TOLERANCE) & " LSBs"
                severity failure;
            report "  " & test_name & " PASS" severity note;
        end procedure;

        variable dc_re, dc_im     : integer_vector(0 to N - 1);
        variable imp_re, imp_im   : integer_vector(0 to N - 1);
        variable tone_re, tone_im : integer_vector(0 to N - 1);
        variable rand_re, rand_im : integer_vector(0 to N - 1);
        variable phase            : real;
        variable seed1, seed2     : positive := 1;
        variable r                : real;

    begin
        report "=== SDF FFT vs Iterative FFT Equivalence ===" severity note;
        report "  N=" & integer'image(N) & ", DATA_WIDTH=" &
               integer'image(DATA_WIDTH) & ", tolerance=" &
               integer'image(TOLERANCE) & " LSBs" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 2;

        -----------------------------------------------------------------
        -- Test 1: DC input
        --   Expected: all energy in bin 0; other bins ~0.
        -----------------------------------------------------------------
        report "--- Test 1: DC input ---" severity note;
        for k in 0 to N - 1 loop
            dc_re(k) := 1000;
            dc_im(k) := 0;
        end loop;
        send_frame(dc_re, dc_im);
        compare_bins("Test 1 DC");

        -----------------------------------------------------------------
        -- Test 2: Impulse at sample 0
        --   Expected: flat magnitude across all bins.
        -----------------------------------------------------------------
        report "--- Test 2: Impulse ---" severity note;
        for k in 0 to N - 1 loop
            if k = 0 then
                imp_re(k) := 10000;
            else
                imp_re(k) := 0;
            end if;
            imp_im(k) := 0;
        end loop;
        send_frame(imp_re, imp_im);
        compare_bins("Test 2 Impulse");

        -----------------------------------------------------------------
        -- Test 3: Complex tone at bin 8
        --   x[k] = e^(j 2 pi 8 k / N)
        --   Expected: peak at bin 8, near-zero elsewhere.
        -----------------------------------------------------------------
        report "--- Test 3: Tone at bin 8 ---" severity note;
        for k in 0 to N - 1 loop
            phase := 2.0 * MATH_PI * 8.0 * real(k) / real(N);
            tone_re(k) := integer(cos(phase) * 5000.0);
            tone_im(k) := integer(sin(phase) * 5000.0);
        end loop;
        send_frame(tone_re, tone_im);
        compare_bins("Test 3 Tone bin 8");

        -----------------------------------------------------------------
        -- Test 4: Pseudo-random input
        --   Exercises all bins at varied magnitudes; catches subtle
        --   per-bin rounding bugs that DC/impulse/single-tone might miss.
        -----------------------------------------------------------------
        report "--- Test 4: Pseudo-random ---" severity note;
        for k in 0 to N - 1 loop
            uniform(seed1, seed2, r);
            rand_re(k) := integer((r - 0.5) * 4000.0);
            uniform(seed1, seed2, r);
            rand_im(k) := integer((r - 0.5) * 4000.0);
        end loop;
        send_frame(rand_re, rand_im);
        compare_bins("Test 4 Random");

        report "" severity note;
        report "=== ALL EQUIVALENCE TESTS PASSED ===" severity note;
        running <= false;
        wait;
    end process;

end architecture sim;
