`include "util.v"
module register(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire flush,


    //from rob
    input wire commit_en,
    input wire [`REG_WIDTH - 1 : 0] dec2rf_rd,
    input wire dec2rob_en, // can issue
    input wire [`ROB_ID_WIDTH: 0] rob2rf_tag,
    input wire [`REG_WIDTH - 1 : 0] rob2rf_commit_rd,
    input wire [`VAL_WIDTH - 1 : 0] rob2rf_commit_res,
    input wire [`ROB_ID_WIDTH: 0] rob2rf_commit_lab,
    output wire [`VAL_WIDTH - 1 : 0] rf2rob_val1,
    output wire [`VAL_WIDTH - 1 : 0] rf2rob_val2,
    output wire [`ROB_ID_WIDTH: 0] rf2rob_lab1,
    output wire [`ROB_ID_WIDTH: 0] rf2rob_lab2,

    // from decoder
    input wire [`REG_WIDTH - 1 : 0] dec2rf_rs1,
    input wire [`REG_WIDTH - 1 : 0] dec2rf_rs2

);

reg [`VAL_WIDTH - 1 : 0] value [0 : `REG_SIZE - 1];
reg [`ROB_ID_WIDTH: 0] label [0 : `REG_SIZE - 1];
reg [31 : 0] counter;
initial begin
    counter = 0;
end

always @(commit_en) begin
    if (rob2rf_commit_rd) begin
        value[rob2rf_commit_rd] <= rob2rf_commit_res;
        if (label[rob2rf_commit_rd] == rob2rf_commit_lab) begin
            label[rob2rf_commit_rd] <= 0;
            if (dec2rf_rd == 1) begin
                //$display("ra change: --- %d, counter=%d", rob2rf_commit_res, counter);
            end  
        end
    end
end


integer i;
always @(posedge clk) begin
    counter <= counter + 1;
        if (counter >= `START && counter <= `END_ && `RF_DEBUG) begin
            $display("register---------------%d", counter);
            //for (i = 0; i < `REG_SIZE; i++) begin
            $display("counter=%d, label=%d, val=%d", counter, label[13], value[13]);
            $display("counter=%d, label=%d, val=%h", counter, label[25], value[25]);
            //end
         end
    if (rst_in || (flush && rdy_in)) begin
        for (i = 0; i < `REG_SIZE; i++) begin
            label[i] <= 0;
            if (rst_in) begin
                value[i] <= 0;
            end
        end
    end
    else if (dec2rob_en && dec2rf_rd) begin  
        label[dec2rf_rd] <= rob2rf_tag;
    end
end

assign rf2rob_val1 = value[dec2rf_rs1];
assign rf2rob_val2 = value[dec2rf_rs2];
assign rf2rob_lab1 = label[dec2rf_rs1];
assign rf2rob_lab2 = label[dec2rf_rs2];

endmodule