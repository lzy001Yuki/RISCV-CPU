`include "util.v"

module reorderBuffer(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire [`ADDR_WIDTH - 1 : 0] curPC,

    // from decoder
    input wire [`OP_WIDTH - 1 : 0] inst,
    input wire [`REG_SIZE - 1 : 0] dest_rd,
    input wire [`ADDR_WIDTH - 1: 0] jump_addr,
    input wire dec2rob_en,

    // from rf
    input wire [`ROB_ID_WIDTH : 0] rf_label1,
    input wire [`ROB_ID_WIDTH: 0] rf_label2,
    input wire [`VAL_WIDTH - 1 : 0] rf_val1,
    input wire [`VAL_WIDTH - 1 : 0] rf_val2,

    // to rf
    output wire [`REG_WIDTH - 1 : 0] commit_rd,
    output wire [`VAL_WIDTH - 1 : 0] commit_res,
    output wire [`ROB_ID_WIDTH : 0] commit_lab,

    // from rs
    input wire rsFull,
    // to rs
    output wire [`ROB_ID_WIDTH: 0] label1,
    output wire [`ROB_ID_WIDTH : 0] label2,
    output wire [`VAL_WIDTH - 1 : 0] res1, //from rob or regFile
    output wire [`VAL_WIDTH - 1 : 0] res2,
    output wire ready1,
    output wire ready2,
    output wire [`ROB_ID_WIDTH : 0] newTag, // to rs

    // from cdb
    input wire cdbReady,
    input wire [`ROB_ID_WIDTH : 0] rs_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] rs_cdb2val,
    input wire [`ROB_ID_WIDTH : 0] lsb_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] lsb_cdb2val,

    output wire robFull,

    // to predictor
    output wire pred_res,
    output wire [`ADDR_WIDTH - 1 : 0] rob2pre_curPC,
    output wire rob2pred_en,

    // to ifetch
    output wire [`ADDR_WIDTH - 1 : 0] newPC,

    output wire flush_out,

    // from lsb
    input wire lsbFull
);

// consider simplify register use????

reg [`ROB_ID_WIDTH : 0] tag;
reg [`ROB_ID_WIDTH - 1 : 0] head;
reg [`ROB_ID_WIDTH - 1 : 0] tail;
reg ready [0 : `ROB_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] res [0 : `ROB_SIZE - 1]; // res_val 
reg [`ADDR_WIDTH - 1 : 0] nowPC [0 : `ROB_SIZE - 1];
reg [`REG_WIDTH - 1 : 0] dest [0 : `ROB_SIZE - 1]; //rd
reg [`ROB_ID_WIDTH : 0] label [0 : `ROB_SIZE - 1];
reg [`ADDR_WIDTH - 1 : 0] jump [0 : `ROB_SIZE - 1]; // jump_address if jump
reg [`OP_WIDTH - 1 : 0] reg_instType;
reg reg_flush;
reg reg_pred_res;
reg [`ADDR_WIDTH - 1 : 0] reg_rob2pre_curPC;
reg [`ADDR_WIDTH - 1 : 0] reg_newPC;
reg reg_update;
reg [`REG_WIDTH - 1 : 0] reg_commit_rd;
reg [`VAL_WIDTH - 1 : 0] reg_commit_res;
reg [`ROB_ID_WIDTH: 0] reg_commit_lab;

integer i;

always @(posedge clk) begin
    if (rst_in || (reg_flush && rdy_in)) begin
        tag <= 1;
        head <= 0;
        tail <= 0;
        for (i = 0; i < `ROB_SIZE; i++) begin
            ready[i] <= 0;
            res[i] <= 0;
            nowPC[i] <= 0;
            dest[i] <= 0;
            label[i] <= 0;
            jump[i] <= 0;
        end
        reg_flush <= 0;
    end
    else if (rdy_in) begin
        // issue
        reg_instType <= inst;
        if (dec2rob_en) begin
            tail <= tail + 1;
            nowPC[tail] <= curPC;
            jump[tail] <= jump_addr; // 0 or true addr
            dest[tail] <= dest_rd;
            label[tail] <= tag;
            tag <= (tag != `ROB_SIZE) ? tag + 1 : 1;
        end
        // fetchData
        if (cdbReady) begin
            ready[rs_cdb2lab] <= 1;
            res[rs_cdb2lab] <= rs_cdb2val;
        end
        if (cdbReady) begin
            ready[lsb_cdb2lab] <= 1;
            res[lsb_cdb2lab] <= lsb_cdb2val;
        end

        // commit
        if ((head != `ROB_SIZE - 1 && ready[head + 1]) || (head == `ROB_SIZE - 1 && ready[0])) begin
            head <= head + 1;
            // consider how to exit????
            if (reg_instType[2 : 0] == `OP_B_TYPE && reg_instType != `OP_JAL) begin
                reg_update <= 1;
                if ((res[head] && jump[head]) || (!res[head] && !jump[head])) begin
                    reg_pred_res <= 1;
                    reg_rob2pre_curPC <= nowPC[head];
                end
                else begin
                    // false prediction
                    reg_newPC <= res[head] ? jump[head] : nowPC[head] + 4;
                    reg_pred_res <= 0;
                    reg_rob2pre_curPC <= nowPC[head];
                    reg_flush <= 1;
                end
            end 
            else if (reg_instType[2 : 0] != `OP_S_TYPE && reg_instType[2 : 0] != `OP_B_TYPE && reg_instType != `OP_LUI && reg_instType != `OP_AUIPC && reg_instType !=`OP_JAL) begin
                reg_update <= 0;
                if (dest[head]) begin
                    reg_commit_rd <= dest[head];
                    reg_commit_res <= res[head];
                    reg_commit_lab <= label[head];
                end
            end
        end
    end
end

assign newTag = tag;
assign robFull = (head == tail);
assign flush_out = reg_flush;
assign pred_res = reg_pred_res;
assign rob2pre_curPC = reg_rob2pre_curPC;
assign rob2pred_en = reg_update;
assign newPC = reg_newPC;
assign commit_rd = reg_commit_rd;
assign commit_res = reg_commit_res;
assign commit_lab = reg_commit_lab;
assign label1 = rf_label1;
assign label2 = rf_label2;
assign res1 = rf_label1 ? res[rf_label1 - 1] : rf_val1;
assign res2 = rf_label2 ? res[rf_label2 - 1] : rf_val2;
assign ready1 = ready[rf_label1 - 1];
assign ready2 = ready[rf_label2 - 1];
endmodule