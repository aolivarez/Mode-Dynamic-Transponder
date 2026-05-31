# Haifuraiya Filter Coefficients

Prototype-filter coefficients for the 64-channel polyphase channelizer:
1,536 entries = 64 channels x 24 taps per branch, 16-bit signed Q1.14
(stored as 4-hex-digit lines, branch-major).

## Files

| File | Role |
|------|------|
| `haifuraiya_coeffs.hex`           | Source of truth: one coefficient per line, branch-major. Branch *b* tap *t* is on line *b*&nbsp;`*`&nbsp;24&nbsp;`+`&nbsp;*t*. |
| `gen_coeff_pkg.py`                | Generator: reads the `.hex`, emits the VHDL coefficient package. |
| `../channelizer/haifuraiya_coeffs_pkg.vhd` | Generated VHDL-93 package consumed by the FIR branches. |

## Why a package, not TEXTIO?

The earlier design read each branch's slice from `haifuraiya_coeffs.hex`
at elaboration time via `std.textio` / `ieee.std_logic_textio` (`hread`).
That works for Vivado simulation/synthesis but breaks OpenCPI's
synth flow, which does not propagate file context to the elaborator.
Embedding the coefficients in a generated VHDL-93 package eliminates the
file dependency entirely while staying VHDL-93-compatible.

## Regenerating the package

When you change `haifuraiya_coeffs.hex`, regenerate the package and
commit the result alongside it:

```
python3 gen_coeff_pkg.py \
    --in  haifuraiya_coeffs.hex \
    --out ../channelizer/haifuraiya_coeffs_pkg.vhd \
    --n-channels 64 --taps-per-branch 24 --coeff-width 16
```

The script validates that the `.hex` has exactly `N x TAPS` 4-digit lines
before writing.

## Cross-reference

The MDT-SIC coefficients live separately at
[`../../../mdt_sic/rtl/coeffs/mdt_coeffs.hex`](../../../mdt_sic/rtl/coeffs/).
