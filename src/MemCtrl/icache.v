`include"../util.v"
module icache(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    // from ifetch
    input wire inst_en,
    input wire [`ADDR_WIDTH - 1 : 0] next_PC,

    // from memory
    input wire update,
    input wire [`INST_WIDTH - 1 : 0] mem2cache_inst,
    input wire [`INDEX_WIDTH - 1 : 0] mem2cache_idx,
    input wire [`TAG_WIDTH - 1 : 0] mem2cache_tag,
    output wire [`ADDR_WIDTH - 1 : 0] cache2mem_PC,
    output wire upd_cache2mem_en,


    // to ifetch
    output wire cache_rdy, // if miss, false
    output wire [`INST_WIDTH - 1 : 0] next_inst_out
);

reg valid[`ICACHE_SIZE - 1 : 0];
reg [`TAG_WIDTH - 1 : 0] tag [`ICACHE_SIZE - 1 : 0];
reg [`INST_WIDTH - 1 : 0] instData[`ICACHE_SIZE - 1 : 0];

wire [`TAG_WIDTH - 1 : 0] inst_tag = next_PC[31 : 8];
wire [`INDEX_WIDTH - 1 : 0] inst_index = next_PC[7 : 4];

wire hit = valid[inst_index] && (tag[inst_index] == inst_tag);
wire [`INST_WIDTH - 1 : 0] cur_inst = instData[inst_index];

assign cache2mem_PC = next_PC;
assign cache_rdy = hit;
assign upd_cache2mem_en = !hit;
assign next_inst_out = cur_inst;

integer i;
always @(posedge clk) begin
    if (rst_in) begin
        for (i = 0; i < `ICACHE_SIZE; i = i + 1) begin
            valid[i] <= 0;
            tag[i] <= 0;
            instData[i] <= 0;
        end
    end
    else if (update) begin
        valid[mem2cache_idx] <= 1;
        tag[mem2cache_idx] <= mem2cache_tag;
        instData[mem2cache_idx] <= mem2cache_inst;
    end
end
endmodule