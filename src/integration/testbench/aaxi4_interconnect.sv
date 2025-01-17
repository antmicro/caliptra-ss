/*
    Example top module for instantiation of Master/Slave BFM and
    interconnect.
    Includes 4 AXI Master BFMs and 5 AXI Slave BFMs connected to AXI Interconnect
    (a default slave built in Interconnect)

		[Memory Map]
	    MEM					FIFO
	    (start addr-limit addr)		(addr::depth)
slave 0	    (64'h9000_0000-64'h9000_1000)	(64'h0000_abcc::4), (64'ha000_0000::4), (64'hb000_0001::4)
slave 1	    (64'h9100_0000-64'h9100_1000)	(64'h0100_abcc::4), (64'ha100_0000::4), (64'hb100_0001::4)
slave 2	    (64'h9200_0000-64'h9200_1000)	(64'h0200_abcc::4), (64'ha200_0000::4), (64'hb200_0001::4)
slave 3	    (64'h9300_0000-64'h9300_1000)	(64'h0300_abcc::4), (64'ha300_0000::4), (64'hb300_0001::4)
slave 4	    (64'h9400_0000-64'h9400_1000)	(64'h0400_abcc::4), (64'ha400_0000::4), (64'hb400_0001::4)

TODO: slave 5 for I3C at 64'h2000_4000
*/

`timescale 1ps/1ps

module aaxi4_interconnect(
    input logic		core_clk,	
    input logic      rst_l);

import aaxi_pkg::*;
import aaxi_pkg_xactor::*;
import aaxi_pkg_test::*;
import aaxi_pll::*;
import aaxi_pkg_caliptra_test::*;

// AXI Reset, Deassert=H, Assert=L
// bit         rst_l;
wire        ACLK;               // AXI Clock, it was generated by pll class


// low power interface
wire		   CSYSREQ;
wire		   CACTIVE;
wire		   CACTIVE_PLL;
wire		   CSYSACK;
wire		   CSYSACK_PLL;

// pll class 
// aaxi_class_pll sys_pll;

// device classes
aaxi_interconnect intc;
aaxi_device_class master[AAXI_INTC_MASTER_CNT];
aaxi_device_class slave[AAXI_INTC_SLAVE_CNT];

// device interface
// aaxi_pll_intf		ports_intf		(core_clk, rst_l, CACTIVE_PLL, CSYSREQ, CSYSACK_PLL);
aaxi_interconnect_intf	ports			(core_clk, rst_l, CACTIVE, CSYSREQ, CSYSACK);
aaxi_intf #(.MCB_INPUT(aaxi_pkg::AAXI_MCB_INPUT),.MCB_OUTPUT(aaxi_pkg::AAXI_MCB_OUTPUT),.SCB_INPUT(aaxi_pkg::AAXI_SCB_INPUT),.SCB_OUTPUT(aaxi_pkg::AAXI_SCB_OUTPUT))mintf_arr[AAXI_INTC_MASTER_CNT-1:0]	(core_clk, rst_l, CACTIVE, CSYSREQ, CSYSACK);
aaxi_intf #(.MCB_INPUT(aaxi_pkg::AAXI_MCB_INPUT),.MCB_OUTPUT(aaxi_pkg::AAXI_MCB_OUTPUT),.SCB_INPUT(aaxi_pkg::AAXI_SCB_INPUT),.SCB_OUTPUT(aaxi_pkg::AAXI_SCB_OUTPUT))sintf_arr[AAXI_INTC_SLAVE_CNT-1:0]	(core_clk, rst_l, CACTIVE, CSYSREQ, CSYSACK);

/* When all CACTIVE signal of ports, mintf_arr[] and sintf_arr[] 
   are different from each other(some ports whose CACTIVE was 1,
   these ports has transaction to write or read), 
   the CACTIVE_PLL will be set 1 (can not enter low power state) */
assign CACTIVE_PLL = ((CACTIVE === 1'bx)? 1: CACTIVE);
/* When all CSYSACK signal of ports, mintf_arr[] and sintf_arr[]
   are different from each other(some ports whose CSYSACK was 1,
   these ports has transaction to write or read), 
   the CSYSACK_PLL will be set 1 (can not enter low power state) */
assign CSYSACK_PLL = ((CSYSACK === 1'bx)? 1: CSYSACK);

genvar i;
generate
    for ( i = 0; i < AAXI_INTC_MASTER_CNT; i++ ) begin
	initial begin
	    master[i] = new($psprintf("master%0d" ,i), AAXI_MASTER, AAXI4, mintf_arr[i],, i);
	    #1;	// wait to instantiate intc bfm 
	    intc.master_ports[i].vers= master[i].vers;
	    intc.master_ports[i].ports= mintf_arr[i];
	end
    end

    for ( i = 0; i < AAXI_INTC_SLAVE_CNT; i++ ) begin
	initial begin
	    slave[i] = new($psprintf("slave%0d", i), AAXI_SLAVE_TO_INTERCONNECT, AAXI4, sintf_arr[i],, i);
	    #1;	// wait to instantiate intc bfm 
	    intc.slave_ports[i].vers= slave[i].vers;
	    intc.slave_ports[i].ports= sintf_arr[i];
	end
    end
endgenerate 


// bus monitor/checker0
`ifdef AVERY_ASSERT_ON

