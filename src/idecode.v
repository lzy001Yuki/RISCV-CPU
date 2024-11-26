`include"util.v"
module idecode(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,
    // from ifetch
    input wire if2dec,
    input wire flush,
    input wire [`ADDR_WIDTH - 1 : 0] pc_in,
    input wire [`INST_WIDTH - 1 : 0] inst_in,
    // from predictor
    input wire pred,
    // to lsb & rob & rs
    output wire [`OP_WIDTH - 1 : 0] orderType,
    output wire [`REG_WIDTH - 1 : 0] dec_rd,
    output wire [`REG_WIDTH - 1 : 0] dec_rs1,
    output wire [`REG_WIDTH - 1 : 0] dec_rs2,
    output wire [`VAL_WIDTH - 1 : 0] dec_imm,
    output wire decUpd,
    // to ifetch
    output wire [`ADDR_WIDTH - 1 : 0] dec2if_pc,
    // from lsb & rs
    input wire lsbFull,
    input wire rsFull,
    input wire robFull,
    // to if & rob
    output wire dec2if_rob_en,
    output wire [`ADDR_WIDTH - 1 : 0] dec_inst_curPC,
    output wire [`ADDR_WIDTH - 1 : 0] dec2rob_jump_addr,
    // to lsb
    output wire dec2lsb_en,
    // to rs
    output wire dec2rs_en
);

reg [`OP_WIDTH - 1 : 0] opcode;
reg [`FUNCT3_WIDTH - 1 : 0] funct3;
reg [`FUNCT7_WIDTH - 1 : 0] funct7;

