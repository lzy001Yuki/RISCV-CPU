// RISCV32 CPU top module
// port modification allowed for debugging purposes
`include"util.v"
module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

wire ctrl2if_inst_rdy;
wire [`INST_WIDTH - 1 : 0] ctrl2if_inst_out;
wire if2ctrl2_en;
wire [`ADDR_WIDTH - 1 : 0] if2ctrl_next_PC;

controller ctrl(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .io_buffer_full(io_buffer_full),
  .mem_din(mem_din),
  .mem_rw(mem_wr),
  .mem_aout(mem_a),
  .mem_dout(mem_dout),

  .if2ctrl_en(if2ctrl_en),
  .next_PC(if2ctrl_next_PC),

  .mem2lsb_load_id(mem2lsb_load_id),
  .mem2lsb_load_val(mem2lsb_load_val),
  .mem_busy(mem_busy),
  .mem2lsb_load_en(mem2lsb_load_en),
  .lsb2mem_addr(lsb2mem_addr),
  .lsb2mem_type(lsb2mem_type),
  .lsb2mem_store_load(lsb2mem_store_load),
  .lsb2mem_en(lsb2mem_en),
  .lsb2mem_load_id(lsb2mem_load_id),
  .inst_rdy(ctrl2if_inst_rdy),
  .inst_out(ctrl2if_inst_out)
);

ifetch ins_fetch(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .inst_rdy(ctrl2if_inst_rdy),
  .inst_in(ctrl2if_inst_out),

  .alu2if(rs2if_newPC),
  .rob2if(rob2if_newPC),
  .dec2if(dec2if_pc),
  .dec2if_en(dec2if_rob_en),
  .alu2if_cont(rs2if_continuous),
  .flush(rob_flush),
  .decUpd(decUpd),

  .if2dec(if2dec_en),
  .inst_out(if_inst_out),
  .pc_out(if_pc_out),
  .if2pred_en(if2pred_en),
  .next_PC(if2ctrl_next_PC),
  .next_inst(if2ctrl_en)
);

wire if2dec_en;
wire rob_flush;
wire [`INST_WIDTH - 1 : 0] if_inst_out;
wire [`ADDR_WIDTH - 1 : 0] if_pc_out;
wire [`ADDR_WIDTH - 1 : 0] dec2if_pc;
wire dec2if_rob_en;
wire decUpd;

