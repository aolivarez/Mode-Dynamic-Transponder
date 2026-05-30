################################################################################
# run_fir_branch_equivalence_test.tcl
# Vivado xsim runner for the fir_branch parallel-vs-serial equivalence TB.
#
# Target: ZCU102 (xczu9eg-ffvb1156-2-e)
# DUTs:   fir_branch_parallel  and  fir_branch_serial  (side-by-side)
# Check:  bit-exact result equality at every result_valid_serial pulse
#
# USAGE
#   vivado -mode batch -source run_fir_branch_equivalence_test.tcl
################################################################################

catch {close_sim -force}
cd [file dirname [info script]]

set project_name "fir_branch_equivalence_sim"
set project_dir  "./fir_branch_equivalence_sim_project"
set part_name    "xczu9eg-ffvb1156-2-e"

if {[file exists $project_dir]} {
    file delete -force $project_dir
}

puts "========================================"
puts "FIR Branch Equivalence Testbench"
puts "Project: $project_name"
puts "Part:    $part_name (ZCU102)"
puts "========================================"

create_project $project_name $project_dir -part $part_name -force
set_property target_language    VHDL [current_project]
set_property simulator_language VHDL [current_project]

set_property -name {xsim.compile.vhdl.more_options}   -value {-2008} -objects [get_filesets sim_1]
set_property -name {xsim.elaborate.vhdl.more_options} -value {-2008} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime}            -value {0ns}   -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals}    -value {true}  -objects [get_filesets sim_1]

proc safe_add_files {fileset file_list} {
    foreach file $file_list {
        if {[file exists $file]} {
            puts "OK Adding: $file"
            add_files -fileset $fileset -norecurse $file
            set_property file_type {VHDL 2008} [get_files $file]
        } else {
            puts "MISSING: $file ([file normalize $file])"
            return 0
        }
    }
    return 1
}

puts "\n--- DUT sources ---"
safe_add_files sources_1 {
    ../rtl/channelizer/haifuraiya_coeffs_pkg.vhd
    ../rtl/channelizer/fir_branch_parallel.vhd
    ../rtl/channelizer/fir_branch_serial.vhd
}

puts "\n--- Testbench ---"
safe_add_files sim_1 {
    ./tb_fir_branch_equivalence.vhd
}

# Both branches read the same coefficient file at elaboration via TEXTIO.
set coeff_dst "$project_dir/$project_name.sim/sim_1/behav/xsim"
file mkdir $coeff_dst
file copy -force ./tb_fir_branch_parallel_24tap_coeffs.hex $coeff_dst
puts "\nOK Copied tb_fir_branch_parallel_24tap_coeffs.hex -> $coeff_dst"

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top tb_fir_branch_equivalence [get_filesets sim_1]
set_property top_lib work [get_filesets sim_1]

puts "\nLaunching behavioral simulation..."
if {[catch {launch_simulation -simset sim_1 -mode behavioral} result]} {
    puts "Simulation launch failed: $result"
    return
}
puts "Simulation launched."

# Budget: 48 samples (24 impulse + 24 ramp), each waits ~26 cycles for
# the serial branch + a few cycles of overhead per pulse_and_compare
# (~30 cycles each). 48 * 30 = 1440 cycles = 14.4 us. 20 us is generous.
run 20 us

puts ""
puts "Simulation complete. Grep the log for:"
puts "  EQUIVALENCE PASS  <- success"
puts "  EQUIVALENCE FAIL  <- any mismatch"
puts "  MISMATCH          <- per-sample mismatch detail (failure-gated)"
