// rtl/pipeline/id_ex_reg.v (修改版)
`timescale 1ns/1ps

module id_ex_reg (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire        stall_i,
    input  wire        flush_i,         // 常规冲刷
    input  wire        intr_flush_i,    // 新增：中断冲刷
    
    input  wire [31:0] id_pc_i,
    input  wire [31:0] id_rs1_data_i,
    input  wire [31:0] id_rs2_data_i,
    input  wire [31:0] id_imm_i,
    input  wire [4:0]  id_rs1_addr_i,
    input  wire [4:0]  id_rs2_addr_i,
    input  wire [4:0]  id_rd_addr_i,
    
    input  wire [3:0]  id_alu_op_i,
    input  wire        id_alu_src_i,
    input  wire        id_mem_we_i,
    input  wire        id_mem_re_i,
    input  wire [2:0]  id_mem_width_i,
    input  wire [1:0]  id_wb_sel_i,
    input  wire        id_reg_we_i,
    input  wire        id_branch_i,
    input  wire        id_jump_i,
    input  wire [2:0]  id_funct3_i,
    input  wire [6:0]  id_opcode_i,
    
    // 新增：CSR相关信号
    input  wire        id_csr_inst_i,
    input  wire [11:0] id_csr_addr_i,
    input  wire [2:0]  id_csr_op_i,
    input  wire [4:0]  id_csr_zimm_i,

     input  wire        id_mret_i,
    output reg         ex_mret_o,
    
    output reg  [31:0] ex_pc_o,
    output reg  [31:0] ex_rs1_data_o,
    output reg  [31:0] ex_rs2_data_o,
    output reg  [31:0] ex_imm_o,
    output reg  [4:0]  ex_rs1_addr_o,
    output reg  [4:0]  ex_rs2_addr_o,
    output reg  [4:0]  ex_rd_addr_o,
    
    output reg  [3:0]  ex_alu_op_o,
    output reg         ex_alu_src_o,
    output reg         ex_mem_we_o,
    output reg         ex_mem_re_o,
    output reg  [2:0]  ex_mem_width_o,
    output reg  [1:0]  ex_wb_sel_o,
    output reg         ex_reg_we_o,
    output reg         ex_branch_o,
    output reg         ex_jump_o,
    output reg  [2:0]  ex_funct3_o,
    output reg  [6:0]  ex_opcode_o,
    
    // 新增：CSR相关输出
    output reg         ex_csr_inst_o,
    output reg  [11:0] ex_csr_addr_o,
    output reg  [2:0]  ex_csr_op_o,
    output reg  [4:0]  ex_csr_zimm_o

    
);

always @(posedge clk_i ) begin
    if (!rst_n_i) begin
        ex_pc_o         <= 32'b0;
        ex_rs1_data_o   <= 32'b0;
        ex_rs2_data_o   <= 32'b0;
        ex_imm_o        <= 32'b0;
        ex_rs1_addr_o   <= 5'b0;
        ex_rs2_addr_o   <= 5'b0;
        ex_rd_addr_o    <= 5'b0;
        
        ex_alu_op_o     <= 4'b0000;
        ex_alu_src_o    <= 1'b0;
        ex_mem_we_o     <= 1'b0;
        ex_mem_re_o     <= 1'b0;
        ex_mem_width_o  <= 3'b010;
        ex_wb_sel_o     <= 2'b00;
        ex_reg_we_o     <= 1'b0;
        ex_branch_o     <= 1'b0;
        ex_jump_o       <= 1'b0;
        ex_funct3_o     <= 3'b000;
        ex_opcode_o     <= 7'b0;
        
        ex_csr_inst_o   <= 1'b0;
        ex_csr_addr_o   <= 12'b0;
        ex_csr_op_o     <= 3'b0;
        ex_csr_zimm_o   <= 5'b0;
         ex_mret_o       <= 1'b0;  // 新增
    end
    else if (flush_i || intr_flush_i) begin
        ex_pc_o         <= 32'b0;
        ex_rs1_data_o   <= 32'b0;
        ex_rs2_data_o   <= 32'b0;
        ex_imm_o        <= 32'b0;
        ex_rs1_addr_o   <= 5'b0;
        ex_rs2_addr_o   <= 5'b0;
        ex_rd_addr_o    <= 5'b0;
        
        ex_alu_op_o     <= 4'b0000;
        ex_alu_src_o    <= 1'b1;
        ex_mem_we_o     <= 1'b0;
        ex_mem_re_o     <= 1'b0;
        ex_mem_width_o  <= 3'b010;
        ex_wb_sel_o     <= 2'b00;
        ex_reg_we_o     <= 1'b0;
        ex_branch_o     <= 1'b0;
        ex_jump_o       <= 1'b0;
        ex_funct3_o     <= 3'b000;
        ex_opcode_o     <= 7'b0010011;  // nop的opcode
        
        ex_csr_inst_o   <= 1'b0;
        ex_csr_addr_o   <= 12'b0;
        ex_csr_op_o     <= 3'b0;
        ex_csr_zimm_o   <= 5'b0;
         ex_mret_o       <= 1'b0;  // 新增
    end
    else if (!stall_i) begin
        ex_pc_o         <= id_pc_i;
        ex_rs1_data_o   <= id_rs1_data_i;
        ex_rs2_data_o   <= id_rs2_data_i;
        ex_imm_o        <= id_imm_i;
        ex_rs1_addr_o   <= id_rs1_addr_i;
        ex_rs2_addr_o   <= id_rs2_addr_i;
        ex_rd_addr_o    <= id_rd_addr_i;
        
        ex_alu_op_o     <= id_alu_op_i;
        ex_alu_src_o    <= id_alu_src_i;
        ex_mem_we_o     <= id_mem_we_i;
        ex_mem_re_o     <= id_mem_re_i;
        ex_mem_width_o  <= id_mem_width_i;
        ex_wb_sel_o     <= id_wb_sel_i;
        ex_reg_we_o     <= id_reg_we_i;
        ex_branch_o     <= id_branch_i;
        ex_jump_o       <= id_jump_i;
        ex_funct3_o     <= id_funct3_i;
        ex_opcode_o     <= id_opcode_i;
        
        ex_csr_inst_o   <= id_csr_inst_i;
        ex_csr_addr_o   <= id_csr_addr_i;
        ex_csr_op_o     <= id_csr_op_i;
        ex_csr_zimm_o   <= id_csr_zimm_i;
        ex_mret_o       <= id_mret_i;  // 新增
    end
end

endmodule