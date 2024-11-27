`include "util.v"


module controller(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire io_buffer_full,

    input wire [7 : 0] mem_din,
    output wire mem_rw, // 1 for write
    output wire [`ADDR_WIDTH - 1 : 0] mem_aout,
    output wire [7 : 0] mem_dout,
    // from ifetch
    input wire if2ctrl_en,
    input wire [`ADDR_WIDTH - 1 : 0] next_PC,

    // from lsb
    input wire [`ADDR_WIDTH - 1 - 1 : 0] lsb2mem_addr,
    input wire [`VAL_WIDTH - 1 : 0] lsb2mem_val,
    input wire [`LSB_ID_WIDTH - 1 : 0] lsb2mem_load_id,
    input wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_type,
    input wire lsb2mem_en,
    input wire lsb2mem_store_load,
    output wire mem2lsb_load_en, // may need some cycles to complish
    output wire mem_busy, // rob & lsb 
    output wire [`LSB_ID_WIDTH - 1 : 0] mem2lsb_load_id,
    output wire [`VAL_WIDTH - 1 : 0] mem2lsb_load_val,

    output wire inst_rdy,
    output wire [`INST_WIDTH - 1 : 0] inst_out
);

wire cache2mem_upd_en;
wire [`ADDR_WIDTH - 1 : 0] cache2mem_PC;
wire [`INST_WIDTH - 1 : 0] mem2cache_inst;
wire [`INDEX_WIDTH - 1 : 0] mem2cache_idx;
wire [`TAG_WIDTH - 1 : 0] mem2cache_tag;
wire mem2cache_upd;
wire mem_rdy;
wire [`INST_WIDTH - 1 : 0] mem2if_inst_out;
wire cache_rdy;
wire [`INST_WIDTH - 1 : 0] cache2if_inst_out;
wire [`ADDR_WIDTH - 1 : 0] mem2cache_PC;
wire is_c_inst;
wire [`TAG_WIDTH - 1 : 0] sec_inst_tag;
wire [`ADDR_WIDTH - 1 : 0] sec_inst_addr;
wire [`INDEX_WIDTH - 1 : 0] sec_inst_index;


memory mem (
    .clk(clk),
    .rdy_in(rdy_in),
    .rst_in(rst_in),

    .io_buffer_full(io_buffer_full),
    .mem_din(mem_din),
    .mem_rw(mem_rw),
    .mem_aout(mem_aout),
    .mem_dout(mem_dout),

    .lsb2mem_addr(lsb2mem_addr),
    .lsb2mem_val(lsb2mem_val),
    .lsb2mem_load_id(lsb2mem_load_id),
    .lsb2mem_type(lsb2mem_type),
    .lsb2mem_en(lsb2mem_en),
    .lsb2mem_store_load(lsb2mem_store_load),
    .mem2lsb_load_en(mem2lsb_load_en),
    .mem_busy(mem_busy),
    .mem2lsb_load_id(mem2lsb_load_id),
    .mem2lsb_load_val(mem2lsb_load_val),
    .is_c_inst(is_c_inst),
    .sec_inst_tag(sec_inst_tag),
    .sec_inst_index(sec_inst_index),
    .sec_inst_addr(sec_inst_addr),

    .cache2mem_upd_en(cache2mem_upd_en),
    .cache2mem_PC(cache2mem_PC),
    .mem2cache_idx(mem2cache_idx),
    .mem2cache_tag(mem2cache_tag),
    .mem2cache_upd(mem2cache_upd),
    .mem2cache_PC(mem2cache_PC),

    .mem_rdy(mem_rdy),
    .mem2if_inst_out(mem2if_inst_out)
);

icache ins_cache(
    .clk(clk),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .inst_en(if2ctrl_en),
    .next_PC(next_PC),

    .update(mem2cache_upd),
    .mem2cache_inst(mem2if_inst_out),
    .mem2cache_idx(mem2cache_idx),
    .mem2cache_tag(mem2cache_tag),
    .mem2cache_PC(mem2cache_PC),
    .cache2mem_PC(cache2mem_PC),
    .upd_cache2mem_en(cache2mem_upd_en),
    .is_c_inst(is_c_inst),
    .sec_inst_tag(sec_inst_tag),
    .sec_inst_index(sec_inst_index),
    .sec_inst_addr(sec_inst_addr),


    .cache_rdy(cache_rdy),
    .next_inst_out(cache2if_inst_out)
);

assign inst_rdy = (cache_rdy || mem_rdy) && if2ctrl_en;
assign inst_out = cache_rdy ? cache2if_inst_out : mem2if_inst_out;

endmodule