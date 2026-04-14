// rtl/ifu/ifu_top.v
`timescale 1ns/1ps

// ============================================================================
// 模块: ifu_top
// 功能: 指令取指单元顶层模块，负责指令地址生成和指令读取
// 描述:
//   该模块是流水线取指阶段的核心，负责:
//   1. 维护PC寄存器，根据顺序执行、分支/跳转或中断更新下一个PC
//   2. 中断优先级最高，其次是分支/跳转，最后是顺序执行(PC+4)
//   3. 调用指令ROM读取当前PC指向的指令
//   4. 输出PC、指令和PC+4给IF/ID寄存器
// ============================================================================
module ifu_top(
    // ========== 系统接口 ==========
    input  wire        clk,               // 时钟信号
    input  wire        rst_n,             // 复位信号 (低电平有效)

    // ========== 流水线控制信号 ==========
    input  wire        stall_i,           // 停顿标志 (暂停PC更新)
    input  wire        branch_taken_i,    // 分支跳转标志
    input  wire        jump_taken_i,      // 跳转标志 (JAL/JALR)
    input  wire [31:0] branch_target_i,   // 分支目标地址
    input  wire [31:0] jump_target_i,     // 跳转目标地址

    // ========== 中断接口 ==========
    input  wire        interrupt_pending_i, // 中断请求信号 (来自中断控制器)
    input  wire [31:0] mtvec_i,            // 中断向量基址 (来自CSR)

    // ========== 输出到IF/ID寄存器 ==========
    output wire [31:0] instr,              // 读取的指令
    output wire [31:0] pc,                 // 当前PC值
    output wire [31:0] pc_plus4,           // PC + 4

    // ========== 调试输出 ==========
    output wire        debug_jump_taken_o,      // 调试: 跳转标志
    output wire        debug_branch_taken_o,    // 调试: 分支标志
    output wire        debug_interrupt_pending_o, // 调试: 中断等待标志
    output wire [31:0] debug_mtvec_o            // 调试: mtvec值
);

// 内部信号声明
wire [31:0] pc_value;
wire [31:0] next_pc;

// ========== PC寄存器 ==========
pc_reg u_pc_reg(
    .clk     (clk),
    .rst_n   (rst_n),
    .stall   (stall_i),
    .interrupt_pending(interrupt_pending_i),  // 新增
    .next_pc (next_pc),
    .pc      (pc_value)
);

// ========== 指令ROM ==========
wire [31:0] rom_addr = (!rst_n) ? 32'h0 : pc_value;

inst_rom_hello u_inst_rom(
    .addr_i (rom_addr),
    .data_o (instr)
);

// ========== 下一个PC值计算 ==========
// 中断优先级最高，然后是分支/跳转，最后是顺序执行
assign next_pc = (!rst_n)               ? 32'h0 :
                 (interrupt_pending_i)  ? mtvec_i :          // 中断优先级最高
                 (branch_taken_i)       ? branch_target_i :
                 (jump_taken_i)         ? jump_target_i :
                 (stall_i)              ? pc_value :
                 pc_value + 32'h4;

// ========== 输出赋值 ==========
assign pc = pc_value;
assign pc_plus4 = pc_value + 32'h4;

// 调试输出
assign debug_jump_taken_o       = jump_taken_i;
assign debug_branch_taken_o     = branch_taken_i;
assign debug_interrupt_pending_o = interrupt_pending_i;
assign debug_mtvec_o            = mtvec_i;

endmodule