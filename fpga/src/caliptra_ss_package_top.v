`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 03/21/2023 11:49:47 AM
// Design Name:
// Module Name: caliptra_ss_package_top
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Vivado does not support using a SystemVerilog as the top level file in an package.
//
//////////////////////////////////////////////////////////////////////////////////

`default_nettype wire

`define CALIPTRA_APB_ADDR_WIDTH      32 // bit-width APB address
`define CALIPTRA_APB_DATA_WIDTH      32 // bit-width APB data

module caliptra_ss_package_top (
    input wire core_clk,

    // Caliptra APB Interface
    input  wire [39:0]                s_apb0_paddr,
    input  wire                       s_apb0_penable,
    input  wire [2:0]                 s_apb0_pprot,
    output wire [`CALIPTRA_APB_DATA_WIDTH-1:0] s_apb0_prdata,
    output wire                       s_apb0_pready,
    input  wire                       s_apb0_psel,
    output wire                       s_apb0_pslverr,
    input  wire [3:0]                 s_apb0_pstrb, // Leave unconnected
    input  wire [`CALIPTRA_APB_DATA_WIDTH-1:0] s_apb0_pwdata,
    input  wire                       s_apb0_pwrite,

    // Caliptra APB Interface
    input  wire [39:0]                s_apb1_paddr,
    input  wire                       s_apb1_penable,
    input  wire [2:0]                 s_apb1_pprot,
    output wire [`CALIPTRA_APB_DATA_WIDTH-1:0] s_apb1_prdata,
    output wire                       s_apb1_pready,
    input  wire                       s_apb1_psel,
    output wire                       s_apb1_pslverr,
    input  wire [3:0]                 s_apb1_pstrb, // Leave unconnected
    input  wire [`CALIPTRA_APB_DATA_WIDTH-1:0] s_apb1_pwdata,
    input  wire                       s_apb1_pwrite,

    // ROM AXI Interface
    input  wire                       axi0_bram_clk,
    input  wire                       axi0_bram_en,
    input  wire [3:0]                 axi0_bram_we,
    input  wire [15:0]                axi0_bram_addr,
    input  wire [31:0]                axi0_bram_din,
    output wire [31:0]                axi0_bram_dout,
    input  wire                       axi0_bram_rst,

    // ROM AXI Interface
    input  wire                       axi1_bram_clk,
    input  wire                       axi1_bram_en,
    input  wire [3:0]                 axi1_bram_we,
    input  wire [15:0]                axi1_bram_addr,
    input  wire [31:0]                axi1_bram_din,
    output wire [31:0]                axi1_bram_dout,
    input  wire                       axi1_bram_rst,

    // JTAG Interface
    input wire [4:0]                  jtag_in,     // JTAG input signals concatenated
    output wire [4:0]                 jtag_out,    // JTAG tdo

    inout wire i3c_scl_io,
    inout wire i3c_sda_io,

    // FPGA Realtime register AXI Interface to Caliptra
    input	wire                      S_AXI0_ARESETN,
    input	wire                      S_AXI0_AWVALID,
    output	wire                      S_AXI0_AWREADY,
    input	wire [31:0]               S_AXI0_AWADDR,
    input	wire [2:0]                S_AXI0_AWPROT,
    input	wire                      S_AXI0_WVALID,
    output	wire                      S_AXI0_WREADY,
    input	wire [31:0]               S_AXI0_WDATA,
    input	wire [3:0]                S_AXI0_WSTRB,
    output	wire                      S_AXI0_BVALID,
    input	wire                      S_AXI0_BREADY,
    output	wire [1:0]                S_AXI0_BRESP,
    input	wire                      S_AXI0_ARVALID,
    output	wire                      S_AXI0_ARREADY,
    input	wire [31:0]               S_AXI0_ARADDR,
    input	wire [2:0]                S_AXI0_ARPROT,
    output	wire                      S_AXI0_RVALID,
    input	wire                      S_AXI0_RREADY,
    output	wire [31:0]               S_AXI0_RDATA,
    output	wire [1:0]                S_AXI0_RRESP,

    // FPGA Realtime register AXI Interface to Caliptra MCU
    input	wire                      S_AXI1_ARESETN,
    input	wire                      S_AXI1_AWVALID,
    output	wire                      S_AXI1_AWREADY,
    input	wire [31:0]               S_AXI1_AWADDR,
    input	wire [2:0]                S_AXI1_AWPROT,
    input	wire                      S_AXI1_WVALID,
    output	wire                      S_AXI1_WREADY,
    input	wire [31:0]               S_AXI1_WDATA,
    input	wire [3:0]                S_AXI1_WSTRB,
    output	wire                      S_AXI1_BVALID,
    input	wire                      S_AXI1_BREADY,
    output	wire [1:0]                S_AXI1_BRESP,
    input	wire                      S_AXI1_ARVALID,
    output	wire                      S_AXI1_ARREADY,
    input	wire [31:0]               S_AXI1_ARADDR,
    input	wire [2:0]                S_AXI1_ARPROT,
    output	wire                      S_AXI1_RVALID,
    input	wire                      S_AXI1_RREADY,
    output	wire [31:0]               S_AXI1_RDATA,
    output	wire [1:0]                S_AXI1_RRESP
    );

