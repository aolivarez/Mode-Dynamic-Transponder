################################################################################
# run_fft_n_pt_sdf_test.tcl
# Vivado xsim runner for the SDF-vs-iterative FFT equivalence testbench.
################################################################################

catch {close_sim -force}
cd [file dirname [info script]]

set project_name "fft_n_pt_sdf_sim"
set project_dir  "./fft_n_pt_sdf_sim_project"
set part_name    "xczu9eg-ffvb1156-2-e"

if {[file exists $project_dir]} {
    file delete -force $project_dir
}

puts "========================================"
puts "SDF FFT vs Iterative FFT Equivalence"
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

puts "\n--- Package ---"
safe_add_files sources_1 {
    ../rtl/channelizer/fft_pkg.vhd
}

puts "\n--- DUT sources ---"
safe_add_files sources_1 {
    ../rtl/channelizer/fft_n_pt.vhd
    ../rtl/channelizer/sdf_stage.vhd
    ../rtl/channelizer/fft_n_pt_sdf.vhd
}

puts "\n--- Testbench ---"
safe_add_files sim_1 {
    ./tb_fft_n_pt_sdf.vhd
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top tb_fft_n_pt_sdf [get_filesets sim_1]
set_property top_lib work [get_filesets sim_1]

puts "\nLaunching behavioral simulation..."
if {[catch {launch_simulation -simset sim_1 -mode behavioral} result]} {
    puts "Simulation launch failed: $result"
    return
}
puts "Simulation launched."

# 4 tests x ~500 cycles each (132 input + 350 settle) = ~2000 cycles = 20 us.
# 50 us is generous.
run 50 us

puts ""
puts "Simulation complete. Grep the log for:"
puts "  Test N PASS / Test N FAIL"
puts "  peak per-bin diff = ..."
puts "  MISMATCH bin K  <- per-bin detail (failure-gated)"
