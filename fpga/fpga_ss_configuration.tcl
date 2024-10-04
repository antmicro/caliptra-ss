# Create path variables
set fpgaDir [file dirname [info script]]
set outputDir $fpgaDir/caliptra_build
set packageDir $outputDir/caliptra_package
set adapterDir $outputDir/soc_adapter_package
# Clean and create output directory.
file delete -force $outputDir
file mkdir $outputDir
file mkdir $packageDir
file mkdir $adapterDir

# Simplistic processing of command line arguments to enable different features
# Defaults:
set BUILD FALSE
set GUI   FALSE
set JTAG  TRUE
set ITRNG TRUE
set CG_EN FALSE
set RTL_VERSION latest
foreach arg $argv {
    regexp {(.*)=(.*)} $arg fullmatch option value
    set $option "$value"
}
# If VERSION was not set by tclargs, set it from the commit ID.
# This assumes it is run from within caliptra-sw. If building from outside caliptra-sw call with "VERSION=[hex number]"
if {[info exists VERSION] == 0} {
  set VERSION [exec git rev-parse --short HEAD]
}

# Path to rtl
set 3ptDir $fpgaDir/../third_party
set clptraDir $3ptDir/caliptra-rtl
set veerDir $3ptDir/Cores-VeeR-EL2
set i3cDir $3ptDir/i3c-core
puts "JTAG: $JTAG"
puts "ITRNG: $ITRNG"
puts "CG_EN: $CG_EN"
puts "RTL_VERSION: $RTL_VERSION"
puts "Using RTL directory $clptraDir"

# Set Verilog defines for:
#     Caliptra clock gating module
#     VEER clock gating module
#     VEER core FPGA optimizations (disables clock gating)
if {$CG_EN} {
  set VERILOG_OPTIONS {TECH_SPECIFIC_ICG USER_ICG=fpga_real_icg TECH_SPECIFIC_EC_RV_ICG USER_EC_RV_ICG=fpga_rv_clkhdr}
  set GATED_CLOCK_CONVERSION auto
} else {
  set VERILOG_OPTIONS {TECH_SPECIFIC_ICG USER_ICG=fpga_fake_icg RV_FPGA_OPTIMIZE TEC_RV_ICG=clockhdr}
  set GATED_CLOCK_CONVERSION off
}
if {$ITRNG} {
  # Add option to use Caliptra's internal TRNG instead of ETRNG
  lappend VERILOG_OPTIONS CALIPTRA_INTERNAL_TRNG
}

# Start the Vivado GUI for interactive debug
if {$GUI} {
  start_gui
}

# Create a project to package Caliptra.
# Packaging Caliptra allows Vivado to recognize the APB bus as an endpoint for the memory map.
create_project caliptra_package_project $outputDir -part xczu7ev-ffvc1156-2-e

# Generate ROM
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name fpga_imem -dir $outputDir
set_property -dict [list \
  CONFIG.Memory_Type {True_Dual_Port_RAM} \
  CONFIG.Write_Depth_A {6144} \
  CONFIG.Write_Width_A {64} \
  CONFIG.Write_Width_B {32} \
  CONFIG.Use_RSTB_Pin {true} \
  CONFIG.Byte_Size {8} \
  CONFIG.Use_Byte_Write_Enable {true} \
  CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
  CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
] [get_ips fpga_imem]

# Generate Mailbox RAM. 128K
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name fpga_mbox_ram -dir $outputDir
set_property -dict [list \
  CONFIG.Memory_Type {Single_Port_RAM} \
  CONFIG.Write_Depth_A {32768} \
  CONFIG.Write_Width_A {39} \
  CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
] [get_ips fpga_mbox_ram]

# Generate ECC TDP File
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name fpga_ecc_ram_tdp_file -dir $outputDir
set_property -dict [list \
  CONFIG.Memory_Type {True_Dual_Port_RAM} \
  CONFIG.Write_Depth_A {64} \
  CONFIG.Write_Width_A {384} \
  CONFIG.Write_Width_B {384} \
  CONFIG.Use_RSTA_Pin {true} \
  CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
  CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
] [get_ips fpga_ecc_ram_tdp_file]

# Create FIFO for fake UART communication
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name log_fifo -dir $outputDir
set_property -dict [list \
  CONFIG.Input_Data_Width {8} \
  CONFIG.Input_Depth {8192} \
  CONFIG.Performance_Options {First_Word_Fall_Through} \
  CONFIG.Full_Threshold_Assert_Value {7168} \
  CONFIG.Programmable_Full_Type {Single_Programmable_Full_Threshold_Constant} \
] [get_ips log_fifo]

