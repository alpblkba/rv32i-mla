`timescale 1ns/1ps

module tb_accelerator;

    reg         clk;
    reg         rst_n;
    reg         cmd_valid;
    reg  [1:0]  cmd_op;
    reg  [31:0] rs1_val;
    reg  [31:0] rs2_val;

    wire        busy;
    wire        resp_valid;
    wire [31:0] resp_data;

    accelerator dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(cmd_valid),
        .cmd_op(cmd_op),
        .rs1_val(rs1_val),
        .rs2_val(rs2_val),
        .busy(busy),
        .resp_valid(resp_valid),
        .resp_data(resp_data)
    );

    integer idx;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_cmd;
        input [1:0]  op;
        input [31:0] v1;
        input [31:0] v2;
        begin
            @(posedge clk);
            cmd_valid <= 1'b1;
            cmd_op    <= op;
            rs1_val   <= v1;
            rs2_val   <= v2;

            @(posedge clk);
            cmd_valid <= 1'b0;
            cmd_op    <= 2'd0;
            rs1_val   <= 32'd0;
            rs2_val   <= 32'd0;
        end
    endtask

    initial begin
        rst_n     = 1'b0;
        cmd_valid = 1'b0;
        cmd_op    = 2'd0;
        rs1_val   = 32'd0;
        rs2_val   = 32'd0;

        #30;
        rst_n = 1'b1;

        // load A = identity matrix
        // row0 = [1,0,0,0]
        send_cmd(2'd0, 32'h00000001, 32'd0);
        // row1 = [0,1,0,0]
        send_cmd(2'd0, 32'h00000100, 32'd1);
        // row2 = [0,0,1,0]
        send_cmd(2'd0, 32'h00010000, 32'd2);
        // row3 = [0,0,0,1]
        send_cmd(2'd0, 32'h01000000, 32'd3);

        // load B rows
        send_cmd(2'd1, 32'h04030201, 32'd0); // [1,2,3,4]
        send_cmd(2'd1, 32'h08070605, 32'd1); // [5,6,7,8]
        send_cmd(2'd1, 32'h0C0B0A09, 32'd2); // [9,10,11,12]
        send_cmd(2'd1, 32'h100F0E0D, 32'd3); // [13,14,15,16]

        // start compute
        send_cmd(2'd2, 32'd0, 32'd0);

        // wait until done
        wait (busy == 1'b1);
        wait (busy == 1'b0);

        // read all C elements
        for (idx = 0; idx < 16; idx = idx + 1) begin
            send_cmd(2'd3, idx, 32'd0);
            @(posedge clk);
            if (resp_valid)
                $display("C[%0d] = %0d (0x%08h)", idx, $signed(resp_data), resp_data);
        end

        $finish;
    end

endmodule