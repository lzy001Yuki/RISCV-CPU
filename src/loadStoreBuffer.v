`include"util.v"
module loadStoreBuffer#(
    parameter STATUS_ISSUE = 2'b00,
    parameter STATUS_EXE = 2'b01,
    parameter STATUS_WRITE = 2'b10,
    parameter STATUS_COMMIT = 2'b11
)(
    input wire clk,
    input wire rdy_in,
    input wire rst_in,

    input wire flush,

    // from decoder
    input wire [`OP_WIDTH - 1 : 0] type,
    input wire [`VAL_WIDTH - 1 : 0] imm,
    input wire dec2lsb_en,
    output wire isFull,

    // from rob
    input wire [`ROB_ID_WIDTH : 0] newTag,
    input wire [`ROB_ID_WIDTH: 0] label1,
    input wire [`ROB_ID_WIDTH: 0] label2,
    input wire [`VAL_WIDTH - 1 : 0] res1, //from rob (val from rob / rf)
    input wire [`VAL_WIDTH - 1 : 0] res2,
    input wire ready1,
    input wire ready2,
    input wire rob2lsb_store_en,
    input wire [`ROB_ID_WIDTH: 0] store_index,
    input wire commit_en,
    input wire [`ROB_ID_WIDTH : 0] commit_lab,
    input wire [`VAL_WIDTH - 1 : 0] commit_val,

    // from cdb
    input wire rs_cdb_en,
    input wire cdb2lsb_en,
    input wire [`ROB_ID_WIDTH: 0] rs_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] rs_cdb2val,
    input wire [`ROB_ID_WIDTH: 0] lsb_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] lsb_cdb2val,
    // to cdb
    output wire[`VAL_WIDTH - 1 : 0] val2cdb,
    output wire[`ROB_ID_WIDTH: 0] lab2cdb,
    output wire lsb_cdb_en,

    // from memory
    input wire [`LSB_ID_WIDTH - 1 : 0] mem2lsb_load_id,
    input wire [`VAL_WIDTH - 1 : 0] mem2lsb_load_val,
    input wire mem_busy,
    input wire mem2lsb_load_en,
    output wire [`ADDR_WIDTH - 1 : 0] lsb2mem_addr,
    output wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_type, 
    output wire [`VAL_WIDTH - 1 : 0] lsb2mem_val,
    output wire lsb2mem_store_en,
    output wire lsb2mem_load_en,
    output wire [`LSB_ID_WIDTH - 1 : 0] lsb2mem_load_id


);

// FIFO in lsb to apply to the time requirement
// load & store in order

reg [`LSB_ID_WIDTH : 0] load_write_id;
reg [`LSB_ID_WIDTH : 0] store_write_id;
reg [`LSB_ID_WIDTH - 1 : 0] head;
reg [`LSB_ID_WIDTH - 1 : 0] tail;
reg nodeType [`LSB_SIZE - 1 : 0]; // 0 for load, 1 for store12
reg [`OP_WIDTH - 1 : 0] orderType [0 : `LSB_SIZE - 1];
reg busy [0 : `LSB_SIZE - 1];
reg [`ROB_ID_WIDTH: 0] entry [0 : `LSB_SIZE - 1]; // index in rob
reg [`VAL_WIDTH - 1 : 0] V1 [0 : `LSB_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] V2 [0 : `LSB_SIZE - 1];
reg [`ROB_ID_WIDTH: 0] Q1 [0 : `LSB_SIZE - 1];
reg [`ROB_ID_WIDTH: 0] Q2 [0 : `LSB_SIZE - 1];
reg [`ADDR_WIDTH - 1 : 0] addr [0 : `LSB_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] res [0 : `LSB_SIZE - 1];
reg [1 : 0] status [0 : `LSB_SIZE - 1];
reg [`OP_WIDTH - 1 : 0] reg_commit_type;
reg [`ADDR_WIDTH - 1 : 0] reg_commit_addr;
reg [`VAL_WIDTH - 1 : 0 ] reg_commit_val;

assign isFull = (head == tail);

