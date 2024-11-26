`include "util.v"

module ifetch(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    // from controller
    input wire inst_rdy,
    input wire [`INST_WIDTH - 1 : 0] inst_in,
    
    input wire[`ADDR_WIDTH - 1 : 0] alu2if, // get next PC from alu
    input wire[`ADDR_WIDTH - 1 : 0] rob2if, // get next PC from rob
    input wire[`ADDR_WIDTH - 1 : 0] dec2if, // get next PC from decoder
    input wire alu2if_cont,
    input wire flush,
    input wire decUpd,
    input wire lsbFull,
    input wire robFull,
    input wire rsFull,

    output wire if2dec, // enable decode operation
    output wire[`INST_WIDTH - 1 : 0] inst_out,
    output wire[`ADDR_WIDTH - 1 : 0] pc_out, // to decode & predictor
    output wire if2pred_en,
    output wire[`ADDR_WIDTH - 1 : 0] next_PC, // to cache
    output wire next_inst // to cache, enable next_inst into ifetch
    
);
reg if_stall;
reg [`ADDR_WIDTH - 1 : 0] reg_pc_out;
reg [`ADDR_WIDTH - 1 : 0] reg_next_PC;
reg [`INST_WIDTH - 1 : 0] reg_inst_out;
always @(posedge clk) begin
    if (rst_in) begin
        reg_pc_out <= 0;
        reg_next_PC <= 0;
        reg_inst_out <= 0;
        if_stall <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else if (flush || (if_stall && alu2if_cont) || (if_stall && decUpd)) begin
        // wait for next inst because of branch/flush
        if (flush) begin
            reg_next_PC <= rob2if;
        end
        else if (alu2if_cont) begin
            reg_next_PC <= alu2if;
        end
        else if (decUpd) begin
            reg_next_PC <= dec2if;
        end
        if_stall <= 0;
        reg_inst_out <= 0;
        reg_pc_out <= 0;
    end
    else if (!if_stall && inst_rdy) begin
        if (inst_in[1 : 0] == 2'b11) begin
            reg_inst_out <= inst_in;
            reg_pc_out <= reg_next_PC;
            reg_next_PC <= reg_next_PC + 4;
            if (inst_in[6 : 4] == `OP_B_TYPE) begin
                if_stall <= 1;
            end
            else if (inst_in[6 : 4] == `OP_L_TYPE || inst_in[6 : 4] == `OP_S_TYPE) begin
                if_stall <= (lsbFull) ? 1 : 0;
            end
            else if (!inst_in[6 : 4] == `OP_L_TYPE && !inst_in[6 : 4] == `OP_S_TYPE) begin
                if_stall <= (rsFull) ? 1 : 0;
            end
            else begin
                if_stall <= robFull ? 1 : 0;
            end
        end
        else begin
            reg_inst_out <= {16'b0, inst_in[15 : 0]};
            reg_pc_out <= reg_next_PC;
            reg_next_PC <= reg_next_PC + 2;
            if (inst_in[1 : 0] == 2'b01 && (inst_in[15 : 13] == 3'b110 || inst_in[15 : 13] == 3'b111
             || reg_inst_out[15 : 13] == 3'b001 || inst_in[15 : 13] == 3'b101)) begin
                if_stall <= 1;
            end
            else if (inst_in[1 : 0] == 2'b10 && !inst_in[6 : 2] && inst_in[15 : 13] == 3'b100) begin
                if_stall <= 1;
            end
            else if (inst_in[1 : 0] == 2'b10 && inst_in[15 : 13] == 3'b010) begin
                if_stall <= lsbFull ? 1 : 0;
            end
            else if (inst_in[1 : 0] == 2'b10 && inst_in[15 : 13] == 3'b110) begin
                if_stall <= lsbFull ? 1 : 0;
            end
            else if (inst_in[1 : 0] == 2'b00 && inst_in[15 : 13] == 3'b010) begin
                if_stall <= lsbFull ? 1 : 0;
            end
            else if (inst_in[1 : 0] == 2'b00 && inst_in[15 : 13] == 3'b110) begin
                if_stall <= lsbFull ? 1 : 0;
            end
            else begin
                if_stall <= rsFull ? 1 : robFull ? 1 : 0;
            end

        end

    end
end

assign next_inst = !if_stall; // to cache
assign pc_out = reg_pc_out;
assign next_PC = reg_next_PC;
assign inst_out = reg_inst_out;
assign if2dec = !if_stall && inst_rdy;

endmodule
