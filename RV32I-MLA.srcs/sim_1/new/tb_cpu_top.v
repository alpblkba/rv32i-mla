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

    // unified synchronous BRAM model
    // CPU uses byte addresses directly, and this TB mirrors that convention.
    reg [31:0] mem [0:2047];
    reg [10:0] read_addr_q;

    integer i;

    // NO_BRANCH diagnostic program
    localparam [31:0] INSN_ADDI_X1_5    = 32'h00500093; // 0x00
    localparam [31:0] INSN_ADDI_X2_7    = 32'h00700113; // 0x04
    localparam [31:0] INSN_ADD_X3_X1X2  = 32'h002081B3; // 0x08
    localparam [31:0] INSN_SW_X3_0100   = 32'h10302023; // 0x0C
    localparam [31:0] INSN_ADDI_X5_2    = 32'h00200293; // 0x10
    localparam [31:0] INSN_SW_X5_0104   = 32'h10502223; // 0x14
    localparam [31:0] INSN_JAL_X0_0     = 32'h0000006F; // 0x18

    localparam integer DMEM_ADDR_0100 = 16'h0100;
    localparam integer DMEM_ADDR_0104 = 16'h0104;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // synchronous BRAM behavior:
    // address is sampled on clock edge
    // read data returns from previously sampled address
    // write occurs on that edge when WE is asserted
    always @(posedge clk) begin
        if (dmem_en) begin
            read_addr_q <= dmem_addr;

            if (dmem_we) begin
                mem[dmem_addr] <= dmem_wdata;
                $display("[%0t] STORE addr=0x%03h data=0x%08h (%0d)",
                         $time, dmem_addr, dmem_wdata, dmem_wdata);
            end
        end

        dmem_rdata <= mem[read_addr_q];
    end

    initial begin
        for (i = 0; i < 2048; i = i + 1)
            mem[i] = 32'd0;

        // program image
        mem[16'h0000] = INSN_ADDI_X1_5;
        mem[16'h0004] = INSN_ADDI_X2_7;
        mem[16'h0008] = INSN_ADD_X3_X1X2;
        mem[16'h000C] = INSN_SW_X3_0100;
        mem[16'h0010] = INSN_ADDI_X5_2;
        mem[16'h0014] = INSN_SW_X5_0104;
        mem[16'h0018] = INSN_JAL_X0_0;

        dmem_rdata  = 32'd0;
        read_addr_q = 11'd0;
        rst_n       = 1'b0;

        #40;
        rst_n = 1'b1;

        #1200;

        $display("\nFINAL mem[0x0100]=0x%08h (%0d)", mem[DMEM_ADDR_0100], mem[DMEM_ADDR_0100]);
        $display("FINAL mem[0x0104]=0x%08h (%0d)", mem[DMEM_ADDR_0104], mem[DMEM_ADDR_0104]);

        if ((mem[DMEM_ADDR_0100] == 32'd12) && (mem[DMEM_ADDR_0104] == 32'd2))
            $display("PASS: NO_BRANCH program completed.");
        else
            $display("FAIL: expected DMEM[0x0100]=12 and DMEM[0x0104]=2.");

        $finish;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            $display("[%0t] state=%0d pc=0x%08h fetch_pc_q=0x%08h if_pc=0x%08h if_instr=0x%08h ex_pc=0x%08h ex_instr=0x%08h x3=0x%08h x5=0x%08h we=%b addr=0x%03h wdata=0x%08h rdata=0x%08h",
                     $time,
                     dut.state,
                     dut.pc,
                     dut.fetch_pc_q,
                     dut.if_pc,
                     dut.if_instr,
                     dut.ex_pc,
                     dut.ex_instr,
                     dut.regs[3],
                     dut.regs[5],
                     dmem_we,
                     dmem_addr,
                     dmem_wdata,
                     dmem_rdata);
        end
    end

endmodule