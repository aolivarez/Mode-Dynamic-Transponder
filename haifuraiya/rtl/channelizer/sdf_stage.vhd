-- =========================================================================
-- sdf_stage.vhd
-- One stage of a Radix-2 Single-path Delay Feedback (R2SDF) DIF FFT.
--
-- Each stage:
--   - Holds an internal FIFO of depth d = N_TOTAL / 2^(STAGE_INDEX+1).
--   - Runs a free-running phase counter mod 2*d:
--       phase in [0, d-1]   -> "load" half: input goes into FIFO; the
--                              FIFO output (the sum written here d cycles
--                              ago by the previous frame's butterfly half,
--                              or zero for the first frame) is forwarded
--                              to the next stage.
--       phase in [d, 2d-1]  -> "butterfly" half: input combines with the
--                              FIFO output via a radix-2 DIF butterfly:
--                                sum  = fifo_out + input  -> back to FIFO
--                                diff = fifo_out - input  -> *twiddle -> out
--                              (sign convention matches the iterative
--                              fft_n_pt.vhd butterfly: diff = a - b where
--                              a is the lower-index / first-half sample.)
--   - Pre-computes its twiddle ROM at elaboration:
--       twiddle(k) = W_{N_TOTAL}^{k * 2^STAGE_INDEX}
--                  = cos(theta) - j*sin(theta), theta = 2*pi*k*2^s / N
--     Stored Q1.14 signed, scale = 2^(TWIDDLE_WIDTH - 2).
--   - in_valid gates the phase counter; samples must arrive contiguously
--     within a frame (one per clock).
--
-- Output validity:
--   The FIRST in_valid burst takes d cycles to fill the FIFO; only after
--   that is the stage's output meaningful (it has real fifo content to
--   forward or to butterfly with). out_valid is asserted from the d-th
--   in_valid onward (each cycle that in_valid is also high).
--
-- License: CERN-OHL-S-2.0
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.fft_pkg.all;

entity sdf_stage is
    generic (
        N_TOTAL     : positive;   -- full FFT size
        STAGE_INDEX : natural;    -- 0..clog2(N_TOTAL)-1
        DATA_WIDTH  : positive
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        in_re     : in  signed(DATA_WIDTH - 1 downto 0);
        in_im     : in  signed(DATA_WIDTH - 1 downto 0);
        in_valid  : in  std_logic;
        out_re    : out signed(DATA_WIDTH - 1 downto 0);
        out_im    : out signed(DATA_WIDTH - 1 downto 0);
        out_valid : out std_logic
    );
end entity sdf_stage;

