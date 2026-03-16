module cpu_top (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [3:0]  led,

    output reg         dmem_en,
    output reg         dmem_we,
    output reg  [10:0] dmem_addr,
    output reg  [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);

    localparam [10:0] CMD_ADDR    = 11'd0;
    localparam [10:0] STATUS_ADDR = 11'd4;

    localparam [2:0]
        S_IDLE_ADDR   = 3'd0,
        S_IDLE_WAIT   = 3'd1,
        S_RUN         = 3'd2,
        S_WRITE       = 3'd3,
        S_DONE_ADDR   = 3'd4,
        S_DONE_WAIT   = 3'd5;

    localparam [31:0] RUN_CYCLES = 32'd16;;

    reg [2:0]  state;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            state      <= S_IDLE_ADDR;
            counter    <= 32'd0;

            dmem_en    <= 1'b1;
            dmem_we    <= 1'b0;
            dmem_addr  <= 11'd0;
            dmem_wdata <= 32'd0;

            led        <= 4'b0001;
        end else begin
            // defaults for every cycle
            dmem_en <= 1'b1;
            dmem_we <= 1'b0;

            case (state)
                // point BRAM to CMD_ADDR
                S_IDLE_ADDR: begin
                    dmem_addr <= CMD_ADDR;
                    led       <= 4'b0001;
                    state     <= S_IDLE_WAIT;
                end

                // one-cycle-later read of CMD_ADDR
                S_IDLE_WAIT: begin
                    if (dmem_rdata == 32'd1) begin
                        counter <= 32'd0;
                        led     <= 4'b0010;
                        state   <= S_RUN;
                    end else begin
                        state   <= S_IDLE_ADDR;
                    end
                end

                // fake workload / placeholder for CPU work
                S_RUN: begin
                    led <= 4'b0100;

                    if (counter == RUN_CYCLES - 1) begin
                        state <= S_WRITE;
                    end else begin
                        counter <= counter + 32'd1;
                    end
                end

                // write STATUS_ADDR = 2 for one cycle
                S_WRITE: begin
                    dmem_addr  <= STATUS_ADDR;
                    dmem_wdata <= 32'd2;
                    dmem_we    <= 1'b1;
                    led        <= 4'b1000;
                    state      <= S_DONE_ADDR;
                end

                // now point back to CMD_ADDR
                S_DONE_ADDR: begin
                    dmem_addr <= CMD_ADDR;
                    state     <= S_DONE_WAIT;
                end

                // wait until PS clears command, avoids retrigger loop
                S_DONE_WAIT: begin
                    led <= 4'b1000;
                    if (dmem_rdata != 32'd1) begin
                        state <= S_IDLE_ADDR;
                    end
                end

                default: begin
                    state <= S_IDLE_ADDR;
                end
            endcase
        end
    end

endmodule