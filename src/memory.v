`include"util.v"
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
    output wire mem2lsb_store_en,
    output wire mem2lsb_load_en
);
endmodule