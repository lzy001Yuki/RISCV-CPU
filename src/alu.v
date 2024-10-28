`include "util.v"
module alu(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire execute,
    input wire [`OP_WIDTH - 1 : 0] type,
    input wire [`VAL_WIDTH - 1 : 0] val1, 
    input wire [`VAL_WIDTH - 1 : 0] val2,
    input wire [`ID_WIDTH - 1 : 0] entry,

    // connect to cdb & rob
    output wire aluReady,
    output wire [`ID_WIDTH - 1 : 0] entry_out,
    output wire [`VAL_WIDTH - 1 : 0] val_out
);

assign entry_out = entry;
reg [`VAL_WIDTH - 1 : 0] val_out_reg;
reg ready;
reg [2 : 0] typeSign;
reg [2 : 0] funcSign;
reg otherSign;

always @(posedge clk) begin
    if (rst_in) begin
        ready <= 0;
        val_out_reg <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else begin
        if (execute) begin
        ready <= 1;
        typeSign = type[2 : 0];
        funcSign = type[5 : 3];
        otherSign = type[6];
        case (typeSign)
            `OP_B_TYPE:begin
                case (funcSign)
                    3'b000: val_out_reg <= val1 == val2; // beq
                    3'b001: val_out_reg <= val1 != val2; // bne
                    3'b100: val_out_reg <= $signed(val1) < $signed(val2); // blt
                    3'b101: val_out_reg <= $signed(val1) >= $signed(val2); // bge
                    3'b110: val_out_reg <= $unsigned(val1) < $unsigned(val2); // bltu
                    3'b111: begin
                        case (otherSign)
                            1'b0: val_out_reg <= $unsigned(val1) >= $unsigned(val2); // bgeu
                            1'b1: val_out_reg <= val1 + val2; //jal
                        endcase
                    end
                    3'b011: val_out_reg <= (val1 + val2) & 32'hfffffffe; //jalr
                endcase
            end
            `OP_I_TYPE: begin
                case (funcSign)
                    3'b000: val_out_reg <= val1 + val2; //addi
                    3'b010: val_out_reg <= $signed(val1) < $signed(val2); // slti
                    3'b011: begin
                        case (otherSign)
                            1'b0: val_out_reg <= $unsigned(val1) < $unsigned(val2); // sltiu
                            1'b1: val_out_reg <= val1 + val2; //auipc
                        endcase
                    end
                    3'b100: val_out_reg <= val1 ^ val2; //xori
                    3'b110: val_out_reg <= val1 | val2; //andi
                    3'b111: val_out_reg <= val1 & val2; // ori
                    3'b001: val_out_reg <= (val1 << val2); // slli
                    3'b101: begin
                        case (otherSign)
                            1'b0: val_out_reg <= val1 >> val2; // srli
                            1'b1: val_out_reg <= $signed(val1) >> val2; // srai
                        endcase
                    end
                endcase
            end
            `OP_L_TYPE: val_out_reg <= val1 + val2; // lb, lh, lw, lbu, lhu  be caseful--> 'u' means that data fetched from memory is unsigned
            `OP_S_TYPE: val_out_reg <= val1 + val2; // sb, sh, sw
            `OP_R_TYPE: begin
                case (funcSign)
                    3'b000: begin
                    case (otherSign)
                        1'b0: val_out_reg <= val1 + val2; // add
                        1'b1: val_out_reg <= val1 - val2; // sub
                    endcase
                    end
                    3'b001: val_out_reg <= val1 << val2; // sll
                    3'b010: val_out_reg <= val1 < val2; // slt
                    3'b011: begin
                        case (otherSign)
                            1'b0: val_out_reg <= $unsigned(val1) < $unsigned(val2); // sltu
                            1'b1: val_out_reg <= val1 + val2; //lui
                        endcase
                    end
                    3'b100: val_out_reg <= val1 ^ val2; // xor
                    3'b101: begin
                        case (otherSign)
                            1'b0: val_out_reg <= val1 << val2; // sll
                            1'b1: val_out_reg <= val1 >> val2; // srl
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
        end
    end
end

assign aluReady = ready;
assign val_out = val_out_reg;
endmodule