generate 
    // interfaces between Master BFMs and Interconnect slave ports
    for ( i = 0; i < AAXI_INTC_MASTER_CNT; i++ ) begin: master_mon
	aaxi_monitor_wrapper monitor(mintf_arr[i]);
	defparam monitor.VER= "AXI4";
	defparam monitor.ID_WIDTH= AAXI_ID_WIDTH;
	defparam monitor.BUS_DATA_WIDTH= AAXI_DATA_WIDTH;	    // set DATA BUS WIDTH
	defparam monitor.monitor.FNAME_TRACK= {"m0"+i,"_intf.txt"};
        defparam monitor.checker0.MAXWAITS= 60;
    end

    // interfaces between Slave BFMs and Interconnect master ports
    for ( i = 0; i < AAXI_INTC_SLAVE_CNT; i++ ) begin: slave_mon
	aaxi_monitor_wrapper monitor(sintf_arr[i]);
	defparam monitor.VER= "AXI4";
	defparam monitor.ID_WIDTH= AAXI_INTC_ID_WIDTH;
	defparam monitor.BUS_DATA_WIDTH= AAXI_DATA_WIDTH;	    // set DATA BUS WIDTH
	defparam monitor.monitor.FNAME_TRACK= {"s0"+i,"_intf.txt"};
        defparam monitor.checker0.MAXWAITS= 60;
    end
endgenerate 

// instantiates monitor/protocol checker0 for default slave interface
aaxi_monitor_wrapper def_monitor(ports.default_slave_intf);
defparam def_monitor.VER= "AXI4";
defparam def_monitor.ID_WIDTH= AAXI_INTC_ID_WIDTH;
defparam def_monitor.BUS_DATA_WIDTH= AAXI_DATA_WIDTH;    // set DATA BUS WIDTH
defparam def_monitor.checker0.MAXWAITS= 60;
defparam def_monitor.monitor.FNAME_TRACK= "default_slave_intf.txt";

`endif

// instance device classes

int j, depth2;
aaxi_priority_tier_type priority_master;


initial begin
    #0;
    intc = new("intc", AAXI_INTERCONNECT,, ports);
    // PLL class, instantiates clock generator
    // sys_pll = new("Avery_pll", ports_intf);
    #0;

    for (int i = 0; i < AAXI_INTC_MASTER_CNT; i++) begin
	// instantiates Master BFMs
        master[i].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
        master[i].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        master[i].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        master[i].cfg_info.passive_mode= 1;       //-- changed to put master to passive mode
        // master[i].cfg_info.id_width=3;
`ifdef FOUR_OUTSTANDING
	master[i].cfg_info.total_outstanding_depth = 4;
	master[i].cfg_info.id_outstanding_depth = 4;
`else
	master[i].cfg_info.total_outstanding_depth = 1;
	master[i].cfg_info.id_outstanding_depth = 1;
`endif
	master[i].cfg_info.no_overlap_allow = 0;
