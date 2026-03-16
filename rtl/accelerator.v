module accelerator (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cmd_valid,
    input  wire [1:0]  cmd_op,       // 0: load A row, 1: load B row, 2: compute, 3: read C
    input  wire [31:0] rs1_val,
    input  wire [31:0] rs2_val,

    output reg         busy,
    output reg         resp_valid,
    output reg [31:0]  resp_data
);

    reg [31:0] A [0:3];              // packed rows of A
    reg [31:0] B [0:3];              // packed rows of B
    reg signed [31:0] C [0:15];      // row-major C

    reg [4:0] compute_idx;           // 0..15
    integer i;

    // signed int8 extract from a packed 32-bit row
    function signed [7:0] get_elem;
        input [31:0] row_data;
        input [1:0]  idx;
        begin
            case (idx)
                2'd0: get_elem = row_data[7:0];
                2'd1: get_elem = row_data[15:8];
                2'd2: get_elem = row_data[23:16];
                2'd3: get_elem = row_data[31:24];
                default: get_elem = 8'sd0;
            endcase
        end
    endfunction

    reg [1:0] row;
    reg [1:0] col;
    reg signed [31:0] sum;

    always @(posedge clk) begin
        if (!rst_n) begin
            busy        <= 1'b0;
            resp_valid  <= 1'b0;
            resp_data   <= 32'd0;
            compute_idx <= 5'd0;

            for (i = 0; i < 4; i = i + 1) begin
                A[i] <= 32'd0;
                B[i] <= 32'd0;
            end

            for (i = 0; i < 16; i = i + 1) begin
                C[i] <= 32'sd0;
            end
        end else begin
            resp_valid <= 1'b0;

            // accept commands only when not busy
            if (cmd_valid && !busy) begin
                case (cmd_op)
                    2'd0: begin
                        A[rs2_val[1:0]] <= rs1_val;
                    end

                    2'd1: begin
                        B[rs2_val[1:0]] <= rs1_val;
                    end

                    2'd2: begin
                        busy        <= 1'b1;
                        compute_idx <= 5'd0;
                    end

                    2'd3: begin
                        resp_data  <= C[rs1_val[3:0]];
                        resp_valid <= 1'b1;
                    end

                    default: begin
                    end
                endcase
            end

            // compute one C element per cycle
            if (busy) begin
                row = compute_idx[4:2]; // effectively 0..3 for 0..15
                col = compute_idx[1:0];

                sum =
                    $signed(get_elem(A[row], 2'd0)) * $signed(get_elem(B[2'd0], col)) +
                    $signed(get_elem(A[row], 2'd1)) * $signed(get_elem(B[2'd1], col)) +
                    $signed(get_elem(A[row], 2'd2)) * $signed(get_elem(B[2'd2], col)) +
                    $signed(get_elem(A[row], 2'd3)) * $signed(get_elem(B[2'd3], col));

                C[compute_idx] <= sum;

                if (compute_idx == 5'd15) begin
                    busy <= 1'b0;
                end else begin
                    compute_idx <= compute_idx + 5'd1;
                end
            end
        end
    end

endmodule