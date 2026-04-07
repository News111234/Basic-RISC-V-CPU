// rtl/ifu/ifu_top.v
`timescale 1ns/1ps

module ifu_top(
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire        stall_i,
    input  wire        branch_taken_i,
    input  wire        jump_taken_i,
    input  wire [31:0] branch_target_i,
    input  wire [31:0] jump_target_i,
    
    // ========== 新增中断接口 ==========
    input  wire        interrupt_pending_i,   // 中断请求信号
    input  wire [31:0] mtvec_i,               // 中断向量基址
    
    output wire [31:0] instr,
    output wire [31:0] pc,
    output wire [31:0] pc_plus4,

    // ===== 新增调试输出 =====
    output wire        debug_jump_taken_o,
    output wire        debug_branch_taken_o,
    output wire        debug_interrupt_pending_o,
    output wire [31:0] debug_mtvec_o
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