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

    // frozen compact 3-stage CPU:
    //   IF -> ID -> EX/MEM/WB
    //
    // instruction/data share one synchronous BRAM port,
    // the controller uses internal wait states for fetch/load/store.

    localparam [3:0]
        S_RESET        = 4'd0,
        S_IF_ADDR      = 4'd1,
        S_IF_WAIT1     = 4'd2,
        S_IF_WAIT2     = 4'd3,
        S_IF_LATCH     = 4'd4,
        S_ID           = 4'd5,
        S_EXWB         = 4'd6,
        S_LOAD_WAIT    = 4'd7,
        S_LOAD_CAPTURE = 4'd8,
        S_STORE_COMMIT = 4'd9;

    localparam [6:0] OPC_RTYPE  = 7'b0110011;
    localparam [6:0] OPC_ITYPE  = 7'b0010011;
    localparam [6:0] OPC_LOAD   = 7'b0000011;
    localparam [6:0] OPC_STORE  = 7'b0100011;
    localparam [6:0] OPC_BRANCH = 7'b1100011;
    localparam [6:0] OPC_JAL    = 7'b1101111;

    reg [3:0]  state;
    reg [31:0] pc;
    reg [31:0] cycle_counter;

    reg [31:0] regs [0:31];

    reg [31:0] fetch_pc_q;   // PC used when fetch address was issued

    reg [31:0] if_pc;
    reg [31:0] if_instr;

    reg [31:0] ex_pc;
    reg [31:0] ex_instr;
    reg [31:0] ex_rs1_val;
    reg [31:0] ex_rs2_val;
    reg [31:0] ex_imm;
    reg [4:0]  ex_rd;
    reg [4:0]  ex_rs1;
    reg [4:0]  ex_rs2;
    reg [2:0]  ex_funct3;
    reg [6:0]  ex_funct7;
    reg [6:0]  ex_opcode;

    reg [4:0]  load_rd;
    reg [31:0] load_pc_next;

    reg [10:0] store_addr_q;
    reg [31:0] store_data_q;
    reg [31:0] store_pc_next_q;

    integer i;

    wire [6:0] dec_opcode = if_instr[6:0];
    wire [4:0] dec_rd     = if_instr[11:7];
    wire [2:0] dec_funct3 = if_instr[14:12];
    wire [4:0] dec_rs1    = if_instr[19:15];
    wire [4:0] dec_rs2    = if_instr[24:20];
    wire [6:0] dec_funct7 = if_instr[31:25];

    wire [31:0] imm_i = {{20{if_instr[31]}}, if_instr[31:20]};
    wire [31:0] imm_s = {{20{if_instr[31]}}, if_instr[31:25], if_instr[11:7]};
    wire [31:0] imm_b = {{19{if_instr[31]}}, if_instr[31], if_instr[7], if_instr[30:25], if_instr[11:8], 1'b0};
    wire [31:0] imm_j = {{11{if_instr[31]}}, if_instr[31], if_instr[19:12], if_instr[20], if_instr[30:21], 1'b0};

    reg [31:0] alu_result;
    reg        branch_taken;
    reg [31:0] branch_target;
    reg [31:0] pc_next_default;

    always @(posedge clk) begin
        if (!rst_n) begin
            state           <= S_RESET;
            pc              <= 32'd0;
            cycle_counter   <= 32'd0;

            dmem_en         <= 1'b1;
            dmem_we         <= 1'b0;
            dmem_addr       <= 11'd0;
            dmem_wdata      <= 32'd0;

            fetch_pc_q      <= 32'd0;
            if_pc           <= 32'd0;
            if_instr        <= 32'd0;

            ex_pc           <= 32'd0;
            ex_instr        <= 32'd0;
            ex_rs1_val      <= 32'd0;
            ex_rs2_val      <= 32'd0;
            ex_imm          <= 32'd0;
            ex_rd           <= 5'd0;
            ex_rs1          <= 5'd0;
            ex_rs2          <= 5'd0;
            ex_funct3       <= 3'd0;
            ex_funct7       <= 7'd0;
            ex_opcode       <= 7'd0;

            load_rd         <= 5'd0;
            load_pc_next    <= 32'd0;

            store_addr_q    <= 11'd0;
            store_data_q    <= 32'd0;
            store_pc_next_q <= 32'd0;

            led             <= 4'b0001;

            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else begin
            cycle_counter <= cycle_counter + 32'd1;

            // defaults every cycle
            dmem_en    <= 1'b1;
            dmem_we    <= 1'b0;
            dmem_wdata <= 32'd0;

            alu_result      = 32'd0;
            branch_taken    = 1'b0;
            branch_target   = 32'd0;
            pc_next_default = ex_pc + 32'd4;

            case (state)
                S_RESET: begin
                    led        <= 4'b0001;
                    fetch_pc_q <= pc;
                    dmem_addr  <= pc[10:0];
                    state      <= S_IF_WAIT1;
                end

                S_IF_ADDR: begin
                    led        <= 4'b0001;
                    fetch_pc_q <= pc;
                    dmem_addr  <= pc[10:0];
                    state      <= S_IF_WAIT1;
                end

                // one wait is not enough after a data access on this shared,
                // synchronous BRAM-style interface. two waits let dmem_rdata
                // settle to the instruction word for the requested address.
                S_IF_WAIT1: begin
                    led   <= 4'b0001;
                    state <= S_IF_WAIT2;
                end

                S_IF_WAIT2: begin
                    led   <= 4'b0001;
                    state <= S_IF_LATCH;
                end

                S_IF_LATCH: begin
                    led      <= 4'b0001;
                    if_pc    <= fetch_pc_q;
                    if_instr <= dmem_rdata;
                    state    <= S_ID;
                end

                S_ID: begin
                    led        <= 4'b0010;

                    ex_pc      <= if_pc;
                    ex_instr   <= if_instr;
                    ex_rs1_val <= regs[dec_rs1];
                    ex_rs2_val <= regs[dec_rs2];
                    ex_rd      <= dec_rd;
                    ex_rs1     <= dec_rs1;
                    ex_rs2     <= dec_rs2;
                    ex_funct3  <= dec_funct3;
                    ex_funct7  <= dec_funct7;
                    ex_opcode  <= dec_opcode;

                    case (dec_opcode)
                        OPC_ITYPE,
                        OPC_LOAD:   ex_imm <= imm_i;
                        OPC_STORE:  ex_imm <= imm_s;
                        OPC_BRANCH: ex_imm <= imm_b;
                        OPC_JAL:    ex_imm <= imm_j;
                        default:    ex_imm <= 32'd0;
                    endcase

                    state <= S_EXWB;
                end

                S_EXWB: begin
                    led <= 4'b0100;

                    case (ex_opcode)
                        OPC_RTYPE: begin
                            case (ex_funct3)
                                3'b000: begin
                                    if (ex_funct7 == 7'b0100000)
                                        alu_result = ex_rs1_val - ex_rs2_val;
                                    else
                                        alu_result = ex_rs1_val + ex_rs2_val;
                                end
                                3'b111: alu_result = ex_rs1_val & ex_rs2_val;
                                3'b110: alu_result = ex_rs1_val | ex_rs2_val;
                                default: alu_result = 32'd0;
                            endcase

                            if (ex_rd != 5'd0)
                                regs[ex_rd] <= alu_result;

                            pc    <= pc_next_default;
                            state <= S_IF_ADDR;
                        end

                        OPC_ITYPE: begin
                            case (ex_funct3)
                                3'b000: alu_result = ex_rs1_val + ex_imm;
                                default: alu_result = 32'd0;
                            endcase

                            if (ex_rd != 5'd0)
                                regs[ex_rd] <= alu_result;

                            pc    <= pc_next_default;
                            state <= S_IF_ADDR;
                        end

                        OPC_LOAD: begin
                            if (ex_funct3 == 3'b010) begin
                                alu_result   = ex_rs1_val + ex_imm;
                                dmem_addr    <= alu_result[10:0];
                                load_rd      <= ex_rd;
                                load_pc_next <= pc_next_default;
                                state        <= S_LOAD_WAIT;
                            end else begin
                                pc    <= pc_next_default;
                                state <= S_IF_ADDR;
                            end
                        end

                        OPC_STORE: begin
                            if (ex_funct3 == 3'b010) begin
                                store_addr_q    <= ex_rs1_val[10:0] + ex_imm[10:0];
                                store_data_q    <= ex_rs2_val;
                                store_pc_next_q <= pc_next_default;
                                state           <= S_STORE_COMMIT;
                            end else begin
                                pc    <= pc_next_default;
                                state <= S_IF_ADDR;
                            end
                        end

                        OPC_BRANCH: begin
                            case (ex_funct3)
                                3'b000: branch_taken = (ex_rs1_val == ex_rs2_val);
                                3'b001: branch_taken = (ex_rs1_val != ex_rs2_val);
                                default: branch_taken = 1'b0;
                            endcase

                            branch_target = ex_pc + ex_imm;

                            if (branch_taken)
                                pc <= branch_target;
                            else
                                pc <= pc_next_default;

                            state <= S_IF_ADDR;
                        end

                        OPC_JAL: begin
                            if (ex_rd != 5'd0)
                                regs[ex_rd] <= ex_pc + 32'd4;

                            pc    <= ex_pc + ex_imm;
                            state <= S_IF_ADDR;
                        end

                        default: begin
                            pc    <= pc_next_default;
                            state <= S_IF_ADDR;
                        end
                    endcase
                end

                S_LOAD_WAIT: begin
                    led   <= 4'b1000;
                    state <= S_LOAD_CAPTURE;
                end

                S_LOAD_CAPTURE: begin
                    led <= 4'b1000;

                    if (load_rd != 5'd0)
                        regs[load_rd] <= dmem_rdata;

                    pc    <= load_pc_next;
                    state <= S_IF_ADDR;
                end

                S_STORE_COMMIT: begin
                    led        <= 4'b1001;
                    dmem_addr  <= store_addr_q;
                    dmem_wdata <= store_data_q;
                    dmem_we    <= 1'b1;
                    pc         <= store_pc_next_q;
                    state      <= S_IF_ADDR;
                end

                default: begin
                    state <= S_RESET;
                end
            endcase

            regs[0] <= 32'd0;
        end
    end

endmodule