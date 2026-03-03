module accelerator (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cmd_valid,
    input  wire [1:0]  cmd_op,        // 0: load A, 1: load B, 2: compute, 3: read C
    input  wire [31:0] rs1_val,
    input  wire [31:0] rs2_val,

    output reg         busy,
    output reg         resp_valid,
    output reg [31:0]  resp_data
);

    // 4x4 tile
    reg [31:0] A [0:3];
    reg [31:0] B [0:3];
    reg signed [31:0] C [0:15];

    reg [4:0] compute_cnt;

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            busy <= 0;
            resp_valid <= 0;
            compute_cnt <= 0;
            for (i=0;i<16;i=i+1)
                C[i] <= 0;
        end else begin
            resp_valid <= 0;

            if (cmd_valid && !busy) begin
                case (cmd_op)

                    2'd0: begin // load A row
                        A[rs2_val[1:0]] <= rs1_val;
                    end

                    2'd1: begin // load B row
                        B[rs2_val[1:0]] <= rs1_val;
                    end

                    2'd2: begin // compute
                        busy <= 1;
                        compute_cnt <= 0;
                    end

                    2'd3: begin // read C
                        resp_data <= C[rs1_val[3:0]];
                        resp_valid <= 1;
                    end

                endcase
            end

            // multi-cycle compute (16 cycles simple version)
            if (busy) begin
                compute_cnt <= compute_cnt + 1;

                if (compute_cnt == 16) begin
                    busy <= 0;
                end
            end
        end
    end

endmodule