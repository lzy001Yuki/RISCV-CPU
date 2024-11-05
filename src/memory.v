`include"util.v"
// we only contain the ins_cache part
module memory(
    input wire clk,
    input wire rdy_in,
    input wire rst_in,

    // from lsb
    output wire [`LSB_WIDTH - 1 : 0] mem2lsb_load_id,
    output wire [`VAL_WIDTH - 1 : 0] mem2lsb_load_val,
    input wire [`ADDR_WIDTH - 1 - 1 : 0] lsb2mem_store_addr,
    input wire [`VAL_WIDTH - 1 : 0] lsb2mem_store_val,
    input wire [`ADDR_WIDTH - 1 : 0] lsb2mem_load_addr,
    input wire [`LSB_WIDTH - 1 : 0] lsb2mem_load_id,
    output wire mem2lsb_store_en,
    output wire mem2lsb_load_en,

    // from icache
    input wire cache2mem_upd_en,
    input wire [`ADDR_WIDTH - 1 : 0] cache2mem_PC,
    output wire [`BLOCK_WIDTH - 1 : 0] mem2cache_blk,
    output wire [`INDEX_WIDTH - 1 : 0] mem2cache_idx,
    output wire [`TAG_WIDTH - 1 : 0] mem2cache_tag,
    output wire mem2cache_upd,

    // to ifetch
    output wire mem_rdy

);
assign mem_rdy = cache2mem_upd_en;
always @(posedge clk) begin
    if (rst_in) begin

    end
    else if (!rdy_in) begin
        // do nothing
    end
    else begin
        if (cache2mem_upd_en) begin
            
        end
    end
end
endmodule