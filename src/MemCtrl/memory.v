`include"util.v"
// we only contain the ins_cache part
module memory(
    input wire clk,
    input wire rdy_in,
    input wire rst_in,

    input wire io_buffer_full,

    input wire flush,
    input wire [7 : 0] mem_din,
    output wire mem_rw, // 1 for write
    output wire [`ADDR_WIDTH - 1 : 0] mem_aout,
    output wire [7 : 0] mem_dout,
    input wire [31 : 0] commit_cnt,

    // from lsb
    input wire [`ADDR_WIDTH - 1 : 0] lsb2mem_addr,
    input wire [`VAL_WIDTH - 1 : 0] lsb2mem_val,
    input wire [`LSB_ID_WIDTH - 1 : 0] lsb2mem_load_id,
    input wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_type,
    input wire lsb2mem_en,
    input wire lsb2mem_store_en,
    input wire lsb2mem_load_en,
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
reg store_or_load;
reg [`VAL_WIDTH - 1 : 0] reg_lsb2mem_val;
reg [`FUNCT3_WIDTH - 1 : 0] reg_lsb2mem_type;

reg [`INST_WIDTH - 1 : 0] reg_inst_out;
reg cache_finish;
reg reg_lsb2mem_en;
initial begin
    reg_lsb2mem_en = 0;
    io_ready = 1;
end
// 00 for none, 01 for lsb_working, 10 for ifetch_working, no changes until finished
wire is_io_op;
assign is_io_op = (lsb2mem_addr >= 32'd196608);
wire io_fail;
assign io_fail = is_io_op && io_buffer_full;
assign mem_aout = (lsb2mem_en && !io_fail) ? lsb2mem_addr : (current_status || (!io_ready && !io_buffer_full)) ? current_addr : cache2mem_PC;
assign mem_dout = (lsb2mem_store_en && !io_fail) ? lsb2mem_val[7 : 0] : current_data;
assign mem_rw = (lsb2mem_en && !io_fail) ? lsb2mem_store_en : (current_status || !io_ready && !io_buffer_full) ? current_rw : 0;
reg io_ready;


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
reg [31 : 0] counter;

initial begin
    counter = 0;
    current_rw = 0;
end

always @(posedge clk) begin
    counter <= counter + 1;
    if (lsb2mem_en && lsb2mem_store_en && lsb2mem_addr == 32'h30000 && `MEM_DEBUG) begin
        $display("counter=%d, addr=%h, value=%d, commit_cnt=%d", counter, lsb2mem_addr, lsb2mem_val, commit_cnt);  
    end    
    if (rst_in || flush) begin
        ready <= 0;
        cache_finish <= 0;
        if (!current_rw) begin
            current_addr <= 0;
            current_res <= 0;
            current_status <= 0;
            current_data <= 0;
            current_rw <= 0;
            reg_inst_out <= 0;
            reg_addr <= 0;
            reg_lsb2mem_en <= 0;
        end
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else if (lsb2mem_en || reg_lsb2mem_en) begin
        if (ready || cache_finish) begin
            ready <= 0;
            cache_finish <= 0;
            reg_lsb2mem_val <= 0;
        end
        //reg_lsb2mem_load_id <= lsb2mem_load_en ? lsb2mem_load_id : 0;
        if (lsb2mem_en) begin
            reg_lsb2mem_en <= 1;
            current_status <= 2'b00;
            reg_addr <= lsb2mem_addr;
            current_rw <= lsb2mem_store_en;
            store_or_load <= lsb2mem_store_en;
            reg_lsb2mem_val <= lsb2mem_val;
            reg_lsb2mem_type <= lsb2mem_type;
            reg_lsb2mem_load_id <= lsb2mem_load_id;
            if (lsb2mem_type[1 : 0]) begin
                current_addr <= lsb2mem_addr + 1;
                current_status <= 2'b01;
                current_data <= lsb2mem_val[15 : 8];
            end                        
            else begin
                current_addr <= (lsb2mem_addr[17 : 16] == 2'b11) ? 0 : lsb2mem_addr;
                if (io_fail) begin
                    ready <= 0;
                    current_addr <= lsb2mem_addr;
                    current_data <= lsb2mem_val[7 : 0];
                    current_rw <= lsb2mem_store_en;
                    reg_lsb2mem_en <= 1;
                    io_ready <= 0;
                    current_status <= 2'b00;
                end
                else begin
                    current_status <= 2'b00;
                    current_data <= 0;
                    current_rw <= 0;
                    reg_lsb2mem_en <= 0;
                    ready <= 1;
                end
            end
        end
        else begin
            case (current_status) 
                2'b00: begin
                    // if (reg_lsb2mem_type[1 : 0]) begin
                    //     reg_addr <= lsb2mem_addr;
                    //     current_rw <= lsb2mem_store_en;
                    //     store_or_load <= lsb2mem_store_en;
                    //     current_addr <= lsb2mem_addr + 1;
                    //     current_status <= 2'b01;
                    //     current_data <= reg_lsb2mem_val[15 : 8];
                    // end                        
                    // else begin
                        //current_addr <= (lsb2mem_addr[17 : 16] == 2'b11) ? 0 : reg_addr;
                        //reg_addr <= lsb2mem_addr;
                        //current_rw <= lsb2mem_store_en;
                        //store_or_load <= lsb2mem_store_en;
                        if (!io_buffer_full) begin
                            current_status <= 2'b00;
                            current_data <= 0;
                            current_addr <= 0;
                            current_rw <= 0;
                            ready <= 1;
                            io_ready <= 1;
                            reg_lsb2mem_en <= 0;
                        end
                    // end
                end
                2'b01: begin
                    current_res[7 : 0] <= mem_din;
                    if (reg_lsb2mem_type[1 : 0] == 2'b01) begin
                        ready <= 1;
                        current_rw <= 0;
                        current_data <= 0;
                        current_status <= 2'b00;
                        reg_lsb2mem_en <= 0;
                        current_addr <= 0;
                    end
                    else begin
                        current_status <= 2'b10;
                        current_data <= reg_lsb2mem_val[23 : 16];
                        current_addr <= reg_addr + 2;
                    end
                end
                2'b10: begin
                    current_res[15 : 8] <= mem_din;
                    current_addr <= reg_addr + 3;
                    current_data <= reg_lsb2mem_val[31 : 24];
                    current_status <= 2'b11;
                end
                2'b11: begin
                    current_res[23 : 16] <= mem_din;
                    ready <= 1;
                    current_status <= 2'b00;
                    reg_lsb2mem_en <= 0;
                    current_rw <= 0;
                    current_addr <= 0;
                    current_data <= 0;
                end
            endcase
        end
    end
    else if (cache2mem_upd_en) begin
        if (cache_finish || ready) begin
            cache_finish <= 0;
            ready <= 0;
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
    end
    else if (cache_finish || ready) begin
            cache_finish <= 0;
            ready <= 0;
    end

    // to do : continue instruction fetch when no operation in process
    // else if (mem_work_type == 2'b00)
end
assign is_c_inst = cache_finish ? mem2if_inst_out[1 : 0] == 2'b11 ? 0 : 1 : 0;

assign mem_busy = lsb2mem_en || reg_lsb2mem_en;
assign mem2lsb_load_en = ready && !store_or_load;
assign mem2lsb_load_id = reg_lsb2mem_load_id;
assign mem2lsb_load_val = mem2lsb_load_en ? load_result(reg_lsb2mem_type, current_res, mem_din) : 0;
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