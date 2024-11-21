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

    // from icache
    input wire cache2mem_upd_en,
    input wire [`ADDR_WIDTH - 1 : 0] cache2mem_PC,
    output wire [`INST_WIDTH - 1 : 0] mem2cache_inst,
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
reg [1 : 0] mem_work_type; 
// 00 for none, 01 for lsb_working, 10 for ifetch_working, no changes until finished

assign mem_aout = current_status ? current_addr : (mem_work_type == 2'b01) ? lsb2mem_addr : cache2mem_PC;
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

always @(posedge clk) begin
    mem_work_type <= mem_work_type ? mem_work_type : (lsb2mem_en) ? 2'b01 : (cache2mem_upd_en) ? 2'b10 : 2'b00;
    if (rst_in) begin
        ready <= 1;
        current_addr <= 0;
        current_res <= 0;
        current_status <= 0;
        current_data <= 0;
        current_rw <= 0;
        reg_inst_out <= 0;
        reg_addr <= 0;
        cache_finish <= 1;
        mem_work_type <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else if (mem_work_type == 2'b01) begin
        reg_lsb2mem_load_id <= !lsb2mem_store_load ? lsb2mem_load_id : 0;
        if (ready) begin
            ready <= 0;
        end
        if (cache_finish) begin
            cache_finish <= 0;
        end
        //else begin
            case (current_status) 
                2'b00: begin
                    reg_addr <= lsb2mem_addr;
                    current_rw <= lsb2mem_store_load;
                    if (lsb2mem_type[1 : 0]) begin
                        current_addr <= reg_addr + 1;
                        current_status <= 2'b01;
                        current_data <= lsb2mem_val[15 : 8];
                    end                        
                    else begin
                        current_addr <= (reg_addr[17 : 16] == 2'b11) ? 0 : reg_addr;
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
        //end
        if (ready) begin
            mem_work_type <= 2'b00;
        end
    end
    else if (mem_work_type == 2'b10) begin
        if (cache_finish) begin
            cache_finish <= 0;
        end
        if (ready) begin
            ready <= 0;
        end
        case (current_status) 
            2'b00: begin
                reg_addr <= cache2mem_PC;
                current_rw <= 0;
                current_addr <= reg_addr + 1;
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
                mem_work_type <= 2'b00;
                cache_finish <= 1;
            end
        endcase
    end

    // to do : continue instruction fetch when no operation in process
    // else if (mem_work_type == 2'b00)
    
end

assign mem_busy = (!mem_work_type) ? 0 : 1;
assign mem2lsb_load_en = ready && !lsb2mem_store_load;
assign mem2lsb_load_id = reg_lsb2mem_load_id;
assign mem2lsb_load_val = lsb2mem_store_load ? load_result(lsb2mem_type, current_res, mem_din) : 0;
assign mem2lsb_upd = cache_finish;
assign mem_rdy = cache_finish;
assign mem2if_inst_out = (mem_work_type == 2'b10) ? load_result(3'b010, current_res, mem_din) : 0;
assign mem2cache_idx = cache_finish ? reg_addr[5 : 1] : 0;
assign mem2cache_tag = cache_finish ? reg_addr[31 : 6] : 0;
assign mem2cache_PC = cache_finish ? reg_addr : 0;

endmodule