`ifdef UNALIGNED_WSTRB_ONLY
	master[i].cfg_info.unaligned_transfer_addr = 1;
`endif
`ifdef DEFAULT_HIGH
	master[i].cfg_info.bready_default = 1;
	master[i].cfg_info.rready_default = 1;
`endif

	end

    wait (slave[0] != null);
    for (int i=0; i<AAXI_INTC_SLAVE_CNT; i++) begin
	    // instantiates Slave BFMs
        slave[i].cfg_info.passive_mode= 1; 
        slave[i].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[i].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        // slave[i].add_fifo(64'habcc+i*64'h100_0000, 4);
        // slave[i].add_fifo(64'ha000_0000+i*64'h100_0000, 4);
        // slave[i].add_fifo(64'hb000_0001+i*64'h100_0000, 4);
        // slave[i].cfg_info.fifo_address[0] = 64'hc000_0000;
        // slave[i].cfg_info.fifo_limit[0] = 64'hc000_1000;
        slave[i].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
`ifdef FOUR_OUTSTANDING
	slave[i].cfg_info.total_outstanding_depth = 4;
	slave[i].cfg_info.id_outstanding_depth = 4;
`else
	slave[i].cfg_info.total_outstanding_depth = 1;
	slave[i].cfg_info.id_outstanding_depth = 1;
`endif
`ifdef DEFAULT_HIGH
	slave[i].cfg_info.awready_default = 1;
	slave[i].cfg_info.dwready_default = 1;
	slave[i].cfg_info.arready_default = 1;