reg reg_lsb2mem_store_en;
reg reg_lsb2mem_load_en;
reg [`LSB_ID_WIDTH - 1 : 0] reg_commit_id;
reg [`ROB_ID_WIDTH: 0] reg_lab2cdb;
reg [`VAL_WIDTH - 1 : 0] reg_val2cdb;
reg [`LSB_ID_WIDTH - 1 : 0] reg_mem2lsb_load_id;
reg [31 : 0] counter;
reg reg_lsb2cdb_en;
reg busy_head;
reg [`VAL_WIDTH - 1 : 0] V1_head;
reg [`VAL_WIDTH - 1 : 0] V2_head;
reg [1 : 0] status_head;
reg busy_tail;
initial begin
    counter = 0;
    reg_lsb2mem_store_en = 0;
    reg_lsb2mem_load_en = 0;
    V1_head = 0;
    V2_head = 0;
    busy_head = 0;
    status_head = 0;
    busy_tail = 0;
end
integer i;
integer flag;
always @(posedge clk) begin
    counter <= counter + 1;
         if (counter >= `START && counter <= `END_ && `LSB_DEBUG) begin
         $display("time -----------------> %d     lsb", counter);
             $display("head=%d, tail=%d", head, tail);
     for (i = 0; i < `LSB_SIZE; i++) begin
                $display("entry=%d, V1=%d, V2=%d, busy=%d, status=%d, Q1=%d, Q2=%d", entry[i], V1[i], V2[i], busy[i], status[i], Q1[i], Q2[i]);
         end
         end
    if (rst_in || (flush && rdy_in)) begin
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            busy[i] <= 0;
            entry[i] <= 0;
            V1[i] <= 0;
            V2[i] <= 0;
            Q1[i] <= 0;
            Q2[i] <= 0;
            nodeType[i] <= 0;
            orderType[i] <= 0;
            head <= 0;
            tail <= 1;
            status[i] <= 0;
            load_write_id <= 4'b1000;
            store_write_id <= 4'b1000;
            reg_lsb2mem_store_en <= 0;
            reg_lsb2mem_load_en <= 0;
            reg_lsb2cdb_en <= 0;
            reg_lab2cdb <= 0;
            reg_val2cdb <= 0;
        end
    end
    else if (rdy_in) begin
        // issue
        busy_head <= busy[(head == `LSB_SIZE - 1) ? 0 : head + 1];
        busy_tail <= busy[tail];
        V1_head <= V1[(head == `LSB_SIZE - 1) ? 0 : head + 1];
        V2_head <= V2[(head == `LSB_SIZE - 1) ? 0 : head + 1];
        status_head <= status[(head == `LSB_SIZE - 1) ? 0 : head + 1];
        if (dec2lsb_en) begin
            tail <= tail + 1;
            entry[tail] <= newTag;
            busy[tail] <= 1;
            orderType[tail] <= type;
            status[tail] <= STATUS_ISSUE;
            if (type[6 : 4] == `OP_L_TYPE) begin
                nodeType[tail] <= 0;
                if (label1) begin
                    if (ready1) begin
                        V1[tail] <= res1;
                    end
                    else begin
                        Q1[tail] <= label1;
                    end
                end
                else begin
                    V1[tail] <= res1;
                end
                V2[tail] <= imm;
                Q2[tail] <= 0;
            end
            else begin
                nodeType[tail] <= 1;
                V1[tail] <= imm;
                Q1[tail] <= 0;
                if (label1) begin
                    if (ready1) begin
                        V1[tail] <= imm + res1;
                    end
                    else begin
                        Q1[tail] <= label1;
                    end
                end
                else begin
                    V1[tail] <= imm + res1;
                end
                if (label2) begin
                    if (ready2) begin
                        V2[tail] <= res2;
                    end
                    else begin
                        Q2[tail] <= label2;
                    end
                end
                else begin
                    V2[tail] <= res2;
                end
            end
        end

        // Execute
        flag = 0;
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            if (busy[i] && !Q1[i] && !Q2[i] && status[i] == STATUS_ISSUE) begin 
                if (nodeType[i]) begin
                    addr[i] <= V1[i];
                    res[i] <= V2[i];                   
                end
                else begin
                    addr[i] <= V1[i] + V2[i];
                end
                status[i] <= STATUS_EXE;
            end
        end
        // load or store
        // pop the first node and FIFO ensures that load&store are in time order
        if (reg_lsb2cdb_en) begin
            reg_lsb2cdb_en <= 0;
        end
        reg_lsb2mem_load_en <= 0;
        if (!mem_busy && !rob2lsb_store_en && busy[(head == `LSB_SIZE - 1) ? 0 : head + 1]) begin
            reg_commit_id <= head + 1;
            if (!nodeType[(head == `LSB_SIZE - 1) ? 0 : head + 1] && status[(head == `LSB_SIZE - 1) ? 0 : head + 1] == STATUS_EXE) begin
                reg_lsb2mem_load_en <= 1;
                reg_commit_addr <= addr[(head == `LSB_SIZE - 1) ? 0 : head + 1];
                reg_commit_type <= orderType[(head == `LSB_SIZE - 1) ? 0 : head + 1];
                head <= head + 1;
                busy[(head == `LSB_SIZE - 1) ? 0 : head + 1] <= 0;
            end
        end
        if (rob2lsb_store_en) begin
            // store
            head <= head + 1;
            busy[(head == `LSB_SIZE - 1) ? 0 : head + 1] <= 0;
        end
        

        // write
        reg_lsb2cdb_en <= 0;
        reg_lab2cdb <= 0;
        reg_val2cdb <= 0;
        if (mem2lsb_load_en) begin
            reg_mem2lsb_load_id <= mem2lsb_load_id;
            res[mem2lsb_load_id] <= mem2lsb_load_val;
            status[mem2lsb_load_id] <= STATUS_WRITE;
            reg_lab2cdb <= entry[mem2lsb_load_id];
            reg_val2cdb <= mem2lsb_load_val;
            reg_lsb2cdb_en <= 1;
        end
        else if (nodeType[(head == `LSB_SIZE - 1) ? 0 : head + 1] && status[(head == `LSB_SIZE - 1) ? 0 : head + 1] == STATUS_EXE) begin
            reg_lsb2cdb_en <= 1;
            reg_lab2cdb <= entry[(head == `LSB_SIZE - 1) ? 0 : head + 1];
            reg_val2cdb <= res[(head == `LSB_SIZE - 1) ? 0 : head + 1];
            status[(head == `LSB_SIZE - 1) ? 0 : head + 1] <= STATUS_WRITE;
        end
        


        // fetch data
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            if (busy[i]) begin
                if (rs_cdb_en) begin
                if (rs_cdb2lab == Q1[i]) begin
                    V1[i] = nodeType[i] ? rs_cdb2val + V1[i] : rs_cdb2val;
                    Q1[i] = 0;
                end
                else if (rs_cdb2lab == Q2[i]) begin
                    V2[i] = rs_cdb2val;
                    Q2[i] = 0;
                end
                end
                if (cdb2lsb_en) begin
                if (lsb_cdb2lab == Q1[i]) begin
                    V1[i] = nodeType[i] ? lsb_cdb2val + V1[i] : lsb_cdb2val;
                    Q1[i] = 0;
                end
                else if (lsb_cdb2lab == Q2[i]) begin
                    V2[i] = lsb_cdb2val;
                    Q2[i] = 0;
                end
                end
                if (commit_en) begin
                if (commit_lab == Q1[i]) begin
                    V1[i] = nodeType[i] ? commit_val + V1[i] : commit_val;
                    Q1[i] = 0;
                end
                else if (commit_lab == Q2[i]) begin
                    V2[i] = commit_val;
                    Q2[i] = 0;
                end
                end
            end                                                                                                                                  
        end
    end
end 

assign lsb2mem_load_en = reg_lsb2mem_load_en;
assign lsb2mem_store_en = rob2lsb_store_en;
assign lsb2mem_addr = rob2lsb_store_en ? addr[(head == `LSB_SIZE - 1) ? 0 : head + 1] : reg_lsb2mem_load_en ? reg_commit_addr : 0;
assign lsb2mem_type = rob2lsb_store_en ? orderType[(head == `LSB_SIZE - 1) ? 0 : head + 1][3 : 1] : reg_lsb2mem_load_en ? reg_commit_type[3 : 1] : 0;
assign lsb2mem_val = rob2lsb_store_en ? res[(head == `LSB_SIZE - 1) ? 0 : head + 1] : reg_lsb2mem_load_en ? reg_commit_val : 0;
assign lab2cdb = reg_lab2cdb;
assign val2cdb = reg_val2cdb;
assign lsb_cdb_en = reg_lsb2cdb_en;
assign lsb2mem_load_id = reg_lsb2mem_load_en ? reg_commit_id : 0;
endmodule