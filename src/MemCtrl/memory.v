`include"util.v"
// we only contain the ins_cache part
module memory(
    input wire clk,
    input wire rdy_in,
    input wire rst_in,

    input wire io_buffer_full,
    input wire [7 : 0] mem_din,
    output wire mem_rw, // 1 for write
    output wire [`ADDR_WIDTH - 1 : 0] mem_aout,
    output wire [7 : 0] mem_dout,

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
    output wire is_c_inst,
    output wire [`TAG_WIDTH - 1 : 0] sec_inst_tag,
    output wire [`ADDR_WIDTH - 1 : 0] sec_inst_addr,
    output wire [`INDEX_WIDTH - 1 : 0] sec_inst_index,

    // from icache
    input wire cache2mem_upd_en,
    input wire [`ADDR_WIDTH - 1 : 0] cache2mem_PC,
    output wire [`INDEX_WIDTH - 1 : 0] mem2cache_idx,
    output wire [`TAG_WIDTH - 1 : 0] mem2cache_tag,
    output wire mem2cache_upd,
    output wire [`ADDR_WIDTH - 1 : 0] mem2cache_PC,

    // to ifetch
    output wire mem_rdy,
    output wire [`INST_WIDTH - 1 : 0] mem2if_inst_out
);

reg [`ADDR_WIDTH - 1 : 0] current_addr;
reg [`ADDR_WIDTH - 1 : 0] reg_addr;
reg [`VAL_WIDTH - 1 : 0] current_res;
reg current_rw;
reg [1 : 0] current_status;
reg [7 : 0] current_data;
reg ready;
reg [`LSB_ID_WIDTH - 1 : 0] reg_lsb2mem_load_id;

reg [`INST_WIDTH - 1 : 0] reg_inst_out;
reg cache_finish;
reg reg_mem_busy;
// 00 for none, 01 for lsb_working, 10 for ifetch_working, no changes until finished

assign mem_aout = current_status ? current_addr : (lsb2mem_en) ? lsb2mem_addr : cache2mem_PC;
assign mem_dout = (!current_status && lsb2mem_store_load) ? lsb2mem_val[7 : 0]: current_data;


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

// bugs caused because of initialization....

always @(posedge clk) begin
    if (rst_in) begin
        ready <= 1;
        current_addr <= 0;
        current_res <= 0;
        current_status <= 0;
        current_data <= 0;
        current_rw <= 0;
        reg_inst_out <= 0;
        reg_addr <= 0;
        cache_finish <= 0;
        reg_mem_busy <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else if (lsb2mem_en) begin
        reg_lsb2mem_load_id <= !lsb2mem_store_load ? lsb2mem_load_id : 0;
        if (ready) begin
            ready <= 0;
        end
        else begin
            case (current_status) 
                2'b00: begin
                    reg_addr <= lsb2mem_addr;
                    current_rw <= lsb2mem_store_load;
                    if (lsb2mem_type[1 : 0]) begin
                        current_addr <= lsb2mem_addr + 1;
                        current_status <= 2'b01;
                        current_data <= lsb2mem_val[15 : 8];
                    end                        
                    else begin
                        current_addr <= (lsb2mem_addr[17 : 16] == 2'b11) ? 0 : reg_addr;
                        current_status <= 2'b00;
                        current_data <= 0;
                        current_rw <= 0;
                        ready <= 1;
                    end
                end
                2'b01: begin
                    current_res[7 : 0] <= mem_din;
                    if (lsb2mem_type[1 : 0] == 2'b01) begin
                        ready <= 1;
                        current_rw <= 0;
                        current_data <= 0;
                        current_status <= 2'b00;
                        current_addr <= 0;
                    end
                    else begin
                        current_status <= 2'b10;
                        current_data <= lsb2mem_val[23 : 16];
                        current_addr <= reg_addr + 2;
                    end
                end
                2'b10: begin
                    current_res[15 : 8] <= mem_din;
                    current_addr <= reg_addr + 3;
                    current_data <= lsb2mem_val[31 : 24];
                    current_status <= 2'b11;
                end
                2'b11: begin
                    current_res[23 : 16] <= mem_din;
                    ready <= 1;
                    current_status <= 2'b00;
                    current_rw <= 0;
                    current_addr <= 0;
                    current_data <= 0;
                end
            endcase
        end
        reg_mem_busy <= ready ? 0 : 1;
    end
    else if (cache2mem_upd_en) begin
        if (cache_finish) begin
            cache_finish <= 0;
        end
        else begin
        case (current_status) 
            2'b00: begin
                reg_addr <= cache2mem_PC;
                current_rw <= 0;
                current_addr <= cache2mem_PC + 1;
                current_status <= 2'b01;  
            end               
            2'b01: begin
                current_res[7 : 0] <= mem_din;
                current_status <= 2'b10;
                current_addr <= reg_addr + 2;
            end
            2'b10: begin                    
                current_res[15 : 8] <= mem_din;
                current_addr <= reg_addr + 3;
                current_status <= 2'b11;
            end
            2'b11: begin
                current_res[23 : 16] <= mem_din;
                current_status <= 2'b00;
                current_rw <= 0;
                current_addr <= 0;
                cache_finish <= 1;
            end
        endcase
        end
        reg_mem_busy <= cache_finish ? 0 : 1;
    end

    // to do : continue instruction fetch when no operation in process
    // else if (mem_work_type == 2'b00)
end
assign is_c_inst = cache_finish ? mem2if_inst_out[1 : 0] == 2'b11 ? 0 : 1 : 0;

assign mem_busy = reg_mem_busy;
assign mem2lsb_load_en = ready && !lsb2mem_store_load;
assign mem2lsb_load_id = reg_lsb2mem_load_id;
assign mem2lsb_load_val = mem2lsb_load_en ? load_result(lsb2mem_type, current_res, mem_din) : 0;
assign mem2cache_upd = cache_finish;
assign mem_rdy = cache_finish;
assign mem2if_inst_out = (cache_finish) ? load_result(3'b010, current_res, mem_din) : 0;
assign mem2cache_idx = cache_finish ? reg_addr[4 : 1] : 0;
assign mem2cache_tag = cache_finish ? reg_addr[31 : 5] : 0;
assign mem2cache_PC = cache_finish ? reg_addr : 0;
assign sec_inst_addr = is_c_inst ? reg_addr + 2 : 0;
assign sec_inst_tag = sec_inst_addr[31 : 5];
assign sec_inst_index = sec_inst_addr[4 : 1];

endmodule