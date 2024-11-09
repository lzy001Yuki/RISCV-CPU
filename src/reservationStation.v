`include "alu.v"
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

    input wire [`ADDR_WIDTH - 1 : 0] nowPC,

    // connect to decoder
    input wire [`OP_WIDTH - 1 : 0 ] type,
    input wire [`VAL_WIDTH - 1 : 0] imm, 
    input wire dec2rs_en,
    output wire isFull,
    // connect to rob
    input wire [`ID_WIDTH - 1 : 0] label1,
    input wire [`ID_WIDTH - 1 : 0] label2,
    input wire [`VAL_WIDTH - 1 : 0] res1, //from rob or regFile
    input wire [`VAL_WIDTH - 1 : 0] res2,
    input wire ready1,
    input wire ready2,
    input wire [`ID_WIDTH - 1 : 0] newTag,
    //input wire [`ID_WIDTH - 1 : 0] lab2idx, // label in rob --> index in rs

    // connect to cdb
    input wire cdbReady,
    input wire [`ID_WIDTH - 1 : 0] cdb2lab,
    input wire [`VAL_WIDTH - 1 : 0] cdb2val,

    // connect to alu
    output wire execute,
    input wire aluReady,
    input wire[`ID_WIDTH - 1 : 0] entry_in, 
    input wire[`VAL_WIDTH - 1 : 0] val_in,

    output wire[`VAL_WIDTH - 1 : 0] val2cdb,
    output wire[`ID_WIDTH - 1 : 0] lab2cdb,
    output wire rs_cdb_en
);
// reg inside the module can remain until changed, thus useful!!
reg busy [0 : `RS_SIZE - 1];
reg [`ID_WIDTH - 1 : 0] entry [0 : `RS_SIZE - 1]; // index in rob
reg [`VAL_WIDTH - 1 : 0] V1 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] V2 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] Q1 [0 : `RS_SIZE - 1];
reg [`VAL_WIDTH - 1 : 0] Q2 [0 : `RS_SIZE - 1];
reg [`OP_WIDTH - 1 : 0] orderType [0 : `RS_SIZE - 1];
reg [`RS_ID_WIDTH : 0] issue_id;
reg [`RS_ID_WIDTH : 0] exe_id;
reg[`ID_WIDTH - 1 : 0] reg_entry_in;
reg[`VAL_WIDTH - 1 : 0] reg_val_in;
reg rsFull;
reg reg_execute;

integer i;

// find issue_id
always @(*) begin
    issue_id <= 4'b1000;
    exe_id <= 4'b1000;
    for (i = 0; i < `RS_SIZE; i = i + 1) begin
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
assign execute = reg_execute;

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
        if (!rsFull && dec2rs_en) begin
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
        if (cdbReady) begin
            for (i = 0; i < `RS_SIZE; i++) begin
                if (busy[i]) begin
                    if (Q1[i] == cdb2lab) begin
                        V1[i] = cdb2val;
                        Q1[i] = 0;
                    end
                    if (Q2[i] == cdb2lab) begin
                        V2[i] = cdb2val;
                        Q2[i] = 0;
                    end
                end
            end
        end
        // write
        if (aluReady) begin
            reg_entry_in <= entry_in;
            reg_val_in <= val_in;
        end
    end
end

// connect to alu

alu alu(
    .clk(clk),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .type(orderType[exe_id]),
    .val1(V1[exe_id]),
    .val2(V2[exe_id]),
    .entry(entry[exe_id]),

    .aluReady(aluReady),
    .entry_out(entry_in),
    .val_out(val_in)
);

assign rs_issue_id = issue_id;
assign val2cdb = aluReady ? reg_val_in : 0;
assign lab2cdb = aluReady ? reg_entry_in : 0;
assign rs_cdb_en = aluReady? 1 : 0;


endmodule