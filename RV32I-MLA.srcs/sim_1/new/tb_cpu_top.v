`timescale 1ns/1ps

module tb_cpu_top;

    reg clk;
    reg rst_n;
    wire [3:0] led;

    wire        dmem_en;
    wire        dmem_we;
    wire [10:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;

    cpu_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .led(led),
        .dmem_en(dmem_en),
        .dmem_we(dmem_we),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata)
    );

    reg [31:0] mem [0:2047];
    reg [10:0] read_addr_q;

    integer i;

    // clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100 MHz sim clock
    end

    // simple synchronous BRAM model
    always @(posedge clk) begin
        if (dmem_en) begin
            read_addr_q <= dmem_addr;

            if (dmem_we) begin
                mem[dmem_addr] <= dmem_wdata;
                $display("[%0t] WRITE mem[%0d] = %0d", $time, dmem_addr, dmem_wdata);
            end
        end

        dmem_rdata <= mem[read_addr_q];
    end

    initial begin
        for (i = 0; i < 2048; i = i + 1)
            mem[i] = 32'd0;

        dmem_rdata = 32'd0;
        read_addr_q = 11'd0;
        rst_n = 1'b0;

        #40;
        rst_n = 1'b1;

        // let CPU settle into polling
        #50;

        // PS writes command = 1 to CMD_ADDR = 0
        mem[0] = 32'd1;
        $display("[%0t] TESTBENCH sets mem[0] = 1", $time);

        // wait long enough for CPU to detect and eventually write status
        #12000000;

        $display("[%0t] FINAL mem[0] = %0d, mem[1] = %0d, led = %b", $time, mem[0], mem[1], led);

        if (mem[1] == 32'd2)
            $display("PASS: cpu_top wrote STATUS_ADDR correctly.");
        else
            $display("FAIL: cpu_top did not write STATUS_ADDR correctly.");

        $finish;
    end

endmodule