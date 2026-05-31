# RTL - Haifuraiya

Synthesizable VHDL for the Haifuraiya 64-channel polyphase channelizer,
the Opulent Voice ground-station front end. Vendor-agnostic design (no
Xilinx LogiCORE IP), pure VHDL-93 (no 2008 features in synth-bound RTL).
Tested-clean on ZCU102 (Zynq UltraScale+) and libresdr (Zynq-7020).

## Architecture

Production path: **serial-MAC polyphase filterbank + single pipelined R2SDF
FFT.** The parallel-MAC filterbank and the iterative FFT are retained
alongside as reference implementations for the equivalence testbenches.

- **Serial FIR branch** (`fir_branch_serial`): one DSP time-multiplexed
  across `TAPS_PER_BRANCH` taps (versus a parallel MAC per tap). Delay
  line is a circular buffer that infers distributed RAM (LUTRAM).
- **Polyphase filterbank** (`polyphase_filterbank_serial`): 64 branches
  + commutator; one instance per I and Q path.
- **R2SDF FFT** (`fft_n_pt_sdf` / `sdf_stage`): streaming Radix-2
  Single-path Delay Feedback FFT, 6 stages. One FFT sustains the
  filterbank frame rate (replaces the earlier dual iterative FFTs).
- **Top wrapper** (`haifuraiya_channelizer_top`): I/Q filterbanks ->
  parallel-to-serial adapter -> single SDF FFT -> channel output stream.

```
haifuraiya/rtl/
├── channelizer/
│   ├── fft_pkg.vhd                       # clog2, bit_reverse helpers
│   ├── fft_n_pt.vhd                      # iterative DIF FFT (reference)
│   ├── sdf_stage.vhd                     # one R2SDF butterfly + FIFO + twiddle multiplier
│   ├── fft_n_pt_sdf.vhd                  # 6-stage pipelined R2SDF FFT (production)
│   ├── fir_branch_parallel.vhd           # 24 parallel MACs/branch (reference)
│   ├── fir_branch_serial.vhd             # 1 time-shared MAC/branch (production)
│   ├── polyphase_filterbank_parallel.vhd # filterbank from parallel branches (reference)
│   ├── polyphase_filterbank_serial.vhd   # filterbank from serial branches (production)
│   ├── haifuraiya_coeffs_pkg.vhd         # generated coefficient package
│   └── haifuraiya_channelizer_top.vhd    # I/Q filterbanks + P2S + single SDF FFT
└── coeffs/
    ├── haifuraiya_coeffs.hex             # 1536 coefficients (64 ch x 24 taps)
    └── gen_coeff_pkg.py                  # .hex -> haifuraiya_coeffs_pkg.vhd
```

## Coefficients

Both serial and parallel branches `use work.haifuraiya_coeffs_pkg.all`
and pull their 24-tap slice from the embedded flat constant array. There
is **no elaboration-time TEXTIO** -- the package is generated once from
`coeffs/haifuraiya_coeffs.hex` by `coeffs/gen_coeff_pkg.py` and committed
alongside the RTL. Regenerate it when the `.hex` changes. See
[`coeffs/README.md`](coeffs/README.md).

## Configuration

| Parameter         | Value           |
|-------------------|-----------------|
| Channels (N)      | 64              |
| Taps per branch   | 24              |
| Decimation (M)    | 16 (4x oversampled) |
| Sample width      | 16 bits (Q1.14) |
| Coefficient width | 16 bits (Q1.14) |
| Accumulator width | 40 bits         |
| FFT size          | 64-point        |

## Resources (post-refactor, ZCU102 OOC)

| Resource | Used | Available | % |
|----------|-----:|----------:|--:|
| DSP48E2  |  168 |     2520  |  6.7 |
| LUT      | ~13k |     274k  |  4.7 |
| FF       | ~23k |     548k  |  4.2 |
| BRAM     |    0 |      912  |  0   |

On Zynq-7020 (DSP48E1) the channelizer uses ~176 DSPs; LUT/FF are
comparable. The smaller DSP48E1 multiplier needs more cascaded DSPs for
the 40x16 twiddle multiply than DSP48E2.

## Build

**Simulation** ([`../sim/`](../sim/)):

- `run_haifuraiya_channelizer_test.tcl` -- 6-test top-level integration
  (smoke, DC, swept tones, off-bin split, alias rejection, carrier
  capture).
- `run_fft_n_pt_sdf_test.tcl` -- SDF-vs-iterative FFT equivalence (bit
  exact).
- `run_fir_branch_equivalence_test.tcl` -- parallel-vs-serial FIR branch
  equivalence.
- `run_fir_branch_parallel_test.tcl` -- standalone parallel-branch
  smoke.

Run from the Vivado xsim Tcl Console: `cd haifuraiya/sim && source <runner>.tcl`.

**Synthesis** ([`../syn/zcu102/`](../syn/zcu102/)):
`synth_haifuraiya_channelizer.tcl` -- OOC synth targeting ZCU102, writes
utilization and timing reports.

**OpenCPI**: the same RTL (plus a thin worker wrapper) hosts the design
as an OpenCPI HDL worker. The TEXTIO removal and VHDL-93 cleanup were
done specifically so the channelizer builds under OpenCPI's VHDL-93
flow without modification.
