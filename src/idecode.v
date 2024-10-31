`include"util.v"
module decode(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,
    // from ifetch
    input wire if2dec,
    input wire [`ADDR_WIDTH - 1 : 0] pc_out,
    input wire [`INST_WIDTH - 1 : 0] inst_in,
    output wire decFlush,
    output wire [`ADDR_WIDTH - 1 : 0] dec2if,
    output wire [`OP_WIDTH - 1 : 0] orderType,
    output wire [`REG_WIDTH - 1 : 0] dec_rd,
    output wire [`REG_WIDTH - 1 : 0] dec_rs1,
    output wire [`REG_WIDTH - 1 : 0] dec_rs2,
    output wire [`VAL_WIDTH - 1 : 0] dec_imm
);

reg [`OP_WIDTH - 1 : 0] opcode;
reg [`FUNCT3_WIDTH - 1 : 0] funct3;
reg [`FUNCT7_WIDTH - 1 : 0] funct7;

reg reg_decFlush;
reg [`ADDR_WIDTH - 1 : 0] reg_dec2if;
reg [`OP_WIDTH - 1 : 0] reg_orderType,
reg [`REG_WIDTH - 1 : 0] reg_dec_rd,
reg [`REG_WIDTH - 1 : 0] reg_dec_rs1,
reg [`REG_WIDTH - 1 : 0] reg_dec_rs2,
reg [`VAL_WIDTH - 1 : 0] reg_dec_imm;


always @(posedge clk) begin
    if (rst_in) begin
        // initialize
        reg_decFlush <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else if (if2dec && rdy_in) begin
        opcode <= inst_in[`OP_WIDTH - 1 : 0];
        reg_dec_rd <= 0;
        reg_dec_rs1 <= 0;
        reg_dec_rs2 <= 0;
        if (opcode == `OP_AUIPC) begin
            reg_dec_imm <= {inst_in[31 : 12], 12'b0};
            reg_orderType <= opcode;
            reg_dec_rd <= inst_in[11 : 7];
        end
        else if (opcode == `OP_LUI) begin
            reg_dec_imm <= {inst_in[31 : 12], 12'b0};
            reg_orderType <= opcode;
            reg_dec_rd <= inst_in[11 : 7];
        end
        else if (opcode == `OP_JAL) begin
            reg_dec_imm <=  {{12{inst_in[31]}}, inst_in[19:12], inst_in[20], inst_in[30:21], 1'b0};
            reg_orderType <= opcode;
            reg_dec_rd <= inst_in[11 : 7];
        end
        else if (opcode == `OP_JALR) begin
            reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30:20]}) & 32'b11111111111111111111111111111110;
            reg_orderType <= opcode;
            reg_dec_rd <= inst_in[11 : 7];
            reg_dec_rs1 <= inst_in[19 : 15];
        end
        else begin
            case(opcode[6 : 4])
                `OP_I_TYPE: begin
                    funct3 <= inst_in[14 : 12];
                    reg_dec_rs1 <= inst_in[19 : 15];
                    reg_dec_rs2 <= 0;
                    case (funct3)
                        3'b000: begin // addi
                            reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30 : 20]};
                        end
                        3'b001: begin // slli
                            reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            reg_dec_imm <= {27'b0, inst_in[24 : 20]};
                        end
                        3'b010: begin // slti
                            reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30 : 20]};
                        end
                        3'b011: begin //sltiu
                            reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            reg_dec_imm <= {20'b0, inst_in[31 : 20]};
                        end
                        3'b100: begin // xori
                            reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30 : 20]};
                        end
                        3'b110: begin //ori
                            reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30 : 20]};
                        end
                        3'b111: begin //andi
                            reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30 : 20]};
                        end
                        3'b101: begin
                            reg_dec_imm <= {27'b0, inst_in[24 : 20]};
                            if (inst_in[30]) begin
                                // srai
                                reg_orderType <= {opcode[6 : 4], funct3, 1'b1};
                            end
                            else begin
                                reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            end
                        end

                    endcase
                end
                `OP_R_TYPE: begin
                    reg_dec_rs1 <= inst_in[19 : 15];
                    reg_dec_rs2 <= inst_in[24 : 20];
                    funct3 <= inst_in[14 : 12];
                    funct7 <= inst_in[31 : 25];
                    reg_dec_rd <= inst_in[11 : 7];
                    case (funct3) 
                        3'b00: begin
                            if (funct7) begin
                                // sub
                                reg_orderType <= {opcode[6 : 4], funct3, 1'b1};
                            end
                            else begin // add
                                reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                            end
                        end
                        3'b001: reg_orderType <= {opcode[6 : 4], funct3, 1'b0}; // sll
                        3'b010: reg_orderType <= {opcode[6 : 4], funct3, 1'b0}; // slt
                        3'b011: reg_orderType <= {opcode[6 : 4], funct3, 1'b0}; // sltu
                        3'b100: reg_orderType <= {opcode[6 : 4], funct3, 1'b0}; // xor
                        3'b101: begin
                            if (funct7) begin
                                reg_orderType <= {opcode[6 : 4], funct3, 1'b1}; // sra
                            end
                            else begin
                                reg_orderType <= {opcode[6 : 4], funct3, 1'b0}; // srl
                            end
                        end
                        3'b110: reg_orderType <= {opcode[6 : 4], funct3, 1'b0}; // or
                        3'b111: reg_orderType <= {opcode[6 : 4], funct3, 1'b0}; // and
                    endcase
                end
                `OP_L_TYPE: begin
                    reg_dec_rd <= inst_in[11 : 7];
                    reg_dec_rs1 <= inst_in[19 : 15];
                    funct3 <= inst_in[14 : 12];
                    reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                    reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30 : 20]};
                end
                `OP_S_TYPE: begin
                    reg_dec_rs1 <= inst_in[19 : 15];
                    funct3 <= inst_in[14 : 12];
                    reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                    reg_dec_rs2 <= inst_in[24 : 20];
                    reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30 : 25], inst_in[11 : 7]};
                end
                `OP_B_TYPE: begin
                    reg_dec_rs1 <= inst_in[19 : 15];
                    reg_dec_rs2 <= inst_in[24 : 20];
                    funct3 <= inst_in[14 : 12];
                    reg_orderType <= {opcode[6 : 4], funct3, 1'b0};
                    reg_dec_imm <= {{20{inst_in[31]}}, inst_in[7], inst_in[30 : 25], inst_in[11 : 8], 1'b0};
                end
            endcase
        end
        
    end
end

assign decFlush = reg_decFlush;
assign orderType = reg_orderType;
assign dec_rd = reg_dec_rd;
assign dec_rs1 = reg_dec_rs1;
assign dec_rs2 = reg_dec_rs2;                                         
assign dec_imm = reg_dec_imm;
endmodule