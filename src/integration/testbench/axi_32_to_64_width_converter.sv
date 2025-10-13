// This module is simulation only
// Converts 32-bit wide master to 64 bit wide master

`include "caliptra_macros.svh"

module axi_32_to_64_width_converter(
    input logic clk,
    input logic rst_l,
    axi_if narrow,
    axi_if wide
);
    longint unsigned read_address, read_range;
    longint unsigned write_address, write_range;
    int read_length, read_size;
    int write_length, write_size;
    logic read_queue[$];
    logic write_queue[$];
    logic read_shift, read_valid;
    logic write_shift, write_valid;

    always@(posedge clk or negedge rst_l) begin
        if(!rst_l) begin
            read_queue = {};
        end else if (narrow.arvalid && narrow.arready) begin
            read_address = narrow.araddr;
            read_range   = (narrow.arlen + 1) * (64'h1 << narrow.arsize);
            read_size    = 64'h1 << narrow.arsize;
            read_length  = narrow.arlen;
            for (int i=-1; i < read_length; ++i) begin
                read_queue.push_back((read_address & 64'h4) >> 2);
                if (narrow.arburst == 2'h1)
                    read_address += read_size;
                else if (narrow.arburst == 2'h2)
                    read_address = (read_address / read_range) * read_range +
                        (read_address + read_size) % read_range;
            end
        end
    end

    always@(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            read_valid <= '0;
            read_shift <= '0;
        end else begin
            if (narrow.rready && narrow.rvalid) begin
                read_queue.pop_front();
            end
            if (read_queue.size() > 0) read_shift <= read_queue[0];
            else read_shift <= '0;
            read_valid <= read_queue.size() > 0;
        end
    end

    always@(posedge clk or negedge rst_l) begin
        if(!rst_l) begin
            write_queue = {};
        end else if (narrow.awvalid && narrow.awready) begin
            write_address = narrow.awaddr;
            write_range   = (narrow.awlen + 1) * (64'h1 << narrow.awsize);
            write_size    = 64'h1 << narrow.awsize;
            write_length  = narrow.awlen;
            for (int i=-1; i < write_length; ++i) begin
                write_queue.push_back((write_address & 64'h4) >> 2);
                if (narrow.awburst == 2'h1)
                    write_address += write_size;
                else if (narrow.awburst == 2'h2)
                    write_address = (write_address / write_range) * write_range +
                        (write_address + write_size) % write_range;
            end
        end
    end

    always@(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            write_valid <= '0;
            write_shift <= '0;
        end else begin
            if (narrow.wready && narrow.wvalid) begin
                write_queue.pop_front();
            end
            if (write_queue.size() > 0) write_shift <= write_queue[0];
            else write_shift <= '0;
            write_valid <= write_queue.size() > 0;
        end
    end

    assign wide.awvalid   = narrow.awvalid;
    assign wide.awaddr    = narrow.awaddr;
    assign wide.awid      = narrow.awid;
    assign wide.awlen     = narrow.awlen;
    assign wide.awsize    = narrow.awsize;
    assign wide.awburst   = narrow.awburst;
    assign wide.awlock    = narrow.awlock;
    assign wide.awuser    = narrow.awuser;
    assign narrow.awready = wide.awready;

    assign wide.wvalid    = narrow.wvalid & write_valid;
    assign wide.wdata     = narrow.wdata << (write_shift ? 32 : 0);
    assign wide.wstrb     = narrow.wstrb << (write_shift ? 4 : 0);
    assign wide.wlast     = narrow.wlast;
    assign wide.wuser     = narrow.wuser;
    assign narrow.wready  = wide.wready & write_valid;

    assign narrow.bvalid  = wide.bvalid;
    assign narrow.bresp   = wide.bresp;
    assign narrow.buser   = wide.buser;
    assign narrow.bid     = wide.bid;
    assign wide.bready    = narrow.bready;

    assign wide.arvalid   = narrow.arvalid;
    assign wide.araddr    = narrow.araddr;
    assign wide.arid      = narrow.arid;
    assign wide.arlen     = narrow.arlen;
    assign wide.arsize    = narrow.arsize;
    assign wide.arburst   = narrow.arburst;
    assign wide.arlock    = narrow.arlock;
    assign wide.aruser    = narrow.aruser;
    assign narrow.arready = wide.arready;

    assign narrow.rvalid  = wide.rvalid & read_valid;
    assign narrow.rdata   = 64'(wide.rdata) >> (read_shift ? 32 : 0);
    assign narrow.rresp   = wide.rresp;
    assign narrow.ruser   = wide.ruser;
    assign narrow.rid     = wide.rid;
    assign narrow.rlast   = wide.rlast;
    assign wide.rready    = narrow.rready & read_valid;

    `CALIPTRA_ASSERT(CPTRA_AXI_RD_32BIT, (narrow.arvalid && narrow.arready) -> (narrow.arsize < 3), clk, !rst_l)
    `CALIPTRA_ASSERT(CPTRA_AXI_WR_32BIT, (narrow.awvalid && narrow.awready) -> (narrow.awsize < 3), clk, !rst_l)
endmodule
