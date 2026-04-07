// rtl/id/ctrl.v (修改版，添加CSR支持)
`timescale 1ns/1ps

module ctrl (
    // ========== 输入端口 ==========
    input  wire [6:0]  opcode_i,   // 操作码（7位）
    input  wire [2:0]  funct3_i,   // 功能码3位
    input  wire [6:0]  funct7_i,   // 功能码7位
    input  wire [31:0] instr_i,    // 新增：完整指令（用于识别 MRET）

    // ========== 输出端口：主要控制信号 ==========
    output wire        alu_src_o,
    output wire        mem_to_reg_o,
    output wire        reg_write_o,
    output wire        mem_read_o,
    output wire        mem_write_o,
    output wire        branch_o,
    output wire        jump_o,
    
    // 新增：CSR控制信号
    output wire        csr_inst_o,    // CSR指令标志
    output wire        csr_write_o,    // CSR写使能

      // 新增：MRET 信号
    output wire        mret_o         // MRET 指令标志
);

// ========== 第一部分：指令类型识别 ==========
wire is_r_type = (opcode_i == 7'b0110011);
wire is_i_type = (opcode_i == 7'b0010011);
wire is_load   = (opcode_i == 7'b0000011);
wire is_store  = (opcode_i == 7'b0100011);
wire is_branch = (opcode_i == 7'b1100011);
wire is_jal    = (opcode_i == 7'b1101111);
wire is_jalr   = (opcode_i == 7'b1100111);
wire is_lui    = (opcode_i == 7'b0110111);
wire is_auipc  = (opcode_i == 7'b0010111);
wire is_system = (opcode_i == 7'b1110011);

// ========== 新增：MRET 识别 ==========
wire is_mret = is_system && (funct3_i == 3'b000) && (instr_i[31:20] == 12'h302);

// CSR指令：SYSTEM指令且funct3 != 0
wire is_csr = is_system && (funct3_i != 3'b000) && !is_mret;  // MRET 不是 CSR 指令

// ========== 第二部分：生成控制信号 ==========
assign alu_src_o = is_i_type || is_load || is_store || is_lui || is_auipc;
assign mem_to_reg_o = is_load;
assign reg_write_o = is_r_type || is_i_type || is_load || 
                     is_jal || is_jalr || is_lui || is_auipc || 
                     is_csr;
assign mem_read_o = is_load;
assign mem_write_o = is_store;
assign branch_o = is_branch;

//  关键修改：MRET 也产生跳转信号
assign jump_o = is_jal || is_jalr || is_mret;

// CSR相关信号
assign csr_inst_o = is_csr;
// CSRRW/CSRRS/CSRRC 且 rs1!=0 时才写
// CSRRWI/CSRRSI/CSRRCI 且 zimm!=0 时才写
// 具体写使能由csr_instructions模块处理，这里只输出指令类型
assign csr_write_o = is_csr;
// MRET 输出
assign mret_o = is_mret;
endmodule