wire [`OP_WIDTH - 1 : 0] dec_op_out;
wire [`REG_WIDTH - 1 : 0] dec_rd_out;
wire [`REG_WIDTH - 1 : 0] dec_rs1_out;
wire [`REG_WIDTH - 1 : 0] dec_rs2_out;
wire [`VAL_WIDTH - 1 : 0] dec_imm_out;


idecode ins_dec(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .if2dec(if2dec_en),
  .flush(rob_flush),
  .pc_in(if_pc_out),
  .inst_in(if_inst_out),

  .pred(prediction),
  .orderType(dec_op_out),
  .dec_rd(dec_rd_out),
  .dec_rs1(dec_rs1_out),
  .dec_rs2(dec_rs2_out),
  .dec_imm(dec_imm_out),
  .decUpd(decUpd),
  .dec2if_pc(dec2if_pc),

  .lsbFull(lsbFull),
  .rsFull(rsFull),
  .robFull(robFull),

  .dec2if_rob_en(dec2if_rob_en),
  .dec_inst_curPC(dec_instPC_out),
  .dec2rob_jump_addr(dec2rob_jump_addr),
  .dec2lsb_en(dec2lsb_en),
  .dec2rs_en(dec2rs_en)
);

wire if2pred_en;
wire prediction;

predictor pred(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .if2pre_PC(if_pc_out),
  .rob2pre_nextPC(rob2pred_curPC),
  .if2pred_en(if2pred_en),
  .rob2pred_en(rob2pred_en),
  .pred_res(pred_res),
  .prediction(prediction)
);

wire robFull;
wire [`ROB_ID_WIDTH : 0] rob_label1;
wire [`ROB_ID_WIDTH : 0] rob_label2;
wire [`VAL_WIDTH - 1 : 0] rob_res1;
wire [`VAL_WIDTH - 1 : 0] rob_res2;
wire rob_ready1;
wire rob_ready2;
wire [`ROB_ID_WIDTH : 0] rob_newTag;
wire [`ADDR_WIDTH - 1 : 0] dec_instPC_out;
wire [`ADDR_WIDTH - 1 : 0] rob2if_newPC;
wire rob2pred_en;
wire [`ADDR_WIDTH - 1 : 0] rob2pred_curPC;
wire pred_res;
wire [`ADDR_WIDTH - 1 : 0] dec2rob_jump_addr;
reorderBuffer rob(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .curPC(dec_instPC_out),
  .inst(dec_op_out),
  .dest_rd(dec_rd_out),
  .jump_addr(dec2rob_jump_addr),
  .dec2rob_en(dec2if_rob_en),

  .rf_label1(rf2rob_lab1),
  .rf_label2(rf2rob_lab2),
  .rf_val1(rf2rob_val1),
  .rf_val2(rf2rob_val2),

  .commit_rd(rob2rf_commit_rd),
  .commit_res(rob2rf_commit_res),
  .commit_lab(rob2rf_commit_lab),

  .rsFull(rsFull),

  .label1(rob_label1),
  .label2(rob_label2),
  .res1(rob_res1),
  .res2(rob_res2),
  .ready1(rob_ready1),
  .ready2(rob_ready2),
  .newTag(rob_newTag),

  .cdbReady(cdbReady),
  .rs_cdb2lab(cdb2rs_lab),
  .rs_cdb2val(cdb2rs_val),
  .lsb_cdb2lab(cdb2lsb_lab),
  .lsb_cdb2val(cdb2lsb_val),

  .robFull(robFull),

  .pred_res(pred_res),
  .rob2pre_curPC(rob2pred_curPC),
  .rob2pred_en(rob2pred_en),

  .newPC(rob2if_newPC),
  .flush_out(rob_flush),

  .lsbFull(lsbFull)
);

wire [`REG_WIDTH - 1 : 0] rob2rf_commit_rd;
wire [`VAL_WIDTH - 1 : 0] rob2rf_commit_res;
wire [`ROB_ID_WIDTH : 0] rob2rf_commit_lab;
wire [`VAL_WIDTH - 1 : 0] rf2rob_val1;
wire [`VAL_WIDTH - 1 : 0] rf2rob_val2;
wire [`ROB_ID_WIDTH : 0] rf2rob_lab1;
wire [`ROB_ID_WIDTH : 0] rf2rob_lab2;

register regFile(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .flush(rob_flush),

  .dec2rf_rd(dec_rd_out),
  .dec2rob_en(dec2if_rob_en),
  .rob2rf_tag(rob_newTag),
  .rob2rf_commit_rd(rob2rf_commit_rd),
  .rob2rf_commit_res(rob2rf_commit_res),
  .rob2rf_commit_lab(rob2rf_commit_lab),
  .rf2rob_val1(rf2rob_val1),
  .rf2rob_val2(rf2rob_val2),
  .rf2rob_lab1(rf2rob_lab1),
  .rf2rob_lab2(rf2rob_lab2),

  .dec2rf_rs1(dec_rs1_out),
  .dec2rf_rs2(dec_rs2_out)
);

wire rsFull;
wire dec2rs_en;
wire [`ADDR_WIDTH - 1 : 0] rs2if_newPC;
wire rs2if_continuous;

reservationStation rs(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .flush(rob_flush),

  .alu2if_newPC(rs2if_newPC),
  .alu2if_continuous(rs2if_continuous),

  .nowPC(dec_instPC_out),
  .type(dec_op_out),
  .imm(dec_imm_out),
  .dec2rs_en(dec2rs_en),
  .isFull(rsFull),

  .label1(rob_label1),
  .label2(rob_label2),
  .res1(rob_res1),
  .res2(rob_res2),
  .ready1(rob_ready1),
  .ready2(rob_ready2),
  .newTag(rob_newTag),

  .cdbReady(cdbReady),
  .rs_cdb2lab(cdb2rs_lab),
  .rs_cdb2val(cdb2rs_val),
  .lsb_cdb2lab(cdb2lsb_lab),
  .lsb_cdb2val(cdb2lsb_val),

  .aluReady(rs2cdb_en),
  .val2cdb(rs2cdb_val),
  .lab2cdb(rs2cdb_lab)
);

