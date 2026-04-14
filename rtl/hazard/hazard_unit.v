// rtl/hazard/hazard_unit.v (完整修改版)
`timescale 1ns/1ps

// 模块: hazard_unit
// 功能: 冒险检测单元，处理流水线的加载-使用冒险和控制冒险
// 描述:
//   该模块检测流水线中的两种主要冒险:
//   1. 加载-使用冒险 (Load-Use Hazard):
//      当前指令(ID阶段)的源寄存器依赖上一条load指令(EX阶段)的目标寄存器，
//      且load指令尚未进入MEM阶段。此时需要停顿流水线(IF/ID)一个周期，
//      让load数据从MEM阶段前递到EX阶段。
//
//   2. 控制冒险 (Control Hazard):
//      当分支或跳转指令在EX阶段判定为跳转时，需要冲刷(flush)IF/ID阶段，
//      丢弃已取出的错误指令。
//
//   此外，该模块还处理中断引起的流水线冲刷，中断冲刷所有流水线阶段。
// ============================================================================
module hazard_unit (
    // ========== 系统接口 ==========
    input  wire        clk_i,           // 时钟信号
    input  wire        rst_n_i,         // 复位信号 (低电平有效)

    // ========== ID阶段当前指令的源寄存器 ==========
    input  wire [4:0] id_rs1_addr_i,    // ID阶段指令的rs1地址
    input  wire [4:0] id_rs2_addr_i,    // ID阶段指令的rs2地址

    // ========== ID/EX寄存器中的指令信息 ==========
    input  wire [4:0] id_ex_rd_addr_i,  // ID/EX阶段指令的目标寄存器地址
    input  wire       id_ex_reg_we_i,   // ID/EX阶段寄存器写使能
    input  wire       id_ex_mem_re_i,   // ID/EX阶段是否为load指令

    // ========== EX/MEM寄存器中的指令信息 ==========
    input  wire [4:0] ex_mem_rd_addr_i, // EX/MEM阶段指令的目标寄存器地址
    input  wire       ex_mem_reg_we_i,  // EX/MEM阶段寄存器写使能
    input  wire       ex_mem_mem_re_i,  // EX/MEM阶段是否为load指令

    // ========== 控制冒险信号 ==========
    input  wire       branch_taken_i,   // 分支跳转标志 (来自EX阶段)
    input  wire       jump_taken_i,     // 跳转标志 (来自EX阶段)

    // ========== 中断信号 ==========
    input  wire       interrupt_taken_i,  // 中断被接受标志
    input  wire       interrupt_flush_i,  // 中断冲刷标志

    // ========== 流水线控制输出 ==========
    output wire       stall_if_o,       // 停顿IF阶段 (IF/ID寄存器)
    output wire       stall_id_o,       // 停顿ID阶段 (ID/EX寄存器)
    output wire       flush_if_o,       // 冲刷IF阶段 (控制冒险)
    output wire       flush_id_o,       // 冲刷ID阶段 (控制冒险)

    // ========== 中断冲刷输出 (冲刷所有流水级) ==========
    output wire       intr_flush_if_o,  // 中断冲刷IF阶段
    output wire       intr_flush_id_o,  // 中断冲刷ID阶段
    output wire       intr_flush_ex_o,  // 中断冲刷EX阶段
    output wire       intr_flush_mem_o, // 中断冲刷MEM阶段
    output wire       intr_flush_wb_o,  // 中断冲刷WB阶段

    // ========== 调试输出 ==========
    output wire       debug_load_use_hazard_o,  // 调试: 加载-使用冒险标志
    output wire       debug_control_hazard_o,   // 调试: 控制冒险标志
    output wire [4:0] debug_id_rs1_addr_o,      // 调试: ID阶段rs1地址
    output wire [4:0] debug_id_rs2_addr_o,      // 调试: ID阶段rs2地址
    output wire [4:0] debug_id_ex_rd_addr_o,    // 调试: ID/EX目标寄存器地址
    output wire       debug_id_ex_reg_we_o,     // 调试: ID/EX写使能
    output wire       debug_id_ex_mem_re_o,     // 调试: ID/EX是否为load
    output wire [4:0] debug_ex_mem_rd_addr_o,   // 调试: EX/MEM目标寄存器地址
    output wire       debug_ex_mem_reg_we_o,    // 调试: EX/MEM写使能
    output wire       debug_ex_mem_mem_re_o     // 调试: EX/MEM是否为load
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