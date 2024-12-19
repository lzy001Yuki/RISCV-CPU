`include"util.v"
module predictor # (
    parameter BHT_WIDTH = 4,
    parameter PHT_WIDTH = 6,
    parameter PHT_SIZE = 64,
    parameter BHT_SIZE = 16
)    (
    input wire clk,
    input wire rdy_in,
    input wire rst_in,
    input wire[`ADDR_WIDTH - 1 : 0] if2pre_PC,
    input wire[`ADDR_WIDTH - 1 : 0] rob2pre_nextPC,
    input wire if2pred_en,
    input wire rob2pred_en,
    input wire pred_res,
    output wire prediction // 0/1
);

reg [1 : 0] PHTable [PHT_SIZE - 1 : 0][BHT_SIZE - 1 : 0];
reg [BHT_WIDTH - 1 : 0] BHTable [PHT_SIZE - 1 : 0];
wire [PHT_WIDTH - 1 : 0] hash_index_if;
wire [PHT_WIDTH - 1 : 0] hash_index_rob;
assign hash_index_if = if2pre_PC[PHT_WIDTH - 1 : 0];
assign hash_index_rob = rob2pre_nextPC[PHT_WIDTH - 1 : 0];
assign prediction = (if2pred_en) ? PHTable[hash_index_if][BHTable[hash_index_if]][1] : 1'b0;
integer i, j;
always @(posedge clk) begin
    if (rst_in) begin
        for (i = 0; i < PHT_SIZE; i=i+1) begin
            BHTable[i] = 0;
            for (j = 0; j < BHT_SIZE; j=j+1) begin
                PHTable[i][j] = 2'b00;
            end
        end
    end
    else if (rdy_in && rob2pred_en) begin
        BHTable[hash_index_rob] <= {BHTable[hash_index_rob][BHT_WIDTH - 1 : 1], pred_res};
        if (pred_res) begin
            if (PHTable[hash_index_rob][BHTable[hash_index_rob]] == 2'b10) begin
                PHTable[hash_index_rob][BHTable[hash_index_rob]] <= PHTable[hash_index_rob][BHTable[hash_index_rob]] + 1;
            end
            else if (PHTable[hash_index_rob][BHTable[hash_index_rob]] == 2'b01) begin
                PHTable[hash_index_rob][BHTable[hash_index_rob]] <= PHTable[hash_index_rob][BHTable[hash_index_rob]] - 1;
            end
        end
        else begin
            if (PHTable[hash_index_rob][BHTable[hash_index_rob]] >= 2'b10) begin
                PHTable[hash_index_rob][BHTable[hash_index_rob]] <= PHTable[hash_index_rob][BHTable[hash_index_rob]] - 1;
            end
            else if (PHTable[hash_index_rob][BHTable[hash_index_rob]] <= 2'b01) begin
                PHTable[hash_index_rob][BHTable[hash_index_rob]] <= PHTable[hash_index_rob][BHTable[hash_index_rob]] + 1;
            end
        end
    end
end    

endmodule