`endif
	end
        //-- imem
        slave[0].cfg_info.base_address[0] = 64'h8000_0000;
        slave[0].cfg_info.limit_address[0] = 64'h8000_FFFF;

        //-- lmem/Mailbox
        // slave[1].cfg_info.base_address[0] = 64'h9001_0000;
        // slave[1].cfg_info.limit_address[0] = 64'h9001_FFFF;
        // slave[1].cfg_info.base_address[1]  = 64'hD058_0000;
        // slave[1].cfg_info.limit_address[1] = 64'hD058_0000;
        // slave[1].cfg_info.fifo_address[1]  = 64'hE000_0000;
        // slave[1].cfg_info.fifo_limit[1]    = 64'hE000_1000;

        //-- MCU AXI DMA sub
        slave[2].cfg_info.base_address[0] = 64'h8002_0000;
        slave[2].cfg_info.limit_address[0] = 64'h8002_FFFF;

        //-- Caliptra SoC IFC Sub
        slave[3].cfg_info.passive_mode= 1; 
        slave[3].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[3].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[3].cfg_info.base_address[0] = 64'h3000_0000;
        slave[3].cfg_info.limit_address[0] = 64'h3FFF_FFFF;
        // slave[3].cfg_info.fifo_address[0] = 64'hc000_0000;
        // slave[3].cfg_info.fifo_limit[0] = 64'hc000_1000;
        slave[3].cfg_info.base_address[1]  = 64'h0003_0000;
        slave[3].cfg_info.limit_address[1] = 64'h0003_FFFF;
        // slave[3].cfg_info.fifo_address[1] = 64'hc000_1001;
        // slave[3].cfg_info.fifo_limit[1] = 64'hc000_2000;
        slave[3].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
        slave[3].cfg_info.total_outstanding_depth = 4;
        slave[3].cfg_info.id_outstanding_depth = 4;

//        //-- Caliptra SRAM
//        slave[4].cfg_info.passive_mode= 1; 
//        slave[4].cfg_info.opt_awuser_enable = 0; // optional, axi4_interconn_routings.sv need it
//        slave[4].cfg_info.opt_aruser_enable = 0; // optional, axi4_interconn_routings.sv need it
//        slave[4].cfg_info.base_address[0] = 64'h1_2345_0000;
//        slave[4].cfg_info.limit_address[0] = 64'h1_4001_FFFF;
//        slave[4].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 4; // set DATA BUS WIDTH
//        slave[4].cfg_info.total_outstanding_depth = 4;
//        slave[4].cfg_info.id_outstanding_depth = 4;

        //-- I3C --> MCI
        slave[4].cfg_info.passive_mode= 1; 
        slave[4].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[4].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        // slave[4].cfg_info.limit_address[0] = 64'h2000_4FFF;
        // slave[4].cfg_info.base_address[0] = 64'h2000_4000;
        slave[4].cfg_info.base_address[0]  = {32'h0, `SOC_MCI_REG_BASE_ADDR};//64'h2100_0000;
        slave[4].cfg_info.limit_address[0] = {32'h0, `SOC_MCI_REG_BASE_ADDR + 32'h00FF_FFFF};
        // slave[4].cfg_info.base_address[1]  = 64'h0000_0000_D058_0000;
        // slave[4].cfg_info.limit_address[1] = 64'h0000_0000_D058_0000;
        slave[4].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
        slave[4].cfg_info.total_outstanding_depth = 4;
        slave[4].cfg_info.id_outstanding_depth = 4;

        //-- Fuse Controller Core AXI 
        slave[5].cfg_info.passive_mode = 1; 
        slave[5].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[5].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[5].cfg_info.base_address[0] = 64'h7000_0000;
        slave[5].cfg_info.limit_address[0] = 64'h7000_01FF;
        slave[5].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
        slave[5].cfg_info.total_outstanding_depth = 4;
        slave[5].cfg_info.id_outstanding_depth = 4;

        //-- Fuse Controller Prim AXI 
        slave[6].cfg_info.passive_mode = 1; 
        slave[6].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[6].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[6].cfg_info.base_address[0] = 64'h7000_0200;
        slave[6].cfg_info.limit_address[0] = 64'h7000_03FF;
        slave[6].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
        slave[6].cfg_info.total_outstanding_depth = 4;
        slave[6].cfg_info.id_outstanding_depth = 4;

        //-- Life-cycle Controller Core AXI 
        slave[7].cfg_info.passive_mode = 1; 
        slave[7].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[7].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[7].cfg_info.base_address[0] = 64'h7000_0400;
        slave[7].cfg_info.limit_address[0] = 64'h7000_05FF;
        slave[7].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
        slave[7].cfg_info.total_outstanding_depth = 4;
        slave[7].cfg_info.id_outstanding_depth = 4;

        //-- MCI interface --> I3C
        slave[1].cfg_info.passive_mode = 1;
        slave[1].cfg_info.opt_awuser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[1].cfg_info.opt_aruser_enable = 1; // optional, axi4_interconn_routings.sv need it
        slave[1].cfg_info.base_address[0] = 64'h2000_4000;
        slave[1].cfg_info.limit_address[0] = 64'h2000_4FFF;
        slave[1].cfg_info.data_bus_bytes = AAXI_DATA_WIDTH >> 3; // set DATA BUS WIDTH
        slave[1].cfg_info.total_outstanding_depth = 4;
        slave[1].cfg_info.id_outstanding_depth = 4;

//#1;
//do not sure what feature of #1
    // connect devices to the Interconnect
    for (int i=0; i<AAXI_INTC_MASTER_CNT; i++) begin
	j = (i+2)%3;
	priority_master = aaxi_priority_tier_type'(j);
	master[i].cfg_info.ms_priority= priority_master;
	master[i].cfg_info.copy_partial_fields(intc.master_ports[i].cfg_info);
    end
    for (int i=0; i<AAXI_INTC_SLAVE_CNT; i++) begin
	slave[i].cfg_info.copy_partial_fields(intc.slave_ports[i].cfg_info);
    end

    depth2= 1;
`ifdef INTERCONNECT_PORT_INTERLEAVE_FOUR
    depth2= 4;
`endif
    for (int i=0; i < AAXI_INTC_MASTER_CNT; i++) begin
`ifdef INTERCONNECT_DEFAULT_LOW
	// set the default ready of intc ports as zero
	intc.set_port_default_ready(i, 1, AAXI_ALL_READY, 0);
`endif

	// set the write/read interleave depth of Interconnect slave/master ports as four
	intc.set_port_interleave_depth(i, 1, depth2);

