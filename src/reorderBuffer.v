`include "util.v"
module reorderBuffer(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire [`ADDR_WIDTH - 1 : 0] curPC,

    input wire mem_busy,

    // from decoder
    input wire [`OP_WIDTH - 1 : 0] inst,
    input wire [`REG_WIDTH - 1 : 0] dest_rd,
    input wire [`ADDR_WIDTH - 1: 0] jump_addr,
    input wire dec2rob_en,
    input wire [`INST_WIDTH - 1 : 0] instruction,
    input wire dec2rob_pred,

    // from rf
    input wire [`ROB_ID_WIDTH : 0] rf_label1,
    input wire [`ROB_ID_WIDTH : 0] rf_label2,
    input wire [`VAL_WIDTH - 1 : 0] rf_val1,
    input wire [`VAL_WIDTH - 1 : 0] rf_val2,

    // to rf
    output wire [`REG_WIDTH - 1 : 0] commit_rd,
    output wire [`VAL_WIDTH - 1 : 0] commit_res,
    output wire [`ROB_ID_WIDTH: 0] commit_lab,

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
    output wire commit_en,

    // from cdb
    input wire rs_cdb_en,
    input wire lsb_cdb_en,
    input wire [`ROB_ID_WIDTH: 0] rs_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] rs_cdb2val,
    input wire [`ROB_ID_WIDTH: 0] lsb_cdb2lab,
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
    input wire lsbFull,
    output wire rob2lsb_store_en,
    output wire [`ROB_ID_WIDTH: 0] store_index
);

// consider simplify register use????

reg [`ROB_ID_WIDTH: 0] tag;
reg [`ROB_ID_WIDTH - 1 : 0] head;
reg [`ROB_ID_WIDTH - 1 : 0] tail;
reg ready [0 : `ROB_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] res [0 : `ROB_SIZE - 1]; // res_val 
reg [`ADDR_WIDTH - 1 : 0] nowPC [0 : `ROB_SIZE - 1];
reg [`REG_WIDTH - 1 : 0] dest [0 : `ROB_SIZE - 1]; //rd
reg [`ROB_ID_WIDTH : 0] label [0 : `ROB_SIZE - 1];
reg [`ADDR_WIDTH - 1 : 0] jump [0 : `ROB_SIZE - 1]; // jump_address if jump
reg [`OP_WIDTH - 1 : 0] orderType [0 : `ROB_SIZE - 1];
reg pred_result[0 : `ROB_SIZE - 1];
reg reg_flush;
reg reg_pred_res;
reg [`ADDR_WIDTH - 1 : 0] reg_rob2pre_curPC;
reg [`ADDR_WIDTH - 1 : 0] reg_newPC;
reg reg_update;
reg [`REG_WIDTH - 1 : 0] reg_commit_rd;
reg [`VAL_WIDTH - 1 : 0] reg_commit_res;
reg [`ROB_ID_WIDTH: 0] reg_commit_lab;
reg reg_rob2lsb_store_en;
reg [`ROB_ID_WIDTH : 0] reg_store_index;
reg [31 : 0] counter;
reg ready_head;
reg [`OP_WIDTH - 1 : 0] op_head;

reg [`INST_WIDTH - 1 : 0] rob_inst[0 : `ROB_SIZE - 1];
reg [`INST_WIDTH - 1 : 0] commit_inst;
reg reg_commit_en;

initial begin
    counter = 0;
    reg_rob2lsb_store_en = 0;
end

integer i;

