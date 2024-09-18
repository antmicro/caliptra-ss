# Caliptra Subsystem FPGA Setup
Setup based on https://github.com/chipsalliance/caliptra-sw/tree/main/hw/fpga.

## Requirements
 - Vivado
   - Tested with v2023.2
 - FPGA
   - [ZCU106 Development Board](https://www.xilinx.com/products/boards-and-kits/zcu106.html)

## ZCU106
#### Processing system one time setup
1. Install ZCU106 SD card image
   - https://ubuntu.com/download/amd-xilinx
1. Configure SW6 to boot from SD1.
   - Mode SW6[4:1]: OFF, OFF, OFF, ON
1. Install rustup using Unix directions: https://rustup.rs/#

#### Serial port configuration
Serial port settings for connection over USB.
 - Speed: 115200
 - Data bits: 8
 - Stop bits: 1
 - Parity: None
 - Flow control: None

### FPGA build steps
The FPGA build process uses Vivado's batch mode to procedurally create the Vivado project using fpga_configuration.tcl.
This script provides a number of configuration options for features that can be enabled using "-tclargs OPTION=VALUE OPTION=VALUE"

| Option    | Purpose
| ------    | -------
| BUILD     | Automatically start building the FPGA.
| GUI       | Open the Vivado GUI.
| JTAG      | Assign JTAG signals to Zynq PS GPIO.
| ITRNG     | Enable Caliptra's ITRNG.
| CG_EN     | Removes FPGA optimizations and allows clock gating.

This setup provides two `TCL` scripts:
- `fpga_ss_configuration.tcl` - the configured design will incorporate both Caliptra (Top) & Caliptra MCU into a common package that is then connected to the PS and/or designated PL pins.
     - **Warning!** This design **will** fail to implement due to the LUT overutilization.
- `fpga_mcu_configuration.tcl` - the configured design will be a package consisting only of one core - Caliptra MCU.

#### Build FPGA image without GUI
   - `vivado -mode batch -source fpga_x_configuration.tcl -tclargs BUILD=TRUE`
   - Above command creates a bitstream located at: caliptra_build/caliptra_fpga.bin
   - To check the git revision a bitstream was generated with
     - `xxd -s 0x88 -l 8 caliptra_build/caliptra_x_fpga.bin`
     - Result should be `3001 a001 xxxx xxxx`. 3001 a001 is a command to write the USR_ACCESS register and the rest is the hash.
#### Launch Vivado with GUI
   - `vivado -mode batch -source fpga_configuration.tcl -tclargs GUI=TRUE`
   - Run Synthesis: `launch_runs synth_1`
   - [Optional] Set Up Debug signals on Synthesized Design
   - Run Implementation: `launch_runs impl_1`
   - Generate Bitstream: `write_bitstream -bin_file \tmp\caliptra_x_fpga`

//TODO: Adjust the `setup_fpga.sh` script to Capiltra Subsystem on ZCU106.
//TODO: Add & describe Caliptra Subsystem tests on ZCU106
