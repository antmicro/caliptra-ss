`timescale 1ps/1ps

`define DRAM(bk) caliptra_ss_top.mcu_top_i.dccm_loop[bk].ram.ram_core
`define MCU_RV_LSU_BUS_TAG_local 1
`default_nettype none

`include "common_defines.sv"
`include "config_defines.svh"
`include "caliptra_reg_defines.svh"
`include "caliptra_macros.svh"

module caliptra_ss_top
    import tb_top_pkg::*;
#(
    `include "mcu_el2_param.vh"
) (
    `ifdef VERILATOR
    input bit [31:0]            mem_signature_begin,
    input bit [31:0]            mem_signature_end,
    input bit [31:0]            mem_mailbox
    `endif // VERILATOR
);
import axi_pkg::*;
import soc_ifc_pkg::*;
import caliptra_top_tb_pkg::*;

        bit                         core_clk;
    `ifndef VERILATOR
        bit          [31:0]         mem_signature_begin = 32'd0; // TODO:
        bit          [31:0]         mem_signature_end   = 32'd0;
        bit          [31:0]         mem_mailbox         = 32'hD0580000;
    `endif
        logic                       rst_l;
        logic                       porst_l;
        logic [mcu_pt.PIC_TOTAL_INT:1]  ext_int;
        logic                       nmi_int;
        logic                       timer_int;
        logic                       soft_int;

        logic        [31:0]         reset_vector;
        logic        [31:0]         nmi_vector;
        logic        [31:1]         jtag_id;

        logic        [31:0]         ic_haddr        ;
        logic        [2:0]          ic_hburst       ;
        logic                       ic_hmastlock    ;
        logic        [3:0]          ic_hprot        ;
        logic        [2:0]          ic_hsize        ;
        logic        [1:0]          ic_htrans       ;
        logic                       ic_hwrite       ;
        logic        [63:0]         ic_hrdata       ;
        logic                       ic_hready       ;
        logic                       ic_hresp        ;

        logic        [31:0]         lsu_haddr       ;
        logic        [2:0]          lsu_hburst      ;
        logic                       lsu_hmastlock   ;
        logic        [3:0]          lsu_hprot       ;
        logic        [2:0]          lsu_hsize       ;
        logic        [1:0]          lsu_htrans      ;
        logic                       lsu_hwrite      ;
        logic        [63:0]         lsu_hrdata      ;
        logic        [63:0]         lsu_hwdata      ;
        logic                       lsu_hready      ;
        logic                       lsu_hresp        ;

        logic        [31:0]         sb_haddr        ;
        logic        [2:0]          sb_hburst       ;
        logic                       sb_hmastlock    ;
        logic        [3:0]          sb_hprot        ;
        logic        [2:0]          sb_hsize        ;
        logic        [1:0]          sb_htrans       ;
        logic                       sb_hwrite       ;

        logic        [63:0]         sb_hrdata       ;
        logic        [63:0]         sb_hwdata       ;
        logic                       sb_hready       ;
        logic                       sb_hresp        ;

        logic        [31:0]         trace_rv_i_insn_ip;
        logic        [31:0]         trace_rv_i_address_ip;
        logic                       trace_rv_i_valid_ip;
        logic                       trace_rv_i_exception_ip;
        logic        [4:0]          trace_rv_i_ecause_ip;
        logic                       trace_rv_i_interrupt_ip;
        logic        [31:0]         trace_rv_i_tval_ip;

        logic                       o_debug_mode_status;


        logic                       jtag_tdo;
        logic                       o_cpu_halt_ack;
        logic                       o_cpu_halt_status;
        logic                       o_cpu_run_ack;

        logic                       mailbox_write;
        logic        [63:0]         mailbox_data;

        logic        [63:0]         dma_hrdata       ;
        logic        [63:0]         dma_hwdata       ;
        logic                       dma_hready       ;
        logic                       dma_hresp        ;

        logic                       mpc_debug_halt_req;
        logic                       mpc_debug_run_req;
        logic                       mpc_reset_run_req;
        logic                       mpc_debug_halt_ack;
        logic                       mpc_debug_run_ack;
        logic                       debug_brkpt_status;

        int                         cycleCnt;
        logic                       mailbox_data_val;

        wire                        dma_hready_out;
        int                         commit_count;

        logic                       wb_valid;
        logic [4:0]                 wb_dest;
        logic [31:0]                wb_data;

        logic                       wb_csr_valid;
        logic [11:0]                wb_csr_dest;
        logic [31:0]                wb_csr_data;

    `ifdef MCU_RV_BUILD_AXI4
       //-------------------------- LSU AXI signals--------------------------
       // AXI Write Channels
        wire                        lsu_axi_awvalid;
        wire                        lsu_axi_awready;
        wire [`MCU_RV_LSU_BUS_TAG-1:0]  lsu_axi_awid;
        wire [31:0]                 lsu_axi_awaddr;
        wire [3:0]                  lsu_axi_awregion;
        wire [7:0]                  lsu_axi_awlen;
        wire [2:0]                  lsu_axi_awsize;
        wire [1:0]                  lsu_axi_awburst;
        wire                        lsu_axi_awlock;
        wire [3:0]                  lsu_axi_awcache;
        wire [2:0]                  lsu_axi_awprot;
        wire [3:0]                  lsu_axi_awqos;

        wire                        lsu_axi_wvalid;
        wire                        lsu_axi_wready;
        wire [63:0]                 lsu_axi_wdata;
        wire [7:0]                  lsu_axi_wstrb;
        wire                        lsu_axi_wlast;

        wire                        lsu_axi_bvalid;
        wire                        lsu_axi_bready;
        wire [1:0]                  lsu_axi_bresp;
        wire [`MCU_RV_LSU_BUS_TAG-1:0]  lsu_axi_bid;

        // AXI Read Channels
        wire                        lsu_axi_arvalid;
        wire                        lsu_axi_arready;
        wire [`MCU_RV_LSU_BUS_TAG-1:0]  lsu_axi_arid;
        wire [31:0]                 lsu_axi_araddr;
        wire [3:0]                  lsu_axi_arregion;
        wire [7:0]                  lsu_axi_arlen;
        wire [2:0]                  lsu_axi_arsize;
        wire [1:0]                  lsu_axi_arburst;
        wire                        lsu_axi_arlock;
        wire [3:0]                  lsu_axi_arcache;
        wire [2:0]                  lsu_axi_arprot;
        wire [3:0]                  lsu_axi_arqos;

        wire                        lsu_axi_rvalid;
        wire                        lsu_axi_rready;
        wire [`MCU_RV_LSU_BUS_TAG-1:0]  lsu_axi_rid;
        wire [63:0]                 lsu_axi_rdata;
        wire [1:0]                  lsu_axi_rresp;
        wire                        lsu_axi_rlast;

        //-------------------------- IFU AXI signals--------------------------
        // AXI Write Channels
        wire                        ifu_axi_awvalid;
        wire                        ifu_axi_awready;
        wire [`MCU_RV_IFU_BUS_TAG-1:0]  ifu_axi_awid;
        wire [31:0]                 ifu_axi_awaddr;
        wire [3:0]                  ifu_axi_awregion;
        wire [7:0]                  ifu_axi_awlen;
        wire [2:0]                  ifu_axi_awsize;
        wire [1:0]                  ifu_axi_awburst;
        wire                        ifu_axi_awlock;
        wire [3:0]                  ifu_axi_awcache;
        wire [2:0]                  ifu_axi_awprot;
        wire [3:0]                  ifu_axi_awqos;

        wire                        ifu_axi_wvalid;
        wire                        ifu_axi_wready;
        wire [63:0]                 ifu_axi_wdata;
        wire [7:0]                  ifu_axi_wstrb;
        wire                        ifu_axi_wlast;

        wire                        ifu_axi_bvalid;
        wire                        ifu_axi_bready;
        wire [1:0]                  ifu_axi_bresp;
        wire [`MCU_RV_IFU_BUS_TAG-1:0]  ifu_axi_bid;

        // AXI Read Channels
        wire                        ifu_axi_arvalid;
        wire                        ifu_axi_arready;
        wire [`MCU_RV_IFU_BUS_TAG-1:0]  ifu_axi_arid;
        wire [31:0]                 ifu_axi_araddr;
        wire [3:0]                  ifu_axi_arregion;
        wire [7:0]                  ifu_axi_arlen;
        wire [2:0]                  ifu_axi_arsize;
        wire [1:0]                  ifu_axi_arburst;
        wire                        ifu_axi_arlock;
        wire [3:0]                  ifu_axi_arcache;
        wire [2:0]                  ifu_axi_arprot;
        wire [3:0]                  ifu_axi_arqos;

        wire                        ifu_axi_rvalid;
        wire                        ifu_axi_rready;
        wire [`MCU_RV_IFU_BUS_TAG-1:0]  ifu_axi_rid;
        wire [63:0]                 ifu_axi_rdata;
        wire [1:0]                  ifu_axi_rresp;
        wire                        ifu_axi_rlast;

        //-------------------------- SB AXI signals--------------------------
        // AXI Write Channels
        wire                        sb_axi_awvalid;
        wire                        sb_axi_awready;
        wire [`MCU_RV_SB_BUS_TAG-1:0]   sb_axi_awid;
        wire [31:0]                 sb_axi_awaddr;
        wire [3:0]                  sb_axi_awregion;
        wire [7:0]                  sb_axi_awlen;
        wire [2:0]                  sb_axi_awsize;
        wire [1:0]                  sb_axi_awburst;
        wire                        sb_axi_awlock;
        wire [3:0]                  sb_axi_awcache;
        wire [2:0]                  sb_axi_awprot;
        wire [3:0]                  sb_axi_awqos;

        wire                        sb_axi_wvalid;
        wire                        sb_axi_wready;
        wire [63:0]                 sb_axi_wdata;
        wire [7:0]                  sb_axi_wstrb;
        wire                        sb_axi_wlast;

        wire                        sb_axi_bvalid;
        wire                        sb_axi_bready;
        wire [1:0]                  sb_axi_bresp;
        wire [`MCU_RV_SB_BUS_TAG-1:0]   sb_axi_bid;

        // AXI Read Channels
        wire                        sb_axi_arvalid;
        wire                        sb_axi_arready;
        wire [`MCU_RV_SB_BUS_TAG-1:0]   sb_axi_arid;
        wire [31:0]                 sb_axi_araddr;
        wire [3:0]                  sb_axi_arregion;
        wire [7:0]                  sb_axi_arlen;
        wire [2:0]                  sb_axi_arsize;
        wire [1:0]                  sb_axi_arburst;
        wire                        sb_axi_arlock;
        wire [3:0]                  sb_axi_arcache;
        wire [2:0]                  sb_axi_arprot;
        wire [3:0]                  sb_axi_arqos;

        wire                        sb_axi_rvalid;
        wire                        sb_axi_rready;
        wire [`MCU_RV_SB_BUS_TAG-1:0]   sb_axi_rid;
        wire [63:0]                 sb_axi_rdata;
        wire [1:0]                  sb_axi_rresp;
        wire                        sb_axi_rlast;

       //-------------------------- DMA AXI signals--------------------------
       // AXI Write Channels
        wire                        dma_axi_awvalid;
        wire                        dma_axi_awready;
        wire [`MCU_RV_DMA_BUS_TAG-1:0]  dma_axi_awid;
        wire [31:0]                 dma_axi_awaddr;
        wire [2:0]                  dma_axi_awsize;
        wire [2:0]                  dma_axi_awprot;
        wire [7:0]                  dma_axi_awlen;
        wire [1:0]                  dma_axi_awburst;


        wire                        dma_axi_wvalid;
        wire                        dma_axi_wready;
        wire [63:0]                 dma_axi_wdata;
        wire [7:0]                  dma_axi_wstrb;
        wire                        dma_axi_wlast;

        wire                        dma_axi_bvalid;
        wire                        dma_axi_bready;
        wire [1:0]                  dma_axi_bresp;
        wire [`MCU_RV_DMA_BUS_TAG-1:0]  dma_axi_bid;

        // AXI Read Channels
        wire                        dma_axi_arvalid;
        wire                        dma_axi_arready;
        wire [`MCU_RV_DMA_BUS_TAG-1:0]  dma_axi_arid;
        wire [31:0]                 dma_axi_araddr;
        wire [2:0]                  dma_axi_arsize;
        wire [2:0]                  dma_axi_arprot;
        wire [7:0]                  dma_axi_arlen;
        wire [1:0]                  dma_axi_arburst;

        wire                        dma_axi_rvalid;
        wire                        dma_axi_rready;
        wire [`MCU_RV_DMA_BUS_TAG-1:0]  dma_axi_rid;
        wire [63:0]                 dma_axi_rdata;
        wire [1:0]                  dma_axi_rresp;
        wire                        dma_axi_rlast;

        wire                        lmem_axi_arvalid;
        wire                        lmem_axi_arready;

        wire                        lmem_axi_rvalid;
        wire [`MCU_RV_LSU_BUS_TAG-1:0]  lmem_axi_rid;
        wire [1:0]                  lmem_axi_rresp;
        wire [63:0]                 lmem_axi_rdata;
        wire                        lmem_axi_rlast;
        wire                        lmem_axi_rready;

        wire                        lmem_axi_awvalid;
        wire                        lmem_axi_awready;

        wire                        lmem_axi_wvalid;
        wire                        lmem_axi_wready;

        wire [1:0]                  lmem_axi_bresp;
        wire                        lmem_axi_bvalid;
        wire [`MCU_RV_LSU_BUS_TAG-1:0]  lmem_axi_bid;
        wire                        lmem_axi_bready;

    `endif
        string                      abi_reg[32]; // ABI register names
        mcu_el2_mem_if                  mcu_el2_mem_export ();
        el2_mem_if                  caliptra_el2_mem_export ();        

        logic [mcu_pt.ICCM_NUM_BANKS-1:0][                   38:0] iccm_bank_wr_fdata;
        logic [mcu_pt.ICCM_NUM_BANKS-1:0][                   38:0] iccm_bank_fdout;
        logic [mcu_pt.DCCM_NUM_BANKS-1:0][mcu_pt.DCCM_FDATA_WIDTH-1:0] dccm_wr_fdata_bank;
        logic [mcu_pt.DCCM_NUM_BANKS-1:0][mcu_pt.DCCM_FDATA_WIDTH-1:0] dccm_bank_fdout;

        tb_top_pkg::veer_sram_error_injection_mode_t error_injection_mode;

        `define DEC rvtop_wrapper.rvtop.veer.dec


        assign mailbox_write    = lmem.awvalid && (lmem.awaddr == 32'hD0580000) && rst_l;
        assign mailbox_data     = lmem.wdata;

        assign mailbox_data_val = mailbox_data[7:0] > 8'h5 && mailbox_data[7:0] < 8'h7f;

        parameter MAX_CYCLES = 20_000;

        integer fd, tp, el;

        always @(negedge core_clk) begin
            cycleCnt <= cycleCnt+1;
            // Test timeout monitor
            if(cycleCnt == MAX_CYCLES) begin
                $display ("Hit max cycle count (%0d) .. stopping",cycleCnt);
                $finish;
            end
            // console Monitor
            if( mailbox_data_val & mailbox_write) begin
                $fwrite(fd,"%c", mailbox_data[7:0]);
                $write("%c", mailbox_data[7:0]);
            end
            // Interrupt signals control
            // data[7:0] == 0x80 - clear ext irq line index given by data[15:8]
            // data[7:0] == 0x81 - set ext irq line index given by data[15:8]
            // data[7:0] == 0x82 - clean NMI, timer and soft irq lines to bits data[8:10]
            // data[7:0] == 0x83 - set NMI, timer and soft irq lines to bits data[8:10]
            // data[7:0] == 0x90 - clear all interrupt request signals
            if(mailbox_write && (mailbox_data[7:0] >= 8'h80 && mailbox_data[7:0] < 8'h84)) begin
                if (mailbox_data[7:0] == 8'h80) begin
                    if (mailbox_data[15:8] > 0 && mailbox_data[15:8] < mcu_pt.PIC_TOTAL_INT)
                        ext_int[mailbox_data[15:8]] <= 1'b0;
                end
                if (mailbox_data[7:0] == 8'h81) begin
                    if (mailbox_data[15:8] > 0 && mailbox_data[15:8] < mcu_pt.PIC_TOTAL_INT)
                        ext_int[mailbox_data[15:8]] <= 1'b1;
                end
                if (mailbox_data[7:0] == 8'h82) begin
                    nmi_int   <= nmi_int   & ~mailbox_data[8];
                    timer_int <= timer_int & ~mailbox_data[9];
                    soft_int  <= soft_int  & ~mailbox_data[10];
                end
                if (mailbox_data[7:0] == 8'h83) begin
                    nmi_int   <= nmi_int   |  mailbox_data[8];
                    timer_int <= timer_int |  mailbox_data[9];
                    soft_int  <= soft_int  |  mailbox_data[10];
                end
            end
            if(mailbox_write && (mailbox_data[7:0] == 8'h90)) begin
                ext_int   <= {mcu_pt.PIC_TOTAL_INT-1{1'b0}};
                nmi_int   <= 1'b0;
                timer_int <= 1'b0;
                soft_int  <= 1'b0;
            end
            // ECC error injection
            if(mailbox_write && (mailbox_data[7:0] == 8'he0)) begin
                $display("Injecting single bit ICCM error");
                error_injection_mode.iccm_single_bit_error <= 1'b1;
            end
            else if(mailbox_write && (mailbox_data[7:0] == 8'he1)) begin
                $display("Injecting double bit ICCM error");
                error_injection_mode.iccm_double_bit_error <= 1'b1;
            end
            else if(mailbox_write && (mailbox_data[7:0] == 8'he2)) begin
                $display("Injecting single bit DCCM error");
                error_injection_mode.dccm_single_bit_error <= 1'b1;
            end
            else if(mailbox_write && (mailbox_data[7:0] == 8'he3)) begin
                $display("Injecting double bit DCCM error");
                error_injection_mode.dccm_double_bit_error <= 1'b1;
            end
            else if(mailbox_write && (mailbox_data[7:0] == 8'he4)) begin
                $display("Disable ECC error injection");
                error_injection_mode <= '0;
            end
            // Memory signature dump
            if(mailbox_write && (mailbox_data[7:0] == 8'hFF || mailbox_data[7:0] == 8'h01)) begin
                if (mem_signature_begin < mem_signature_end) begin
                    dump_signature();
                end
            end
            // // End Of test monitor
            // if(mailbox_write && mailbox_data[7:0] == 8'hff) begin
            //     $display("TEST_PASSED");
            //     $display("\nFinished : minstret = %0d, mcycle = %0d", `DEC.tlu.minstretl[31:0],`DEC.tlu.mcyclel[31:0]);
            //     $display("See \"exec.log\" for execution trace with register updates..\n");
            //     $finish;
            // end
            // else if(mailbox_write && mailbox_data[7:0] == 8'h1) begin
            //     $display("TEST_FAILED");
            //     $finish;
            // end
        end


        // trace monitor
        always @(posedge core_clk) begin
            wb_valid      <= `DEC.dec_i0_wen_r;
            wb_dest       <= `DEC.dec_i0_waddr_r;
            wb_data       <= `DEC.dec_i0_wdata_r;
            wb_csr_valid  <= `DEC.dec_csr_wen_r;
            wb_csr_dest   <= `DEC.dec_csr_wraddr_r;
            wb_csr_data   <= `DEC.dec_csr_wrdata_r;
            if (trace_rv_i_valid_ip) begin
               $fwrite(tp,"%b,%h,%h,%0h,%0h,3,%b,%h,%h,%b\n", trace_rv_i_valid_ip, 0, trace_rv_i_address_ip,
                      0, trace_rv_i_insn_ip,trace_rv_i_exception_ip,trace_rv_i_ecause_ip,
                      trace_rv_i_tval_ip,trace_rv_i_interrupt_ip);
               // Basic trace - no exception register updates
               // #1 0 ee000000 b0201073 c 0b02       00000000
               commit_count++;
               $fwrite (el, "%10d : %8s 0 %h %h%13s %14s ; %s\n", cycleCnt, $sformatf("#%0d",commit_count),
                            trace_rv_i_address_ip, trace_rv_i_insn_ip,
                            (wb_dest !=0 && wb_valid)?  $sformatf("%s=%h", abi_reg[wb_dest], wb_data) : "            ",
                            (wb_csr_valid)? $sformatf("c%h=%h", wb_csr_dest, wb_csr_data) : "             ",
                            dasm(trace_rv_i_insn_ip, trace_rv_i_address_ip, wb_dest & {5{wb_valid}}, wb_data)
                       );
            end
            if(`DEC.dec_nonblock_load_wen) begin
                $fwrite (el, "%10d : %32s=%h                ; nbL\n", cycleCnt, abi_reg[`DEC.dec_nonblock_load_waddr], `DEC.lsu_nonblock_load_data);
                caliptra_ss_top.gpr[0][`DEC.dec_nonblock_load_waddr] = `DEC.lsu_nonblock_load_data;
            end
            if(`DEC.exu_div_wren) begin
                $fwrite (el, "%10d : %32s=%h                ; nbD\n", cycleCnt, abi_reg[`DEC.div_waddr_wb], `DEC.exu_div_result);
                caliptra_ss_top.gpr[0][`DEC.div_waddr_wb] = `DEC.exu_div_result;
            end
        end


        initial begin
            abi_reg[0] = "zero";
            abi_reg[1] = "ra";
            abi_reg[2] = "sp";
            abi_reg[3] = "gp";
            abi_reg[4] = "tp";
            abi_reg[5] = "t0";
            abi_reg[6] = "t1";
            abi_reg[7] = "t2";
            abi_reg[8] = "s0";
            abi_reg[9] = "s1";
            abi_reg[10] = "a0";
            abi_reg[11] = "a1";
            abi_reg[12] = "a2";
            abi_reg[13] = "a3";
            abi_reg[14] = "a4";
            abi_reg[15] = "a5";
            abi_reg[16] = "a6";
            abi_reg[17] = "a7";
            abi_reg[18] = "s2";
            abi_reg[19] = "s3";
            abi_reg[20] = "s4";
            abi_reg[21] = "s5";
            abi_reg[22] = "s6";
            abi_reg[23] = "s7";
            abi_reg[24] = "s8";
            abi_reg[25] = "s9";
            abi_reg[26] = "s10";
            abi_reg[27] = "s11";
            abi_reg[28] = "t3";
            abi_reg[29] = "t4";
            abi_reg[30] = "t5";
            abi_reg[31] = "t6";

            ext_int     = {mcu_pt.PIC_TOTAL_INT-1{1'b0}};
            nmi_int     = 0;
            timer_int   = 0;
            soft_int    = 0;

        // tie offs
            jtag_id[31:28] = 4'b1;
            jtag_id[27:12] = '0;
            jtag_id[11:1]  = 11'h45;
            reset_vector = `MCU_RV_RESET_VEC;
            nmi_vector   = 32'hee000000;

            $readmemh("mcu_program.hex",  lmem.mem);
            $readmemh("mcu_program.hex",  imem.mem);
            tp = $fopen("trace_port.csv","w");
            el = $fopen("exec.log","w");
            $fwrite (el, "//   Cycle : #inst    0    pc    opcode    reg=value    csr=value     ; mnemonic\n");
            fd = $fopen("console.log","w");
            commit_count = 0;
            preload_dccm();
            preload_iccm();

    // `ifndef VERILATOR
    //         // if($test$plusargs("dumpon")) $dumpvars;
    //         // forever  ACLK     = #5 ~ACLK;
    // `endif

        end

        initial  begin
            core_clk = 0;
            forever  core_clk = #5 ~core_clk;
        end

        assign rst_l = cycleCnt < 2 ? 1'b1 : (cycleCnt > 5 ? 1'b1 : 1'b0);
        assign porst_l = cycleCnt > 2;
    
       //=========================================================================
       // AXI Interconnect 
       //=========================================================================

        aaxi4_interconnect axi_interconnect(
            .core_clk (core_clk),
            .rst_l    (rst_l)
        );

        // Caliptra RTL TOP TB
        caliptra_top_tb caliptra_top_tb_i (
            .core_clk           (core_clk)
        );

        // // AXI Interconnect connections
        // assign caliptra_top_tb_i.s_axi_if.awvalid = axi_interconnect.sintf_arr[3].AWVALID;
        // assign caliptra_top_tb_i.s_axi_if.awaddr  = axi_interconnect.sintf_arr[3].AWADDR;
        // assign caliptra_top_tb_i.s_axi_if.awid    = axi_interconnect.sintf_arr[3].AWID;
        // assign caliptra_top_tb_i.s_axi_if.awlen   = axi_interconnect.sintf_arr[3].AWLEN;
        // assign caliptra_top_tb_i.s_axi_if.awsize  = axi_interconnect.sintf_arr[3].AWSIZE;
        // assign caliptra_top_tb_i.s_axi_if.awburst = axi_interconnect.sintf_arr[3].AWBURST;
        // assign caliptra_top_tb_i.s_axi_if.awlock  = axi_interconnect.sintf_arr[3].AWLOCK;
        // assign caliptra_top_tb_i.s_axi_if.awuser  = axi_interconnect.sintf_arr[3].AWUSER;
        // assign axi_interconnect.sintf_arr[3].AWREADY = caliptra_top_tb_i.s_axi_if.awready;

        // assign caliptra_top_tb_i.s_axi_if.wvalid = axi_interconnect.sintf_arr[3].WVALID;
        // assign caliptra_top_tb_i.s_axi_if.wdata  = axi_interconnect.sintf_arr[3].WDATA;
        // assign caliptra_top_tb_i.s_axi_if.wstrb  = axi_interconnect.sintf_arr[3].WSTRB;
        // assign caliptra_top_tb_i.s_axi_if.wlast  = axi_interconnect.sintf_arr[3].WLAST;
        // assign axi_interconnect.sintf_arr[3].WREADY = caliptra_top_tb_i.s_axi_if.wready;

        // assign axi_interconnect.sintf_arr[3].BVALID = caliptra_top_tb_i.s_axi_if.bvalid;
        // assign axi_interconnect.sintf_arr[3].BRESP  = caliptra_top_tb_i.s_axi_if.bresp;
        // assign axi_interconnect.sintf_arr[3].BID    = caliptra_top_tb_i.s_axi_if.bid;
        // assign caliptra_top_tb_i.s_axi_if.bready = axi_interconnect.sintf_arr[3].BREADY;

        // assign caliptra_top_tb_i.s_axi_if.arvalid = axi_interconnect.sintf_arr[3].ARVALID;
        // assign caliptra_top_tb_i.s_axi_if.araddr  = axi_interconnect.sintf_arr[3].ARADDR;
        // assign caliptra_top_tb_i.s_axi_if.arid    = axi_interconnect.sintf_arr[3].ARID;
        // assign caliptra_top_tb_i.s_axi_if.arlen   = axi_interconnect.sintf_arr[3].ARLEN;
        // assign caliptra_top_tb_i.s_axi_if.arsize  = axi_interconnect.sintf_arr[3].ARSIZE;
        // assign caliptra_top_tb_i.s_axi_if.arburst = axi_interconnect.sintf_arr[3].ARBURST;
        // assign caliptra_top_tb_i.s_axi_if.arlock  = axi_interconnect.sintf_arr[3].ARLOCK;
        // assign caliptra_top_tb_i.s_axi_if.aruser  = axi_interconnect.sintf_arr[3].ARUSER;
        // assign axi_interconnect.sintf_arr[3].ARREADY = caliptra_top_tb_i.s_axi_if.arready;
        
        // assign axi_interconnect.sintf_arr[3].RVALID = caliptra_top_tb_i.s_axi_if.rvalid;
        // assign axi_interconnect.sintf_arr[3].RDATA  = caliptra_top_tb_i.s_axi_if.rdata;
        // assign axi_interconnect.sintf_arr[3].RRESP  = caliptra_top_tb_i.s_axi_if.rresp;
        // assign axi_interconnect.sintf_arr[3].RID    = caliptra_top_tb_i.s_axi_if.rid;
        // assign axi_interconnect.sintf_arr[3].RLAST  = caliptra_top_tb_i.s_axi_if.rlast;
        // assign caliptra_top_tb_i.s_axi_if.rready = axi_interconnect.sintf_arr[3].RREADY;
        
        // // AXI Interconnect connections
        // assign axi_interconnect.mintf_arr[3].AWVALID = caliptra_top_tb_i.m_axi_if.awvalid;
        // assign axi_interconnect.mintf_arr[3].AWADDR  = caliptra_top_tb_i.m_axi_if.awaddr;
        // assign axi_interconnect.mintf_arr[3].AWID    = caliptra_top_tb_i.m_axi_if.awid;
        // assign axi_interconnect.mintf_arr[3].AWLEN   = caliptra_top_tb_i.m_axi_if.awlen;
        // assign axi_interconnect.mintf_arr[3].AWSIZE  = caliptra_top_tb_i.m_axi_if.awsize;
        // assign axi_interconnect.mintf_arr[3].AWBURST = caliptra_top_tb_i.m_axi_if.awburst;
        // assign axi_interconnect.mintf_arr[3].AWLOCK  = caliptra_top_tb_i.m_axi_if.awlock;
        // assign axi_interconnect.mintf_arr[3].AWUSER  = caliptra_top_tb_i.m_axi_if.awuser;
        // assign caliptra_top_tb_i.m_axi_if.awready = axi_interconnect.mintf_arr[3].AWREADY;
        
        // assign axi_interconnect.mintf_arr[3].WVALID = caliptra_top_tb_i.m_axi_if.wvalid;
        // assign axi_interconnect.mintf_arr[3].WDATA  = caliptra_top_tb_i.m_axi_if.wdata;
        // assign axi_interconnect.mintf_arr[3].WSTRB  = caliptra_top_tb_i.m_axi_if.wstrb;
        // assign axi_interconnect.mintf_arr[3].WLAST  = caliptra_top_tb_i.m_axi_if.wlast;
        // assign caliptra_top_tb_i.m_axi_if.wready = axi_interconnect.mintf_arr[3].WREADY;
        
        // assign caliptra_top_tb_i.m_axi_if.bvalid = axi_interconnect.mintf_arr[3].BVALID;
        // assign caliptra_top_tb_i.m_axi_if.bresp  = axi_interconnect.mintf_arr[3].BRESP;
        // assign caliptra_top_tb_i.m_axi_if.bid    = axi_interconnect.mintf_arr[3].BID;
        // assign axi_interconnect.mintf_arr[3].BREADY = caliptra_top_tb_i.m_axi_if.bready;
        
        // assign axi_interconnect.mintf_arr[3].ARVALID = caliptra_top_tb_i.m_axi_if.arvalid;
        // assign axi_interconnect.mintf_arr[3].ARADDR  = caliptra_top_tb_i.m_axi_if.araddr;
        // assign axi_interconnect.mintf_arr[3].ARID    = caliptra_top_tb_i.m_axi_if.arid;
        // assign axi_interconnect.mintf_arr[3].ARLEN   = caliptra_top_tb_i.m_axi_if.arlen;
        // assign axi_interconnect.mintf_arr[3].ARSIZE  = caliptra_top_tb_i.m_axi_if.arsize;
        // assign axi_interconnect.mintf_arr[3].ARBURST = caliptra_top_tb_i.m_axi_if.arburst;
        // assign axi_interconnect.mintf_arr[3].ARLOCK  = caliptra_top_tb_i.m_axi_if.arlock;
        // assign axi_interconnect.mintf_arr[3].ARUSER  = caliptra_top_tb_i.m_axi_if.aruser;
        // assign caliptra_top_tb_i.m_axi_if.arready = axi_interconnect.mintf_arr[3].ARREADY;
        
        // assign caliptra_top_tb_i.m_axi_if.rvalid = axi_interconnect.mintf_arr[3].RVALID;
        // assign caliptra_top_tb_i.m_axi_if.rdata  = axi_interconnect.mintf_arr[3].RDATA;
        // assign caliptra_top_tb_i.m_axi_if.rresp  = axi_interconnect.mintf_arr[3].RRESP;
        // assign caliptra_top_tb_i.m_axi_if.rid    = axi_interconnect.mintf_arr[3].RID;
        // assign caliptra_top_tb_i.m_axi_if.rlast  = axi_interconnect.mintf_arr[3].RLAST;
        // assign axi_interconnect.mintf_arr[3].RREADY = caliptra_top_tb_i.m_axi_if.rready;


        // //=========================================================================-
        // // Caliptra RTL TOP
        // //=========================================================================-
            
        // // Caliptra power good signal
        // logic                       caliptra_pwrgood;
        // // Caliptra OBFS Key
        // logic [`CLP_OBF_KEY_DWORDS-1:0][31:0]          caliptra_obf_key;
        // logic [0:`CLP_OBF_KEY_DWORDS-1][31:0]          caliptra_obf_key_uds, caliptra_obf_key_fe;
        // logic [0:`CLP_OBF_UDS_DWORDS-1][31:0]          caliptra_uds_tb;
        // logic [0:`CLP_OBF_FE_DWORDS-1][31:0]           caliptra_fe_tb;
        // //jtag interface
        // logic                       caliptra_jtag_tck;    // JTAG clk
        // logic                       caliptra_jtag_tms;    // JTAG TMS
        // logic                       caliptra_jtag_tdi;    // JTAG tdi
        // logic                       caliptra_jtag_trst_n; // JTAG Reset
        // logic                       caliptra_jtag_tdo;    // JTAG TDO
        // logic                       caliptra_jtag_tdoEn;  // JTAG TDO enable
        // // QSPI Interface
        // logic                                qspi_clk;
        // logic [`CALIPTRA_QSPI_CS_WIDTH-1:0]  qspi_cs_n;
        // wire  [`CALIPTRA_QSPI_IO_WIDTH-1:0]  qspi_data;
        // logic [`CALIPTRA_QSPI_IO_WIDTH-1:0]  qspi_data_host_to_device, qspi_data_device_to_host;
        // logic [`CALIPTRA_QSPI_IO_WIDTH-1:0]  qspi_data_host_to_device_en;
        // // UART Interface
        // logic                               uart_loopback;

        // logic                               ready_for_fuses;
        // logic                               ready_for_fw_push;
        // logic                               mailbox_data_avail;
        // logic                               mbox_sram_cs;
        // logic                               mbox_sram_we;
        // logic [14:0]                        mbox_sram_addr;
        // logic [MBOX_DATA_AND_ECC_W-1:0]     mbox_sram_wdata;
        // logic [MBOX_DATA_AND_ECC_W-1:0]     mbox_sram_rdata;
        // logic                                 imem_cs;
        // logic [`CALIPTRA_IMEM_ADDR_WIDTH-1:0] imem_addr;
        // logic [`CALIPTRA_IMEM_DATA_WIDTH-1:0] imem_rdata;
        // logic                               caliptra_error_fatal;
        // logic                               caliptra_error_non_fatal;
        // logic                               calipta_scan_mode;
        // logic                               mailbox_data_avail;
        // logic                               BootFSM_BrkPoint;
        // logic [63:0]                        generic_input_wires;
        // //device lifecycle
        // security_state_t                    caliptra_security_state;

        // // Caliptra Top TB Services
        // ras_test_ctrl_t ras_test_ctrl;
        // logic int_flag;
        // logic cycleCnt_smpl_en;

        // //Reset flags
        // logic assert_hard_rst_flag;
        // logic deassert_hard_rst_flag;

        // logic assert_rst_flag_from_service;
        // logic deassert_rst_flag_from_service;


        // logic [0:`CLP_OBF_UDS_DWORDS-1][31:0]          caliptra_uds_rand;
        // logic [0:`CLP_OBF_FE_DWORDS-1][31:0]           caliptra_fe_rand;
        // logic [0:`CLP_OBF_KEY_DWORDS-1][31:0]          caliptra_obf_key_tb;
                
        // // AXI Interface
        // axi_if #(
        //     .AW(`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC)),
        //     .DW(`CALIPTRA_AXI_DATA_WIDTH),
        //     .IW(`CALIPTRA_AXI_ID_WIDTH),
        //     .UW(`CALIPTRA_AXI_USER_WIDTH)
        // ) caliptra_top_tb_i.s_axi_if (.clk(core_clk), .rst_n(rst_l));
        // axi_if #(
        //     .AW(`CALIPTRA_AXI_DMA_ADDR_WIDTH),
        //     .DW(CPTRA_AXI_DMA_DATA_WIDTH),
        //     .IW(CPTRA_AXI_DMA_ID_WIDTH),
        //     .UW(CPTRA_AXI_DMA_USER_WIDTH)
        // ) caliptra_top_tb_i.m_axi_if (.clk(core_clk), .rst_n(rst_l));


        // caliptra_top caliptra_top_dut (
        //     .cptra_pwrgood              (caliptra_pwrgood),
        //     .clk                        (core_clk),
        //     .cptra_rst_b                (rst_l),
        //     .cptra_obf_key              (caliptra_obf_key), 
        //     .jtag_tck                   (caliptra_jtag_tck),
        //     .jtag_tdi                   (caliptra_jtag_tdi),
        //     .jtag_tms                   (caliptra_jtag_tms),
        //     .jtag_trst_n                (caliptra_jtag_trst_n),
        //     .jtag_tdo                   (caliptra_jtag_tdo),
        //     .jtag_tdoEn                 (caliptra_jtag_tdoEn), 
        //     //SoC AXI Interface
        //     .s_axi_w_if                 (caliptra_top_tb_i.s_axi_if),
        //     .s_axi_r_if                 (caliptra_top_tb_i.s_axi_if.r_sub),
        //     //AXI DMA Interface
        //     .m_axi_w_if                 (caliptra_top_tb_i.m_axi_if.w_mgr),
        //     .m_axi_r_if                 (caliptra_top_tb_i.m_axi_if.r_mgr),
        //     // QSPI Interface
        //     .qspi_clk_o                 (qspi_clk),
        //     .qspi_cs_no                 (qspi_cs_n),
        //     .qspi_d_i                   (qspi_data_device_to_host),
        //     .qspi_d_o                   (qspi_data_host_to_device),
        //     .qspi_d_en_o                (qspi_data_host_to_device_en),   
        //     // UART 
        //     .uart_tx                    (uart_loopback),
        //     .uart_rx                    (uart_loopback),
            
        //     .el2_mem_export             (caliptra_el2_mem_export.veer_sram_src),

        //     .ready_for_fuses            (ready_for_fuses),
        //     .ready_for_fw_push          (ready_for_fw_push),
        //     .ready_for_runtime          (),

        //     .mbox_sram_cs               (mbox_sram_cs),
        //     .mbox_sram_we               (mbox_sram_we),
        //     .mbox_sram_addr             (mbox_sram_addr),
        //     .mbox_sram_wdata            (mbox_sram_wdata),
        //     .mbox_sram_rdata            (mbox_sram_rdata),
                
        //     .imem_cs                    (imem_cs),
        //     .imem_addr                  (imem_addr),
        //     .imem_rdata                 (imem_rdata),

        //     .mailbox_data_avail         (mailbox_data_avail),
        //     .mailbox_flow_done          (),
        //     .BootFSM_BrkPoint           (BootFSM_BrkPoint),

        //     .recovery_data_avail        (1'b1/*TODO*/),

        //     //SoC Interrupts
        //     .cptra_error_fatal          (caliptra_error_fatal    ),
        //     .cptra_error_non_fatal      (caliptra_error_non_fatal),

        //     .etrng_req                  (),
        //     .itrng_data                 (4'b0),
        //     .itrng_valid                (1'b0),

        //     .generic_input_wires        (generic_input_wires),
        //     .generic_output_wires       (),

        //     .security_state             (caliptra_security_state),
        //     .scan_mode     (calipta_scan_mode)
        // );

        // // Caliptra Top TB Services
        // caliptra_top_tb_services #(
        //     .UVM_TB(0)
        // ) tb_services_i (
        //     .clk                        (core_clk),
        //     .cptra_rst_b                (rst_l),

        //     // Caliptra Memory Export Interface
        //     .el2_mem_export             (caliptra_el2_mem_export.veer_sram_sink),

        //     //SRAM interface for mbox
        //     .mbox_sram_cs               (mbox_sram_cs   ),
        //     .mbox_sram_we               (mbox_sram_we   ),
        //     .mbox_sram_addr             (mbox_sram_addr ),
        //     .mbox_sram_wdata            (mbox_sram_wdata),
        //     .mbox_sram_rdata            (mbox_sram_rdata),

        //     //SRAM interface for imem
        //     .imem_cs                    (imem_cs   ),
        //     .imem_addr                  (imem_addr ),
        //     .imem_rdata                 (imem_rdata),

        //     // Security State
        //     .security_state             (caliptra_security_state),

        //     //Scan mode
        //     .scan_mode                  (calipta_scan_mode),

        //     // TB Controls
        //     .ras_test_ctrl              (ras_test_ctrl),
        //     .cycleCnt                   (), //cycleCnt),

        //     //Interrupt flags
        //     .int_flag                   (int_flag),
        //     .cycleCnt_smpl_en           (cycleCnt_smpl_en),

        //     //Reset flags
        //     .assert_hard_rst_flag       (assert_hard_rst_flag),
        //     .deassert_hard_rst_flag     (deassert_hard_rst_flag),

        //     .assert_rst_flag            (assert_rst_flag_from_service),
        //     .deassert_rst_flag          (deassert_rst_flag_from_service),
            
        //     .cptra_uds_tb               (caliptra_uds_rand),
        //     .cptra_fe_tb                (caliptra_fe_rand),
        //     .cptra_obf_key_tb           (caliptra_obf_key_tb)

        // );

        // AXI Interconnect connections
        assign caliptra_top_tb_i.s_axi_if.awvalid = axi_interconnect.sintf_arr[3].AWVALID;
        assign caliptra_top_tb_i.s_axi_if.awaddr  = axi_interconnect.sintf_arr[3].AWADDR;
        assign caliptra_top_tb_i.s_axi_if.awid    = axi_interconnect.sintf_arr[3].AWID;
        assign caliptra_top_tb_i.s_axi_if.awlen   = axi_interconnect.sintf_arr[3].AWLEN;
        assign caliptra_top_tb_i.s_axi_if.awsize  = axi_interconnect.sintf_arr[3].AWSIZE;
        assign caliptra_top_tb_i.s_axi_if.awburst = axi_interconnect.sintf_arr[3].AWBURST;
        assign caliptra_top_tb_i.s_axi_if.awlock  = axi_interconnect.sintf_arr[3].AWLOCK;
        assign caliptra_top_tb_i.s_axi_if.awuser  = axi_interconnect.sintf_arr[3].AWUSER;
        assign axi_interconnect.sintf_arr[3].AWREADY = caliptra_top_tb_i.s_axi_if.awready;

        assign caliptra_top_tb_i.s_axi_if.wvalid = axi_interconnect.sintf_arr[3].WVALID;
        assign caliptra_top_tb_i.s_axi_if.wdata  = axi_interconnect.sintf_arr[3].WDATA;
        assign caliptra_top_tb_i.s_axi_if.wstrb  = axi_interconnect.sintf_arr[3].WSTRB;
        assign caliptra_top_tb_i.s_axi_if.wlast  = axi_interconnect.sintf_arr[3].WLAST;
        
        assign axi_interconnect.sintf_arr[3].WREADY = caliptra_top_tb_i.s_axi_if.wready;

        assign axi_interconnect.sintf_arr[3].BVALID = caliptra_top_tb_i.s_axi_if.bvalid;
        assign axi_interconnect.sintf_arr[3].BRESP  = caliptra_top_tb_i.s_axi_if.bresp;
        assign axi_interconnect.sintf_arr[3].BID    = caliptra_top_tb_i.s_axi_if.bid;
        assign caliptra_top_tb_i.s_axi_if.bready    = axi_interconnect.sintf_arr[3].BREADY;

        assign caliptra_top_tb_i.s_axi_if.arvalid = axi_interconnect.sintf_arr[3].ARVALID;
        assign caliptra_top_tb_i.s_axi_if.araddr  = axi_interconnect.sintf_arr[3].ARADDR;
        assign caliptra_top_tb_i.s_axi_if.arid    = axi_interconnect.sintf_arr[3].ARID;
        assign caliptra_top_tb_i.s_axi_if.arlen   = axi_interconnect.sintf_arr[3].ARLEN;
        assign caliptra_top_tb_i.s_axi_if.arsize  = axi_interconnect.sintf_arr[3].ARSIZE;
        assign caliptra_top_tb_i.s_axi_if.arburst = axi_interconnect.sintf_arr[3].ARBURST;
        assign caliptra_top_tb_i.s_axi_if.arlock  = axi_interconnect.sintf_arr[3].ARLOCK;
        assign caliptra_top_tb_i.s_axi_if.aruser  = axi_interconnect.sintf_arr[3].ARUSER;
        assign axi_interconnect.sintf_arr[3].ARREADY = caliptra_top_tb_i.s_axi_if.arready;
        
        assign axi_interconnect.sintf_arr[3].RVALID = caliptra_top_tb_i.s_axi_if.rvalid;
        assign axi_interconnect.sintf_arr[3].RDATA  = caliptra_top_tb_i.s_axi_if.rdata;
        assign axi_interconnect.sintf_arr[3].RRESP  = caliptra_top_tb_i.s_axi_if.rresp;
        assign axi_interconnect.sintf_arr[3].RID    = caliptra_top_tb_i.s_axi_if.rid;
        assign axi_interconnect.sintf_arr[3].RLAST  = caliptra_top_tb_i.s_axi_if.rlast;
        assign caliptra_top_tb_i.s_axi_if.rready = axi_interconnect.sintf_arr[3].RREADY;
        
        // -- CALIPTRA SRAM 
        // AXI Interconnect connections
        assign caliptra_top_tb_i.axi_sram_if.awvalid = axi_interconnect.sintf_arr[4].AWVALID;
        assign caliptra_top_tb_i.axi_sram_if.awaddr  = axi_interconnect.sintf_arr[4].AWADDR;
        assign caliptra_top_tb_i.axi_sram_if.awid    = axi_interconnect.sintf_arr[4].AWID;
        assign caliptra_top_tb_i.axi_sram_if.awlen   = axi_interconnect.sintf_arr[4].AWLEN;
        assign caliptra_top_tb_i.axi_sram_if.awsize  = axi_interconnect.sintf_arr[4].AWSIZE;
        assign caliptra_top_tb_i.axi_sram_if.awburst = axi_interconnect.sintf_arr[4].AWBURST;
        assign caliptra_top_tb_i.axi_sram_if.awlock  = axi_interconnect.sintf_arr[4].AWLOCK;
        assign caliptra_top_tb_i.axi_sram_if.awuser  = axi_interconnect.sintf_arr[4].AWUSER;
        assign axi_interconnect.sintf_arr[4].AWREADY = caliptra_top_tb_i.axi_sram_if.awready;

        assign caliptra_top_tb_i.axi_sram_if.wvalid = axi_interconnect.sintf_arr[4].WVALID;
        assign caliptra_top_tb_i.axi_sram_if.wdata  = axi_interconnect.sintf_arr[4].WDATA;
        assign caliptra_top_tb_i.axi_sram_if.wstrb  = axi_interconnect.sintf_arr[4].WSTRB;
        assign caliptra_top_tb_i.axi_sram_if.wlast  = axi_interconnect.sintf_arr[4].WLAST;
        assign axi_interconnect.sintf_arr[4].WREADY = caliptra_top_tb_i.axi_sram_if.wready;

        assign axi_interconnect.sintf_arr[4].BVALID = caliptra_top_tb_i.axi_sram_if.bvalid;
        assign axi_interconnect.sintf_arr[4].BRESP  = caliptra_top_tb_i.axi_sram_if.bresp;
        assign axi_interconnect.sintf_arr[4].BID    = caliptra_top_tb_i.axi_sram_if.bid;
        assign caliptra_top_tb_i.axi_sram_if.bready    = axi_interconnect.sintf_arr[4].BREADY;

        assign caliptra_top_tb_i.axi_sram_if.arvalid = axi_interconnect.sintf_arr[4].ARVALID;
        assign caliptra_top_tb_i.axi_sram_if.araddr  = axi_interconnect.sintf_arr[4].ARADDR;
        assign caliptra_top_tb_i.axi_sram_if.arid    = axi_interconnect.sintf_arr[4].ARID;
        assign caliptra_top_tb_i.axi_sram_if.arlen   = axi_interconnect.sintf_arr[4].ARLEN;
        assign caliptra_top_tb_i.axi_sram_if.arsize  = axi_interconnect.sintf_arr[4].ARSIZE;
        assign caliptra_top_tb_i.axi_sram_if.arburst = axi_interconnect.sintf_arr[4].ARBURST;
        assign caliptra_top_tb_i.axi_sram_if.arlock  = axi_interconnect.sintf_arr[4].ARLOCK;
        assign caliptra_top_tb_i.axi_sram_if.aruser  = axi_interconnect.sintf_arr[4].ARUSER;
        assign axi_interconnect.sintf_arr[4].ARREADY = caliptra_top_tb_i.axi_sram_if.arready;
        
        assign axi_interconnect.sintf_arr[4].RVALID = caliptra_top_tb_i.axi_sram_if.rvalid;
        assign axi_interconnect.sintf_arr[4].RDATA  = caliptra_top_tb_i.axi_sram_if.rdata;
        assign axi_interconnect.sintf_arr[4].RRESP  = caliptra_top_tb_i.axi_sram_if.rresp;
        assign axi_interconnect.sintf_arr[4].RID    = caliptra_top_tb_i.axi_sram_if.rid;
        assign axi_interconnect.sintf_arr[4].RLAST  = caliptra_top_tb_i.axi_sram_if.rlast;
        assign caliptra_top_tb_i.axi_sram_if.rready = axi_interconnect.sintf_arr[4].RREADY;
        


        // AXI Interconnect connections
        assign axi_interconnect.mintf_arr[3].AWVALID = caliptra_top_tb_i.m_axi_if.awvalid;
        assign axi_interconnect.mintf_arr[3].AWADDR  = caliptra_top_tb_i.m_axi_if.awaddr;
        assign axi_interconnect.mintf_arr[3].AWID    = caliptra_top_tb_i.m_axi_if.awid;
        assign axi_interconnect.mintf_arr[3].AWLEN   = caliptra_top_tb_i.m_axi_if.awlen;
        assign axi_interconnect.mintf_arr[3].AWSIZE  = caliptra_top_tb_i.m_axi_if.awsize;
        assign axi_interconnect.mintf_arr[3].AWBURST = caliptra_top_tb_i.m_axi_if.awburst;
        assign axi_interconnect.mintf_arr[3].AWLOCK  = caliptra_top_tb_i.m_axi_if.awlock;
        assign axi_interconnect.mintf_arr[3].AWUSER  = caliptra_top_tb_i.m_axi_if.awuser;
        assign caliptra_top_tb_i.m_axi_if.awready    = axi_interconnect.mintf_arr[3].AWREADY;
        
        assign axi_interconnect.mintf_arr[3].WVALID = caliptra_top_tb_i.m_axi_if.wvalid;
        assign axi_interconnect.mintf_arr[3].WDATA  = caliptra_top_tb_i.m_axi_if.wdata;
        assign axi_interconnect.mintf_arr[3].WSTRB  = caliptra_top_tb_i.m_axi_if.wstrb;
        assign axi_interconnect.mintf_arr[3].WLAST  = caliptra_top_tb_i.m_axi_if.wlast;
        assign caliptra_top_tb_i.m_axi_if.wready    = axi_interconnect.mintf_arr[3].WREADY;
        
        assign caliptra_top_tb_i.m_axi_if.bvalid = axi_interconnect.mintf_arr[3].BVALID;
        assign caliptra_top_tb_i.m_axi_if.bresp  = axi_interconnect.mintf_arr[3].BRESP;
        assign caliptra_top_tb_i.m_axi_if.bid    = axi_interconnect.mintf_arr[3].BID;
        assign axi_interconnect.mintf_arr[3].BREADY = caliptra_top_tb_i.m_axi_if.bready;
        
        assign axi_interconnect.mintf_arr[3].ARVALID = caliptra_top_tb_i.m_axi_if.arvalid;
        assign axi_interconnect.mintf_arr[3].ARADDR  = caliptra_top_tb_i.m_axi_if.araddr;
        assign axi_interconnect.mintf_arr[3].ARID    = caliptra_top_tb_i.m_axi_if.arid;
        assign axi_interconnect.mintf_arr[3].ARLEN   = caliptra_top_tb_i.m_axi_if.arlen;
        assign axi_interconnect.mintf_arr[3].ARSIZE  = caliptra_top_tb_i.m_axi_if.arsize;
        assign axi_interconnect.mintf_arr[3].ARBURST = caliptra_top_tb_i.m_axi_if.arburst;
        assign axi_interconnect.mintf_arr[3].ARLOCK  = caliptra_top_tb_i.m_axi_if.arlock;
        assign axi_interconnect.mintf_arr[3].ARUSER  = caliptra_top_tb_i.m_axi_if.aruser;
        assign caliptra_top_tb_i.m_axi_if.arready    = axi_interconnect.mintf_arr[3].ARREADY;
        
        assign caliptra_top_tb_i.m_axi_if.rvalid = axi_interconnect.mintf_arr[3].RVALID;
        assign caliptra_top_tb_i.m_axi_if.rdata  = axi_interconnect.mintf_arr[3].RDATA;
        assign caliptra_top_tb_i.m_axi_if.rresp  = axi_interconnect.mintf_arr[3].RRESP;
        assign caliptra_top_tb_i.m_axi_if.rid    = axi_interconnect.mintf_arr[3].RID;
        assign caliptra_top_tb_i.m_axi_if.rlast  = axi_interconnect.mintf_arr[3].RLAST;
        assign axi_interconnect.mintf_arr[3].RREADY = caliptra_top_tb_i.m_axi_if.rready;

        // AXI Interconnect connections
        assign axi_interconnect.mintf_arr[4].AWVALID = caliptra_top_tb_i.m_axi_bfm_if.awvalid;
        assign axi_interconnect.mintf_arr[4].AWADDR  = caliptra_top_tb_i.m_axi_bfm_if.awaddr;
        assign axi_interconnect.mintf_arr[4].AWID    = caliptra_top_tb_i.m_axi_bfm_if.awid;
        assign axi_interconnect.mintf_arr[4].AWLEN   = caliptra_top_tb_i.m_axi_bfm_if.awlen;
        assign axi_interconnect.mintf_arr[4].AWSIZE  = caliptra_top_tb_i.m_axi_bfm_if.awsize;
        assign axi_interconnect.mintf_arr[4].AWBURST = caliptra_top_tb_i.m_axi_bfm_if.awburst;
        assign axi_interconnect.mintf_arr[4].AWLOCK  = caliptra_top_tb_i.m_axi_bfm_if.awlock;
        assign axi_interconnect.mintf_arr[4].AWUSER  = caliptra_top_tb_i.m_axi_bfm_if.awuser;
        assign caliptra_top_tb_i.m_axi_bfm_if.awready = axi_interconnect.mintf_arr[4].AWREADY;

        assign axi_interconnect.mintf_arr[4].WVALID = caliptra_top_tb_i.m_axi_bfm_if.wvalid;
        assign axi_interconnect.mintf_arr[4].WDATA  = caliptra_top_tb_i.m_axi_bfm_if.wdata;
        assign axi_interconnect.mintf_arr[4].WSTRB  = caliptra_top_tb_i.m_axi_bfm_if.wstrb;
        assign axi_interconnect.mintf_arr[4].WLAST  = caliptra_top_tb_i.m_axi_bfm_if.wlast;
        assign caliptra_top_tb_i.m_axi_bfm_if.wready = axi_interconnect.mintf_arr[4].WREADY;

        assign caliptra_top_tb_i.m_axi_bfm_if.bvalid = axi_interconnect.mintf_arr[4].BVALID;
        assign caliptra_top_tb_i.m_axi_bfm_if.bresp  = axi_interconnect.mintf_arr[4].BRESP;
        assign caliptra_top_tb_i.m_axi_bfm_if.bid    = axi_interconnect.mintf_arr[4].BID;
        assign axi_interconnect.mintf_arr[4].BREADY  = caliptra_top_tb_i.m_axi_bfm_if.bready;

        assign axi_interconnect.mintf_arr[4].ARVALID = caliptra_top_tb_i.m_axi_bfm_if.arvalid;
        assign axi_interconnect.mintf_arr[4].ARADDR  = caliptra_top_tb_i.m_axi_bfm_if.araddr;
        assign axi_interconnect.mintf_arr[4].ARID    = caliptra_top_tb_i.m_axi_bfm_if.arid;
        assign axi_interconnect.mintf_arr[4].ARLEN   = caliptra_top_tb_i.m_axi_bfm_if.arlen;
        assign axi_interconnect.mintf_arr[4].ARSIZE  = caliptra_top_tb_i.m_axi_bfm_if.arsize;
        assign axi_interconnect.mintf_arr[4].ARBURST = caliptra_top_tb_i.m_axi_bfm_if.arburst;
        assign axi_interconnect.mintf_arr[4].ARLOCK  = caliptra_top_tb_i.m_axi_bfm_if.arlock;
        assign axi_interconnect.mintf_arr[4].ARUSER  = caliptra_top_tb_i.m_axi_bfm_if.aruser;
        assign caliptra_top_tb_i.m_axi_bfm_if.arready = axi_interconnect.mintf_arr[4].ARREADY;

        assign caliptra_top_tb_i.m_axi_bfm_if.rvalid = axi_interconnect.mintf_arr[4].RVALID;
        assign caliptra_top_tb_i.m_axi_bfm_if.rdata  = axi_interconnect.mintf_arr[4].RDATA;
        assign caliptra_top_tb_i.m_axi_bfm_if.rresp  = axi_interconnect.mintf_arr[4].RRESP;
        assign caliptra_top_tb_i.m_axi_bfm_if.rid    = axi_interconnect.mintf_arr[4].RID;
        assign caliptra_top_tb_i.m_axi_bfm_if.rlast  = axi_interconnect.mintf_arr[4].RLAST;
        assign axi_interconnect.mintf_arr[4].RREADY  = caliptra_top_tb_i.m_axi_bfm_if.rready;
        

        // initial begin
        //     $display("Caliptra RTL TOP instantiated");
        //     caliptra_pwrgood = 1'b0;
        //     BootFSM_BrkPoint = 1'b1; //Set to 1 even before anything starts

        //     // Caliptra OBFS Key
        //     //Key for UDS
        //     caliptra_obf_key_uds = 256'h54682728db5035eb04b79645c64a95606abb6ba392b6633d79173c027c5acf77;
        //     caliptra_uds_tb = 384'he4046d05385ab789c6a72866e08350f93f583e2a005ca0faecc32b5cfc323d461c76c107307654db5566a5bd693e227c;

        //     //Key for FE
        //     caliptra_obf_key_fe = 256'h31358e8af34d6ac31c958bbd5c8fb33c334714bffb41700d28b07f11cfe891e7;
        //     caliptra_fe_tb = 256'hb32e2b171b63827034ebb0d1909f7ef1d51c5f82c1bb9bc26bc4ac4dccdee835;
        //                    /*256'h7dca6154c2510ae1c87b1b422b02b621bb06cac280023894fcff3406af08ee9b,
        //                    256'he1dd72419beccddff77c722d992cdcc87e9c7486f56ab406ea608d8c6aeb060c,
        //                    256'h64cf2785ad1a159147567e39e303370da445247526d95942bf4d7e88057178b0};*/

        //     //swizzle the key so it matches the endianness of AES block
        //     //used for visual inspection of uds/fe flow, manually switching keys and checking both
        //     for (int dword = 0; dword < $bits(caliptra_obf_key/32); dword++) begin
        //         //caliptra_obf_key[dword] = caliptra_obf_key_uds[dword];
        //         caliptra_obf_key[dword] = caliptra_obf_key_fe[dword];
        //     end

        //     caliptra_top_tb_i.s_axi_if.rst_mgr();

        // end

        // always @(posedge core_clk) begin
        //     if (rst_l) begin
        //         caliptra_pwrgood <= 1'b0;
        //     end
        //     else begin
        //         caliptra_pwrgood <= 1'b1;
        //     end
        // end
        
        // // QSPI
        // for (genvar ii = 0; ii < `CALIPTRA_QSPI_IO_WIDTH; ii += 1) begin: gen_qspi_io
        //     assign qspi_data[ii] = qspi_data_host_to_device_en[ii]
        //         ? qspi_data_host_to_device[ii]
        //         : 1'bz;
        //     assign qspi_data_device_to_host[ii] = qspi_data_host_to_device_en[ii]
        //         ? 1'bz
        //         : qspi_data[ii];
        //   end
          
        //   localparam logic [15:0] DeviceId0 = 16'hF10A;
        //   localparam logic [15:0] DeviceId1 = 16'hF10B;
          
        //   spiflash #(
        //     .DeviceId(DeviceId0),
        //     .SpiFlashRandomData(0) // fixed pattern for smoke test
        //   ) spiflash0 (
        //     .sck (qspi_clk),
        //     .csb (qspi_cs_n[0]),
        //     .sd  (qspi_data)
        //   );
          
        //   spiflash #(
        //     .DeviceId(DeviceId1),
        //     .SpiFlashRandomData(0) // fixed pattern for smoke test
        //   ) spiflash1 (
        //     .sck (qspi_clk),
        //     .csb (qspi_cs_n[1]),
        //     .sd  (qspi_data)
        //   );

        // //-- JTAG
        // // JTAG DPI
        // jtagdpi #(
        //     .Name           ("jtag0"),
        //     .ListenPort     (5000)
        // ) jtagdpi (
        //     .clk_i          (core_clk),
        //     .rst_ni         (rst_l),
        //     .jtag_tck       (caliptra_jtag_tck),
        //     .jtag_tms       (caliptra_jtag_tms),
        //     .jtag_tdi       (caliptra_jtag_tdi),
        //     .jtag_tdo       (caliptra_jtag_tdo),
        //     .jtag_trst_n    (caliptra_jtag_trst_n),
        //     .jtag_srst_n    ()
        // );

       //=========================================================================-
       // RTL instance
       //=========================================================================-
        mcu_top rvtop_wrapper (
        .rst_l                  ( rst_l         ),
        .dbg_rst_l              ( porst_l       ),
        .clk                    ( core_clk      ),
        .rst_vec                ( reset_vector[31:1]),
        .nmi_int                ( nmi_int       ),
        .nmi_vec                ( nmi_vector[31:1]),
        .jtag_id                ( jtag_id[31:1]),



        //-------------------------- LSU AXI signals--------------------------
        // // AXI Write Channels

        .lsu_axi_awvalid        (axi_interconnect.mintf_arr[0].AWVALID),
        .lsu_axi_awready        (axi_interconnect.mintf_arr[0].AWREADY),
        .lsu_axi_awid           (axi_interconnect.mintf_arr[0].AWID),
        .lsu_axi_awaddr         (axi_interconnect.mintf_arr[0].AWADDR),
        .lsu_axi_awregion       (axi_interconnect.mintf_arr[0].AWREGION),
        .lsu_axi_awlen          (axi_interconnect.mintf_arr[0].AWLEN),
        .lsu_axi_awsize         (axi_interconnect.mintf_arr[0].AWSIZE),
        .lsu_axi_awburst        (axi_interconnect.mintf_arr[0].AWBURST),
        .lsu_axi_awlock         (axi_interconnect.mintf_arr[0].AWLOCK),
        .lsu_axi_awcache        (axi_interconnect.mintf_arr[0].AWCACHE),
        .lsu_axi_awprot         (axi_interconnect.mintf_arr[0].AWPROT),
        .lsu_axi_awqos          (axi_interconnect.mintf_arr[0].AWQOS),

        .lsu_axi_wvalid         (axi_interconnect.mintf_arr[0].WVALID),
        .lsu_axi_wready         (axi_interconnect.mintf_arr[0].WREADY),
        .lsu_axi_wdata          (axi_interconnect.mintf_arr[0].WDATA),
        .lsu_axi_wstrb          (axi_interconnect.mintf_arr[0].WSTRB),
        .lsu_axi_wlast          (axi_interconnect.mintf_arr[0].WLAST),

        .lsu_axi_bvalid         (axi_interconnect.mintf_arr[0].BVALID),
        .lsu_axi_bready         (axi_interconnect.mintf_arr[0].BREADY),
        .lsu_axi_bresp          (axi_interconnect.mintf_arr[0].BRESP),
        .lsu_axi_bid            (axi_interconnect.mintf_arr[0].BID),

        .lsu_axi_arvalid        (axi_interconnect.mintf_arr[0].ARVALID),
        .lsu_axi_arready        (axi_interconnect.mintf_arr[0].ARREADY),
        .lsu_axi_arid           (axi_interconnect.mintf_arr[0].ARID),
        .lsu_axi_araddr         (axi_interconnect.mintf_arr[0].ARADDR),
        .lsu_axi_arregion       (axi_interconnect.mintf_arr[0].ARREGION),
        .lsu_axi_arlen          (axi_interconnect.mintf_arr[0].ARLEN),
        .lsu_axi_arsize         (axi_interconnect.mintf_arr[0].ARSIZE),
        .lsu_axi_arburst        (axi_interconnect.mintf_arr[0].ARBURST),
        .lsu_axi_arlock         (axi_interconnect.mintf_arr[0].ARLOCK),
        .lsu_axi_arcache        (axi_interconnect.mintf_arr[0].ARCACHE),
        .lsu_axi_arprot         (axi_interconnect.mintf_arr[0].ARPROT),
        .lsu_axi_arqos          (axi_interconnect.mintf_arr[0].ARQOS),

        .lsu_axi_rvalid         (axi_interconnect.mintf_arr[0].RVALID),
        .lsu_axi_rready         (axi_interconnect.mintf_arr[0].RREADY),
        .lsu_axi_rid            (axi_interconnect.mintf_arr[0].RID),
        .lsu_axi_rdata          (axi_interconnect.mintf_arr[0].RDATA),
        .lsu_axi_rresp          (axi_interconnect.mintf_arr[0].RRESP),
        .lsu_axi_rlast          (axi_interconnect.mintf_arr[0].RLAST),

        //-------------------------- IFU AXI signals--------------------------
        // AXI Write Channels

        .ifu_axi_awvalid        ( axi_interconnect.mintf_arr[1].AWVALID ),
        .ifu_axi_awready        ( axi_interconnect.mintf_arr[1].AWREADY ),
        .ifu_axi_awid           ( axi_interconnect.mintf_arr[1].AWID    ),
        .ifu_axi_awaddr         ( axi_interconnect.mintf_arr[1].AWADDR  ),
        .ifu_axi_awregion       ( axi_interconnect.mintf_arr[1].AWREGION),
        .ifu_axi_awlen          ( axi_interconnect.mintf_arr[1].AWLEN   ),
        .ifu_axi_awsize         ( axi_interconnect.mintf_arr[1].AWSIZE  ),
        .ifu_axi_awburst        ( axi_interconnect.mintf_arr[1].AWBURST ),
        .ifu_axi_awlock         ( axi_interconnect.mintf_arr[1].AWLOCK  ),
        .ifu_axi_awcache        ( axi_interconnect.mintf_arr[1].AWCACHE ),
        .ifu_axi_awprot         ( axi_interconnect.mintf_arr[1].AWPROT  ),
        .ifu_axi_awqos          ( axi_interconnect.mintf_arr[1].AWQOS   ),

        .ifu_axi_wvalid         ( axi_interconnect.mintf_arr[1].WVALID  ),
        .ifu_axi_wready         ( axi_interconnect.mintf_arr[1].WREADY  ),
        .ifu_axi_wdata          ( axi_interconnect.mintf_arr[1].WDATA   ),
        .ifu_axi_wstrb          ( axi_interconnect.mintf_arr[1].WSTRB   ),
        .ifu_axi_wlast          ( axi_interconnect.mintf_arr[1].WLAST   ),

        .ifu_axi_bvalid         ( axi_interconnect.mintf_arr[1].BVALID  ),
        .ifu_axi_bready         ( axi_interconnect.mintf_arr[1].BREADY  ),
        .ifu_axi_bresp          ( axi_interconnect.mintf_arr[1].BRESP   ),
        .ifu_axi_bid            ( axi_interconnect.mintf_arr[1].BID     ),

        .ifu_axi_arvalid        ( axi_interconnect.mintf_arr[1].ARVALID ),
        .ifu_axi_arready        ( axi_interconnect.mintf_arr[1].ARREADY ),
        .ifu_axi_arid           ( axi_interconnect.mintf_arr[1].ARID    ),
        .ifu_axi_araddr         ( axi_interconnect.mintf_arr[1].ARADDR  ),
        .ifu_axi_arlen          ( axi_interconnect.mintf_arr[1].ARLEN   ),
        .ifu_axi_arsize         ( axi_interconnect.mintf_arr[1].ARSIZE  ),
        .ifu_axi_arburst        ( axi_interconnect.mintf_arr[1].ARBURST ),
        .ifu_axi_arlock         ( axi_interconnect.mintf_arr[1].ARLOCK  ),
        .ifu_axi_arcache        ( axi_interconnect.mintf_arr[1].ARCACHE ),
        .ifu_axi_arprot         ( axi_interconnect.mintf_arr[1].ARPROT  ),
        .ifu_axi_arqos          ( axi_interconnect.mintf_arr[1].ARQOS   ),
        .ifu_axi_arregion       ( axi_interconnect.mintf_arr[1].ARREGION),

        .ifu_axi_rvalid         ( axi_interconnect.mintf_arr[1].RVALID  ),
        .ifu_axi_rready         ( axi_interconnect.mintf_arr[1].RREADY  ),
        .ifu_axi_rid            ( axi_interconnect.mintf_arr[1].RID     ),
        .ifu_axi_rdata          ( axi_interconnect.mintf_arr[1].RDATA   ),
        .ifu_axi_rresp          ( axi_interconnect.mintf_arr[1].RRESP   ),
        .ifu_axi_rlast          ( axi_interconnect.mintf_arr[1].RLAST   ),

        //-------------------------- SB AXI signals--------------------------
        // AXI Write Channels
        .sb_axi_awvalid         (sb_axi_awvalid),
        .sb_axi_awready         (sb_axi_awready),
        .sb_axi_awid            (sb_axi_awid),
        .sb_axi_awaddr          (sb_axi_awaddr),
        .sb_axi_awregion        (sb_axi_awregion),
        .sb_axi_awlen           (sb_axi_awlen),
        .sb_axi_awsize          (sb_axi_awsize),
        .sb_axi_awburst         (sb_axi_awburst),
        .sb_axi_awlock          (sb_axi_awlock),
        .sb_axi_awcache         (sb_axi_awcache),
        .sb_axi_awprot          (sb_axi_awprot),
        .sb_axi_awqos           (sb_axi_awqos),

        .sb_axi_wvalid          (sb_axi_wvalid),
        .sb_axi_wready          (sb_axi_wready),
        .sb_axi_wdata           (sb_axi_wdata),
        .sb_axi_wstrb           (sb_axi_wstrb),
        .sb_axi_wlast           (sb_axi_wlast),

        .sb_axi_bvalid          (sb_axi_bvalid),
        .sb_axi_bready          (sb_axi_bready),
        .sb_axi_bresp           (sb_axi_bresp),
        .sb_axi_bid             (sb_axi_bid),


        .sb_axi_arvalid         (sb_axi_arvalid),
        .sb_axi_arready         (sb_axi_arready),
        .sb_axi_arid            (sb_axi_arid),
        .sb_axi_araddr          (sb_axi_araddr),
        .sb_axi_arregion        (sb_axi_arregion),
        .sb_axi_arlen           (sb_axi_arlen),
        .sb_axi_arsize          (sb_axi_arsize),
        .sb_axi_arburst         (sb_axi_arburst),
        .sb_axi_arlock          (sb_axi_arlock),
        .sb_axi_arcache         (sb_axi_arcache),
        .sb_axi_arprot          (sb_axi_arprot),
        .sb_axi_arqos           (sb_axi_arqos),

        .sb_axi_rvalid          (sb_axi_rvalid),
        .sb_axi_rready          (sb_axi_rready),
        .sb_axi_rid             (sb_axi_rid),
        .sb_axi_rdata           (sb_axi_rdata),
        .sb_axi_rresp           (sb_axi_rresp),
        .sb_axi_rlast           (sb_axi_rlast),

        //-------------------------- DMA AXI signals--------------------------
        // AXI Write Channels
        .dma_axi_awvalid        (axi_interconnect.sintf_arr[2].AWVALID),
        .dma_axi_awready        (axi_interconnect.sintf_arr[2].AWREADY),
        .dma_axi_awid           (axi_interconnect.sintf_arr[2].AWID),
        .dma_axi_awaddr         (axi_interconnect.sintf_arr[2].AWADDR),
        .dma_axi_awsize         (axi_interconnect.sintf_arr[2].AWSIZE),
        .dma_axi_awprot         (axi_interconnect.sintf_arr[2].AWPROT),
        .dma_axi_awlen          (axi_interconnect.sintf_arr[2].AWLEN),
        .dma_axi_awburst        (axi_interconnect.sintf_arr[2].AWBURST),

        .dma_axi_wvalid         (axi_interconnect.sintf_arr[2].WVALID),
        .dma_axi_wready         (axi_interconnect.sintf_arr[2].WREADY),
        .dma_axi_wdata          (axi_interconnect.sintf_arr[2].WDATA),
        .dma_axi_wstrb          (axi_interconnect.sintf_arr[2].WSTRB),
        .dma_axi_wlast          (axi_interconnect.sintf_arr[2].WLAST),

        .dma_axi_bvalid         (axi_interconnect.sintf_arr[2].BVALID),
        .dma_axi_bready         (axi_interconnect.sintf_arr[2].BREADY),
        .dma_axi_bresp          (axi_interconnect.sintf_arr[2].BRESP),
        .dma_axi_bid            (axi_interconnect.sintf_arr[2].BID),

        .dma_axi_arvalid        (axi_interconnect.sintf_arr[2].ARVALID),
        .dma_axi_arready        (axi_interconnect.sintf_arr[2].ARREADY),
        .dma_axi_arid           (axi_interconnect.sintf_arr[2].ARID),
        .dma_axi_araddr         (axi_interconnect.sintf_arr[2].ARADDR),
        .dma_axi_arsize         (axi_interconnect.sintf_arr[2].ARSIZE),
        .dma_axi_arprot         (axi_interconnect.sintf_arr[2].ARPROT),
        .dma_axi_arlen          (axi_interconnect.sintf_arr[2].ARLEN),
        .dma_axi_arburst        (axi_interconnect.sintf_arr[2].ARBURST),

        .dma_axi_rvalid         (axi_interconnect.sintf_arr[2].RVALID),
        .dma_axi_rready         (axi_interconnect.sintf_arr[2].RREADY),
        .dma_axi_rid            (axi_interconnect.sintf_arr[2].RID),
        .dma_axi_rdata          (axi_interconnect.sintf_arr[2].RDATA),
        .dma_axi_rresp          (axi_interconnect.sintf_arr[2].RRESP),
        .dma_axi_rlast          (axi_interconnect.sintf_arr[2].RLAST),

        .timer_int              ( timer_int ),
        .soft_int               ( soft_int ),
        .extintsrc_req          ( ext_int ),

        .lsu_bus_clk_en         ( 1'b1  ),// Clock ratio b/w cpu core clk & AHB master interface
        .ifu_bus_clk_en         ( 1'b1  ),// Clock ratio b/w cpu core clk & AHB master interface
        .dbg_bus_clk_en         ( 1'b1  ),// Clock ratio b/w cpu core clk & AHB Debug master interface
        .dma_bus_clk_en         ( 1'b1  ),// Clock ratio b/w cpu core clk & AHB slave interface

        .trace_rv_i_insn_ip     (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip  (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip    (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip   (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip     (trace_rv_i_tval_ip),

        .jtag_tck               ( 1'b0  ),
        .jtag_tms               ( 1'b0  ),
        .jtag_tdi               ( 1'b0  ),
        .jtag_trst_n            ( 1'b0  ),
        .jtag_tdo               ( jtag_tdo ),
        .jtag_tdoEn             (),

        .mpc_debug_halt_ack     ( mpc_debug_halt_ack),
        .mpc_debug_halt_req     ( 1'b0),
        .mpc_debug_run_ack      ( mpc_debug_run_ack),
        .mpc_debug_run_req      ( 1'b1),
        .mpc_reset_run_req      ( 1'b1),             // Start running after reset
         .debug_brkpt_status    (debug_brkpt_status),

        .i_cpu_halt_req         ( 1'b0  ),    // Async halt req to CPU
        .o_cpu_halt_ack         ( o_cpu_halt_ack ),    // core response to halt
        .o_cpu_halt_status      ( o_cpu_halt_status ), // 1'b1 indicates core is halted
        .i_cpu_run_req          ( 1'b0  ),     // Async restart req to CPU
        .o_debug_mode_status    (o_debug_mode_status),
        .o_cpu_run_ack          ( o_cpu_run_ack ),     // Core response to run req

        .dec_tlu_perfcnt0       (),
        .dec_tlu_perfcnt1       (),
        .dec_tlu_perfcnt2       (),
        .dec_tlu_perfcnt3       (),

        .mem_clk                (mcu_el2_mem_export.clk),

        .iccm_clken             (mcu_el2_mem_export.iccm_clken),
        .iccm_wren_bank         (mcu_el2_mem_export.iccm_wren_bank),
        .iccm_addr_bank         (mcu_el2_mem_export.iccm_addr_bank),
        .iccm_bank_wr_data      (mcu_el2_mem_export.iccm_bank_wr_data),
        .iccm_bank_wr_ecc       (mcu_el2_mem_export.iccm_bank_wr_ecc),
        .iccm_bank_dout         (mcu_el2_mem_export.iccm_bank_dout),
        .iccm_bank_ecc          (mcu_el2_mem_export.iccm_bank_ecc),

        .dccm_clken             (mcu_el2_mem_export.dccm_clken),
        .dccm_wren_bank         (mcu_el2_mem_export.dccm_wren_bank),
        .dccm_addr_bank         (mcu_el2_mem_export.dccm_addr_bank),
        .dccm_wr_data_bank      (mcu_el2_mem_export.dccm_wr_data_bank),
        .dccm_wr_ecc_bank       (mcu_el2_mem_export.dccm_wr_ecc_bank),
        .dccm_bank_dout         (mcu_el2_mem_export.dccm_bank_dout),
        .dccm_bank_ecc          (mcu_el2_mem_export.dccm_bank_ecc),

        .iccm_ecc_single_error  (),
        .iccm_ecc_double_error  (),
        .dccm_ecc_single_error  (),
        .dccm_ecc_double_error  (),

    // remove mems DFT pins for opensource
        .ic_data_ext_in_pkt     ('0),
        .ic_tag_ext_in_pkt      ('0),

        .core_id                ('0),
        .scan_mode              ( 1'b0 ),         // To enable scan mode
        .mbist_mode             ( 1'b0 ),        // to enable mbist

        .dmi_uncore_enable      (),
        .dmi_uncore_en          (),
        .dmi_uncore_wr_en       (),
        .dmi_uncore_addr        (),
        .dmi_uncore_wdata       (),
        .dmi_uncore_rdata       ()

    );


    //=========================================================================-
    // AXI MEM instance
    //=========================================================================-


    axi_slv #(.TAGW(7)) imem(

        .aclk           (core_clk),
        .rst_l          (rst_l),

        .arvalid        (axi_interconnect.sintf_arr[0].ARVALID),
        .arready        (axi_interconnect.sintf_arr[0].ARREADY),
        .araddr         (axi_interconnect.sintf_arr[0].ARADDR),
        .arid           (axi_interconnect.sintf_arr[0].ARID),
        .arlen          (axi_interconnect.sintf_arr[0].ARLEN),
        .arburst        (axi_interconnect.sintf_arr[0].ARBURST),
        .arsize         (axi_interconnect.sintf_arr[0].ARSIZE),

        .rvalid         (axi_interconnect.sintf_arr[0].RVALID),
        .rready         (axi_interconnect.sintf_arr[0].RREADY),
        .rdata          (axi_interconnect.sintf_arr[0].RDATA),
        .rresp          (axi_interconnect.sintf_arr[0].RRESP),
        .rid            (axi_interconnect.sintf_arr[0].RID),
        .rlast          (axi_interconnect.sintf_arr[0].RLAST),

        .awvalid        (axi_interconnect.sintf_arr[0].AWVALID),
        .awready        (axi_interconnect.sintf_arr[0].AWREADY),
        .awaddr         (axi_interconnect.sintf_arr[0].AWADDR),
        .awid           (axi_interconnect.sintf_arr[0].AWID),
        .awlen          (axi_interconnect.sintf_arr[0].AWLEN),
        .awburst        (axi_interconnect.sintf_arr[0].AWBURST),
        .awsize         (axi_interconnect.sintf_arr[0].AWSIZE),

        .wdata          (axi_interconnect.sintf_arr[0].WDATA),
        .wstrb          (axi_interconnect.sintf_arr[0].WSTRB),
        .wvalid         (axi_interconnect.sintf_arr[0].WVALID),
        .wready         (axi_interconnect.sintf_arr[0].WREADY),

        .bvalid         (axi_interconnect.sintf_arr[0].BVALID),
        .bready         (axi_interconnect.sintf_arr[0].BREADY),
        .bresp          (axi_interconnect.sintf_arr[0].BRESP),
        .bid            (axi_interconnect.sintf_arr[0].BID)

    );

    // defparam lmem.TAGW =`MCU_RV_LSU_BUS_TAG;

    //axi_slv #(.TAGW(`MCU_RV_LSU_BUS_TAG)) lmem(
    // -- Addtional 3 required for QVIP Interconnect
    // `MCU_RV_LSU_BUS_TAG + 3
    axi_slv #(.TAGW(7)) lmem(
        .aclk(core_clk),
        .rst_l(rst_l),

        .arvalid        (axi_interconnect.sintf_arr[1].ARVALID),
        .arready        (axi_interconnect.sintf_arr[1].ARREADY),
        .araddr         (axi_interconnect.sintf_arr[1].ARADDR),
        .arid           (axi_interconnect.sintf_arr[1].ARID),
        .arlen          (axi_interconnect.sintf_arr[1].ARLEN),
        .arburst        (axi_interconnect.sintf_arr[1].ARBURST),
        .arsize         (axi_interconnect.sintf_arr[1].ARSIZE),

        .rvalid         (axi_interconnect.sintf_arr[1].RVALID),
        .rready         (axi_interconnect.sintf_arr[1].RREADY),
        .rdata          (axi_interconnect.sintf_arr[1].RDATA),
        .rresp          (axi_interconnect.sintf_arr[1].RRESP),
        .rid            (axi_interconnect.sintf_arr[1].RID),
        .rlast          (axi_interconnect.sintf_arr[1].RLAST),

        .awvalid        (axi_interconnect.sintf_arr[1].AWVALID),
        .awready        (axi_interconnect.sintf_arr[1].AWREADY),
        .awaddr         (axi_interconnect.sintf_arr[1].AWADDR),
        .awid           (axi_interconnect.sintf_arr[1].AWID),
        .awlen          (axi_interconnect.sintf_arr[1].AWLEN),
        .awburst        (axi_interconnect.sintf_arr[1].AWBURST),
        .awsize         (axi_interconnect.sintf_arr[1].AWSIZE),

        .wdata          (axi_interconnect.sintf_arr[1].WDATA),
        .wstrb          (axi_interconnect.sintf_arr[1].WSTRB),
        .wvalid         (axi_interconnect.sintf_arr[1].WVALID),
        .wready         (axi_interconnect.sintf_arr[1].WREADY),

        .bvalid         (axi_interconnect.sintf_arr[1].BVALID),
        .bready         (axi_interconnect.sintf_arr[1].BREADY),
        .bresp          (axi_interconnect.sintf_arr[1].BRESP),
        .bid            (axi_interconnect.sintf_arr[1].BID)

    );

task preload_iccm;
    bit[31:0] data;
    bit[31:0] addr, eaddr, saddr;

    /*
    addresses:
     0xfffffff0 - ICCM start address to load
     0xfffffff4 - ICCM end address to load
    */
    `ifndef VERILATOR
    init_iccm();
    `endif
    addr = 'hffff_fff0;
    saddr = {lmem.mem[addr+3],lmem.mem[addr+2],lmem.mem[addr+1],lmem.mem[addr]};
    if ( (saddr < `MCU_RV_ICCM_SADR) || (saddr > `MCU_RV_ICCM_EADR)) return;
    `ifndef MCU_RV_ICCM_ENABLE
        $display("********************************************************");
        $display("ICCM preload: there is no ICCM in VeeR, terminating !!!");
        $display("********************************************************");
        $finish;
    `endif
    addr += 4;
    eaddr = {lmem.mem[addr+3],lmem.mem[addr+2],lmem.mem[addr+1],lmem.mem[addr]};
    $display("ICCM pre-load from %h to %h", saddr, eaddr);

    for(addr= saddr; addr <= eaddr; addr+=4) begin
        data = {imem.mem[addr+3],imem.mem[addr+2],imem.mem[addr+1],imem.mem[addr]};
        slam_iccm_ram(addr, data == 0 ? 0 : {riscv_ecc32(data),data});
    end

endtask


task preload_dccm;
    bit[31:0] data;
    bit[31:0] addr, saddr, eaddr;

    /*
    addresses:
     0xffff_fff8 - DCCM start address to load
     0xffff_fffc - DCCM end address to load
    */

    addr = 'hffff_fff8;
    saddr = {lmem.mem[addr+3],lmem.mem[addr+2],lmem.mem[addr+1],lmem.mem[addr]};
    if (saddr < `MCU_RV_DCCM_SADR || saddr > `MCU_RV_DCCM_EADR) return;
    `ifndef MCU_RV_DCCM_ENABLE
        $display("********************************************************");
        $display("DCCM preload: there is no DCCM in VeeR, terminating !!!");
        $display("********************************************************");
        $finish;
    `endif
    addr += 4;
    eaddr = {lmem.mem[addr+3],lmem.mem[addr+2],lmem.mem[addr+1],lmem.mem[addr]};
    $display("DCCM pre-load from %h to %h", saddr, eaddr);

    for(addr=saddr; addr <= eaddr; addr+=4) begin
        data = {lmem.mem[addr+3],lmem.mem[addr+2],lmem.mem[addr+1],lmem.mem[addr]};
        slam_dccm_ram(addr, data == 0 ? 0 : {riscv_ecc32(data),data});
    end
endtask



`ifdef VERILATOR
`define DRAM(bk) Gen_dccm_enable.dccm_loop[bk].ram.ram_core
`define IRAM(bk) Gen_iccm_enable.iccm_loop[bk].iccm_bank.ram_core
`else
`define DRAM(bk) Gen_dccm_enable.dccm_loop[bk].dccm.dccm_bank.ram_core
`define IRAM(bk) Gen_iccm_enable.iccm_loop[bk].iccm.iccm_bank.ram_core
`endif


task slam_dccm_ram(input [31:0] addr, input[38:0] data);
    int bank, indx;
    bank = get_dccm_bank(addr, indx);
    `ifdef MCU_RV_DCCM_ENABLE
    case(bank)
    0: `DRAM(0)[indx] = data;
    1: `DRAM(1)[indx] = data;
    `ifdef MCU_RV_DCCM_NUM_BANKS_4
    2: `DRAM(2)[indx] = data;
    3: `DRAM(3)[indx] = data;
    `endif
    `ifdef MCU_RV_DCCM_NUM_BANKS_8
    2: `DRAM(2)[indx] = data;
    3: `DRAM(3)[indx] = data;
    4: `DRAM(4)[indx] = data;
    5: `DRAM(5)[indx] = data;
    6: `DRAM(6)[indx] = data;
    7: `DRAM(7)[indx] = data;
    `endif
    endcase
    `endif
    //$display("Writing bank %0d indx=%0d A=%h, D=%h",bank, indx, addr, data);
endtask


task slam_iccm_ram( input[31:0] addr, input[38:0] data);
    int bank, idx;

    bank = get_iccm_bank(addr, idx);
    `ifdef MCU_RV_ICCM_ENABLE
    case(bank) // {
      0: `IRAM(0)[idx] = data;
      1: `IRAM(1)[idx] = data;
     `ifdef MCU_RV_ICCM_NUM_BANKS_4
      2: `IRAM(2)[idx] = data;
      3: `IRAM(3)[idx] = data;
     `endif
     `ifdef MCU_RV_ICCM_NUM_BANKS_8
      2: `IRAM(2)[idx] = data;
      3: `IRAM(3)[idx] = data;
      4: `IRAM(4)[idx] = data;
      5: `IRAM(5)[idx] = data;
      6: `IRAM(6)[idx] = data;
      7: `IRAM(7)[idx] = data;
     `endif

     `ifdef MCU_RV_ICCM_NUM_BANKS_16
      2: `IRAM(2)[idx] = data;
      3: `IRAM(3)[idx] = data;
      4: `IRAM(4)[idx] = data;
      5: `IRAM(5)[idx] = data;
      6: `IRAM(6)[idx] = data;
      7: `IRAM(7)[idx] = data;
      8: `IRAM(8)[idx] = data;
      9: `IRAM(9)[idx] = data;
      10: `IRAM(10)[idx] = data;
      11: `IRAM(11)[idx] = data;
      12: `IRAM(12)[idx] = data;
      13: `IRAM(13)[idx] = data;
      14: `IRAM(14)[idx] = data;
      15: `IRAM(15)[idx] = data;
     `endif
    endcase // }
    `endif
endtask

task init_iccm;
    `ifdef MCU_RV_ICCM_ENABLE
        `IRAM(0) = '{default:39'h0};
        `IRAM(1) = '{default:39'h0};
    `ifdef MCU_RV_ICCM_NUM_BANKS_4
        `IRAM(2) = '{default:39'h0};
        `IRAM(3) = '{default:39'h0};
    `endif
    `ifdef MCU_RV_ICCM_NUM_BANKS_8
        `IRAM(4) = '{default:39'h0};
        `IRAM(5) = '{default:39'h0};
        `IRAM(6) = '{default:39'h0};
        `IRAM(7) = '{default:39'h0};
    `endif

    `ifdef MCU_RV_ICCM_NUM_BANKS_16
        `IRAM(4) = '{default:39'h0};
        `IRAM(5) = '{default:39'h0};
        `IRAM(6) = '{default:39'h0};
        `IRAM(7) = '{default:39'h0};
        `IRAM(8) = '{default:39'h0};
        `IRAM(9) = '{default:39'h0};
        `IRAM(10) = '{default:39'h0};
        `IRAM(11) = '{default:39'h0};
        `IRAM(12) = '{default:39'h0};
        `IRAM(13) = '{default:39'h0};
        `IRAM(14) = '{default:39'h0};
        `IRAM(15) = '{default:39'h0};
     `endif
    `endif
endtask


function[6:0] riscv_ecc32(input[31:0] data);
    reg[6:0] synd;
    synd[0] = ^(data & 32'h56aa_ad5b);
    synd[1] = ^(data & 32'h9b33_366d);
    synd[2] = ^(data & 32'he3c3_c78e);
    synd[3] = ^(data & 32'h03fc_07f0);
    synd[4] = ^(data & 32'h03ff_f800);
    synd[5] = ^(data & 32'hfc00_0000);
    synd[6] = ^{data, synd[5:0]};
    return synd;
endfunction

function int get_dccm_bank(input[31:0] addr,  output int bank_idx);
    `ifdef MCU_RV_DCCM_NUM_BANKS_2
        bank_idx = int'(addr[`MCU_RV_DCCM_BITS-1:3]);
        return int'( addr[2]);
    `elsif MCU_RV_DCCM_NUM_BANKS_4
        bank_idx = int'(addr[`MCU_RV_DCCM_BITS-1:4]);
        return int'(addr[3:2]);
    `elsif MCU_RV_DCCM_NUM_BANKS_8
        bank_idx = int'(addr[`MCU_RV_DCCM_BITS-1:5]);
        return int'( addr[4:2]);
    `endif
endfunction

function int get_iccm_bank(input[31:0] addr,  output int bank_idx);
    `ifdef MCU_RV_DCCM_NUM_BANKS_2
        bank_idx = int'(addr[`MCU_RV_DCCM_BITS-1:3]);
        return int'( addr[2]);
    `elsif MCU_RV_ICCM_NUM_BANKS_4
        bank_idx = int'(addr[`MCU_RV_ICCM_BITS-1:4]);
        return int'(addr[3:2]);
    `elsif MCU_RV_ICCM_NUM_BANKS_8
        bank_idx = int'(addr[`MCU_RV_ICCM_BITS-1:5]);
        return int'( addr[4:2]);
    `elsif MCU_RV_ICCM_NUM_BANKS_16
        bank_idx = int'(addr[`MCU_RV_ICCM_BITS-1:6]);
        return int'( addr[5:2]);
    `endif
endfunction

task dump_signature ();
        integer fp, i;

        $display("Dumping memory signature (0x%08X - 0x%08X)...",
            mem_signature_begin,
            mem_signature_end
        );

        fp = $fopen("veer.signature", "w");
        for (i=mem_signature_begin; i<mem_signature_end; i=i+4) begin

            // From DCCM
    `ifdef MCU_RV_DCCM_ENABLE
            if (i >= `MCU_RV_DCCM_SADR && i < `MCU_RV_DCCM_EADR) begin
                bit[38:0] data;
                int bank, indx;
                bank = get_dccm_bank(i, indx);

                case (bank)
                0: data = `DRAM(0)[indx];
                1: data = `DRAM(1)[indx];
                `ifdef MCU_RV_DCCM_NUM_BANKS_4
                2: data = `DRAM(2)[indx];
                3: data = `DRAM(3)[indx];
                `endif
                `ifdef MCU_RV_DCCM_NUM_BANKS_8
                2: data = `DRAM(2)[indx];
                3: data = `DRAM(3)[indx];
                4: data = `DRAM(4)[indx];
                5: data = `DRAM(5)[indx];
                6: data = `DRAM(6)[indx];
                7: data = `DRAM(7)[indx];
                `endif
                endcase

                $fwrite(fp, "%08X\n", data[31:0]);
            end else
    `endif
            // From RAM
            begin
                $fwrite(fp, "%02X%02X%02X%02X\n",
                    lmem.mem[i+3],
                    lmem.mem[i+2],
                    lmem.mem[i+1],
                    lmem.mem[i+0]
                );
            end
        end

        $fclose(fp);
endtask

//////////////////////////////////////////////////////
// DCCM
//
if (mcu_pt.DCCM_ENABLE == 1) begin: Gen_dccm_enable
    `define EL2_LOCAL_DCCM_RAM_TEST_PORTS   .TEST1   (1'b0   ), \
                                            .RME     (1'b0   ), \
                                            .RM      (4'b0000), \
                                            .LS      (1'b0   ), \
                                            .DS      (1'b0   ), \
                                            .SD      (1'b0   ), \
                                            .TEST_RNM(1'b0   ), \
                                            .BC1     (1'b0   ), \
                                            .BC2     (1'b0   ), \

    logic [mcu_pt.DCCM_NUM_BANKS-1:0] [mcu_pt.DCCM_FDATA_WIDTH-1:0] dccm_wdata_bitflip;
    int ii;
    localparam DCCM_INDEX_DEPTH = ((mcu_pt.DCCM_SIZE)*1024)/((mcu_pt.DCCM_BYTE_WIDTH)*(mcu_pt.DCCM_NUM_BANKS));  // Depth of memory bank
    // 8 Banks, 16KB each (2048 x 72)
    always_ff @(mcu_el2_mem_export.clk) begin : inject_dccm_ecc_error
        if (~error_injection_mode.dccm_single_bit_error && ~error_injection_mode.dccm_double_bit_error) begin
            dccm_wdata_bitflip <= '{default:0};
        end else if (mcu_el2_mem_export.dccm_clken & mcu_el2_mem_export.dccm_wren_bank) begin
            for (ii=0; ii<mcu_pt.DCCM_NUM_BANKS; ii++) begin: dccm_bitflip_injection_loop
                dccm_wdata_bitflip[ii] <= get_bitflip_mask(error_injection_mode.dccm_double_bit_error);
            end
        end
    end
    for (genvar i=0; i<mcu_pt.DCCM_NUM_BANKS; i++) begin: dccm_loop
        // --- new --- assign dccm_wr_fdata_bank[i][mcu_pt.DCCM_DATA_WIDTH-1:0] = mcu_el2_mem_export.dccm_wr_data_bank[i];
        // --- new --- assign dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:mcu_pt.DCCM_DATA_WIDTH] = mcu_el2_mem_export.dccm_wr_ecc_bank[i];
        // --- new --- assign mcu_el2_mem_export.dccm_bank_dout[i] = dccm_bank_fdout[i][31:0];
        // --- new --- assign mcu_el2_mem_export.dccm_bank_ecc[i] = dccm_bank_fdout[i][38:32];
        //assign mcu_el2_mem_export.dccm_wr_data_bank[i] = dccm_wr_fdata_bank[i][mcu_pt.DCCM_DATA_WIDTH-1:0];
        //assign mcu_el2_mem_export.dccm_wr_ecc_bank[i] = dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:mcu_pt.DCCM_DATA_WIDTH];
        //assign dccm_bank_fdout[i] = {mcu_el2_mem_export.dccm_bank_ecc[i], mcu_el2_mem_export.dccm_bank_dout[i]};

    `ifdef VERILATOR

            el2_ram #(DCCM_INDEX_DEPTH,39)  ram (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
    `else

        if (DCCM_INDEX_DEPTH == 32768) begin : dccm
            ram_32768x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 16384) begin : dccm
            ram_16384x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 8192) begin : dccm
            ram_8192x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 4096) begin : dccm
            ram_4096x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 3072) begin : dccm
            ram_3072x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 2048) begin : dccm
            ram_2048x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 1024) begin : dccm
            ram_1024x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 512) begin : dccm
            ram_512x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 256) begin : dccm
            ram_256x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
        else if (DCCM_INDEX_DEPTH == 128) begin : dccm
            ram_128x39  dccm_bank (
                                    // Primary ports
                                    .ME(mcu_el2_mem_export.dccm_clken[i]),
                                    .CLK(mcu_el2_mem_export.clk),
                                    .WE(mcu_el2_mem_export.dccm_wren_bank[i]),
                                    .ADR(mcu_el2_mem_export.dccm_addr_bank[i]),
                                    .D(dccm_wr_fdata_bank[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .Q(dccm_bank_fdout[i][mcu_pt.DCCM_FDATA_WIDTH-1:0]),
                                    .ROP ( ),
                                    // These are used by SoC
                                    `EL2_LOCAL_DCCM_RAM_TEST_PORTS
                                    .*
                                    );
        end
    `endif
    end : dccm_loop
end :Gen_dccm_enable

//////////////////////////////////////////////////////
// ICCM
//
if (mcu_pt.ICCM_ENABLE) begin : Gen_iccm_enable

logic [mcu_pt.ICCM_NUM_BANKS-1:0] [38:0] iccm_wdata_bitflip;
int jj;
always_ff @(mcu_el2_mem_export.clk) begin : inject_iccm_ecc_error
    if (~error_injection_mode.iccm_single_bit_error && ~error_injection_mode.iccm_double_bit_error) begin
        iccm_wdata_bitflip <= '{default:0};
    end else if (mcu_el2_mem_export.iccm_clken & mcu_el2_mem_export.iccm_wren_bank) begin
        for (jj=0; jj<mcu_pt.ICCM_NUM_BANKS; jj++) begin: iccm_bitflip_injection_loop
            iccm_wdata_bitflip[jj] <= get_bitflip_mask(error_injection_mode.iccm_double_bit_error);
        end
    end
end
for (genvar i=0; i<mcu_pt.ICCM_NUM_BANKS; i++) begin: iccm_loop
    // -- new --- assign iccm_bank_wr_fdata[i][31:0] = mcu_el2_mem_export.iccm_bank_wr_data[i];
    // -- new --- assign iccm_bank_wr_fdata[i][38:32] = mcu_el2_mem_export.iccm_bank_wr_ecc[i];
    // -- new --- assign mcu_el2_mem_export.iccm_bank_dout[i] = iccm_bank_fdout[i][31:0];
    // -- new --- assign mcu_el2_mem_export.iccm_bank_ecc[i] = iccm_bank_fdout[i][38:32];
    //assign mcu_el2_mem_export.iccm_bank_wr_data[i] = iccm_bank_wr_fdata[i][31:0];
    //assign mcu_el2_mem_export.iccm_bank_wr_ecc[i] = iccm_bank_wr_fdata[i][37:32];
    //assign iccm_bank_fdout[i] = {mcu_el2_mem_export.iccm_bank_ecc[i], mcu_el2_mem_export.iccm_bank_dout[i]};

    `ifdef VERILATOR

    el2_ram #(.depth(1<<mcu_pt.ICCM_INDEX_BITS), .width(39)) iccm_bank (
                                        // Primary ports
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .CLK(mcu_el2_mem_export.clk),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
    `else

        if (mcu_pt.ICCM_INDEX_BITS == 6 ) begin : iccm
                ram_64x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm

    else if (mcu_pt.ICCM_INDEX_BITS == 7 ) begin : iccm
                ram_128x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm

        else if (mcu_pt.ICCM_INDEX_BITS == 8 ) begin : iccm
                ram_256x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
        else if (mcu_pt.ICCM_INDEX_BITS == 9 ) begin : iccm
                ram_512x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
        else if (mcu_pt.ICCM_INDEX_BITS == 10 ) begin : iccm
                ram_1024x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
        else if (mcu_pt.ICCM_INDEX_BITS == 11 ) begin : iccm
                ram_2048x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
        else if (mcu_pt.ICCM_INDEX_BITS == 12 ) begin : iccm
                ram_4096x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
        else if (mcu_pt.ICCM_INDEX_BITS == 13 ) begin : iccm
                ram_8192x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
        else if (mcu_pt.ICCM_INDEX_BITS == 14 ) begin : iccm
                ram_16384x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
        else begin : iccm
                ram_32768x39 iccm_bank (
                                        // Primary ports
                                        .CLK(mcu_el2_mem_export.clk),
                                        .ME(mcu_el2_mem_export.iccm_clken[i]),
                                        .WE(mcu_el2_mem_export.iccm_wren_bank[i]),
                                        .ADR(mcu_el2_mem_export.iccm_addr_bank[i]),
                                        .D(iccm_bank_wr_fdata[i][38:0]),
                                        .Q(iccm_bank_fdout[i][38:0]),
                                        .ROP ( ),
                                        // These are used by SoC
                                        .TEST1    (1'b0   ),
                                        .RME      (1'b0   ),
                                        .RM       (4'b0000),
                                        .LS       (1'b0   ),
                                        .DS       (1'b0   ),
                                        .SD       (1'b0   ) ,
                                        .TEST_RNM (1'b0   ),
                                        .BC1      (1'b0   ),
                                        .BC2      (1'b0   )

                                        );
        end // block: iccm
`endif
end : iccm_loop
end : Gen_iccm_enable

/* verilator lint_off CASEINCOMPLETE */
`include "dasm.svi"
/* verilator lint_on CASEINCOMPLETE */

endmodule