wire lsbFull;
wire dec2lsb_en;

wire [`LSB_ID_WIDTH - 1 : 0] mem2lsb_load_id;
wire [`VAL_WIDTH - 1 : 0] mem2lsb_load_val;
wire mem_busy;
wire mem2lsb_load_en;
wire [`ADDR_WIDTH - 1 - 1 : 0] lsb2mem_addr;
wire [`FUNCT3_WIDTH - 1 : 0] lsb2mem_type;
wire [`VAL_WIDTH - 1 : 0] lsb2mem_val;
wire lsb2mem_store_load;
wire lsb2mem_en;
wire [`LSB_ID_WIDTH - 1 : 0] lsb2mem_load_id;

loadStoreBuffer lsb(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .flush(rob_flush),
  .type(dec_op_out),
  .imm(dec_imm_out),
  .dec2lsb_en(dec2lsb_en),
  .isFull(lsbFull),

  .label1(rob_label1),
  .label2(rob_label2),
  .res1(rob_res1),
  .res2(rob_res2),
  .ready1(rob_ready1),
  .ready2(rob_ready2),
  .newTag(rob_newTag),

  .cdbReady(cdbReady),
  .rs_cdb2lab(cdb2rs_lab),
  .rs_cdb2val(cdb2rs_val),
  .lsb_cdb2lab(cdb2lsb_lab),
  .lsb_cdb2val(cdb2lsb_val),

  .val2cdb(lsb2cdb_val),
  .lab2cdb(lsb2cdb_lab),
  .lsb_cdb_en(lsb2cdb_en),

  .mem2lsb_load_id(mem2lsb_load_id),
  .mem2lsb_load_val(mem2lsb_load_val),
  .mem_busy(mem_busy),
  .mem2lsb_load_en(mem2lsb_load_en),
  .lsb2mem_addr(lsb2mem_addr),
  .lsb2mem_type(lsb2mem_type),
  .lsb2mem_store_load(lsb2mem_store_load),
  .lsb2mem_en(lsb2mem_en),
  .lsb2mem_load_id(lsb2mem_load_id)

);

wire cdbReady;
wire rs2cdb_en;
wire lsb2cdb_en;
wire [`ROB_ID_WIDTH : 0] rs2cdb_lab;
wire [`VAL_WIDTH - 1 : 0] rs2cdb_val;
wire [`ROB_ID_WIDTH : 0] lsb2cdb_lab;
wire [`VAL_WIDTH - 1 : 0] lsb2cdb_val;
wire [`ROB_ID_WIDTH : 0] cdb2rs_lab;
wire [`VAL_WIDTH - 1 : 0] cdb2rs_val;
wire [`ROB_ID_WIDTH : 0] cdb2lsb_lab;
wire [`VAL_WIDTH - 1 : 0] cdb2lsb_val;

cdb cdbus(
  .clk(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .flush(rob_flush),
  .rs_cdb_enin(rs2cdb_en),
  .lsb_cdb_enin(lsb2cdb_en),
  .rs_cdb2lab_in(rs2cdb_lab),
  .rs_cdb2val_in(rs2cdb_val),
  .lsb_cdb2lab_in(lsb2cdb_lab),
  .lsb_cdb2val_in(lsb2cdb_val),

  .cdbReady(cdbReady),
  .rs_cdb2lab_out(cdb2rs_lab),
  .rs_cdb2val_out(cdb2rs_val),
  .lsb_cdb2lab_out(cdb2lsb_lab),
  .lsb_cdb2val_out(cdb2lsb_val)
);


// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// always @(posedge clk_in)
//   begin
//     if (rst_in)
//       begin
      
//       end
//     else if (!rdy_in)
//       begin
      
//       end
//     else
//       begin
      
//       end
//   end

endmodule