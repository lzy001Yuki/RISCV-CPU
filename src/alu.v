`include "util.v"
module alu(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire execute,
    input wire flush,
    input wire [`OP_WIDTH - 1 : 0] type,
    input wire [`VAL_WIDTH - 1 : 0] val1, 
    input wire [`VAL_WIDTH - 1 : 0] val2,
    input wire [`ROB_ID_WIDTH: 0] entry,
    input wire [`ADDR_WIDTH - 1 : 0] nowPC,

    // connect to rs & rob
    output wire aluReady,
    output wire [`ROB_ID_WIDTH: 0] entry_out,
    output wire [`VAL_WIDTH - 1 : 0] val_out,

    // to ifetch
    output wire [`ADDR_WIDTH - 1 : 0] alu2if_pc,
    output wire alu2if_con
);

reg [`ROB_ID_WIDTH: 0] reg_entry;
reg [`VAL_WIDTH - 1 : 0] val_out_reg;
reg ready;
reg [`ADDR_WIDTH - 1 : 0] PC;
reg cont;

always @(posedge clk) begin
    if (rst_in || flush) begin
        ready <= 0;
        val_out_reg <= 0;
        reg_entry <= 0;
        PC <= 0;
        cont <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else begin
        if (execute) begin
        ready <= 1;
        reg_entry <= entry;
        cont <= 0;
        case (type[6 : 4])
            `OP_B_TYPE:begin
                case (type[3 : 1])
                    3'b000: val_out_reg <= val1 == val2; // beq
                    3'b001: val_out_reg <= val1 != val2; // bne
                    3'b100: val_out_reg <= $signed(val1) < $signed(val2); // blt
                    3'b101: val_out_reg <= $signed(val1) >= $signed(val2); // bge
                    3'b110: val_out_reg <= $unsigned(val1) < $unsigned(val2); // bltu
                    3'b111: begin
                        case (type[0])
                            1'b0: val_out_reg <= $unsigned(val1) >= $unsigned(val2); // bgeu
                            1'b1: val_out_reg <= val1 + val2; //jal
                        endcase
                    end
                    3'b011: begin
                        PC <= (val1 + val2) & 32'hfffffffe; //jalr
                        val_out_reg <= nowPC;
                        cont <= 1;
                    end
                endcase
            end
            `OP_I_TYPE: begin
                case (type[3 : 1])
                    3'b000: val_out_reg <= val1 + val2; //addi
                    3'b010: val_out_reg <= $signed(val1) < $signed(val2); // slti
                    3'b011: begin
                        case (type[0])
                            1'b0: val_out_reg <= $unsigned(val1) < $unsigned(val2); // sltiu
                            1'b1: val_out_reg <= val1 + val2; //auipc
                        endcase
                    end
                    3'b100: val_out_reg <= val1 ^ val2; //xori
                    3'b110: val_out_reg <= val1 | val2; //andi
                    3'b111: val_out_reg <= val1 & val2; // ori
                    3'b001: val_out_reg <= (val1 << val2); // slli
                    3'b101: begin
                        case (type[0])
                            1'b0: val_out_reg <= val1 >> val2; // srli
                            1'b1: val_out_reg <= $signed(val1) >> val2; // srai
                        endcase
                    end
                endcase
            end
            `OP_L_TYPE: val_out_reg <= val1 + val2; // lb, lh, lw, lbu, lhu  be caseful--> 'u' means that data fetched from memory is unsigned
            `OP_S_TYPE: val_out_reg <= val1 + val2; // sb, sh, sw
            `OP_R_TYPE: begin
                case (type[3 : 1])
                    3'b000: begin
                    case (type[0])
                        1'b0: val_out_reg <= val1 + val2; // add
                        1'b1: val_out_reg <= val1 - val2; // sub
                    endcase
                    end
                    3'b001: val_out_reg <= val1 << val2; // sll
                    3'b010: val_out_reg <= val1 < val2; // slt
                    3'b011: begin
                        case (type[0])
                            1'b0: val_out_reg <= $unsigned(val1) < $unsigned(val2); // sltu
                            1'b1: val_out_reg <= val1 + val2; //lui
                        endcase
                    end
                    3'b100: val_out_reg <= val1 ^ val2; // xor
                    3'b101: begin
                        case (type[0])
                            1'b0: val_out_reg <= val1 >> val2; // srl
                            1'b1: val_out_reg <= $signed(val1) >> val2; // sra
                        endcase
                    end
                    3'b110: val_out_reg <= val1 | val2;
                    3'b111: val_out_reg <= val1 & val2;
                endcase
            end
        endcase
        end
        else begin
            ready <= 0;
            cont <= 0;
        end
    end
end

assign aluReady = ready;
assign val_out = val_out_reg;
assign entry_out = reg_entry;
assign alu2if_con = cont; // has calculated JALR's destination
assign alu2if_pc = PC;
endmodule