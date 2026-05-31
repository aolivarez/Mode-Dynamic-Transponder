# Simulation - Haifuraiya

Vivado xsim testbenches and runners for the 64-channel polyphase
channelizer. All tests are self-checking; pass/fail is asserted from
inside the testbench.

## Testbenches and runners

| Runner (`source` from `haifuraiya/sim/`) | Testbench | What it verifies |
|------------------------------------------|-----------|------------------|
| `run_haifuraiya_channelizer_test.tcl`    | `tb_haifuraiya_channelizer_top.vhd` | End-to-end channelizer: smoke, DC bin, swept tones (k=4, 16, 28, 40), off-bin energy split, adjacent-channel rejection, OPV-like carrier capture. |
| `run_fft_n_pt_sdf_test.tcl`              | `tb_fft_n_pt_sdf.vhd`               | SDF-vs-iterative FFT bit-exact equivalence: DC, impulse, complex tone @ bin 8, pseudo-random complex input. |
| `run_fir_branch_equivalence_test.tcl`    | `tb_fir_branch_equivalence.vhd`     | Parallel-vs-serial FIR branch equivalence: 24-tap impulse response and mixed-input sweep. |
| `run_fir_branch_parallel_test.tcl`       | `tb_fir_branch_parallel.vhd`        | Standalone parallel-branch smoke (predecessor to the equivalence TB; retained for isolated debug). |

## How to run

From the Vivado xsim Tcl Console:

```
cd haifuraiya/sim
source run_haifuraiya_channelizer_test.tcl
```

Or in batch mode:

```
vivado -mode batch -nojournal -nolog -source run_haifuraiya_channelizer_test.tcl
```

Each runner creates its own throwaway project (`*_sim_project/`) so the
runners don't collide. Build artifacts (`*_sim_project/`, `xvhdl.*`,
project logs) are gitignored.

## VHDL standard

Testbenches use VHDL-2008 (chiefly the predefined `integer_vector`
type). The synth-bound RTL underneath is pure VHDL-93 — using 2008 in
the testbenches does not constrain the design's portability to
VHDL-93-only toolchains (e.g. OpenCPI).

## Bit-exact equivalence as the safety net

Every architectural change to the channelizer is validated by running
the relevant equivalence TB and checking for **0 LSB peak per-bin
difference**:

- The serial FIR replacement and any later FIR pipelining ->
  `run_fir_branch_equivalence_test.tcl`.
- The SDF FFT and any later FFT pipelining ->
  `run_fft_n_pt_sdf_test.tcl`.
- Top-level integration (filterbank + FFT + P2S) ->
  `run_haifuraiya_channelizer_test.tcl`.

That pattern is what allowed the recent timing-closure work (SDF
butterfly pipelining, serial-MAC pipelining) to be added without
risking the FFT's correctness: the feedback paths were left untouched,
the forward paths gained pipeline registers, and both equivalence TBs
stayed at 0 LSB.

## Test-data files

`tb_fir_branch_parallel_*coeffs.hex` are testbench-local coefficient
sets held over from when the FIR branches read coefficients via TEXTIO.
The branches now embed their coefficients via `haifuraiya_coeffs_pkg.vhd`
(see [`../rtl/coeffs/`](../rtl/coeffs/)); the `.hex` files remain only
as legacy data for the parallel-branch standalone TB.
