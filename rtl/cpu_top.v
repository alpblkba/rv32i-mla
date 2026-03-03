module cpu_top (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [3:0]  led,

    output reg         dmem_en,
    output reg         dmem_we,          // 1-bit now
    output reg  [10:0] dmem_addr,
    output reg  [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);

    localparam CMD_ADDR    = 11'd0;
    localparam STATUS_ADDR = 11'd1;

    localparam S_IDLE_ADDR = 3'd0;
    localparam S_IDLE_WAIT = 3'd1;
    localparam S_RUN       = 3'd2;
    localparam S_WRITE     = 3'd3;
    localparam S_DONE      = 3'd4;

    reg [2:0] state;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE_ADDR;
            counter <= 0;

            dmem_en <= 1'b1;
            dmem_we <= 1'b0;
            dmem_addr <= 0;
            dmem_wdata <= 0;

            led <= 4'b0001;
        end else begin

            // default: no write
            dmem_we <= 1'b0;

            case (state)

                // set address
                S_IDLE_ADDR: begin
                    dmem_addr <= CMD_ADDR;
                    state <= S_IDLE_WAIT;
                end

                // read value next cycle (BRAM latency)
                S_IDLE_WAIT: begin
                    if (dmem_rdata == 32'd1) begin
                        counter <= 0;
                        state <= S_RUN;
                        led <= 4'b0010;
                    end else begin
                        state <= S_IDLE_ADDR;
                    end
                end

                S_RUN: begin
                    counter <= counter + 1;
                    led <= 4'b0100;
                    if (counter == 32'd1000000)
                        state <= S_WRITE;
                end

                // single-cycle write pulse
                S_WRITE: begin
                    dmem_addr <= STATUS_ADDR;
                    dmem_wdata <= 32'd2;
                    dmem_we <= 1'b1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    led <= 4'b1000;
                    state <= S_IDLE_ADDR;
                end

            endcase
        end
    end
endmodule