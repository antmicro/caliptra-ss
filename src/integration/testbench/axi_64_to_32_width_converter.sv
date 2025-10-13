// This module is simulation only
// Converts 64-bit wide slave to 32 bit wide slave

`include "caliptra_macros.svh"

module axi_64_to_32_width_converter(
    input logic clk,
    input logic rst_l,
    axi_if narrow,
    axi_if wide
);
    longint unsigned read_address,  read_range;
    longint unsigned write_address, write_range;
    int read_size, read_length;
    logic read_shift;
    logic read_push_word, read_push_flag;
    logic [1:0] read_queue[$];
    logic [106:0] read_data_queue[$];
    logic [63:0] rdata;

    int write_size, write_length;
    logic write_shift;
    logic write_pop_word, write_pop_flag;
    logic [1:0] write_queue[$];
    logic [104:0] write_data_queue[$];
    logic [63:0] wdata;
    logic [31:0] wuser;
    logic [7:0] wstrb;
    logic wlast;

    always@(posedge clk or negedge rst_l) begin
        if(!rst_l) begin
            read_queue = {};
            read_push_flag = 0;
        end else if (wide.arvalid && wide.arready) begin
            read_address = wide.araddr;
            read_range  = (wide.arlen + 1) * (64'h1 << wide.arsize);
            read_size   = 64'h1 << wide.arsize;
            read_length = wide.arlen;
            if (read_size  == 8) begin
                read_size = read_size / 2;
                read_length = read_length * 2 + 1;
                if (64'(wide.araddr) & 64'h4) write_length -= 1;
            end
            for (int i=-1; i < read_length; ++i) begin
                if (wide.arsize < 3)
                    read_push_flag = 1;
                else begin
                    read_push_flag = (i == (read_length - 1)) | ((read_address & 'h4) >> 2);
                end
                read_queue.push_back({((read_address & 64'h4) >> 2), read_push_flag});
                if (wide.arburst == 2'h1)
                    read_address += read_size;
                else if (wide.arburst == 2'h2)
                    read_address = (read_address / read_range) * read_range +
                        (read_address + read_size) % read_range;
            end
        end
    end

    always@(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            narrow.rready <= '0;
            {read_shift, read_push_word} = '0;
            rdata = '0;
            read_data_queue = {};
        end else begin
            if (read_queue.size() > 0) begin
                {read_shift, read_push_word} = read_queue[0];
            end else begin
                {read_shift, read_push_word} = '0;
            end
            if (narrow.rready && narrow.rvalid) begin
                rdata |= 64'(narrow.rdata) << (read_shift ? 32 : 0);
                read_queue.pop_front();
                if (read_push_word) begin
                    read_data_queue.push_back({rdata, narrow.ruser, narrow.rid, narrow.rresp, narrow.rlast});
                    rdata = 0;
                end
            end
            narrow.rready <= read_queue.size() > 0;
        end
    end

    always@(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            wide.rvalid <= '0;
            {wide.rdata, wide.ruser, wide.rid, wide.rresp, wide.rlast} <= '0;
        end else begin
            if (wide.rready && wide.rvalid) begin
                read_data_queue.pop_front();
            end
            if (read_data_queue.size() > 0) begin
                {wide.rdata, wide.ruser, wide.rid, wide.rresp, wide.rlast} <= read_data_queue[0];
            end
            wide.rvalid <= read_data_queue.size() > 0;
        end
    end

    always@(posedge clk or negedge rst_l) begin
        if(!rst_l) begin
            write_queue = {};
            write_pop_flag = 0;
        end else if (wide.awvalid && wide.awready) begin
            write_address = wide.awaddr;
            write_range   = (wide.awlen + 1) * (64'h1 << wide.awsize);
            write_size   = 64'h1 << wide.awsize;
            write_length = wide.awlen;
            if (write_size  == 8) begin
                write_size = write_size / 2;
                write_length = write_length * 2 + 1;
                if (64'(wide.awaddr) & 64'h4) write_length -= 1;
            end
            for (int i=-1; i < write_length; ++i) begin
                if (wide.awsize < 3)
                    write_pop_flag = 1;
                else begin
                    write_pop_flag = (i == (write_length - 1)) | ((write_address & 64'h4) >> 2);
                end
                write_queue.push_back({((write_address & 64'h4) >> 2), write_pop_flag});
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
            wide.wready <= '0;
            write_data_queue = {};
        end else begin
            wide.wready <= '1;
            if (wide.wready && wide.wvalid) begin
                write_data_queue.push_back({wide.wdata, wide.wstrb, wide.wlast, wide.wuser});
            end
        end
    end

    always@(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            narrow.wvalid <= '0;
            {write_shift, write_pop_word} = '0;
            {wdata, wstrb, wlast, wuser} = '0;
        end else begin
            if (narrow.wvalid & narrow.wready) begin
                if (write_pop_word) write_data_queue.pop_front();
                write_queue.pop_front();
            end
            if (write_queue.size() > 0) begin
                {write_shift, write_pop_word} = write_queue[0];
            end else begin
                {write_shift, write_pop_word} = '0;
            end
            if (write_data_queue.size() > 0) begin
                {wdata, wstrb, wlast, wuser} = write_data_queue[0];
            end else begin
                {wdata, wstrb, wlast, wuser} = '0;
            end
            narrow.wdata <= wdata >> (write_shift ? 32 : 0);
            narrow.wstrb <= wstrb >> (write_shift ? 4 : 0);
            narrow.wlast <= wlast & write_pop_word;
            narrow.wuser <= wuser;
            narrow.wvalid <= write_data_queue.size() > 0 && write_queue.size() > 0;
        end
    end

    assign narrow.awvalid = wide.awvalid;
    assign narrow.awaddr  = wide.awaddr;
    assign narrow.awid    = wide.awid;
    assign narrow.awlen   = wide.awsize == 3 ? wide.awlen * 2 + 1 : wide.awlen;
    assign narrow.awsize  = wide.awsize == 3 ? 3'h2 : wide.awsize;
    assign narrow.awburst = wide.awburst;
    assign narrow.awlock  = wide.awlock;
    assign narrow.awuser  = wide.awuser;
    assign wide.awready   = narrow.awready;

    assign wide.bvalid   = narrow.bvalid;
    assign wide.bresp    = narrow.bresp;
    assign wide.buser    = narrow.buser;
    assign wide.bid      = narrow.bid;
    assign narrow.bready = wide.bready;

    assign narrow.arvalid = wide.arvalid;
    assign narrow.araddr  = wide.araddr;
    assign narrow.arid    = wide.arid;
    assign narrow.arlen   = wide.arsize == 3 ? wide.arlen * 2 + 1 : wide.arlen;
    assign narrow.arsize  = wide.arsize == 3 ? 3'h2 : wide.arsize;
    assign narrow.arburst = wide.arburst;
    assign narrow.arlock  = wide.arlock;
    assign narrow.aruser  = wide.aruser;
    assign wide.arready   = narrow.arready;

    `CALIPTRA_ASSERT(CPTRA_AXI_RD_32BIT, (wide.arvalid && wide.arready) -> (wide.arsize < 3) || (wide.arsize == 3 && wide.arlen < 128 && wide.arburst != 0), clk, !rst_l)
    `CALIPTRA_ASSERT(CPTRA_AXI_WR_32BIT, (wide.awvalid && wide.awready) -> (wide.awsize < 3) || (wide.awsize == 3 && wide.awlen < 128 && wide.awburst != 0), clk, !rst_l)
endmodule
