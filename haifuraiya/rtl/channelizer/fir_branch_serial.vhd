-------------------------------------------------------------------------------
-- fir_branch_serial.vhd
-- Serial-MAC FIR Branch for Polyphase Channelizer (resource-friendly path)
-------------------------------------------------------------------------------
-- Open Research Institute
-- Project: Polyphase Channelizer (Haifuraiya configuration)
-- Target:  Xilinx Zynq UltraScale+ MPSoC (ZCU102, xczu9eg-ffvb1156-2-e)
--
-------------------------------------------------------------------------------
-- WHY THIS EXISTS
-------------------------------------------------------------------------------
-- fir_branch_parallel instantiates TAPS_PER_BRANCH multipliers per branch.
-- Across the full Haifuraiya filterbank that is 24 * 64 * 2 (IQ) = 3,072
-- DSPs. At 10 Msps on a 100 MHz fabric, each branch only fires once every
-- N_CHANNELS * (clk/sample) = 640 clocks, so ~99.5% of those multipliers
-- are idle.
--
-- This module time-multiplexes a single multiplier across all
-- TAPS_PER_BRANCH taps in TAPS_PER_BRANCH + 2 cycles per sample
-- (~26 cycles for the production 24-tap config), which still fits in the
-- 640-clock budget with ~24x slack. Per-branch DSP cost drops from
-- TAPS_PER_BRANCH to 1.
--
-------------------------------------------------------------------------------
-- INTERFACE
-------------------------------------------------------------------------------
-- Port-compatible drop-in replacement for fir_branch_parallel: same
-- generics, same ports. Coefficients are still loaded from the same
-- COEFF_FILE at elaboration. The only observable behavioural difference
-- is latency:
--   parallel: 3 clocks  from sample_valid to result_valid
--   serial:   TAPS_PER_BRANCH + 2 clocks (26 for 24-tap)
--
-------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------
--   S_IDLE     : waiting for a new sample. On sample_valid='1' the delay
--                line shifts (new sample into taps(0)) and the FSM moves
--                to S_COMPUTE with tap_idx=0, acc=0.
--   S_COMPUTE  : one multiply-accumulate per cycle.
--                  acc <= acc + taps(tap_idx) * COEFFS(tap_idx)
--                  tap_idx <= tap_idx + 1
--                After TAPS_PER_BRANCH cycles (tap_idx reaches the last
--                tap), state moves to S_FINALIZE.
--   S_FINALIZE : registers acc into result_r and pulses result_valid for
--                one cycle, then returns to S_IDLE.
--
-------------------------------------------------------------------------------
-- TIMING (24-tap example)
-------------------------------------------------------------------------------
-- Cycle T    : sample_valid='1' captured; taps shift; state -> S_COMPUTE
-- Cycle T+1  : acc += taps(0)  * COEFFS(0);  tap_idx -> 1
-- Cycle T+2  : acc += taps(1)  * COEFFS(1);  tap_idx -> 2
--   ...
-- Cycle T+24 : acc += taps(23) * COEFFS(23); state -> S_FINALIZE
-- Cycle T+25 : result_r <= acc; result_valid <= '1'; state -> S_IDLE
--
-------------------------------------------------------------------------------
-- RESOURCE USAGE (per branch)
-------------------------------------------------------------------------------
--   1 multiplier (target: DSP48E2 with PCIN/PCOUT MAC mode)
--   TAPS_PER_BRANCH * DATA_WIDTH FFs for the delay-line shift register
--   ACCUM_WIDTH FFs for the accumulator + output register
--   Small FSM: 2 state bits + clog2(TAPS_PER_BRANCH) tap-index bits
--   Coefficient mux: TAPS:1 over COEFF_WIDTH bits (LUTs, or a LUT-ROM)
--
-- License: CERN-OHL-S-2.0
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
-- Coefficients live in a generated package; no TEXTIO needed (OpenCPI's
-- synth flow doesn't propagate file context to the elaborator).
use work.haifuraiya_coeffs_pkg.all;

entity fir_branch_serial is
    generic (
        TAPS_PER_BRANCH : positive := 24;
        DATA_WIDTH      : positive := 16;
        COEFF_WIDTH     : positive := 16;
        ACCUM_WIDTH     : positive := 40;
        -- COEFF_FILE retained as a generic so upstream wrappers don't need
        -- to change. Ignored at elaboration: coefficients come from
        -- haifuraiya_coeffs_pkg.HAIFURAIYA_COEFFS_FLAT.
        COEFF_FILE      : string  := "";
        BRANCH_INDEX    : natural
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        sample_in    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        sample_valid : in  std_logic;
        result       : out std_logic_vector(ACCUM_WIDTH - 1 downto 0);
        result_valid : out std_logic
    );
end entity fir_branch_serial;

architecture rtl of fir_branch_serial is

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

    constant TAP_IDX_WIDTH : positive := clog2(TAPS_PER_BRANCH);

    type sample_array_t is array (0 to TAPS_PER_BRANCH - 1) of
        signed(DATA_WIDTH - 1 downto 0);
    type coeff_array_t is array (0 to TAPS_PER_BRANCH - 1) of
        signed(COEFF_WIDTH - 1 downto 0);

    ---------------------------------------------------------------------------
    -- Pull this branch's coefficient slice out of the embedded flat array.
    -- Layout is branch-major (matches the original .hex file order):
    -- branch B tap T at HAIFURAIYA_COEFFS_FLAT(B * TAPS_PER_BRANCH + T).
    ---------------------------------------------------------------------------
    function get_branch_coeffs return coeff_array_t is
        variable r : coeff_array_t;
    begin
        for t in 0 to TAPS_PER_BRANCH - 1 loop
            r(t) := signed(HAIFURAIYA_COEFFS_FLAT(
                              BRANCH_INDEX * TAPS_PER_BRANCH + t));
        end loop;
        return r;
    end function;

    constant COEFFS : coeff_array_t := get_branch_coeffs;

    ---------------------------------------------------------------------------
    -- FSM and datapath state
    --
    -- Delay-line storage: circular-buffer "sample_ram" instead of a shift
    -- register. head_ptr is the address of the NEWEST sample. To read tap k
    -- (k=0 newest, k=N-1 oldest) we compute (head_ptr - k) mod N.
    --
    -- Synthesis intent: a single write address + single async read address
    -- per clock, no reset on the RAM array. Vivado infers RAM32M16 / RAM64M
    -- distributed RAM (~6 LUTs/branch) instead of TAPS_PER_BRANCH*DATA_WIDTH
    -- flip-flops/branch. Saves ~49k FFs across the 128 branches of the
    -- production filterbank pair.
    ---------------------------------------------------------------------------
    type state_t is (S_IDLE, S_COMPUTE, S_FINALIZE);
    signal state     : state_t := S_IDLE;
    signal issue_idx : unsigned(TAP_IDX_WIDTH - 1 downto 0) := (others => '0');
    signal head_ptr  : unsigned(TAP_IDX_WIDTH - 1 downto 0) := (others => '0');
    -- LUTRAM-targeted storage. Initializer sets all entries to zero at
    -- configuration time (Vivado bakes this into the LUTRAM INIT attribute,
    -- which does NOT prevent distributed-RAM inference). No reset clause
    -- on this signal — that's what breaks LUTRAM inference.
    signal sample_ram : sample_array_t := (others => (others => '0'));
    signal acc      : signed(ACCUM_WIDTH - 1 downto 0) := (others => '0');
    signal result_r : signed(ACCUM_WIDTH - 1 downto 0) := (others => '0');
    signal valid_r  : std_logic := '0';

    signal read_addr : unsigned(TAP_IDX_WIDTH - 1 downto 0);
    signal read_data : signed(DATA_WIDTH - 1 downto 0);

    -- MAC pipeline registers. The sample (LUTRAM read) and its coefficient
    -- are registered before the multiply-accumulate so the DSP sees
    -- registered operands (uses its A/B input registers) and the
    -- tap_idx->read_addr->LUTRAM->DSP path no longer crosses a clock edge in
    -- one hop. Costs one extra clock of branch latency (TAPS_PER_BRANCH + 2
    -- from sample to result_valid, was +1); the polyphase filterbank's
    -- frame-complete pipeline is widened by 1 to match.
    signal read_data_r : signed(DATA_WIDTH  - 1 downto 0) := (others => '0');
    signal coeff_r     : signed(COEFF_WIDTH - 1 downto 0) := (others => '0');
    signal mac_valid   : std_logic := '0';   -- read_data_r/coeff_r hold a product
    signal issuing     : std_logic := '0';   -- still issuing LUTRAM reads

begin

    ---------------------------------------------------------------------------
    -- Async read from the circular buffer.
    -- read_addr = (head_ptr - issue_idx) mod TAPS_PER_BRANCH. The mod is
    -- explicit because TAPS_PER_BRANCH need not be a power of two.
    ---------------------------------------------------------------------------
    p_read_addr : process(head_ptr, issue_idx)
        variable diff : integer;
    begin
        diff := to_integer(head_ptr) - to_integer(issue_idx);
        if diff < 0 then
            diff := diff + TAPS_PER_BRANCH;
        end if;
        read_addr <= to_unsigned(diff, TAP_IDX_WIDTH);
    end process;

    read_data <= sample_ram(to_integer(read_addr));

    p_main : process(clk)
        variable head_next : unsigned(TAP_IDX_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            -- valid_r defaults to '0' each cycle; the S_FINALIZE branch
            -- explicitly pulses it high for one cycle.
            valid_r <= '0';

            if reset = '1' then
                state     <= S_IDLE;
                issue_idx <= (others => '0');
                head_ptr  <= (others => '0');
                acc       <= (others => '0');
                result_r  <= (others => '0');
                mac_valid <= '0';
                issuing   <= '0';
                -- NOTE: sample_ram intentionally not reset (LUTRAM inference).
            else
                case state is

                    when S_IDLE =>
                        if sample_valid = '1' then
                            -- Advance head_ptr (mod N), write new sample
                            -- at the new head position. The new sample
                            -- thus lives at the address `head_next`, which
                            -- becomes the new head_ptr after this cycle.
                            if head_ptr = TAPS_PER_BRANCH - 1 then
                                head_next := (others => '0');
                            else
                                head_next := head_ptr + 1;
                            end if;
                            sample_ram(to_integer(head_next)) <= signed(sample_in);
                            head_ptr <= head_next;
                            -- Prime the MAC pipeline. issue_idx walks the taps;
                            -- the first product is not ready to accumulate yet.
                            acc       <= (others => '0');
                            issue_idx <= (others => '0');
                            mac_valid <= '0';
                            issuing   <= '1';
                            state     <= S_COMPUTE;
                        end if;

                    when S_COMPUTE =>
                        -- Stage 2: accumulate the product registered last cycle.
                        if mac_valid = '1' then
                            acc <= acc + resize(read_data_r * coeff_r,
                                                ACCUM_WIDTH);
                        end if;

                        -- Stage 1: register the operands for tap issue_idx
                        -- (read_data is the LUTRAM async-read at issue_idx).
                        if issuing = '1' then
                            read_data_r <= read_data;
                            coeff_r     <= COEFFS(to_integer(issue_idx));
                            mac_valid   <= '1';
                            if issue_idx = TAPS_PER_BRANCH - 1 then
                                issuing <= '0';   -- last read issued
                            else
                                issue_idx <= issue_idx + 1;
                            end if;
                        else
                            -- All taps issued; the final product was just
                            -- accumulated this cycle (mac_valid was '1').
                            mac_valid <= '0';
                            state     <= S_FINALIZE;
                        end if;

                    when S_FINALIZE =>
                        result_r <= acc;
                        valid_r  <= '1';
                        state    <= S_IDLE;

                end case;
            end if;
        end if;
    end process p_main;

    result       <= std_logic_vector(result_r);
    result_valid <= valid_r;

end architecture rtl;
