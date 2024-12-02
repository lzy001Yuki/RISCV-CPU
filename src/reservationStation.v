`include "util.v"
module reservationStation(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,
    input wire flush,

    /*assume process in issue phase:
    1.decoder connected to rf & rs & rob(rob & rs can issue simutaneously)
    2.rs send 'whether or not need to wait the label' to rob & rf gives label, val to rob
    3.if waiting needed, rob gives label, val, idx back to rs*/
    // just try!!!!
    // if no lab needed, the label input equals to zero?
    // but can use non-blocking assignment

    // to ifetch
    output wire [`ADDR_WIDTH - 1 : 0] alu2if_newPC,
    output wire alu2if_continuous,

    // connect to decoder
    input wire [`ADDR_WIDTH - 1 : 0] nowPC,
    input wire [`OP_WIDTH - 1 : 0 ] type,
    input wire [`VAL_WIDTH - 1 : 0] imm, 
    input wire dec2rs_en,
    output wire isFull,
    // connect to rob
    input wire [`ROB_ID_WIDTH: 0] label1,
    input wire [`ROB_ID_WIDTH: 0] label2,
    input wire [`VAL_WIDTH - 1 : 0] res1, //from rob or regFile
    input wire [`VAL_WIDTH - 1 : 0] res2,
    input wire ready1,
    input wire ready2,
    input wire [`ROB_ID_WIDTH: 0] newTag,
    input wire commit_en,
    input wire [`ROB_ID_WIDTH : 0] commit_lab,
    input wire [`VAL_WIDTH - 1 : 0] commit_val,

    // connect to cdb
    input wire rs_cdb_en,
    input wire lsb_cdb_en,
    input wire [`ROB_ID_WIDTH: 0] rs_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] rs_cdb2val,
    input wire [`ROB_ID_WIDTH: 0] lsb_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] lsb_cdb2val,

    // connect to alu
    output wire aluReady,
    output wire[`VAL_WIDTH - 1 : 0] val2cdb,
    output wire[`ROB_ID_WIDTH : 0] lab2cdb
);
// reg inside the module can remain until changed, thus useful!!
reg busy [0 : `RS_SIZE - 1];
reg [`ROB_ID_WIDTH: 0] entry [0 : `RS_SIZE - 1]; // index in rob
reg [`VAL_WIDTH - 1 : 0] V1 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] V2 [0 : `RS_SIZE - 1];
reg [`ROB_ID_WIDTH: 0] Q1 [0 : `RS_SIZE - 1];
reg [`ROB_ID_WIDTH: 0] Q2 [0 : `RS_SIZE - 1];
reg [`OP_WIDTH - 1 : 0] orderType [0 : `RS_SIZE - 1];
reg [`RS_ID_WIDTH - 1: 0] issue_id;
reg [`RS_ID_WIDTH - 1: 0] exe_id;
reg rsFull;
reg reg_execute;
reg [31 : 0] counter;
initial begin
    counter = 0;
end

integer i;
integer issue_flag;
integer exe_flag;
// find issue_id
always @(negedge clk) begin
    if (lsb_cdb_en || rs_cdb_en || commit_en) begin
        for (i = 0; i < `RS_SIZE; i++) begin
            if (busy[i]) begin
                V1[i] = (Q1[i] == rs_cdb2lab && rs_cdb_en) ? rs_cdb2val : (Q1[i] == commit_lab && commit_en) ? commit_val : (Q1[i] == lsb_cdb2lab && lsb_cdb_en) ? lsb_cdb2val : V1[i];
                Q1[i] = (Q1[i] == rs_cdb2lab && rs_cdb_en) ? 0 : (Q1[i] == commit_lab && commit_en) ? 0 : (Q1[i] == lsb_cdb2lab && lsb_cdb_en) ? 0 : Q1[i];
                V2[i] = (Q2[i] == rs_cdb2lab && rs_cdb_en) ? rs_cdb2val : (Q2[i] == commit_lab && commit_en) ? commit_val : (Q2[i] == lsb_cdb2lab && lsb_cdb_en) ? lsb_cdb2val : V2[i];
                Q2[i] = (Q2[i] == rs_cdb2lab && rs_cdb_en) ? 0 : (Q2[i] == commit_lab && commit_en) ? 0 : (Q2[i] == lsb_cdb2lab && lsb_cdb_en) ? 0 : Q2[i];
            end
        end
    end
    issue_flag = 0;
    exe_flag = 0;
    exe_id = 0;
    issue_id = 0;
    for (i = 0; i < `RS_SIZE; i++) begin
        if (!busy[i] && !issue_flag) begin
            issue_id = i;
            issue_flag = 1;
        end
        if (busy[i] && !Q1[i] && !Q2[i] && !exe_flag) begin
            exe_id = i;
            busy[i] = 0;
            reg_alu_type = orderType[i];
            reg_alu_val1 = V1[i];
            reg_alu_val2 = V2[i];
            reg_alu_entry = entry[i];
            exe_flag = 1;
        end
    end
    reg_execute = exe_flag ? 1 : 0;
    rsFull = issue_flag ? 0 : 1;
end

assign isFull = rsFull;
reg [`VAL_WIDTH - 1 : 0] debug_V1_0;