caliptra_mcu_wrapper_top cptra_mcu_wrapper (
    .core_clk(core_clk),

    .PADDR(s_apb1_paddr[`CALIPTRA_APB_ADDR_WIDTH-1:0]),
    .PPROT(s_apb1_pprot),
    .PENABLE(s_apb1_penable),
    .PRDATA(s_apb1_prdata),
    .PREADY(s_apb1_pready),
    .PSEL(s_apb1_psel),
    .PSLVERR(s_apb1_pslverr),
    .PWDATA(s_apb1_pwdata),
    .PWRITE(s_apb1_pwrite),

    // SOC access to program ROM
    .axi_bram_clk(axi1_bram_clk),
    .axi_bram_en(axi1_bram_en),
    .axi_bram_we(axi1_bram_we),
    .axi_bram_addr(axi1_bram_addr[15:2]),
    .axi_bram_wrdata(axi1_bram_din),
    .axi_bram_rddata(axi1_bram_dout),
    .axi_bram_rst(axi1_bram_rst),

    // EL2 JTAG interface FIXME
    .jtag_tck(0),
    .jtag_tdi(0),
    .jtag_tms(0),
    .jtag_trst_n(0),
    .jtag_tdo(),

    .i3c_scl_io(i3c_scl_io),
    .i3c_sda_io(i3c_sda_io),
    // FPGA Realtime register AXI Interface
    .S_AXI_ARESETN(S_AXI1_ARESETN),
    .S_AXI_AWVALID(S_AXI1_AWVALID),
    .S_AXI_AWREADY(S_AXI1_AWREADY),
    .S_AXI_AWADDR(S_AXI1_AWADDR),
    .S_AXI_AWPROT(S_AXI1_AWPROT),
    .S_AXI_WVALID(S_AXI1_WVALID),
    .S_AXI_WREADY(S_AXI1_WREADY),
    .S_AXI_WDATA(S_AXI1_WDATA),
    .S_AXI_WSTRB(S_AXI1_WSTRB),
    .S_AXI_BVALID(S_AXI1_BVALID),
    .S_AXI_BREADY(S_AXI1_BREADY),
    .S_AXI_BRESP(S_AXI1_BRESP),
    .S_AXI_ARVALID(S_AXI1_ARVALID),
    .S_AXI_ARREADY(S_AXI1_ARREADY),
    .S_AXI_ARADDR(S_AXI1_ARADDR),
    .S_AXI_ARPROT(S_AXI1_ARPROT),
    .S_AXI_RVALID(S_AXI1_RVALID),
    .S_AXI_RREADY(S_AXI1_RREADY),
    .S_AXI_RDATA(S_AXI1_RDATA),
    .S_AXI_RRESP(S_AXI1_RRESP)
);

caliptra_wrapper_top cptra_wrapper (
    .core_clk(core_clk),

    .PADDR(s_apb0_paddr[`CALIPTRA_APB_ADDR_WIDTH-1:0]),
    .PPROT(s_apb0_pprot),
    .PENABLE(s_apb0_penable),
    .PRDATA(s_apb0_prdata),
    .PREADY(s_apb0_pready),
    .PSEL(s_apb0_psel),
    .PSLVERR(s_apb0_pslverr),
    .PWDATA(s_apb0_pwdata),
    .PWRITE(s_apb0_pwrite),

    // SOC access to program ROM
    .axi_bram_clk(axi0_bram_clk),
    .axi_bram_en(axi0_bram_en),
    .axi_bram_we(axi0_bram_we),
    .axi_bram_addr(axi0_bram_addr[15:2]),
    .axi_bram_wrdata(axi0_bram_din),
    .axi_bram_rddata(axi0_bram_dout),
    .axi_bram_rst(axi0_bram_rst),

    // EL2 JTAG interface
    .jtag_tck(jtag_in[0]),
    .jtag_tdi(jtag_in[1]),
    .jtag_tms(jtag_in[2]),
    .jtag_trst_n(jtag_in[3]),
    .jtag_tdo(jtag_out[4]),

    // FPGA Realtime register AXI Interface
    .S_AXI_ARESETN(S_AXI0_ARESETN),
    .S_AXI_AWVALID(S_AXI0_AWVALID),
    .S_AXI_AWREADY(S_AXI0_AWREADY),
    .S_AXI_AWADDR(S_AXI0_AWADDR),
    .S_AXI_AWPROT(S_AXI0_AWPROT),
    .S_AXI_WVALID(S_AXI0_WVALID),
    .S_AXI_WREADY(S_AXI0_WREADY),
    .S_AXI_WDATA(S_AXI0_WDATA),
    .S_AXI_WSTRB(S_AXI0_WSTRB),
    .S_AXI_BVALID(S_AXI0_BVALID),
    .S_AXI_BREADY(S_AXI0_BREADY),
    .S_AXI_BRESP(S_AXI0_BRESP),
    .S_AXI_ARVALID(S_AXI0_ARVALID),
    .S_AXI_ARREADY(S_AXI0_ARREADY),
    .S_AXI_ARADDR(S_AXI0_ARADDR),
    .S_AXI_ARPROT(S_AXI0_ARPROT),
    .S_AXI_RVALID(S_AXI0_RVALID),
    .S_AXI_RREADY(S_AXI0_RREADY),
    .S_AXI_RDATA(S_AXI0_RDATA),
    .S_AXI_RRESP(S_AXI0_RRESP)
);
endmodule
