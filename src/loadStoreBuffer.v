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
    input wire [`ID_WIDTH - 1 : 0] newTag,
    input wire [`ID_WIDTH - 1 : 0] label1,
    input wire [`ID_WIDTH - 1 : 0] label2,
    input wire [`VAL_WIDTH - 1 : 0] res1, //from rob (val from rob / rf)
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
    output wire lsb_cdb_en,

    // from memory
    input wire [`LSB_ID_WIDTH - 1 : 0] mem2lsb_load_id,
    input wire [`VAL_WIDTH - 1 : 0] mem2lsb_load_val,
    output wire [`ADDR_WIDTH - 1 - 1 : 0] lsb2mem_store_addr,
    output wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_store_type, 
    output wire lsb2mem_store_en,
    output wire [`VAL_WIDTH - 1 : 0] lsb2mem_store_val,
    output wire [`ADDR_WIDTH - 1 : 0] lsb2mem_load_addr,
    output wire [`LSB_ID_WIDTH - 1 : 0] lsb2mem_load_id,
    output wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_load_type,
    output wire lsb2mem_load_en,
    input wire mem2lsb_load_en

);

// FIFO in lsb to apply to the time requirement
// load & store in order

reg [`LSB_ID_WIDTH : 0] loadIndex;
reg [`LSB_ID_WIDTH : 0] storeIndex;
reg [`LSB_ID_WIDTH : 0] load_write_id;
reg [`LSB_ID_WIDTH : 0] store_write_id;
reg [`LSB_ID_WIDTH - 1 : 0] head;
reg [`LSB_ID_WIDTH - 1 : 0] tail;
reg nodeType [`LSB_SIZE - 1 : 0]; // 0 for load, 1 for store12
reg [`OP_WIDTH - 1 : 0] orderType;
reg busy [0 : `LSB_SIZE - 1];
reg [`ID_WIDTH - 1 : 0] entry [0 : `LSB_SIZE - 1]; // index in rob
reg [`VAL_WIDTH - 1 : 0] V1 [0 : `LSB_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] V2 [0 : `LSB_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] Q1 [0 : `LSB_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] Q2 [0 : `LSB_SIZE - 1];
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
reg [`ID_WIDTH - 1 : 0] reg_lab2cdb;
reg [`VAL_WIDTH - 1 : 0] reg_val2cdb;
reg [`LSB_ID_WIDTH - 1 : 0] reg_mem2lsb_load_id;

integer i;
always @(posedge clk) begin
    if (rst_in || (flush && rdy_in)) begin
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            busy[i] <= 0;
            entry[i] <= 0;
            V1[i] <= 0;
            V2[i] <= 0;
            Q1[i] <= 0;
            Q2[i] <= 0;
            nodeType[i] <= 0;
            loadIndex <= 4'b1000;
            storeIndex <= 4'b1000;
            head <= 0;
            tail <= 0;
            load_write_id <= 4'b1000;
            store_write_id <= 4'b1000;
        end
    end
    else if (rdy_in) begin
        // issue
        if (!isFull && dec2lsb_en) begin
            tail = (tail == `LSB_SIZE - 1) ? 0 : tail + 1;
            entry[tail] <= newTag;
            busy[tail] <= 1;
            orderType[tail] <= type;
            status[tail] <= STATUS_ISSUE;
            if (type[2 : 0] == `OP_L_TYPE) begin
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
                        V1[tail] <= V1[tail] + res1;
                    end
                    else begin
                        Q1[tail] <= label1;
                    end
                end
                else begin
                    V1[tail] <= V1[tail] + res1;
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
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            if (busy[i] && !Q1[i] && !Q2[i]) begin
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
        reg_commit_id <= (head == `LSB_SIZE - 1) ? 0 : head + 1;
        reg_lsb2mem_store_en <= 0;
        reg_lsb2mem_load_en <= 0;
        if (nodeType[reg_commit_id] && status[reg_commit_id] == STATUS_EXE) begin
            // store
            reg_lsb2mem_store_en <= 1;
            head <= (head == `LSB_SIZE - 1) ? 3'b000 : head + 1；
            busy[reg_commit_id] <= 0;
            reg_commit_addr <= addr[reg_commit_id];
            reg_commit_val <= res[reg_commit_id];
            reg_commit_type <= orderType[reg_commit_id];
        end
        else if (!nodeType[reg_commit_id] && status[reg_commit_id] == STATUS_EXE) begin
            reg_lsb2mem_load_en <= 1;
            head <= (head == `LSB_SIZE - 1) ? 3'b000 : head + 1；
            busy[reg_commit_id] <= 0;
            reg_commit_addr <= addr[reg_commit_id];
            reg_commit_type <= orderType[reg_commit_id];
        end

        // write
        reg_lab2cdb <= 0;
        reg_val2cdb <= 0;
        if (mem2lsb_load_en) begin
            reg_mem2lsb_load_id <= mem2lsb_load_id;
            res[reg_mem2lsb_load_id] <= mem2lsb_load_val;
            status[reg_mem2lsb_load_id] <= STATUS_WRITE;
            reg_lab2cdb <= entry[mem2lsb_load_id];
            reg_val2cdb <= res[mem2lsb_load_id];
        end


        // fetch data
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            if (cdbReady && busy[i]) begin
                if (cdb2lab == Q1[i]) begin
                    if (nodeType[i]) begin
                        V1[i] = cdb2val + V1[i];
                        Q1[i] = 0;
                    end
                    else begin
                        V1[i] = cdb2val;
                        Q1[i] = 0;
                    end
                end
                else if (cdb2lab == Q2[i]) begin
                    V2[i] = cdb2val;
                    Q2[i] = 0;
                end
            end                                                                                                                                  
        end
    end
end 

assign lsb2mem_store_addr = reg_lsb2mem_store_en ? reg_commit_addr : 0;
assign lsb2mem_store_type = reg_lsb2mem_store_en ? reg_commit_type : 0;
assign lsb2mem_store_val = reg_lsb2mem_store_en ? reg_commit_val : 0;
assign lsb2mem_store_en = reg_lsb2mem_store_en;
assign lsb2mem_load_type = reg_lsb2mem_load_en ? reg_commit_type[5 : 3] : 0;
assign lsb2mem_load_en = reg_lsb2mem_load_en;
assign lsb2mem_load_addr = reg_lsb2mem_load_en ? reg_commit_addr[5 : 3] : 0;
assign lab2cdb = mem2lsb_load_en ? reg_lab2cdb : 0;
assign val2cdb = mem2lsb_load_en ? reg_val2cdb : 0;
assign cdbReady = reg_lab2cdb ? 1 : 0;
endmodule