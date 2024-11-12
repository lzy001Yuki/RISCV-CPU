`include "util.v"

module controller(
    input wire clk,
    input wire rst_in,
    input wire rdy_in,

    output wire inst_en,
    output wire [`INST_WIDTH - 1 : 0] inst_out

);

endmodule