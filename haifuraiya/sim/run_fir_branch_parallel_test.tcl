################################################################################
# run_fir_branch_parallel_test.tcl
# Vivado xsim runner for the fir_branch_parallel unit testbench.
#
# Target: ZCU102 (xczu9eg-ffvb1156-2-e)
# DUT:    fir_branch_parallel
# Tests:  positive coeffs, sample shift, latency, mixed-sign coeffs
#
# USAGE
#   vivado -mode batch -source run_fir_branch_parallel_test.tcl
#   - or -
#   In the Vivado TCL console:  source /path/to/run_fir_branch_parallel_test.tcl
################################################################################

catch {close_sim -force}
cd [file dirname [info script]]

set project_name "fir_branch_parallel_sim"
set project_dir  "./fir_branch_parallel_sim_project"
set part_name    "xczu9eg-ffvb1156-2-e"

if {[file exists $project_dir]} {
    file delete -force $project_dir
}

puts "========================================"
puts "FIR Branch Parallel Unit Testbench"
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

puts "\n--- DUT source ---"
safe_add_files sources_1 {
    ../rtl/channelizer/fir_branch_parallel.vhd
}

puts "\n--- Testbench ---"
safe_add_files sim_1 {
    ./tb_fir_branch_parallel.vhd
}

# Copy test coefficient files into the xsim working directory.
# fir_branch_parallel opens its coefficient hex file via TEXTIO at
# elaboration using a relative path, so it must be reachable from the
# xsim cwd.
set coeff_dst "$project_dir/$project_name.sim/sim_1/behav/xsim"
file mkdir $coeff_dst
foreach coeff_src {
    ./tb_fir_branch_parallel_coeffs.hex
    ./tb_fir_branch_parallel_24tap_coeffs.hex
} {
    file copy -force $coeff_src $coeff_dst
    puts "OK Copied [file tail $coeff_src] -> $coeff_dst"
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top tb_fir_branch_parallel [get_filesets sim_1]
set_property top_lib work [get_filesets sim_1]

puts "\nLaunching behavioral simulation..."
if {[catch {launch_simulation -simset sim_1 -mode behavioral} result]} {
    puts "Simulation launch failed: $result"
    return
}
puts "Simulation launched."

# Latency budget: ~3 cycles per sample. Tests 1-4 = ~5 samples total
# (~50 cycles). Test 5 = 24 samples sequenced through 24-tap delay
# line (~200 cycles, ~2 us). 5 us is generous.
run 5 us

puts ""
puts "Simulation complete. Grep the log for:"
puts "  TEST 1 PASS / TEST 2 PASS / TEST 3 PASS / TEST 4 PASS / TEST 5 PASS"
puts "  any 'FAIL' line indicates a hard failure (severity failure)."