# Create FIFO for ITRNG data
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name itrng_fifo -dir $outputDir
set_property -dict [list \
  CONFIG.Input_Data_Width {32} \
  CONFIG.Input_Depth {1024} \
  CONFIG.Output_Data_Width {4} \
  CONFIG.Overflow_Flag {false} \
  CONFIG.Valid_Flag {true} \
  CONFIG.asymmetric_port_width {true} \
] [get_ips itrng_fifo]

set_property verilog_define $VERILOG_OPTIONS [current_fileset]

# Add VEER Headers
add_files $clptraDir/src/riscv_core/veer_el2/rtl/el2_param.vh
add_files $clptraDir/src/riscv_core/veer_el2/rtl/pic_map_auto.h
add_files $clptraDir/src/riscv_core/veer_el2/rtl/el2_pdef.vh

# Add VEER sources
add_files [ glob $clptraDir/src/riscv_core/veer_el2/rtl/*.sv ]
add_files [ glob $clptraDir/src/riscv_core/veer_el2/rtl/*/*.sv ]
add_files [ glob $clptraDir/src/riscv_core/veer_el2/rtl/*/*.v ]

# Add Caliptra Headers
add_files [ glob $clptraDir/src/*/rtl/*.svh ]
# Add Caliptra Sources
add_files [ glob $clptraDir/src/*/rtl/*.sv ]
add_files [ glob $clptraDir/src/*/rtl/*.v ]

# Add Caliptra Subsystem Headers
add_files [ glob $fpgaDir/../src/mcu/rtl/*.svh]
# Add Caliptra Subsystem files
add_files [ glob $fpgaDir/../src/mcu/rtl/*.sv]

# Remove Caliptra files that need to be replaced by FPGA specific versions
# Replace RAM with FPGA block ram
remove_files $clptraDir/src/ecc/rtl/ecc_ram_tdp_file.sv
# Key Vault is very large. Replacing KV with a version with the minimum number of entries.
remove_files $clptraDir/src/keyvault/rtl/kv_reg.sv

# Add I3C sources
add_files [ glob $i3cDir/src/libs/*/*.sv]
add_files [ glob $i3cDir/src/libs/*.sv]
add_files $i3cDir/src/csr/I3CCSR_pkg.sv
add_files $i3cDir/src/csr/I3CCSR.sv
add_files [ glob $i3cDir/src/hci/*.sv]
add_files [ glob $i3cDir/src/hci/*/*.sv]
add_files [ glob $i3cDir/src/phy/*.sv]
add_files [ glob $i3cDir/src/ctrl/*.sv]
add_files [ glob $i3cDir/src/recovery/*.sv]

add_files [ glob $i3cDir/src/*.sv]
add_files [ glob $i3cDir/src/*.svh]

# Add FPGA specific sources
add_files [ glob $fpgaDir/src/*.sv]
add_files [ glob $fpgaDir/src/*.v]

# Mark all Verilog sources as SystemVerilog because some of them have SystemVerilog syntax.
set_property file_type SystemVerilog [get_files *.v]

# Exception: caliptra_ss_package_top.v needs to be Verilog to be included in a Block Diagram.
set_property file_type Verilog [get_files  $fpgaDir/src/caliptra_ss_package_top.v]

# Add include paths
set_property include_dirs $clptraDir/src/integration/rtl [current_fileset]
set_property include_dirs $clptraDir/src/keyvault/rtl [current_fileset]

add_files $clptraDir/src/keyvault/rtl/kv_macros.svh

# Set global defines
set file "kv_macros.svh"
puts "FILE: $file"
set file_obj [get_files -of_objects [current_fileset] [list "*$file"]]
set_property -name "is_global_include" -value "1" -objects $file_obj

set file "config_defines_mcu.svh"
puts "FILE: $file"
set file_obj [get_files -of_objects [current_fileset] [list "*$file"]]
set_property -name "is_global_include" -value "1" -objects $file_obj

set file "config_defines.svh"
puts "FILE: $file"
set file_obj [get_files -of_objects [current_fileset] [list "*$file"]]
set_property -name "is_global_include" -value "1" -objects $file_obj

set file "caliptra_sva.svh"
puts "FILE: $file"
set file_obj [get_files -of_objects [current_fileset] [list "*$file"]]
set_property -name "is_global_include" -value "1" -objects $file_obj

# Set caliptra_ss_package_top as top in case next steps fail so that the top is something useful.
set_property top caliptra_ss_package_top [current_fileset]

# Create block diagram that includes an instance of caliptra_ss_package_top
create_bd_design "caliptra_package_bd"
create_bd_cell -type module -reference caliptra_ss_package_top caliptra_ss_package_top_0
save_bd_design
close_bd_design [get_bd_designs caliptra_package_bd]

# Package IP
ipx::package_project -root_dir $packageDir -vendor design -library user -taxonomy /UserIP -import_files -set_current false
ipx::unload_core $packageDir/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $packageDir $packageDir/component.xml
ipx::infer_bus_interfaces xilinx.com:interface:apb_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interfaces xilinx.com:interface:bram_rtl:1.0 [ipx::current_core]
ipx::associate_bus_interfaces -busif S_AXI0 -clock core_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif S_AXI1 -clock core_clk [ipx::current_core]
set_property core_revision 1 [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]

# Close temp project
close_project
# Close caliptra_package_project
close_project

# Packaging complete

# Create a project for the SOC connections
create_project caliptra_fpga_project $outputDir -part xczu7ev-ffvc1156-2-e

# Include the packaged IP
set_property  ip_repo_paths  "$packageDir $adapterDir" [current_project]
update_ip_catalog

# Create SOC block design
create_bd_design "caliptra_fpga_project_bd"

# Add Caliptra package
create_bd_cell -type ip -vlnv design:user:caliptra_ss_package_top:1.0 caliptra_ss_package_top_0

# Add Zynq PS
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0
set_property -dict [list \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {20} \
  CONFIG.PSU__USE__IRQ0 {1} \
  CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {5} \
] [get_bd_cells zynq_ultra_ps_e_0]

# Add AXI Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property CONFIG.NUM_MI {5} [get_bd_cells axi_interconnect_0]

# Add AXI APB Bridge for Caliptra
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_apb_bridge:3.0 axi_apb_bridge_0
set_property -dict [list \
  CONFIG.C_APB_NUM_SLAVES {2} \
  CONFIG.C_M_APB_PROTOCOL {apb4} \
] [get_bd_cells axi_apb_bridge_0]

# Add AXI BRAM Controller for backdoor access to IMEM
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells axi_bram_ctrl_0]

# Add AXI BRAM Controller for backdoor access to IMEM
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_1
set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells axi_bram_ctrl_1]

# Create reset block
# Create instance: proc_sys_reset_0, and set properties
set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]
# create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

# Move blocks around on the block diagram. This step is optional.
set_property location {1 240 310} [get_bd_cells zynq_ultra_ps_e_0]
set_property location {2 720 290} [get_bd_cells axi_interconnect_0]
set_property location {2 720 580} [get_bd_cells proc_sys_reset_0]
set_property location {3 1050 310} [get_bd_cells axi_apb_bridge_0]
set_property location {3 1050 450} [get_bd_cells axi_bram_ctrl_0]
set_property location {3 1050 590} [get_bd_cells axi_bram_ctrl_0]
set_property location {4 1350 360} [get_bd_cells caliptra_ss_package_top_0]

# Create interface connections
connect_bd_intf_net -intf_net axi_apb_bridge_0_APB_M [get_bd_intf_pins axi_apb_bridge_0/APB_M] [get_bd_intf_pins caliptra_ss_package_top_0/s_apb0]
connect_bd_intf_net -intf_net axi_apb_bridge_0_APB_M2 [get_bd_intf_pins axi_apb_bridge_0/APB_M2] [get_bd_intf_pins caliptra_ss_package_top_0/s_apb1]
connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins caliptra_ss_package_top_0/axi0_bram]
connect_bd_intf_net -intf_net axi_bram_ctrl_1_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTA] [get_bd_intf_pins caliptra_ss_package_top_0/axi1_bram]
connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins caliptra_ss_package_top_0/S_AXI0] -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M00_AXI]
connect_bd_intf_net -intf_net axi_interconnect_0_M01_AXI [get_bd_intf_pins caliptra_ss_package_top_0/S_AXI1] -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M01_AXI]
connect_bd_intf_net -intf_net axi_interconnect_0_M02_AXI [get_bd_intf_pins axi_apb_bridge_0/AXI4_LITE] [get_bd_intf_pins axi_interconnect_0/M02_AXI]
connect_bd_intf_net -intf_net axi_interconnect_0_M03_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M03_AXI]
connect_bd_intf_net -intf_net axi_interconnect_0_M04_AXI [get_bd_intf_pins axi_bram_ctrl_1/S_AXI] -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M04_AXI]
connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_LPD [get_bd_intf_pins axi_interconnect_0/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD]

# Create port connections
connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_apb_bridge_0/s_axi_aresetn] [get_bd_pins axi_interconnect_0/M02_ARESETN] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_interconnect_0/M03_ARESETN] [get_bd_pins axi_bram_ctrl_1/s_axi_aresetn] [get_bd_pins axi_interconnect_0/M04_ARESETN] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins caliptra_ss_package_top_0/S_AXI0_ARESETN] [get_bd_pins caliptra_ss_package_top_0/S_AXI1_ARESETN]
connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_apb_bridge_0/s_axi_aclk] [get_bd_pins axi_interconnect_0/M02_ACLK] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_interconnect_0/M03_ACLK] [get_bd_pins axi_bram_ctrl_1/s_axi_aclk] [get_bd_pins axi_interconnect_0/M04_ACLK] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] [get_bd_pins caliptra_ss_package_top_0/core_clk]
connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins proc_sys_reset_0/ext_reset_in]

# Create address segments
assign_bd_address -offset 0x80000000 -range 0x00002000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs caliptra_ss_package_top_0/S_AXI0/reg0] -force
assign_bd_address -offset 0x80002000 -range 0x00002000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs caliptra_ss_package_top_0/S_AXI1/reg0] -force
assign_bd_address -offset 0x82000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
assign_bd_address -offset 0x82020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] -force
assign_bd_address -offset 0x90000000 -range 0x00100000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs caliptra_ss_package_top_0/s_apb0/Reg] -force
assign_bd_address -offset 0x90200000 -range 0x00100000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs caliptra_ss_package_top_0/s_apb1/Reg] -force

if {$JTAG} {
  # Connect JTAG signals to PS GPIO pins
  connect_bd_net [get_bd_pins caliptra_ss_package_top_0/jtag_out] [get_bd_pins zynq_ultra_ps_e_0/emio_gpio_i]
  connect_bd_net [get_bd_pins caliptra_ss_package_top_0/jtag_in]  [get_bd_pins zynq_ultra_ps_e_0/emio_gpio_o]

  # Add constraints for JTAG signals
  add_files -fileset constrs_1 $fpgaDir/src/jtag_constraints.xdc
} else {
  # Tie off JTAG inputs
  create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
  connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins caliptra_ss_package_top_0/jtag_tck]
  connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins caliptra_ss_package_top_0/jtag_tms]
  connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins caliptra_ss_package_top_0/jtag_tdi]
  connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins caliptra_ss_package_top_0/jtag_trst_n]
}

# Create IO ports for I3C
create_bd_port -dir IO i3c_scl_io
connect_bd_net [get_bd_pins /caliptra_ss_package_top_0/i3c_scl_io] [get_bd_ports i3c_scl_io]
create_bd_port -dir IO i3c_sda_io
connect_bd_net [get_bd_pins /caliptra_ss_package_top_0/i3c_sda_io] [get_bd_ports i3c_sda_io]

# Add I3C constrains with IO placement & standard
add_files -fileset constrs_1 $fpgaDir/src/i3c_constraints.xdc

save_bd_design
set_property verilog_define $VERILOG_OPTIONS [current_fileset]

# Create the HDL wrapper for the block design and add it. This will be set as top.
make_wrapper -files [get_files $outputDir/caliptra_fpga_project.srcs/sources_1/bd/caliptra_fpga_project_bd/caliptra_fpga_project_bd.bd] -top
add_files -norecurse $outputDir/caliptra_fpga_project.gen/sources_1/bd/caliptra_fpga_project_bd/hdl/caliptra_fpga_project_bd_wrapper.v

update_compile_order -fileset sources_1

# Assign the gated clock conversion setting in the caliptra_ss_package_top out of context run.
create_ip_run [get_files *.bd]
set_property STEPS.SYNTH_DESIGN.ARGS.GATED_CLOCK_CONVERSION $GATED_CLOCK_CONVERSION [get_runs caliptra_fpga_project_bd_caliptra_ss_package_top_0_0_synth_1]

# The FPGA loading methods currently in use require the bin file to be generated.
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

# Start build
if {$BUILD} {
  launch_runs synth_1 -jobs 4
  wait_on_runs synth_1
  launch_runs impl_1 -jobs 4
  wait_on_runs impl_1
  open_run impl_1
  report_utilization -file $outputDir/utilization.txt
  # Embed git hash in USR_ACCESS register for bitstream identification.
  set_property BITSTREAM.CONFIG.USR_ACCESS 0x$VERSION [current_design]
  write_bitstream -bin_file $outputDir/caliptra_ss_fpga
}
