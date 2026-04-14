// rtl/id/id_top.v (修改版，添加CSR支持)
`timescale 1ns/1ps
// ============================================================================
// 模块: id_top
// 功能: 译码阶段顶层模块，集成寄存器堆、立即数生成、解码和控制单元
// 描述:
//   该模块是流水线译码阶段的核心，负责:
//   1. 接收IF/ID寄存器的指令和PC
//   2. 调用decoder和ctrl进行指令译码，生成所有控制信号
//   3. 调用imm_gen生成立即数
//   4. 访问寄存器堆，读取rs1和rs2的值
//   5. 接收来自WB阶段的写回数据(前递)，用于解决RAW冒险
//   6. 将所有译码结果和控制信号输出到ID/EX寄存器
// ============================================================================
module id_top (
    // ========== 系统接口 ==========
    input  wire        clk,           // 时钟信号
    input  wire        rst_n,         // 复位信号 (低电平有效)

    // ========== 来自IF/ID寄存器的输入 ==========
    input  wire [31:0] instr,         // 指令
    input  wire [31:0] pc,            // 当前PC值

    // ========== 来自WB阶段的写回数据 (前递) ==========
    input  wire        wb_we_i,       // WB阶段寄存器写使能
    input  wire [4:0]  wb_rd_addr_i,  // WB阶段目标寄存器地址
    input  wire [31:0] wb_rd_data_i,  // WB阶段写回数据

    // ========== 输出到ID/EX寄存器 ==========
    output wire [31:0] rs1_data_o,    // rs1寄存器值
    output wire [31:0] rs2_data_o,    // rs2寄存器值
    output wire [31:0] imm_o,         // 立即数
    output wire [4:0]  rs1_addr_o,    // rs1地址
    output wire [4:0]  rs2_addr_o,    // rs2地址
    output wire [4:0]  rd_addr_o,     // 目标寄存器地址
    output wire [3:0]  alu_op_o,      // ALU操作码
    output wire        alu_src_o,     // ALU源操作数2选择
    output wire        mem_we_o,      // 内存写使能
    output wire        mem_re_o,      // 内存读使能
    output wire [1:0]  wb_sel_o,      // 写回选择
    output wire        reg_we_o,      // 寄存器写使能
    output wire        branch_o,      // 分支指令标志
    output wire        jump_o,        // 跳转指令标志
    output wire [2:0]  funct3_o,      // funct3字段
    output wire [2:0]  mem_width_o,   // 内存访问宽度
    output wire [6:0]  opcode_o,      // 操作码

    // ========== CSR相关输出 ==========
    output wire        csr_inst_o,    // CSR指令标志
    output wire [11:0] csr_addr_o,    // CSR地址
    output wire [2:0]  csr_op_o,      // CSR操作类型
    output wire [4:0]  csr_zimm_o,    // CSR立即数

    // ========== MRET输出 ==========
    output wire        mret_o,        // MRET指令标志

    // ========== 调试输出 ==========
    // 32个通用寄存器的调试输出 (x0-x31)
   output wire [31:0] debug_x0_o,
    output wire [31:0] debug_x1_o,
    output wire [31:0] debug_x2_o,
    output wire [31:0] debug_x3_o,
    output wire [31:0] debug_x4_o,
    output wire [31:0] debug_x5_o,
    output wire [31:0] debug_x6_o,
    output wire [31:0] debug_x7_o,
    output wire [31:0] debug_x8_o,
    output wire [31:0] debug_x9_o,
    output wire [31:0] debug_x10_o,
    output wire [31:0] debug_x11_o,
    output wire [31:0] debug_x12_o,
    output wire [31:0] debug_x13_o,
    output wire [31:0] debug_x14_o,
    output wire [31:0] debug_x15_o,
    output wire [31:0] debug_x16_o,
    output wire [31:0] debug_x17_o,
    output wire [31:0] debug_x18_o,
    output wire [31:0] debug_x19_o,
    output wire [31:0] debug_x20_o,
    output wire [31:0] debug_x21_o,
    output wire [31:0] debug_x22_o,
    output wire [31:0] debug_x23_o,
    output wire [31:0] debug_x24_o,
    output wire [31:0] debug_x25_o,
    output wire [31:0] debug_x26_o,
    output wire [31:0] debug_x27_o,
    output wire [31:0] debug_x28_o,
    output wire [31:0] debug_x29_o,
    output wire [31:0] debug_x30_o,
    output wire [31:0] debug_x31_o,

    output wire [4:0]  debug_rd_addr_o,   // 调试: 目标寄存器地址
    output wire        debug_reg_we_o,     // 调试: 寄存器写使能
    output wire [31:0] debug_imm_value_o,  // 调试: 立即数值
    output wire [6:0]  debug_opcode_o      // 调试: 操作码
);


wire [4:0]  rs1_addr;
wire [4:0]  rs2_addr;
wire [4:0]  rd_addr;
wire [31:0] imm;
wire [6:0]  opcode;
wire [2:0]  funct3;
wire [6:0]  funct7;
wire        branch;
wire        jump;

// CSR相关内部信号
wire        csr_inst;
wire [11:0] csr_addr;
wire [2:0]  csr_op;
wire [4:0]  csr_zimm;

// 内部信号
wire mret;

decoder u_decoder (
    .instr_i   (instr),
    .opcode_o  (opcode),
    .rd_addr_o (rd_addr),
    .funct3_o  (funct3),
    .rs1_addr_o(rs1_addr),
    .rs2_addr_o(rs2_addr),
    .funct7_o  (funct7),
    .alu_op_o  (alu_op_o),
    .alu_src_o (alu_src_o),
    .mem_we_o  (mem_we_o),
    .mem_re_o  (mem_re_o),
    .wb_sel_o  (wb_sel_o),
    .reg_we_o  (reg_we_o),
    
    // 新增：CSR输出
    .csr_inst_o(csr_inst),
    .csr_addr_o(csr_addr),
    .csr_op_o  (csr_op),
    .csr_zimm_o(csr_zimm),
     .mret_o    (mret)           // 新增
);

imm_gen u_imm_gen (
    .instr_i (instr),
    .imm_o   (imm)
);

regfile u_regfile (
    .clk      (clk),
    .rst_n    (rst_n),
    .raddr1_i (rs1_addr),
    .raddr2_i (rs2_addr),
    .rdata1_o (rs1_data_o),
    .rdata2_o (rs2_data_o),
    .we_i     (wb_we_i),
    .waddr_i  (wb_rd_addr_i),
    .wdata_i  (wb_rd_data_i),

    // 调试输出
    .debug_x0_o  (debug_x0_o),
    .debug_x1_o  (debug_x1_o),
    .debug_x2_o  (debug_x2_o),
    .debug_x3_o  (debug_x3_o),
    .debug_x4_o  (debug_x4_o),
    .debug_x5_o  (debug_x5_o),
    .debug_x6_o  (debug_x6_o),
    .debug_x7_o  (debug_x7_o),
    .debug_x8_o  (debug_x8_o),
    .debug_x9_o  (debug_x9_o),
    .debug_x10_o (debug_x10_o),
    .debug_x11_o (debug_x11_o),
    .debug_x12_o (debug_x12_o),
    .debug_x13_o (debug_x13_o),
    .debug_x14_o (debug_x14_o),
    .debug_x15_o (debug_x15_o),
    .debug_x16_o (debug_x16_o),
    .debug_x17_o (debug_x17_o),
    .debug_x18_o (debug_x18_o),
    .debug_x19_o (debug_x19_o),
    .debug_x20_o (debug_x20_o),
    .debug_x21_o (debug_x21_o),
    .debug_x22_o (debug_x22_o),
    .debug_x23_o (debug_x23_o),
    .debug_x24_o (debug_x24_o),
    .debug_x25_o (debug_x25_o),
    .debug_x26_o (debug_x26_o),
    .debug_x27_o (debug_x27_o),
    .debug_x28_o (debug_x28_o),
    .debug_x29_o (debug_x29_o),
    .debug_x30_o (debug_x30_o),
    .debug_x31_o (debug_x31_o)
);

ctrl u_ctrl (
    .opcode_i     (opcode),
    .funct3_i     (funct3),
    .funct7_i     (funct7),
    .instr_i      (instr),      // 新增：传入完整指令
    .branch_o     (branch),
    .jump_o       (jump),
    
    // 新增：CSR输出
    .csr_inst_o   (),
    .csr_write_o  (),
    .mret_o       (mret)        // 新增：MRET 输出

);

// 输出赋值
assign imm_o       = imm;
assign rs1_addr_o  = rs1_addr;
assign rs2_addr_o  = rs2_addr;
assign rd_addr_o   = rd_addr;
assign branch_o    = branch;

assign mret_o = mret;
assign jump_o = jump;  // 注意：jump_o 现在来自 ctrl，包含了 MRET

assign funct3_o    = funct3;
assign opcode_o    = opcode;
assign mem_width_o = (opcode == 7'b0000011 || opcode == 7'b0100011) ? funct3 : 3'b010;

// CSR输出赋值
assign csr_inst_o  = csr_inst;
assign csr_addr_o  = csr_addr;
assign csr_op_o    = csr_op;
assign csr_zimm_o  = csr_zimm;

// 调试输出
assign debug_rd_addr_o   = rd_addr_o;
assign debug_reg_we_o    = reg_we_o;
assign debug_imm_value_o = imm_o;
assign debug_opcode_o    = instr[6:0];
// 输出 MRET
assign mret_o = mret;
endmodule