#!/usr/bin/env python3
"""
gen_coeff_pkg.py

Convert a 4-hex-digit-per-line coefficient .hex into a VHDL-93 package that
embeds every coefficient as a std_logic_vector aggregate. Eliminates the
TEXTIO file-open at elaboration in fir_branch_*.vhd, so the design can be
synthesized in flows (OpenCPI) that don't propagate file context.

Layout matches the original branch-major .hex:
    branch B tap T is at HAIFURAIYA_COEFFS_FLAT(B * TAPS_PER_BRANCH + T)

Usage:
    python3 gen_coeff_pkg.py \\
        --in  haifuraiya_coeffs.hex \\
        --out ../channelizer/haifuraiya_coeffs_pkg.vhd \\
        --n-channels 64 --taps-per-branch 24 --coeff-width 16
"""

import argparse
import os
import sys
import textwrap


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--in",  dest="in_path",  required=True)
    p.add_argument("--out", dest="out_path", required=True)
    p.add_argument("--n-channels",      type=int, default=64)
    p.add_argument("--taps-per-branch", type=int, default=24)
    p.add_argument("--coeff-width",     type=int, default=16)
    args = p.parse_args()

    hex_chars = args.coeff_width // 4
    if hex_chars * 4 != args.coeff_width:
        sys.exit("coeff-width must be a multiple of 4 for hex literals")

    expected = args.n_channels * args.taps_per_branch

    with open(args.in_path) as f:
        lines = [ln.strip() for ln in f if ln.strip()]

    if len(lines) != expected:
        sys.exit(f"{args.in_path}: expected {expected} entries, got {len(lines)}")

    for i, ln in enumerate(lines):
        if len(ln) != hex_chars:
            sys.exit(f"{args.in_path}:{i+1}: '{ln}' is not {hex_chars} hex chars")
        try:
            int(ln, 16)
        except ValueError:
            sys.exit(f"{args.in_path}:{i+1}: '{ln}' is not valid hex")

    src = os.path.basename(args.in_path)
    out_lines = []
    out_lines.append(textwrap.dedent(f"""\
        -- =========================================================================
        -- haifuraiya_coeffs_pkg.vhd  (AUTO-GENERATED, do not edit by hand)
        --
        -- Source     : rtl/coeffs/{src}
        -- Generated  : gen_coeff_pkg.py
        -- Layout     : branch-major; branch B tap T at
        --              HAIFURAIYA_COEFFS_FLAT(B * TAPS_PER_BRANCH_C + T)
        -- N_CHANNELS : {args.n_channels}
        -- TAPS/BRNCH : {args.taps_per_branch}
        -- COEFF_W    : {args.coeff_width} bits
        --
        -- Replaces the elaboration-time TEXTIO load used by the old
        -- fir_branch_*.vhd files. Embedding the coefficients as a
        -- VHDL-93 std_logic_vector aggregate lets the design synthesize
        -- under tool flows that don't pass file context to the elaborator
        -- (notably OpenCPI HDL workers).
        -- =========================================================================

        library ieee;
        use ieee.std_logic_1164.all;

        package haifuraiya_coeffs_pkg is

            constant N_CHANNELS_C      : natural := {args.n_channels};
            constant TAPS_PER_BRANCH_C : natural := {args.taps_per_branch};
            constant COEFF_WIDTH_C     : natural := {args.coeff_width};

            type coeff_slv_array_t is array (natural range <>) of
                std_logic_vector(COEFF_WIDTH_C - 1 downto 0);

            constant HAIFURAIYA_COEFFS_FLAT : coeff_slv_array_t(
                0 to N_CHANNELS_C * TAPS_PER_BRANCH_C - 1) := (
        """))

    # Emit the aggregate body, 8 coefficients per line for readability.
    per_line = 8
    for branch in range(args.n_channels):
        out_lines.append(f"            -- branch {branch}")
        slice_start = branch * args.taps_per_branch
        slice_end   = slice_start + args.taps_per_branch
        for chunk_start in range(slice_start, slice_end, per_line):
            chunk = lines[chunk_start : chunk_start + per_line]
            tail_idx = chunk_start + len(chunk) - 1
            is_last = (tail_idx == expected - 1)
            sep = ", " if not is_last else "  "
            parts = [f'x"{c}"' for c in chunk]
            # Trailing comma between items, except after the very last item.
            joined = ", ".join(parts)
            if not is_last:
                joined += ","
            out_lines.append(f"            {joined}")

    out_lines.append("        );")
    out_lines.append("")
    out_lines.append("    end package;")
    out_lines.append("")

    out_text = "\n".join(out_lines)
    with open(args.out_path, "w") as f:
        f.write(out_text)
    print(f"Wrote {args.out_path}: {expected} entries "
          f"({args.n_channels} branches x {args.taps_per_branch} taps)")


if __name__ == "__main__":
    main()
