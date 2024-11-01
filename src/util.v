`define INST_WIDTH 32
`define FUNCT3_WIDTH 3
`define FUNCT7_WIDTH 7
`define OP_WIDTH 7
`define ADDR_WIDTH 32
`define OP_LUI 7'b0110111 // U-TYPE
`define OP_AUIPC 7'b0010111 // U_TYPE
`define OP_JAL 7'b1101111 // J_TYPE
`define OP_JALR 7'b1100111 // I_TYPE

`define OP_I_TYPE 3'b001
`define OP_L_TYPE 3'b000
`define OP_B_TYPE 3'b110
`define OP_R_TYPE 3'b011
`define OP_S_TYPE 3'b010

`define REG_WIDTH 6
`define RS_SIZE 8
`define REG_SIZE 32
`define ROB_SIZE 32
`define ROB_ID_WIDTH 6
`define ID_WIDTH 5
`define VAL_WIDTH 32
`define RS_ID_WIDTH 3
`define LSB_ID_WIDTH 3
`define LSB_SIZE 8