`ifdef INTERCONNECT_BUS_BUFFER_SIZE_FOUR
	// set the buffer size of data/resp buses inside Interconnect
	intc.set_port_bus_buffer_size(AAXI_BUS_TYPE_READ_DATA, 4, i);
	intc.set_port_bus_buffer_size(AAXI_BUS_TYPE_WRITE_RESP, 4, i);
`endif
	end


    for (int i=0; i < AAXI_INTC_SLAVE_CNT; i++) begin
`ifdef INTERCONNECT_DEFAULT_LOW
	// set the default ready of intc ports as zero
	intc.set_port_default_ready(i, 0, AAXI_ALL_READY, 0);
`endif

	// set the write/read interleave depth of Interconnect slave/master ports as four
	intc.set_port_interleave_depth(i, 0, depth2);

`ifdef INTERCONNECT_BUS_BUFFER_SIZE_FOUR
	// set the buffer size of data buses inside Interconnect
	intc.set_port_bus_buffer_size(AAXI_BUS_TYPE_WRITE_DATA, 4, i);
`endif
	end

`ifdef INTERCONNECT_BUS_BUFFER_SIZE_FOUR
    // set the buffer size of write/read address bus inside Interconnect
    intc.set_port_bus_buffer_size(AAXI_BUS_TYPE_WRITE_ADDR, 4);
    intc.set_port_bus_buffer_size(AAXI_BUS_TYPE_READ_ADDR, 4);
`endif
    end

    //task automatic start_test(aaxi_test_base test);
    task automatic start_test(aaxi_test_caliptra_ss test);
        aaxi_pkg_test::aaxi_test_select(test.test_name);
        test.master0= master[0];
        test.master1= master[1];
        test.master2= master[2];
        test.master3= master[3];
        for (int i=0; i< AAXI_INTC_MASTER_CNT; i++) begin
        test.ms_bfms.push_back(master[i]);
    `ifdef PASSIVE_MASTER
        test.psv_ms_bfms.push_back(passive_master[i]);
    `endif
        end

        // initial memory value to be 0 for data comparision on Slave BFM 
        slave[0].set("mem_uninitialized_value", 0);
        slave[1].set("mem_uninitialized_value", 0);
        slave[2].set("mem_uninitialized_value", 0);
        slave[3].set("mem_uninitialized_value", 0);
        slave[4].set("mem_uninitialized_value", 0);
        slave[5].set("mem_uninitialized_value", 0);
        slave[6].set("mem_uninitialized_value", 0);
        slave[7].set("mem_uninitialized_value", 0);
        slave[8].set("mem_uninitialized_value", 0);


        test.slave0= slave[0];
        test.slave1= slave[1];
        test.slave2= slave[2];
        test.slave3= slave[3];
        test.slave4= slave[4];
        test.slave5= slave[5];
        test.slave6= slave[6];
        test.slave7= slave[7];
        test.slave8= slave[8];

        for (int i=0; i< AAXI_INTC_SLAVE_CNT; i++)
            test.slv_bfms.push_back(slave[i]);

        test.itc_bfm= intc;
    `ifdef PASSIVE_ITC
        test.psv_itc_bfm= passive_intc;
    `endif
        test.run();
    endtask
endmodule
// `ifdef AAXI_DUMP_VCD
// initial begin
//     $dumpfile("aaxi_interconnect.vcd");
//     $dumpvars(0, aaxi_interconnect);
// `ifdef AVERY_MS
//     $dumpvars(0, aaxi_interconnect.ports);
// `endif
//     $dumpon;
//     end
// `endif

// `ifdef AAXI_DUMP_VPD

// generate 
//     for ( i = 0; i < AAXI_INTC_MASTER_CNT; i++) begin
// 	initial begin
// 	    $vcdpluson(0, aaxi_interconnect.mintf_arr[i]);
// 	end
//     end
//     for ( i = 0; i < AAXI_INTC_SLAVE_CNT; i++) begin
// 	initial begin
// 	    $vcdpluson(0, aaxi_interconnect.sintf_arr[i]);
// 	end 
//     end
// endgenerate 

// initial begin
//     $vcdpluson(0, aaxi_interconnect.ports);
// end

// `endif

// // generate reset
// initial begin
//     rst_l = 1;
//     #20;
//     rst_l = 0;
//     #20;
//     rst_l = 1;
// end
