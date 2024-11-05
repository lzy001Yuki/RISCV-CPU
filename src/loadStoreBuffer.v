`include"util.v"
module loadStoreBuffer(
    input wire clk,
    input wire rdy_in,
    input wire rst_in,

    input wire flush,

    // from decoder
    input wire [`OP_WIDTH - 1 : 0] type,
    input wire [`VAL_WIDTH - 1 : 0] imm,
    input wire dec2lsb_en,
    output wire lsbFull,

    // from rob
    input wire [`ID_WIDTH - 1 : 0] newTag,
    input wire [`ID_WIDTH - 1 : 0] label1,
    input wire [`ID_WIDTH - 1 : 0] label2,
    input wire [`VAL_WIDTH - 1 : 0] res1, //from rob or regFile
    input wire [`VAL_WIDTH - 1 : 0] res2,
    input wire ready1,
    input wire ready2,

    // from cdb
    input wire cdbReady,
    input wire [`ID_WIDTH - 1 : 0] cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] cdb2val,

    // to alu
    output wire execute,
    input wire aluReady,
    input wire[`ID_WIDTH - 1 : 0] entry_in, 
    input wire[`VAL_WIDTH - 1 : 0] val_in,
    // to cdb
    output wire[`VAL_WIDTH - 1 : 0] val2cdb,
    output wire[`ID_WIDTH - 1 : 0] lab2cdb,

    // from memory
    input wire [`LSB_WIDTH - 1 : 0] mem2lsb_load_id,
    input wire [`VAL_WIDTH - 1 : 0] mem2lsb_load_val,
    output wire [`ADDR_WIDTH - 1 - 1 : 0] lsb2mem_store_addr,
    output wire [`VAL_WIDTH - 1 : 0] lsb2mem_store_val,
    output wire [`ADDR_WIDTH - 1 : 0] lsb2mem_load_addr,
    output wire [`LSB_WIDTH - 1 : 0] lsb2mem_load_id,
    input wire mem2lsb_store_en,
    input wire mem2lsb_load_en

);

reg [`VAL_WIDTH - 1 : 0] count;
reg [`LSB_WIDTH - 1 : 0] loadIndex;
reg [`LSB_WIDTH - 1 : 0] storeIndex;
reg nodeType [`LSB_SIZE - 1 : 0]; // 0 for load, 1 for store12
reg [`OP_WIDTH - 1 : 0] orderType;
reg busy [0 : `RS_SIZE - 1];
reg [`ID_WIDTH - 1 : 0] entry [0 : `RS_SIZE - 1]; // index in rob
reg [`VAL_WIDTH - 1 : 0] V1 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] V2 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] Q1 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] Q2 [0 : `RS_SIZE - 1];

always @(*) begin

end


always @(posedge clk) begin
    if (rst_in || (flush && rdy_in)) begin
        count <= 0;
    end
end 

endmodule