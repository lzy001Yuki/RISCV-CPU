`include "util.v"
module cdb(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    input wire flush,
    input rs_cdb_enin,
    input lsb_cdb_enin,
    input wire [`ROB_ID_WIDTH : 0] rs_cdb2lab_in,
    input wire [`VAL_WIDTH - 1 : 0] rs_cdb2val_in,
    input wire [`ROB_ID_WIDTH : 0] lsb_cdb2lab_in,
    input wire [`VAL_WIDTH - 1 : 0] lsb_cdb2val_in,

    output cdbReady,
    output wire [`ROB_ID_WIDTH : 0] rs_cdb2lab_out,
    output wire [`VAL_WIDTH - 1 : 0] rs_cdb2val_out,
    output wire [`ROB_ID_WIDTH : 0] lsb_cdb2lab_out,
    output wire [`VAL_WIDTH - 1 : 0] lsb_cdb2val_out
);

reg reg_rs_en;
reg reg_lsb_en;
reg [`ROB_ID_WIDTH : 0] reg_rs_lab;
reg [`VAL_WIDTH - 1 : 0] reg_rs_val;
reg [`ROB_ID_WIDTH : 0] reg_lsb_lab;
reg [`VAL_WIDTH - 1 : 0] reg_lsb_val;

always @(*) begin
    reg_rs_en <= rs_cdb_enin;
    reg_lsb_en <= lsb_cdb_enin;
    reg_rs_lab <= rs_cdb2lab_in;
    reg_rs_val <= rs_cdb2val_in;
    reg_lsb_lab <= lsb_cdb2lab_in;
    reg_lsb_val <= lsb_cdb2val_in;
end

always @(posedge clk) begin
    if (rst_in || flush) begin
        reg_rs_en <= 0;
        reg_lsb_en <= 0;
        reg_rs_lab <= 0;
        reg_lsb_lab <= 0;
        reg_rs_val <= 0;
        reg_lsb_val <= 0;
    end
    else if (rdy_in) begin

    end
end

assign cdbReady = reg_rs_en || reg_lsb_en;
assign rs_cdb2lab_out = reg_rs_lab;
assign rs_cdb2val_out = reg_rs_val;
assign lsb_cdb2lab_out = reg_lsb_lab;
assign lsb_cdb2val_out = reg_lsb_val;


endmodule