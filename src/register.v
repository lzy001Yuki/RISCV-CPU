`include "util.v"
module register(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire flush,

    //from rob
    input wire [`REG_WIDTH - 1 : 0] rob2rf_rd,
    input wire [`ID_WIDTH - 1 : 0] rob2rf_tag,
    input wire [`REG_WIDTH - 1 : 0] rob2rf_commit_rd,
    input wire [`VAL_WIDTH - 1 : 0] rob2rf_commit_res,
    input wire [`ID_WIDTH - 1 : 0] rob2rf_commit_lab,
    output wire [`VAL_WIDTH - 1 : 0] rf2rob_val1,
    output wire [`VAL_WIDTH - 1 : 0] rf2rob_val2,
    output wire [`ID_WIDTH - 1 : 0] rf2rob_lab1,
    output wire [`ID_WIDTH - 1 : 0] rf2rob_lab2,

    // from decoder
    input wire [`REG_WIDTH - 1 : 0] dec2rf_rs1,
    input wire [`REG_WIDTH - 1 : 0] dec2rf_rs2

);

reg [`VAL_WIDTH - 1 : 0] value [0 : `REG_SIZE - 1];
reg [`ID_WIDTH - 1 : 0] label [0 : `REG_SIZE - 1];

integer i;
always @(posedge clk) begin
    if (rst_in || (flush && rdy_in)) begin
        for (i = 0; i < `REG_SIZE; i++) begin
            value[i] <= 0;
            label[i] <= 0;
        end
    end
    else if (rdy_in) begin
        if (rob2rf_rd) begin
            label[rob2rf_rd] <= rob2rf_tag;
        end
        if (rob2rf_commit_rd) begin
            value[rob2rf_commit_rd] <= rob2rf_commit_res;
            if (label[rob2rf_commit_rd] == rob2rf_commit_lab) begin
                label[rob2rf_commit_rd] <= 0;
            end
        end
    end
end

assign rf2rob_val1 = value[dec2rf_rs1];
assign rf2rob_val2 = value[dec2rf_rs2];
assign rf2rob_lab1 = label[dec2rf_rs1];
assign rf2rob_lab2 = label[dec2rf_rs2];

endmodule