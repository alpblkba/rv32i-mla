// Test fixture for the harness, not a CPU. It has the port the contract plans for cpu_top, a 32-bit dmem_addr, a 4-bit dmem_we and sticky halted and trap, and every output is a register loaded from the matching t_* input, as a CPU loads its outputs. cocotb drives t_* to put any bus sequence on the port and reads q_rdata, the dmem_rdata sampled at each rising edge, to see what a CPU would have captured.
module stub_cpu (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [3:0]  led,
    output reg         dmem_en,
    output reg  [3:0]  dmem_we,
    output reg  [31:0] dmem_addr,
    output reg  [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output reg         halted,
    output reg         trap,
    input  wire        t_en,
    input  wire [3:0]  t_we,
    input  wire [31:0] t_addr,
    input  wire [31:0] t_wdata,
    input  wire        t_halt,
    input  wire        t_trap,
    output reg  [31:0] q_rdata
);
    always @(posedge clk) begin
        led        <= 4'b0000;
        dmem_en    <= t_en;
        dmem_we    <= t_we;
        dmem_addr  <= t_addr;
        dmem_wdata <= t_wdata;
        q_rdata    <= dmem_rdata;
        halted     <= rst_n & (halted | t_halt);
        trap       <= rst_n & (trap | (t_halt & t_trap));
    end
endmodule
