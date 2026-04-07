// rtl/hazard/hazard_unit.v (完整修改版)
`timescale 1ns/1ps

module hazard_unit (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // ID 阶段当前指令的源寄存器
    input  wire [4:0] id_rs1_addr_i,
    input  wire [4:0] id_rs2_addr_i,
    
    // ID/EX 寄存器中的指令（即将进入 EX）
    input  wire [4:0] id_ex_rd_addr_i,
    input  wire       id_ex_reg_we_i,
    input  wire       id_ex_mem_re_i,   // 是否是 load 指令（在 EX 阶段）
    
    // ========== 新增：EX/MEM 阶段的信号 ==========
    input  wire [4:0] ex_mem_rd_addr_i,     // EX/MEM 阶段的目标寄存器
    input  wire       ex_mem_reg_we_i,      // EX/MEM 阶段写使能
    input  wire       ex_mem_mem_re_i,      // EX/MEM 阶段是否是 load
    
    // 控制冒险信号
    input  wire       branch_taken_i,
    input  wire       jump_taken_i,
    
    // 中断信号
    input  wire       interrupt_taken_i,
    input  wire       interrupt_flush_i,
    
    // 输出：流水线控制信号
    output wire       stall_if_o,
    output wire       stall_id_o,
    output wire       flush_if_o,
    output wire       flush_id_o,
    
    // 中断冲刷输出
    output wire       intr_flush_if_o,
    output wire       intr_flush_id_o,
    output wire       intr_flush_ex_o,
    output wire       intr_flush_mem_o,
    output wire       intr_flush_wb_o,
    
    // 调试输出
    output wire       debug_load_use_hazard_o,
    output wire       debug_control_hazard_o,
    output wire [4:0] debug_id_rs1_addr_o,
    output wire [4:0] debug_id_rs2_addr_o,
    output wire [4:0] debug_id_ex_rd_addr_o,
    output wire       debug_id_ex_reg_we_o,
    output wire       debug_id_ex_mem_re_o,
    
    // ========== 新增调试输出 ==========
    output wire [4:0] debug_ex_mem_rd_addr_o,
    output wire       debug_ex_mem_reg_we_o,
    output wire       debug_ex_mem_mem_re_o
);

// ========== 加载-使用冒险检测（修改版）==========
// 关键修改：只有当 load 还在 EX 阶段时才需要 stall
// 如果 load 已经进入 MEM 阶段，应该通过前递解决
wire load_in_ex = id_ex_mem_re_i;                    // load 在 EX 阶段
wire load_in_mem = ex_mem_mem_re_i;                  // load 在 MEM 阶段

// 检测条件：
// 1. 上一条指令是 load 且还在 EX 阶段（还没进入 MEM）
// 2. 要写回寄存器且不是 x0
// 3. 当前指令依赖这个寄存器
wire load_use_hazard = load_in_ex &&           // load 在 EX 阶段
                       !load_in_mem &&         // load 还没有进入 MEM 阶段（关键！）
                       id_ex_reg_we_i &&
                       (id_ex_rd_addr_i != 5'b0) &&
                       ((id_ex_rd_addr_i == id_rs1_addr_i) ||
                        (id_ex_rd_addr_i == id_rs2_addr_i));

// 控制冒险检测
wire control_hazard = branch_taken_i || jump_taken_i;

// ========== 输出信号 ==========
assign stall_if_o = load_use_hazard;
assign stall_id_o = load_use_hazard;
assign flush_if_o = control_hazard;
assign flush_id_o = control_hazard;

// 中断冲刷信号
assign intr_flush_if_o = interrupt_flush_i;
assign intr_flush_id_o = interrupt_flush_i;
assign intr_flush_ex_o = interrupt_flush_i;
assign intr_flush_mem_o = interrupt_flush_i;
assign intr_flush_wb_o = interrupt_flush_i;

// ========== 调试输出 ==========
assign debug_load_use_hazard_o = load_use_hazard;
assign debug_control_hazard_o = control_hazard;
assign debug_id_rs1_addr_o = id_rs1_addr_i;
assign debug_id_rs2_addr_o = id_rs2_addr_i;
assign debug_id_ex_rd_addr_o = id_ex_rd_addr_i;
assign debug_id_ex_reg_we_o = id_ex_reg_we_i;
assign debug_id_ex_mem_re_o = id_ex_mem_re_i;

// 新增调试输出
assign debug_ex_mem_rd_addr_o = ex_mem_rd_addr_i;
assign debug_ex_mem_reg_we_o = ex_mem_reg_we_i;
assign debug_ex_mem_mem_re_o = ex_mem_mem_re_i;

endmodule