reg [`OP_WIDTH - 1 : 0] reg_orderType;
reg [`REG_WIDTH - 1 : 0] reg_dec_rd;
reg [`REG_WIDTH - 1 : 0] reg_dec_rs1;
reg [`REG_WIDTH - 1 : 0] reg_dec_rs2;
reg [`VAL_WIDTH - 1 : 0] reg_dec_imm;
reg [`ADDR_WIDTH - 1 : 0] reg_dec2if_pc;
reg [`ADDR_WIDTH - 1 : 0] reg_curPC;


always @(posedge clk) begin
    if (rst_in || flush) begin
        // initialize
        reg_orderType <= 0;
        reg_dec_rs1 <= 0;
        reg_dec_rs2 <= 0;
        reg_dec_rd <= 0;
        reg_dec_imm <= 0;
        funct3 <= 0;
        funct7 <= 0;
        opcode <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else if (if2dec && rdy_in) begin
        opcode <= inst_in[`OP_WIDTH - 1 : 0];
        reg_dec_rd <= 0;
        reg_dec_rs1 <= 0;
        reg_dec_rs2 <= 0;
        reg_dec2if_pc <= 0;
        reg_curPC <= pc_in;
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
            reg_dec2if_pc <= pc_in + reg_dec_imm;
        end
        else if (opcode == `OP_JALR) begin
            reg_dec_imm <= {{21{inst_in[31]}}, inst_in[30:20]} & 32'b11111111111111111111111111111110;
            reg_orderType <= opcode;
            reg_dec_rd <= inst_in[11 : 7];
            reg_dec_rs1 <= inst_in[19 : 15];
        end
        else if (opcode[1 : 0] == 2'b11) begin
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
                                // srli
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
                    if (pred) begin
                        reg_dec2if_pc <= pc_in + reg_dec_imm;
                    end
                    else begin
                        reg_dec2if_pc <= pc_in + 4;
                    end
                end
            endcase
        end 
        else begin
            case(opcode[1 : 0])
                2'b01: begin
                    funct3 <= inst_in[15 : 13];
                    case (funct3) 
                        3'b000: begin // c.addi
                            reg_dec_rd <= inst_in[11 : 7];
                            reg_dec_rs1 <= reg_dec_rd;
                            reg_dec_imm <= {{27{inst_in[12]}}, inst_in[4 : 0]};
                            reg_orderType <= 7'b0010000;
                        end
                        3'b001: begin // c.jal
                            reg_orderType <= `OP_JAL;
                            reg_dec_rd <= 5'b00001; // x1
                            reg_dec_imm <= {{21{inst_in[12]}}, inst_in[8], inst_in[10 : 9], inst_in[6], inst_in[7], inst_in[2], inst_in[11], inst_in[5 : 3]};
                            reg_dec2if_pc <= pc_in + reg_dec_imm;
                        end
                        3'b010: begin // c.li
                            reg_orderType <= 7'b0010000;
                            reg_dec_rd <= inst_in[11 : 7];
                            reg_dec_rs1 <= 0;
                            reg_dec_imm <= {{27{inst_in[12]}}, inst_in[6 : 2]};
                        end
                        3'b011: begin 
                            reg_dec_rd <= inst_in[11 : 7];
                            if (reg_dec_rd == 5'b00010) begin // c.addi16sp
                                reg_dec_rs1 <= reg_dec_rd;
                                reg_orderType <= 7'b0010000;
                                reg_dec_imm <= {{23{inst_in[12]}}, inst_in[4 : 3], inst_in[5], inst_in[2], inst_in[6], 4'b0000};
                            end
                            else begin // c.lui
                                reg_orderType <= `OP_LUI;
                                reg_dec_imm <= {{15{inst_in[12]}}, inst_in[6 : 2], 12'b0};
                            end
                        end
                        3'b100: begin 
                            if (inst_in[11 : 10] == 2'b00) begin
                                reg_orderType <= 7'b0011010; // c.srli
                                reg_dec_rd <= {2'b0, inst_in[9 : 7]} + 8;
                                reg_dec_imm <= {26'b0, inst_in[5], inst_in[4 : 0]};
                                reg_dec_rs1 <= reg_dec_rd;
                            end
                            else if (inst_in[11 : 10] == 2'b01) begin
                                reg_orderType <= 7'b0011011; // c.srai
                                reg_dec_rd <= {2'b0, inst_in[9 : 7]} + 8;
                                reg_dec_imm <= {26'b0, inst_in[5], inst_in[4 : 0]};
                                reg_dec_rs1 <= reg_dec_rd;
                            end
                            else if (inst_in[11 : 10] == 2'b10) begin
                                reg_orderType <= {7'b0011110}; // c.andi
                                reg_dec_rd <= {2'b0, inst_in[9 : 7]} + 8;
                                reg_dec_imm <= {26'b0, inst_in[5], inst_in[4 : 0]};
                                reg_dec_rs1 <= reg_dec_rd;
                            end
                            else if (inst_in[11 : 10] == 2'b11) begin
                                if (inst_in[6 : 5] == 2'b00) begin
                                    reg_orderType <= 7'b0110001; // c.sub
                                end
                                else if (inst_in[6 : 5] == 2'b01) begin
                                    reg_orderType <= 7'b0111000; // c.xor
                                end
                                else if (inst_in[6 : 5] == 2'b10) begin
                                    reg_orderType <= 7'b0111100; // c.or
                                end
                                else if (inst_in[6 : 5] == 2'b11) begin
                                    reg_orderType <= 7'b0111110; // c.and
                                end
                                reg_dec_rd <= {2'b0, inst_in[9 : 7]} + 8;
                                reg_dec_rs1 <= reg_dec_rd;
                                reg_dec_rs2 <= {2'b0, inst_in[4 : 2]} + 8;
                            end
                        end
                        3'b101: begin // c.j
                            reg_orderType <= `OP_JAL;
                            reg_dec_rd <= 5'b00000;
                            reg_dec_imm <= {{21{inst_in[12]}}, inst_in[8], inst_in[10 : 9], inst_in[6], inst_in[7], inst_in[2], inst_in[11], inst_in[5 : 3]};
                            reg_dec2if_pc <= pc_in + reg_dec_imm;
                        end
                        3'b110: begin // c.beqz
                            reg_orderType <= 7'b1100000;
                            reg_dec_rs1 <= {2'b0, inst_in[9 : 7]} + 8;
                            reg_dec_rs1 <= 5'b00000;
                            reg_dec_imm <= {{24{inst_in[12]}}, inst_in[6 : 5], inst_in[2], inst_in[11 : 10], inst_in[4 : 3]};
                            if (pred) begin
                                reg_dec2if_pc <= pc_in + reg_dec_imm;
                            end
                            else begin
                                reg_dec2if_pc <= pc_in + 2;
                            end
                        end
                        3'b111: begin // c.bnez
                            reg_orderType <= 7'b1101000;
                            reg_dec_rs1 <= {2'b0, inst_in[9 : 7]} + 8;
                            reg_dec_rs1 <= 5'b00000;
                            reg_dec_imm <= {{24{inst_in[12]}}, inst_in[6 : 5], inst_in[2], inst_in[11 : 10], inst_in[4 : 3]};
                            if (pred) begin
                                reg_dec2if_pc <= pc_in + reg_dec_imm;
                            end
                            else begin
                                reg_dec2if_pc <= pc_in + 2;
                            end
                        end
                    endcase
                end
                2'b10: begin
                    funct3 <= inst_in[15 : 13];
                    case (funct3) 
                        3'b000: begin // c.slli
                            reg_dec_rd <= inst_in[11 : 7];
                            reg_dec_rs1 <= reg_dec_rd;
                            reg_dec_imm <= {26'b0, inst_in[12], inst_in[6 : 2]};
                            reg_orderType <= 7'b0010010;
                        end
                        3'b010: begin // c.lwsp
                            reg_orderType <= 7'b0000100;
                            reg_dec_rd <= inst_in[11 : 7];
                            reg_dec_rs1 <= 5'b00010;
                            reg_dec_imm <= {24'b0, inst_in[3 : 2], inst_in[12], inst_in[6 : 4], 2'b00};
                        end
                        3'b100: begin 
                            if (inst_in[12] == 1'b0) begin 
                                if (inst_in[6 : 2] == 5'b00000) begin
                                    // c.jr
                                    reg_dec_rs1 <= inst_in[11 : 7];
                                    reg_orderType <= `OP_JALR;
                                    reg_dec_imm <= 0;
                                    reg_dec_rd <= 0;
                                end
                                else begin
                                // c.mv
                                    reg_dec_rd <= inst_in[11 : 7];
                                    reg_dec_rs2 <= inst_in[6 : 2];
                                    reg_dec_rs1 <= 5'b00000;
                                    reg_orderType <= 7'b0110000;
                                end
                            end
                            else begin 
                                if (inst_in[6 : 2] == 5'b00000) begin // c.jalr
                                    reg_dec_rd <= 5'b00001;
                                    reg_dec_rs1 <= inst_in[11 : 7];
                                    reg_dec_imm <= 0;
                                    reg_orderType <= `OP_JALR;
                                end
                                else begin // c.add
                                    reg_dec_rs2 <= inst_in[6 : 2];
                                    reg_dec_rd <= inst_in[11 : 7];
                                    reg_dec_rs1 <= reg_dec_rd;
                                    reg_orderType <= 7'b0110000;
                                end
                            end
                        end
                        3'b110: begin // c.swsp
                            reg_orderType <= 7'b0100100;
                            reg_dec_rs2 <= inst_in[6 : 2];
                            reg_dec_rs1 <= 5'b00010;
                            reg_dec_imm <= {24'b0, inst_in[8 : 7], inst_in[12 : 9], 2'b00};
                        end
                    endcase
                end
                2'b00 : begin 
                    funct3 <= inst_in[15 : 13];
                    case (funct3) 
                        3'b000: begin // c.addi4spn
                            reg_orderType <= 7'b0010000; 
                            reg_dec_rd <= {2'b0, inst_in[4 : 2]} + 8;
                            reg_dec_rs1 <= 5'b00010;
                            reg_dec_imm <= {22'b0, inst_in[10 : 7], inst_in[12 : 11], inst_in[5], inst_in[6], 2'b00};
                        end
                        3'b010: begin // c.lw
                            reg_orderType <= 7'b0000100;
                            reg_dec_rd <= {2'b0, inst_in[4 : 2]} + 8;;
                            reg_dec_rs1 <= {2'b0, inst_in[9 : 7]} + 8;
                            reg_dec_imm <= {25'b0, inst_in[5], inst_in[12 : 10], inst_in[6], 2'b00};
                        end
                        3'b110: begin //c.sw
                            reg_orderType <= 7'b0100100;
                            reg_dec_rs2 <= {2'b0, inst_in[4 : 2]} + 8;
                            reg_dec_rs1 <= {2'b0, inst_in[9 : 7]} + 8;
                            reg_dec_imm <= {25'b0, inst_in[5], inst_in[12 : 10], inst_in[6], 2'b00};
                        end
                    endcase
                end
            endcase
        end
    end
end

assign orderType = reg_orderType;
assign dec_rd = reg_dec_rd;
assign dec_rs1 = reg_dec_rs1;
assign dec_rs2 = reg_dec_rs2;                                         
assign dec_imm = reg_dec_imm;
assign decUpd = reg_dec2if_pc ? 1 : 0;
assign dec2if_pc = reg_dec2if_pc;
assign dec2rob_jump_addr = pred ? reg_dec2if_pc : 0;
assign dec2if_rob_en = ((reg_orderType[6 : 4] != `OP_L_TYPE && reg_orderType[6 : 4] != `OP_S_TYPE && !rsFull)
|| ((reg_orderType[6 : 4] == `OP_L_TYPE || reg_orderType[6 : 4] == `OP_S_TYPE) && !lsbFull)) && !robFull ? 1 : 0;
assign dec2lsb_en = ((reg_orderType[6 : 4] == `OP_L_TYPE || reg_orderType[6 : 4] == `OP_S_TYPE) && !lsbFull) ? 1 : 0;
assign dec2rs_en = ((reg_orderType[6 : 4] != `OP_L_TYPE && reg_orderType[6 : 4] != `OP_S_TYPE) && !rsFull) ? 1 : 0;
assign dec2_inst_curPC = reg_curPC;
endmodule

