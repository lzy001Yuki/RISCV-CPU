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
    input wire [`ROB_ID_WIDTH : 0] label1,
    input wire [`ROB_ID_WIDTH : 0] label2,
    input wire [`VAL_WIDTH - 1 : 0] res1, //from rob or regFile
    input wire [`VAL_WIDTH - 1 : 0] res2,
    input wire ready1,
    input wire ready2,
    input wire [`ROB_ID_WIDTH : 0] newTag,

    // connect to cdb
    input wire cdbReady,
    input wire [`ROB_ID_WIDTH : 0] rs_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] rs_cdb2val,
    input wire [`ROB_ID_WIDTH : 0] lsb_cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] lsb_cdb2val,

    // connect to alu
    output wire aluReady,
    output wire[`VAL_WIDTH - 1 : 0] val2cdb,
    output wire[`ROB_ID_WIDTH : 0] lab2cdb
);
// reg inside the module can remain until changed, thus useful!!
reg busy [0 : `RS_SIZE - 1];
reg [`ROB_ID_WIDTH : 0] entry [0 : `RS_SIZE - 1]; // index in rob
reg [`VAL_WIDTH - 1 : 0] V1 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] V2 [0 : `RS_SIZE - 1];
reg [`ROB_ID_WIDTH : 0] Q1 [0 : `RS_SIZE - 1];
reg [`ROB_ID_WIDTH : 0] Q2 [0 : `RS_SIZE - 1];
reg [`OP_WIDTH - 1 : 0] orderType [0 : `RS_SIZE - 1];
reg [`RS_ID_WIDTH : 0] issue_id;
reg [`RS_ID_WIDTH : 0] exe_id;
reg rsFull;
reg reg_execute;

integer i;

// find issue_id
always @(negedge clk) begin
    if (cdbReady) begin
        for (i = 0; i < `RS_SIZE; i++) begin
            if (busy[i]) begin
                V1[i] = (Q1[i] == rs_cdb2lab) ? rs_cdb2val : (Q1[i] == lsb_cdb2lab) ? lsb_cdb2val : V1[i];
                Q1[i] = (Q1[i] == rs_cdb2lab) ? 0 : (Q1[i] == lsb_cdb2lab) ? 0 : Q1[i];
                V2[i] = (Q2[i] == rs_cdb2lab) ? rs_cdb2val : (Q2[i] == lsb_cdb2lab) ? lsb_cdb2val : V2[i];
                Q2[i] = (Q2[i] == rs_cdb2lab) ? 0 : (Q2[i] == lsb_cdb2lab) ? 0 : Q2[i];
            end
        end
    end
    issue_id <= 4'b1000;
    exe_id <= 4'b1000;
    for (i = 0; i < `RS_SIZE; i++) begin
        if (!busy[i] && issue_id == 4'b1000) begin
            issue_id <= i;
        end
        if (busy[i] && !Q1[i] && !Q2[i] && exe_id == 4'b1000) begin
            exe_id <= i;
            busy[exe_id] <= 0;
        end
    end
    if (exe_id == 4'b1000) begin
        reg_execute <= 0;
    end
    else begin
        reg_execute <= 1;
    end
    if (issue_id == 4'b1000) begin
        rsFull <= 1;
    end
    else begin
        rsFull <= 0;
    end
end

assign isFull = rsFull;

always @(posedge clk) begin
    if (rst_in || (flush && rdy_in)) begin
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            busy[i] <= 0;
            entry[i] <= 0;
            V1[i] <= 0;
            V2[i] <= 0;
            Q1[i] <= 0;
            Q2[i] <= 0;
            orderType[i] <= 0;
            issue_id <= 4'b1000;
            exe_id <= 4'b1000;
        end
    end else if (!rdy_in) begin
    end else if (dec2rs_en) begin
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
                V1[issue_id] <= 4;
                V2[issue_id] <= nowPC;
            end
            else if (type[2 : 0] == `OP_I_TYPE) begin
                V2[issue_id] <= imm;
                Q2[issue_id] <= 0;
            end
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
            if (orderType[issue_id][2 : 0] != `OP_I_TYPE) begin
                if (label2) begin
                    if (ready2) begin
                        V2[issue_id] <= res2;
                    end
                    else begin
                        Q1[issue_id] <= label2;
                    end
                end 
                else begin
                    V2[issue_id] <= res2;
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

alu alu(
    .clk(clk),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .execute(reg_execute),
    .type(orderType[exe_id]),
    .val1(V1[exe_id]),
    .val2(V2[exe_id]),
    .entry(entry[exe_id]),
    .nowPC(nowPC),

    .aluReady(aluReady),
    .entry_out(lab2cdb),
    .val_out(val2cdb),

    .alu2if_pc(alu2if_newPC),
    .alu2if_con(alu2if_continuous)
);

endmodule