`include"util.v"
module decode(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,
    // from decoder
    input wire if2dec,
    input wire [`ADDR_WIDTH - 1 : 0] pc_out,
    input wire [`INST_WIDTH - 1 : 0] inst_in,
    output wire decFlush,
    output wire [`ADDR_WIDTH - 1 : 0] dec2if
);

wire [`OP_WIDTH - 1 : 0] opcode = inst_in[`OP_WIDTH - 1 : 0];
wire [`FUNCT3_WIDTH - 1 : 0] funct3 = inst_in[14:12];
wire [`FUNCT7_WIDTH - 1 : 0] funct7 = inst_in[31:25];
wire [`REG_WIDTH - 1 : 0] rd = inst_in[11 : 7];

reg reg_decFluch;
reg [`ADDR_WIDTH - 1 : 0] reg_dec2if;


always @(posedge clk) begin
    if (rst_in) begin
        // initialize
        reg_decFlush <= 0;
    end
    else if (!rdy_in) begin
        // do nothing
    end
    else if (if2dec) begin
        case (opcode) 
        
    end
end