always @(posedge clk) begin
    counter <= counter + 1;
      if (counter >= `START && counter <= `END_ && `DEBUG) begin
           $display("reservatin_station------------- time-----", counter);
           for (i = 0; i < `RS_SIZE; i++) begin
             //if (busy[i]) begin
            $display("busy=%d, entry=%d, Q1=%d, Q2=%d, V1=%d, V2=%d", busy[i], entry[i], Q1[i], Q2[i], V1[i], V2[i]);
             //end
           end
      end
    if (rst_in || (flush && rdy_in)) begin
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            busy[i] <= 0;
            entry[i] <= 0;
            V1[i] <= 0;
            V2[i] <= 0;
            Q1[i] <= 0;
            Q2[i] <= 0;
            orderType[i] <= 0;
            issue_id <= 3'b000;
            exe_id <= 3'b000;
        end
    end else if (!rdy_in) begin
    end else  begin
        debug_V1_0 <= V1[0];
        // issue
        if (dec2rs_en) begin
            entry[issue_id] <= newTag;
            busy[issue_id] <= 1;
            orderType[issue_id] <= type;
            if (type == `OP_AUIPC) begin
                V1[issue_id] <= imm;
                V2[issue_id] <= nowPC;
            end
            else if (type == `OP_LUI) begin
                V1[issue_id] <= imm;
                V2[issue_id] <= 0;
            end
            else if (type == `OP_JAL) begin
                V1[issue_id] <= imm; // 2 or 4
                V2[issue_id] <= nowPC;
            end
            else begin
            if (label1) begin
                if (ready1) begin
                    V1[issue_id] <= res1;
                end
                else begin
                    Q1[issue_id] <= label1;
                end
            end
            else begin
                V1[issue_id] <= res1;
            end
            if (type[6 : 4] != `OP_I_TYPE) begin
                if (label2) begin
                    if (ready2) begin
                        V2[issue_id] <= res2;
                    end
                    else begin
                        Q2[issue_id] <= label2;
                    end
                end 
                else begin
                    V2[issue_id] <= res2;
                end
            end
            else if (type[6 : 4] == `OP_I_TYPE) begin
                V2[issue_id] <= imm;
                Q2[issue_id] <= 0;
            end
            end

        end
        // fetch data
        // if (cdbReady) begin
        //     for (i = 0; i < `RS_SIZE; i++) begin
        //         if (busy[i]) begin
        //             if (Q1[i] == cdb2lab) begin
        //                 V1[i] = cdb2val;
        //                 Q1[i] = 0;
        //             end
        //             if (Q2[i] == cdb2lab) begin
        //                 V2[i] = cdb2val;
        //                 Q2[i] = 0;
        //             end
        //         end
        //     end
        // end
    end
end

// connect to alu

wire [`OP_WIDTH - 1 : 0] alu_type;
reg [`OP_WIDTH - 1 : 0] reg_alu_type;
assign alu_type = reg_alu_type;
wire [`VAL_WIDTH - 1 : 0] alu_val1;
reg [`VAL_WIDTH - 1 : 0] reg_alu_val1;
assign alu_val1 = reg_alu_val1;
wire [`VAL_WIDTH - 1 : 0] alu_val2;
reg [`VAL_WIDTH - 1 : 0] reg_alu_val2;
assign alu_val2 = reg_alu_val2;
wire [`ROB_ID_WIDTH: 0] alu_entry;
reg [`ROB_ID_WIDTH: 0] reg_alu_entry;
assign alu_entry = reg_alu_entry;

initial begin
    reg_alu_type = 0;
    reg_alu_val1 = 0;
    reg_alu_val2 = 0;
    reg_alu_entry = 0;
end

alu alu(
    .clk(clk),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .execute(reg_execute),
    .flush(flush),
    .type(alu_type),
    .val1(alu_val1),
    .val2(alu_val2),
    .entry(alu_entry),
    .nowPC(nowPC),

    .aluReady(aluReady),
    .entry_out(lab2cdb),
    .val_out(val2cdb),

    .alu2if_pc(alu2if_newPC),
    .alu2if_con(alu2if_continuous)
);

endmodule