architecture rtl of sdf_stage is

    constant FIFO_DEPTH    : positive := N_TOTAL / (2 ** (STAGE_INDEX + 1));
    constant TWIDDLE_WIDTH : positive := 16;
    constant TWIDDLE_SCALE : positive := 2 ** (TWIDDLE_WIDTH - 2);  -- = 16384
    constant PHASE_WIDTH   : positive := clog2(2 * FIFO_DEPTH);
    constant TWIDDLE_STEP  : positive := 2 ** STAGE_INDEX;

    type complex_t is record
        re : signed(DATA_WIDTH - 1 downto 0);
        im : signed(DATA_WIDTH - 1 downto 0);
    end record;

    type twiddle_t is record
        re : signed(TWIDDLE_WIDTH - 1 downto 0);
        im : signed(TWIDDLE_WIDTH - 1 downto 0);
    end record;

    type fifo_t        is array (0 to FIFO_DEPTH - 1) of complex_t;
    type twiddle_rom_t is array (0 to FIFO_DEPTH - 1) of twiddle_t;

    constant ZERO_COMPLEX : complex_t :=
        (re => (others => '0'), im => (others => '0'));

    ---------------------------------------------------------------------------
    -- Build the twiddle ROM at elaboration.
    --   k-th butterfly of stage s uses W_N^{k * 2^s} = cos(theta) - j*sin(theta)
    --   theta = 2 pi * (k * 2^s) / N_TOTAL.
    ---------------------------------------------------------------------------
    function build_twiddle_rom return twiddle_rom_t is
        variable rom   : twiddle_rom_t;
        variable angle : real;
    begin
        for k in 0 to FIFO_DEPTH - 1 loop
            angle := 2.0 * MATH_PI *
                     real(k * TWIDDLE_STEP) / real(N_TOTAL);
            rom(k).re := to_signed(
                integer( cos(angle) * real(TWIDDLE_SCALE - 1)),
                TWIDDLE_WIDTH);
            rom(k).im := to_signed(
                integer(-sin(angle) * real(TWIDDLE_SCALE - 1)),
                TWIDDLE_WIDTH);
        end loop;
        return rom;
    end function;

    constant TWIDDLE_ROM : twiddle_rom_t := build_twiddle_rom;

    ---------------------------------------------------------------------------
    -- State
    ---------------------------------------------------------------------------
    signal fifo         : fifo_t := (others => ZERO_COMPLEX);
    signal phase        : unsigned(PHASE_WIDTH - 1 downto 0) := (others => '0');
    signal samples_seen : unsigned(PHASE_WIDTH - 1 downto 0) := (others => '0');
    signal primed       : std_logic := '0';

    signal out_re_r    : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal out_im_r    : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal out_valid_r : std_logic := '0';

    ---------------------------------------------------------------------------
    -- Forward-path (output) pipeline.
    --
    -- The original butterfly did, in one clock: FIFO mux -> 40-bit subtract
    -- -> complex twiddle multiply -> output register. On a slow -1 Zynq-7020
    -- at 100 MHz that path is ~16 ns and fails timing. We pipeline it:
    --   p_main : FIFO mux + (a-b) and the FIFO WRITE-BACK (feedback) -- the
    --            feedback half (a+b -> FIFO) is left exactly as before, so the
    --            FFT result is bit-identical, just delayed.
    --   pm     : the four 40x16 products (DSP A/M registers)
    --   pc     : complex combine (rr-ii, ri+ir)  (DSP P register)
    --   out    : butterfly/load select + Q1.14 slice -> out_*_r
    -- Both the butterfly value and the load-half bypass value travel the same
    -- number of stages, so the output sample order is preserved. Net added
    -- latency = 3 clocks per stage (output appears 4 clocks after the input
    -- instead of 1); the FFT is otherwise unchanged.
    ---------------------------------------------------------------------------
    constant PROD_W : natural := DATA_WIDTH + TWIDDLE_WIDTH;

    -- p0: operands captured in p_main (same cycle as the FIFO access)
    signal p0_valid              : std_logic := '0';
    signal p0_is_bf              : std_logic := '0';
    signal p0_a_re,   p0_a_im    : signed(DATA_WIDTH - 1 downto 0)    := (others => '0');
    signal p0_diff_re,p0_diff_im : signed(DATA_WIDTH - 1 downto 0)    := (others => '0');
    signal p0_tw_re,  p0_tw_im   : signed(TWIDDLE_WIDTH - 1 downto 0) := (others => '0');

    -- pm: products
    signal pm_valid            : std_logic := '0';
    signal pm_is_bf            : std_logic := '0';
    signal pm_a_re, pm_a_im    : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal pm_rr, pm_ii        : signed(PROD_W - 1 downto 0)     := (others => '0');
    signal pm_ri, pm_ir        : signed(PROD_W - 1 downto 0)     := (others => '0');

    -- pc: combined complex product
    signal pc_valid              : std_logic := '0';
    signal pc_is_bf              : std_logic := '0';
    signal pc_a_re, pc_a_im      : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal pc_prod_re, pc_prod_im: signed(PROD_W - 1 downto 0)     := (others => '0');

