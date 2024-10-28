`include "util.v"

module ifetch(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire cache_rdy,
    input wire[`INST_WIDTH - 1 : 0] inst_in,
    input wire[`ADDR_WIDTH - 1 : 0] dec2if, // get next PC from decoder
    input wire robFlush, // for branch prediction
    input wire decFlush, // for branch prediction
    input wire[`ADDR_WIDTH - 1 : 0] rob2if, // get next PC from rob


    output wire if2dec, // enable decode operation
    output wire[`INST_WIDTH - 1 : 0] inst_out,
    output wire[`ADDR_WIDTH - 1 : 0] pc_out, // to decode
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
    else if (robFlush || (if_stall && decFlush)) begin
        // wait for next inst because of branch
        if (robFlush) begin
            reg_next_PC <= rob2if;
        end
        else if (decFlush) begin
            reg_next_PC <= dec2if;
        end
        if_stall <= 0;
        reg_inst_out <= 0;
        reg_if2dec <= 0;
        reg_pc_out <= 0;
    end
    else if (!if_stall && cache_rdy) begin
        reg_if2dec <= 1;
        reg_inst_out <= inst_in;
        if (robFlush) begin
            reg_next_PC <= rob2if;
        end
        else if (decFlush) begin
            reg_next_PC <= dec2if;
        end
        else begin
            reg_next_PC <= reg_next_PC + 4;
        end
        reg_pc_out <= reg_next_PC;
        case (inst_in[`OP_WIDTH - 1 : 0])
            `OP_B_TYPE, `OP_JALR, `OP_JAL: begin
                if_stall <= 1;
            end
        endcase
    end
end

assign next_inst = !if_stall;
assign pc_out = reg_pc_out;
assign next_PC = reg_next_PC;
assign inst_out = reg_inst_out;
assign if2dec = reg_if2dec;

endmodule