always @(posedge clk) begin
    counter <= counter + 1;
        if (`START <= counter && counter <= `END_ && `DEBUG) begin
            $display("time----> %d, head=%d, tail=%d", counter, head, tail);
         for (i = 0; i < `ROB_SIZE; i++) begin
            //if (ready[i]) begin
             $display("%d, label=%d, ready=%d, res=%d, PC=%h", i, label[i], ready[i], res[i], nowPC[i]);
             //end
            end
        end
    if (rst_in || (reg_flush && rdy_in)) begin
        // may let tag be tail...consider later
        tag <= 1;
        head <= 0;
        tail <= 1;
        for (i = 0; i < `ROB_SIZE; i++) begin
            ready[i] <= 0;
            res[i] <= 0;
            nowPC[i] <= 0;
            dest[i] <= 0;
            label[i] <= 0;
            jump[i] <= 0;
            orderType[i] <= 0;
        end
        reg_flush <= 0;
    end
    else if (rdy_in) begin
        // issue
        ready_head <= ready[(head == `ROB_SIZE - 1) ? 0 : head + 1];
        op_head <= orderType[(head == `ROB_SIZE - 1) ? 0 : head + 1];
        if (dec2rob_en) begin
            tail <= tail + 1;
            nowPC[tail] <= curPC;
            jump[tail] <= jump_addr; // 0 or true addr
            dest[tail] <= dest_rd;
            label[tail] <= tag;
            pred_result[tail] <= dec2rob_pred;
            tag <= (tag != `ROB_SIZE) ? tag + 1 : 1;
            rob_inst[tail] <= instruction;
            orderType[tail] <= inst;
        end
        // fetchData
        if (rs_cdb_en) begin
            ready[rs_cdb2lab == `ROB_SIZE ? 0 : rs_cdb2lab] <= 1;
            res[rs_cdb2lab == `ROB_SIZE ? 0 : rs_cdb2lab] <= rs_cdb2val;
        end
        if (lsb_cdb_en) begin
            ready[lsb_cdb2lab == `ROB_SIZE ? 0 : lsb_cdb2lab] <= 1;
            res[lsb_cdb2lab == `ROB_SIZE ? 0 : lsb_cdb2lab] <= lsb_cdb2val;
        end

        // commit
        reg_rob2lsb_store_en <= 0;
        reg_commit_en <= 0;
        if (ready[(head == `ROB_SIZE - 1) ? 0 : head + 1] && ((head == `ROB_SIZE - 1) ? 0 : head + 1) != tail) begin
            // consider how to exit????
            commit_inst <= rob_inst[(head == `ROB_SIZE - 1) ? 0 : head + 1];
            if (orderType[(head == `ROB_SIZE - 1) ? 0 : head + 1][6 : 4] == `OP_B_TYPE && orderType[(head == `ROB_SIZE - 1) ? 0 : head + 1] != `OP_JAL && orderType[(head == `ROB_SIZE - 1) ? 0 : head + 1] != `OP_JALR) begin
                head <= head + 1;
                if (`DEBUG) begin
                $display("commit: %h, counter: %d, res=%d, jump=%h, pred=%d, label=%d", rob_inst[(head == `ROB_SIZE - 1) ? 0 : head + 1], counter, res[(head == `ROB_SIZE - 1) ? 0 : head + 1], jump[(head == `ROB_SIZE - 1) ? 0 : head + 1], pred_result[(head == `ROB_SIZE - 1) ? 0 : head + 1], label[(head == `ROB_SIZE - 1) ? 0 : head + 1]);
                end
                reg_update <= 1;
                if ((res[(head == `ROB_SIZE - 1) ? 0 : head + 1] == pred_result[(head == `ROB_SIZE - 1) ? 0 : head + 1])) begin
                    reg_pred_res <= 1;
                    reg_rob2pre_curPC <= nowPC[(head == `ROB_SIZE - 1) ? 0 : head + 1];
                    ready[(head == `ROB_SIZE - 1) ? 0 : head + 1] <= 0;
                end
                else begin
                    // false prediction
                    reg_newPC <= res[(head == `ROB_SIZE - 1) ? 0 : head + 1] ? jump[(head == `ROB_SIZE - 1) ? 0 : head + 1] : nowPC[(head == `ROB_SIZE - 1) ? 0 : head + 1] + (rob_inst[(head == `ROB_SIZE - 1) ? 0 : head + 1][1 : 0] == 2'b11 ? 4 : 2);
                    reg_pred_res <= 0;
                    reg_rob2pre_curPC <= nowPC[(head == `ROB_SIZE - 1) ? 0 : head + 1];
                    reg_flush <= 1;
                    ready[(head == `ROB_SIZE - 1) ? 0 : head + 1] <= 0;
                end
            end 
            else if (orderType[(head == `ROB_SIZE - 1) ? 0 : head + 1][6 : 4] != `OP_S_TYPE) begin
                reg_update <= 0;
                head <= head + 1;
                if (`DEBUG) begin
                $display("commit: %h, counter: %d, label=%d, res=%d", rob_inst[(head == `ROB_SIZE - 1) ? 0 : head + 1], counter, label[(head == `ROB_SIZE - 1) ? 0 : head + 1], res[label[(head == `ROB_SIZE - 1) ? 0 : head + 1]]);
                end
                if (dest[(head == `ROB_SIZE - 1) ? 0 : head + 1]) begin
                    reg_commit_en <= 1;
                    reg_commit_rd <= dest[(head == `ROB_SIZE - 1) ? 0 : head + 1];
                    reg_commit_res <= res[(head == `ROB_SIZE - 1) ? 0 : head + 1];
                    reg_commit_lab <= label[(head == `ROB_SIZE - 1) ? 0 : head + 1];
                end
                ready[(head == `ROB_SIZE - 1) ? 0 : head + 1] <= 0;
            end
            else if (orderType[(head == `ROB_SIZE - 1) ? 0 : head + 1][6 : 4] == `OP_S_TYPE && !mem_busy) begin
                head <= head + 1;
                if (`DEBUG) begin
                $display("commit: %h, counter: %d, label=%d, res=%d", rob_inst[(head == `ROB_SIZE - 1) ? 0 : head + 1], counter, label[(head == `ROB_SIZE - 1) ? 0 : head + 1], res[label[(head == `ROB_SIZE - 1) ? 0 : head + 1]]);
                end
                reg_rob2lsb_store_en <= 1;
                reg_store_index <= label[(head == `ROB_SIZE - 1) ? 0 : head + 1];
                ready[(head == `ROB_SIZE - 1) ? 0 : head + 1] <= 0;
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
assign commit_en = reg_commit_en;
assign label1 = rf_label1;
assign label2 = rf_label2;
assign res1 = rf_label1 ? res[rf_label1 == `ROB_SIZE ? 0 : rf_label1] : rf_val1;
assign res2 = rf_label2 ? res[rf_label2 == `ROB_SIZE ? 0 : rf_label2] : rf_val2;
assign ready1 = rf_label1 ? ready[rf_label1 == `ROB_SIZE ? 0 : rf_label1] : 1;
assign ready2 = rf_label2 ? ready[rf_label2 == `ROB_SIZE ? 0 : rf_label2] : 1;
assign rob2lsb_store_en = reg_rob2lsb_store_en;
assign store_index = reg_store_index;
endmodule