begin

    -------------------------------------------------------------------------
    -- p_main: FIFO feedback (UNCHANGED behavior) + capture of the forward
    -- operands into pipeline stage p0. The FIFO read/write and the phase /
    -- primed bookkeeping are identical to the single-cycle version, so the
    -- single-path delay-feedback structure is preserved exactly.
    -------------------------------------------------------------------------
    p_main : process(clk)
        variable ptr        : natural range 0 to FIFO_DEPTH - 1;
        variable in_butterfly_half : boolean;
        variable a_re, a_im : signed(DATA_WIDTH - 1 downto 0);
        variable b_re, b_im : signed(DATA_WIDTH - 1 downto 0);
        variable tw         : twiddle_t;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Don't reset `fifo`: removing the reset clause lets
                -- Vivado infer distributed RAM for stages with non-trivial
                -- FIFO depth instead of using a flat register file. The
                -- `primed` flag below gates out_valid until enough valid
                -- inputs have been consumed, so stale FIFO contents at
                -- reset don't reach the output.
                phase        <= (others => '0');
                samples_seen <= (others => '0');
                primed       <= '0';
                p0_valid     <= '0';
            else
                -- Default: no new forward operand this cycle
                p0_valid <= '0';

                if in_valid = '1' then
                    ptr               := to_integer(phase(PHASE_WIDTH - 2 downto 0));
                    in_butterfly_half := phase(PHASE_WIDTH - 1) = '1';

                    -- a = FIFO output (oldest sample, "lower index" / first half)
                    -- b = current input        ("higher index" / second half)
                    a_re := fifo(ptr).re;
                    a_im := fifo(ptr).im;
                    b_re := in_re;
                    b_im := in_im;
                    tw   := TWIDDLE_ROM(ptr);

                    -- FIFO feedback (identical to the single-cycle design):
                    --   LOAD half      -> store the input
                    --   BUTTERFLY half -> store the sum a+b
                    if not in_butterfly_half then
                        fifo(ptr).re <= b_re;
                        fifo(ptr).im <= b_im;
                    else
                        fifo(ptr).re <= a_re + b_re;
                        fifo(ptr).im <= a_im + b_im;
                    end if;

                    -- Forward operands -> pipeline stage p0. The load-half
                    -- bypass value (a) and the butterfly diff (a-b)*tw are
                    -- both carried; the final stage selects on p0_is_bf.
                    p0_a_re    <= a_re;
                    p0_a_im    <= a_im;
                    p0_diff_re <= a_re - b_re;
                    p0_diff_im <= a_im - b_im;
                    p0_tw_re   <= tw.re;
                    p0_tw_im   <= tw.im;
                    if in_butterfly_half then
                        p0_is_bf <= '1';
                    else
                        p0_is_bf <= '0';
                    end if;

                    -- Advance phase counter (mod 2*FIFO_DEPTH).
                    if phase = to_unsigned(2 * FIFO_DEPTH - 1, PHASE_WIDTH) then
                        phase <= (others => '0');
                    else
                        phase <= phase + 1;
                    end if;

                    -- Track when FIFO is full enough to produce real output.
                    if primed = '0' then
                        if samples_seen = to_unsigned(FIFO_DEPTH - 1, PHASE_WIDTH) then
                            primed <= '1';
                        else
                            samples_seen <= samples_seen + 1;
                        end if;
                    end if;

                    p0_valid <= primed;
                end if;
            end if;
        end if;
    end process p_main;

    -------------------------------------------------------------------------
    -- p_pipe: free-running forward pipeline (products -> combine -> output).
    -- Runs every clock; p*_valid marks which pipeline slots hold real data,
    -- so input gaps propagate as out_valid='0' bubbles.
    -------------------------------------------------------------------------
    p_pipe : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pm_valid    <= '0';
                pc_valid    <= '0';
                out_valid_r <= '0';
                out_re_r    <= (others => '0');
                out_im_r    <= (others => '0');
            else
                -- pm: four products (mapped to DSP multiplier + M register)
                pm_rr    <= p0_diff_re * p0_tw_re;
                pm_ii    <= p0_diff_im * p0_tw_im;
                pm_ri    <= p0_diff_re * p0_tw_im;
                pm_ir    <= p0_diff_im * p0_tw_re;
                pm_a_re  <= p0_a_re;
                pm_a_im  <= p0_a_im;
                pm_is_bf <= p0_is_bf;
                pm_valid <= p0_valid;

                -- pc: complex combine (mapped to DSP P-stage adder)
                pc_prod_re <= pm_rr - pm_ii;
                pc_prod_im <= pm_ri + pm_ir;
                pc_a_re    <= pm_a_re;
                pc_a_im    <= pm_a_im;
                pc_is_bf   <= pm_is_bf;
                pc_valid   <= pm_valid;

                -- out: butterfly/load select + Q1.14 slice
                if pc_is_bf = '1' then
                    out_re_r <= pc_prod_re(DATA_WIDTH + TWIDDLE_WIDTH - 3
                                           downto TWIDDLE_WIDTH - 2);
                    out_im_r <= pc_prod_im(DATA_WIDTH + TWIDDLE_WIDTH - 3
                                           downto TWIDDLE_WIDTH - 2);
                else
                    out_re_r <= pc_a_re;
                    out_im_r <= pc_a_im;
                end if;
                out_valid_r <= pc_valid;
            end if;
        end if;
    end process p_pipe;

    out_re    <= out_re_r;
    out_im    <= out_im_r;
    out_valid <= out_valid_r;

end architecture rtl;
