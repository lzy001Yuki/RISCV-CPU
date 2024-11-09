`include"util.v"
// we only contain the ins_cache part
module memory#(

)(
    input wire clk,
    input wire rdy_in,
    input wire rst_in,

    input wire io_buffer_full,
    input wire [7 : 0] mem_din,
    output wire mem_rw,
    output wire [`ADDR_WIDTH - 1 : 0] mem_aout,
    output wire [7 : 0] mem_dout,

    // from lsb
    input wire [`ADDR_WIDTH - 1 - 1 : 0] lsb2mem_store_addr,
    input wire [`VAL_WIDTH - 1 : 0] lsb2mem_store_val,
    input wire [`ADDR_WIDTH - 1 : 0] lsb2mem_load_addr,
    input wire [`LSB_WIDTH - 1 : 0] lsb2mem_load_id,
    input wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_store_type,
    input wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_load_type,
    input wire lsb2mem_load_en,
    input wire lsb2mem_store_en,
    output wire mem2lsb_load_en, // may need some cycles to complish
    output wire [`LSB_WIDTH - 1 : 0] mem2lsb_load_id,
    output wire [`VAL_WIDTH - 1 : 0] mem2lsb_load_val,

    // from icache
    input wire cache2mem_upd_en,
    input wire [`ADDR_WIDTH - 1 : 0] cache2mem_PC,
    output wire [`BLOCK_WIDTH - 1 : 0] mem2cache_blk,
    output wire [`INDEX_WIDTH - 1 : 0] mem2cache_idx,
    output wire [`TAG_WIDTH - 1 : 0] mem2cache_tag,
    output wire mem2cache_upd,

    // to ifetch
    output wire mem_rdy,
    output wire [`INST_WIDTH - 1 : 0] mem2if_inst_out

);

reg [`ADDR_WIDTH - 1 : 0] current_addr;
reg [`VAL_WIDTH - 1 : 0] current_res;
reg current_rw;
reg current_status;
reg 

function [`VAL_WIDTH - 1 : 0] load_result;
    input [`FUNCT3_WIDTH - 1 : 0] type;
    input [`VAL_WIDTH - 1 : 0] res;
    input [7 : 0] mem_din;
    case (type)
        3'b000: load_result = {24'b0, mem_din};
        3'b001: load_result = {16'b0, mem_din[7 : 0], res[7 : 0]};
        3'b010: load_result = {mem_din[7 : 0], res[23 : 0]};
        3'b100: load_result = {{24{mem_din[7]}}, mem_din};
        3'b101: load_result = {{16{mem_din[7]}}, mem_din[7 : 0], res[7 : 0]};
    endcase
endfunction

always @(posedge clk) begin
    if (rst_in) begin

    end
    else if (!rdy_in) begin
        // do nothing
    end
    else begin
        if (cache2mem_upd_en) begin

        end
        current_rw <= lsb2mem_load_en ? 1 : 0;

    end
end
endmodule