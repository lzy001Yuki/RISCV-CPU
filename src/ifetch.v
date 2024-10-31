`include "util.v"

module ifetch(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire cache_rdy,
    input wire[`INST_WIDTH - 1 : 0] inst_in,
    input wire[`ADDR_WIDTH - 1 : 0] alu2if, // get next PC from alu
    input wire[`ADDR_WIDTH - 1 : 0] rob2if, // get next PC from rob
    input wire[`ADDR_WIDTH - 1 : 0] dec2if, // get next PC from decoder
    input wire alu2if_cont,
    input wire flush,
    input wire decUpd,

    output wire if2dec, // enable decode operation
    output wire[`INST_WIDTH - 1 : 0] inst_out,
    output wire[`ADDR_WIDTH - 1 : 0] pc_out, // to decode & predictor
    output wire[`ADDR_WIDTH - 1 : 0] next_PC, // to cache
    output wire next_inst // to cache
);
reg if_stall;
reg [`ADDR_WIDTH - 1 : 0] reg_pc_out;
reg [`ADDR_WIDTH - 1 : 0] reg_next_PC;
reg [`INST_WIDTH - 1 : 0] reg_inst_out;
reg reg_if2dec;
always @(posedge clk) begin
    if (rst_in) begin
        reg_pc_out <= 0;
        reg_next_PC <= 0;
        reg_inst_out <= 0;
        reg_if2dec <= 0;
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
            reg_next_pc <= dec2if;
        end
        if_stall <= 0;
        reg_inst_out <= 0;
        reg_if2dec <= 0;
        reg_pc_out <= 0;
    end
    else if (!if_stall && cache_rdy) begin
        reg_if2dec <= 1;
        reg_inst_out <= inst_in;
        reg_next_PC <= reg_next_PC + 4;
        reg_pc_out <= reg_next_PC;
    
        if (inst_in[6 : 4] == `OP_B_TYPE) begin
            if_stall <= 1;
        end
    end
end

assign next_inst = !if_stall;
assign pc_out = reg_pc_out;
assign next_PC = reg_next_PC;
assign inst_out = reg_inst_out;
assign if2dec = reg_if2dec;

endmodule
