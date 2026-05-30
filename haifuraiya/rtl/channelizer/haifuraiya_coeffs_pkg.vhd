-- =========================================================================
-- haifuraiya_coeffs_pkg.vhd  (AUTO-GENERATED, do not edit by hand)
--
-- Source     : rtl/coeffs/haifuraiya_coeffs.hex
-- Generated  : gen_coeff_pkg.py
-- Layout     : branch-major; branch B tap T at
--              HAIFURAIYA_COEFFS_FLAT(B * TAPS_PER_BRANCH_C + T)
-- N_CHANNELS : 64
-- TAPS/BRNCH : 24
-- COEFF_W    : 16 bits
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

    constant N_CHANNELS_C      : natural := 64;
    constant TAPS_PER_BRANCH_C : natural := 24;
    constant COEFF_WIDTH_C     : natural := 16;

    type coeff_slv_array_t is array (natural range <>) of
        std_logic_vector(COEFF_WIDTH_C - 1 downto 0);

    constant HAIFURAIYA_COEFFS_FLAT : coeff_slv_array_t(
        0 to N_CHANNELS_C * TAPS_PER_BRANCH_C - 1) := (

            -- branch 0
            x"FFFB", x"FFFE", x"0004", x"FFFF", x"0001", x"0003", x"FFFA", x"000B",
            x"FFEF", x"0017", x"FFE4", x"0020", x"00D9", x"001C", x"FFE6", x"0016",
            x"FFEF", x"000C", x"FFFA", x"0003", x"0001", x"FFFF", x"0004", x"FFFE",
            -- branch 1
            x"FFFF", x"FFFE", x"0005", x"FFFF", x"0002", x"0002", x"FFFB", x"000B",
            x"FFEF", x"0017", x"FFE3", x"0024", x"00D9", x"0019", x"FFE7", x"0016",
            x"FFEF", x"000C", x"FFFA", x"0003", x"0001", x"FFFF", x"0004", x"FFFE",
            -- branch 2
            x"FFFF", x"FFFE", x"0005", x"FFFF", x"0002", x"0002", x"FFFB", x"000B",
            x"FFEF", x"0018", x"FFE2", x"0027", x"00D9", x"0016", x"FFE8", x"0015",
            x"FFEF", x"000C", x"FFF9", x"0003", x"0001", x"0000", x"0004", x"FFFE",
            -- branch 3
            x"FFFF", x"FFFE", x"0005", x"FFFF", x"0002", x"0002", x"FFFB", x"000B",
            x"FFEF", x"0018", x"FFE0", x"002B", x"00D9", x"0012", x"FFEA", x"0015",
            x"FFF0", x"000C", x"FFF9", x"0004", x"0001", x"0000", x"0004", x"FFFE",
            -- branch 4
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0002", x"0001", x"FFFB", x"000B",
            x"FFEF", x"0019", x"FFDF", x"002F", x"00D8", x"000F", x"FFEB", x"0014",
            x"FFF0", x"000C", x"FFF9", x"0004", x"0000", x"0000", x"0004", x"FFFE",
            -- branch 5
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0002", x"0001", x"FFFC", x"000A",
            x"FFEF", x"0019", x"FFDE", x"0033", x"00D7", x"000C", x"FFED", x"0013",
            x"FFF0", x"000C", x"FFF9", x"0004", x"0000", x"0000", x"0004", x"FFFE",
            -- branch 6
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0003", x"0001", x"FFFC", x"000A",
            x"FFEF", x"0019", x"FFDD", x"0037", x"00D7", x"0008", x"FFEE", x"0013",
            x"FFF0", x"000C", x"FFF9", x"0004", x"0000", x"0000", x"0004", x"FFFE",
            -- branch 7
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0003", x"0000", x"FFFC", x"000A",
            x"FFF0", x"0019", x"FFDC", x"003B", x"00D6", x"0005", x"FFF0", x"0012",
            x"FFF1", x"000C", x"FFF9", x"0005", x"0000", x"0000", x"0004", x"FFFE",
            -- branch 8
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0003", x"0000", x"FFFD", x"0009",
            x"FFF0", x"001A", x"FFDB", x"003F", x"00D5", x"0002", x"FFF1", x"0011",
            x"FFF1", x"000C", x"FFF8", x"0005", x"FFFF", x"0001", x"0004", x"FFFD",
            -- branch 9
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0003", x"0000", x"FFFD", x"0009",
            x"FFF0", x"001A", x"FFDA", x"0042", x"00D3", x"FFFF", x"FFF3", x"0010",
            x"FFF1", x"000C", x"FFF8", x"0005", x"FFFF", x"0001", x"0003", x"FFFD",
            -- branch 10
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0004", x"0000", x"FFFE", x"0009",
            x"FFF0", x"001A", x"FFD9", x"0046", x"00D2", x"FFFC", x"FFF4", x"000F",
            x"FFF2", x"000C", x"FFF8", x"0005", x"FFFF", x"0001", x"0003", x"FFFD",
            -- branch 11
            x"FFFF", x"FFFE", x"0005", x"FFFE", x"0004", x"FFFF", x"FFFE", x"0008",
            x"FFF0", x"001A", x"FFD8", x"004B", x"00D1", x"FFFA", x"FFF6", x"000F",
            x"FFF2", x"000C", x"FFF8", x"0005", x"FFFF", x"0001", x"0003", x"FFFD",
            -- branch 12
            x"FFFF", x"FFFE", x"0005", x"FFFD", x"0004", x"FFFF", x"FFFE", x"0008",
            x"FFF1", x"001A", x"FFD7", x"004F", x"00CF", x"FFF7", x"FFF7", x"000E",
            x"FFF2", x"000C", x"FFF8", x"0006", x"FFFF", x"0001", x"0003", x"FFFD",
            -- branch 13
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0004", x"FFFF", x"FFFF", x"0007",
            x"FFF1", x"001A", x"FFD6", x"0053", x"00CD", x"FFF4", x"FFF9", x"000D",
            x"FFF3", x"000C", x"FFF8", x"0006", x"FFFF", x"0001", x"0003", x"FFFD",
            -- branch 14
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0004", x"FFFE", x"FFFF", x"0007",
            x"FFF1", x"001A", x"FFD5", x"0057", x"00CC", x"FFF2", x"FFFA", x"000C",
            x"FFF3", x"000C", x"FFF8", x"0006", x"FFFE", x"0002", x"0003", x"FFFD",
            -- branch 15
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0005", x"FFFE", x"0000", x"0006",
            x"FFF2", x"001A", x"FFD5", x"005B", x"00CA", x"FFEF", x"FFFC", x"000B",
            x"FFF4", x"000B", x"FFF8", x"0006", x"FFFE", x"0002", x"0003", x"FFFE",
            -- branch 16
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0005", x"FFFE", x"0000", x"0006",
            x"FFF2", x"001A", x"FFD4", x"005F", x"00C8", x"FFED", x"FFFD", x"000A",
            x"FFF4", x"000B", x"FFF8", x"0006", x"FFFE", x"0002", x"0003", x"FFFE",
            -- branch 17
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0005", x"FFFD", x"0000", x"0005",
            x"FFF3", x"0019", x"FFD4", x"0063", x"00C5", x"FFEB", x"FFFF", x"0009",
            x"FFF5", x"000B", x"FFF8", x"0006", x"FFFE", x"0002", x"0002", x"FFFE",
            -- branch 18
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0005", x"FFFD", x"0001", x"0005",
            x"FFF3", x"0019", x"FFD3", x"0067", x"00C3", x"FFE9", x"0000", x"0009",
            x"FFF5", x"000B", x"FFF8", x"0006", x"FFFE", x"0002", x"0002", x"FFFE",
            -- branch 19
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0005", x"FFFD", x"0001", x"0004",
            x"FFF4", x"0019", x"FFD3", x"006B", x"00C1", x"FFE7", x"0002", x"0008",
            x"FFF6", x"000B", x"FFF8", x"0006", x"FFFE", x"0002", x"0002", x"FFFE",
            -- branch 20
            x"FFFF", x"FFFF", x"0005", x"FFFD", x"0005", x"FFFC", x"0002", x"0004",
            x"FFF4", x"0018", x"FFD2", x"006F", x"00BE", x"FFE5", x"0003", x"0007",
            x"FFF6", x"000A", x"FFF8", x"0006", x"FFFE", x"0003", x"0002", x"FFFE",
            -- branch 21
            x"FFFE", x"FFFF", x"0005", x"FFFD", x"0006", x"FFFC", x"0002", x"0003",
            x"FFF5", x"0018", x"FFD2", x"0073", x"00BC", x"FFE3", x"0004", x"0006",
            x"FFF7", x"000A", x"FFF8", x"0007", x"FFFD", x"0003", x"0002", x"FFFE",
            -- branch 22
            x"FFFE", x"FFFF", x"0005", x"FFFD", x"0006", x"FFFC", x"0003", x"0003",
            x"FFF6", x"0017", x"FFD2", x"0077", x"00B9", x"FFE1", x"0006", x"0005",
            x"FFF7", x"000A", x"FFF8", x"0007", x"FFFD", x"0003", x"0002", x"FFFE",
            -- branch 23
            x"FFFE", x"FFFF", x"0005", x"FFFD", x"0006", x"FFFC", x"0003", x"0002",
            x"FFF6", x"0017", x"FFD2", x"007B", x"00B6", x"FFDF", x"0007", x"0004",
            x"FFF8", x"000A", x"FFF8", x"0007", x"FFFD", x"0003", x"0002", x"FFFE",
            -- branch 24
            x"FFFE", x"0000", x"0005", x"FFFD", x"0006", x"FFFB", x"0003", x"0002",
            x"FFF7", x"0016", x"FFD2", x"007F", x"00B3", x"FFDE", x"0008", x"0003",
            x"FFF8", x"0009", x"FFF8", x"0007", x"FFFD", x"0003", x"0002", x"FFFE",
            -- branch 25
            x"FFFE", x"0000", x"0005", x"FFFD", x"0006", x"FFFB", x"0004", x"0001",
            x"FFF8", x"0016", x"FFD2", x"0083", x"00B0", x"FFDC", x"0009", x"0002",
            x"FFF9", x"0009", x"FFF8", x"0007", x"FFFD", x"0003", x"0001", x"FFFE",
            -- branch 26
            x"FFFE", x"0000", x"0005", x"FFFD", x"0006", x"FFFB", x"0004", x"0000",
            x"FFF8", x"0015", x"FFD2", x"0087", x"00AD", x"FFDB", x"000B", x"0001",
            x"FFFA", x"0009", x"FFF9", x"0007", x"FFFD", x"0003", x"0001", x"FFFE",
            -- branch 27
            x"FFFE", x"0000", x"0005", x"FFFC", x"0006", x"FFFA", x"0005", x"0000",
            x"FFF9", x"0014", x"FFD3", x"008A", x"00AA", x"FFDA", x"000C", x"0000",
            x"FFFA", x"0008", x"FFF9", x"0007", x"FFFD", x"0004", x"0001", x"FFFE",
            -- branch 28
            x"FFFE", x"0000", x"0004", x"FFFC", x"0006", x"FFFA", x"0005", x"FFFF",
            x"FFFA", x"0014", x"FFD3", x"008E", x"00A7", x"FFD9", x"000D", x"FFFF",
            x"FFFB", x"0008", x"FFF9", x"0007", x"FFFD", x"0004", x"0001", x"FFFE",
            -- branch 29
            x"FFFE", x"0000", x"0004", x"FFFD", x"0006", x"FFFA", x"0006", x"FFFF",
            x"FFFB", x"0013", x"FFD4", x"0092", x"00A4", x"FFD7", x"000E", x"FFFF",
            x"FFFB", x"0008", x"FFF9", x"0007", x"FFFD", x"0004", x"0001", x"FFFE",
            -- branch 30
            x"FFFE", x"0000", x"0004", x"FFFD", x"0007", x"FFFA", x"0006", x"FFFE",
            x"FFFB", x"0012", x"FFD4", x"0096", x"00A0", x"FFD7", x"000F", x"FFFE",
            x"FFFC", x"0007", x"FFF9", x"0007", x"FFFD", x"0004", x"0001", x"FFFE",
            -- branch 31
            x"FFFE", x"0000", x"0004", x"FFFD", x"0007", x"FFFA", x"0006", x"FFFD",
            x"FFFC", x"0011", x"FFD5", x"0099", x"009D", x"FFD6", x"0010", x"FFFD",
            x"FFFD", x"0007", x"FFF9", x"0007", x"FFFD", x"0004", x"0001", x"FFFE",
            -- branch 32
            x"FFFE", x"0001", x"0004", x"FFFD", x"0007", x"FFF9", x"0007", x"FFFD",
            x"FFFD", x"0010", x"FFD6", x"009D", x"0099", x"FFD5", x"0011", x"FFFC",
            x"FFFD", x"0006", x"FFFA", x"0007", x"FFFD", x"0004", x"0000", x"FFFE",
            -- branch 33
            x"FFFE", x"0001", x"0004", x"FFFD", x"0007", x"FFF9", x"0007", x"FFFC",
            x"FFFE", x"000F", x"FFD7", x"00A0", x"0096", x"FFD4", x"0012", x"FFFB",
            x"FFFE", x"0006", x"FFFA", x"0007", x"FFFD", x"0004", x"0000", x"FFFE",
            -- branch 34
            x"FFFE", x"0001", x"0004", x"FFFD", x"0007", x"FFF9", x"0008", x"FFFB",
            x"FFFF", x"000E", x"FFD7", x"00A4", x"0092", x"FFD4", x"0013", x"FFFB",
            x"FFFF", x"0006", x"FFFA", x"0006", x"FFFD", x"0004", x"0000", x"FFFE",
            -- branch 35
            x"FFFE", x"0001", x"0004", x"FFFD", x"0007", x"FFF9", x"0008", x"FFFB",
            x"FFFF", x"000D", x"FFD9", x"00A7", x"008E", x"FFD3", x"0014", x"FFFA",
            x"FFFF", x"0005", x"FFFA", x"0006", x"FFFC", x"0004", x"0000", x"FFFE",
            -- branch 36
            x"FFFE", x"0001", x"0004", x"FFFD", x"0007", x"FFF9", x"0008", x"FFFA",
            x"0000", x"000C", x"FFDA", x"00AA", x"008A", x"FFD3", x"0014", x"FFF9",
            x"0000", x"0005", x"FFFA", x"0006", x"FFFC", x"0005", x"0000", x"FFFE",
            -- branch 37
            x"FFFE", x"0001", x"0003", x"FFFD", x"0007", x"FFF9", x"0009", x"FFFA",
            x"0001", x"000B", x"FFDB", x"00AD", x"0087", x"FFD2", x"0015", x"FFF8",
            x"0000", x"0004", x"FFFB", x"0006", x"FFFD", x"0005", x"0000", x"FFFE",
            -- branch 38
            x"FFFE", x"0001", x"0003", x"FFFD", x"0007", x"FFF8", x"0009", x"FFF9",
            x"0002", x"0009", x"FFDC", x"00B0", x"0083", x"FFD2", x"0016", x"FFF8",
            x"0001", x"0004", x"FFFB", x"0006", x"FFFD", x"0005", x"0000", x"FFFE",
            -- branch 39
            x"FFFE", x"0002", x"0003", x"FFFD", x"0007", x"FFF8", x"0009", x"FFF8",
            x"0003", x"0008", x"FFDE", x"00B3", x"007F", x"FFD2", x"0016", x"FFF7",
            x"0002", x"0003", x"FFFB", x"0006", x"FFFD", x"0005", x"0000", x"FFFE",
            -- branch 40
            x"FFFE", x"0002", x"0003", x"FFFD", x"0007", x"FFF8", x"000A", x"FFF8",
            x"0004", x"0007", x"FFDF", x"00B6", x"007B", x"FFD2", x"0017", x"FFF6",
            x"0002", x"0003", x"FFFC", x"0006", x"FFFD", x"0005", x"FFFF", x"FFFE",
            -- branch 41
            x"FFFE", x"0002", x"0003", x"FFFD", x"0007", x"FFF8", x"000A", x"FFF7",
            x"0005", x"0006", x"FFE1", x"00B9", x"0077", x"FFD2", x"0017", x"FFF6",
            x"0003", x"0003", x"FFFC", x"0006", x"FFFD", x"0005", x"FFFF", x"FFFE",
            -- branch 42
            x"FFFE", x"0002", x"0003", x"FFFD", x"0007", x"FFF8", x"000A", x"FFF7",
            x"0006", x"0004", x"FFE3", x"00BC", x"0073", x"FFD2", x"0018", x"FFF5",
            x"0003", x"0002", x"FFFC", x"0006", x"FFFD", x"0005", x"FFFF", x"FFFE",
            -- branch 43
            x"FFFE", x"0002", x"0003", x"FFFE", x"0006", x"FFF8", x"000A", x"FFF6",
            x"0007", x"0003", x"FFE5", x"00BE", x"006F", x"FFD2", x"0018", x"FFF4",
            x"0004", x"0002", x"FFFC", x"0005", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 44
            x"FFFE", x"0002", x"0002", x"FFFE", x"0006", x"FFF8", x"000B", x"FFF6",
            x"0008", x"0002", x"FFE7", x"00C1", x"006B", x"FFD3", x"0019", x"FFF4",
            x"0004", x"0001", x"FFFD", x"0005", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 45
            x"FFFE", x"0002", x"0002", x"FFFE", x"0006", x"FFF8", x"000B", x"FFF5",
            x"0009", x"0000", x"FFE9", x"00C3", x"0067", x"FFD3", x"0019", x"FFF3",
            x"0005", x"0001", x"FFFD", x"0005", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 46
            x"FFFE", x"0002", x"0002", x"FFFE", x"0006", x"FFF8", x"000B", x"FFF5",
            x"0009", x"FFFF", x"FFEB", x"00C5", x"0063", x"FFD4", x"0019", x"FFF3",
            x"0005", x"0000", x"FFFD", x"0005", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 47
            x"FFFE", x"0003", x"0002", x"FFFE", x"0006", x"FFF8", x"000B", x"FFF4",
            x"000A", x"FFFD", x"FFED", x"00C8", x"005F", x"FFD4", x"001A", x"FFF2",
            x"0006", x"0000", x"FFFE", x"0005", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 48
            x"FFFE", x"0003", x"0002", x"FFFE", x"0006", x"FFF8", x"000B", x"FFF4",
            x"000B", x"FFFC", x"FFEF", x"00CA", x"005B", x"FFD5", x"001A", x"FFF2",
            x"0006", x"0000", x"FFFE", x"0005", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 49
            x"FFFD", x"0003", x"0002", x"FFFE", x"0006", x"FFF8", x"000C", x"FFF3",
            x"000C", x"FFFA", x"FFF2", x"00CC", x"0057", x"FFD5", x"001A", x"FFF1",
            x"0007", x"FFFF", x"FFFE", x"0004", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 50
            x"FFFD", x"0003", x"0001", x"FFFF", x"0006", x"FFF8", x"000C", x"FFF3",
            x"000D", x"FFF9", x"FFF4", x"00CD", x"0053", x"FFD6", x"001A", x"FFF1",
            x"0007", x"FFFF", x"FFFF", x"0004", x"FFFD", x"0005", x"FFFF", x"FFFF",
            -- branch 51
            x"FFFD", x"0003", x"0001", x"FFFF", x"0006", x"FFF8", x"000C", x"FFF2",
            x"000E", x"FFF7", x"FFF7", x"00CF", x"004F", x"FFD7", x"001A", x"FFF1",
            x"0008", x"FFFE", x"FFFF", x"0004", x"FFFD", x"0005", x"FFFE", x"FFFF",
            -- branch 52
            x"FFFD", x"0003", x"0001", x"FFFF", x"0005", x"FFF8", x"000C", x"FFF2",
            x"000F", x"FFF6", x"FFFA", x"00D1", x"004B", x"FFD8", x"001A", x"FFF0",
            x"0008", x"FFFE", x"FFFF", x"0004", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 53
            x"FFFD", x"0003", x"0001", x"FFFF", x"0005", x"FFF8", x"000C", x"FFF2",
            x"000F", x"FFF4", x"FFFC", x"00D2", x"0046", x"FFD9", x"001A", x"FFF0",
            x"0009", x"FFFE", x"0000", x"0004", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 54
            x"FFFD", x"0003", x"0001", x"FFFF", x"0005", x"FFF8", x"000C", x"FFF1",
            x"0010", x"FFF3", x"FFFF", x"00D3", x"0042", x"FFDA", x"001A", x"FFF0",
            x"0009", x"FFFD", x"0000", x"0003", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 55
            x"FFFD", x"0004", x"0001", x"FFFF", x"0005", x"FFF8", x"000C", x"FFF1",
            x"0011", x"FFF1", x"0002", x"00D5", x"003F", x"FFDB", x"001A", x"FFF0",
            x"0009", x"FFFD", x"0000", x"0003", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 56
            x"FFFE", x"0004", x"0000", x"0000", x"0005", x"FFF9", x"000C", x"FFF1",
            x"0012", x"FFF0", x"0005", x"00D6", x"003B", x"FFDC", x"0019", x"FFF0",
            x"000A", x"FFFC", x"0000", x"0003", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 57
            x"FFFE", x"0004", x"0000", x"0000", x"0004", x"FFF9", x"000C", x"FFF0",
            x"0013", x"FFEE", x"0008", x"00D7", x"0037", x"FFDD", x"0019", x"FFEF",
            x"000A", x"FFFC", x"0001", x"0003", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 58
            x"FFFE", x"0004", x"0000", x"0000", x"0004", x"FFF9", x"000C", x"FFF0",
            x"0013", x"FFED", x"000C", x"00D7", x"0033", x"FFDE", x"0019", x"FFEF",
            x"000A", x"FFFC", x"0001", x"0002", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 59
            x"FFFE", x"0004", x"0000", x"0000", x"0004", x"FFF9", x"000C", x"FFF0",
            x"0014", x"FFEB", x"000F", x"00D8", x"002F", x"FFDF", x"0019", x"FFEF",
            x"000B", x"FFFB", x"0001", x"0002", x"FFFE", x"0005", x"FFFE", x"FFFF",
            -- branch 60
            x"FFFE", x"0004", x"0000", x"0001", x"0004", x"FFF9", x"000C", x"FFF0",
            x"0015", x"FFEA", x"0012", x"00D9", x"002B", x"FFE0", x"0018", x"FFEF",
            x"000B", x"FFFB", x"0002", x"0002", x"FFFF", x"0005", x"FFFE", x"FFFF",
            -- branch 61
            x"FFFE", x"0004", x"0000", x"0001", x"0003", x"FFF9", x"000C", x"FFEF",
            x"0015", x"FFE8", x"0016", x"00D9", x"0027", x"FFE2", x"0018", x"FFEF",
            x"000B", x"FFFB", x"0002", x"0002", x"FFFF", x"0005", x"FFFE", x"FFFF",
            -- branch 62
            x"FFFE", x"0004", x"FFFF", x"0001", x"0003", x"FFFA", x"000C", x"FFEF",
            x"0016", x"FFE7", x"0019", x"00D9", x"0024", x"FFE3", x"0017", x"FFEF",
            x"000B", x"FFFB", x"0002", x"0002", x"FFFF", x"0005", x"FFFE", x"FFFF",
            -- branch 63
            x"FFFE", x"0004", x"FFFF", x"0001", x"0003", x"FFFA", x"000C", x"FFEF",
            x"0016", x"FFE6", x"001C", x"00D9", x"0020", x"FFE4", x"0017", x"FFEF",
            x"000B", x"FFFA", x"0003", x"0001", x"FFFF", x"0004", x"FFFE", x"FFFB"
        );

    end package;
