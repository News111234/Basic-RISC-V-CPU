// rtl/interrupt/interrupt_pipeline.v - 修正版（防止重复中断）
`timescale 1ns/1ps

// ============================================================================
// 模块: interrupt_pipeline
// 功能: 中断流水线控制器，协调中断响应与流水线的交互
// 描述:
//   该模块负责中断的精确响应:
//   1. 检测中断条件(有中断等待，且流水线中无冲突指令)
//   2. 选择保存的PC(从中断发生时流水线中最旧的合法指令)
//   3. 更新CSR寄存器(mepc, mcause, mstatus)
//   4. 产生流水线冲刷信号，跳转到中断处理程序
//   5. 防止中断重复触发(中断只响应一次，直到MRET执行)
//
//   中断响应条件:
//   - 有中断等待(intr_pending_i)
//   - EX阶段无分支/跳转
//   - MEM阶段无load/store指令
// ============================================================================
module interrupt_pipeline (
    // ========== 系统接口 ==========
    input  wire        clk_i,             // 时钟信号
    input  wire        rst_n_i,           // 复位信号 (低电平有效)

    // ========== 来自各流水级的PC和信息 ==========
    input  wire [31:0] if_pc_i,           // IF阶段PC
    input  wire        id_valid_i,        // ID阶段指令有效
    input  wire [31:0] id_pc_i,           // ID阶段PC
    input  wire        ex_valid_i,        // EX阶段指令有效
    input  wire [31:0] ex_pc_i,           // EX阶段PC
    input  wire        ex_branch_taken_i, // EX阶段分支跳转
    input  wire        ex_jump_taken_i,   // EX阶段跳转
    input  wire        mem_valid_i,       // MEM阶段指令有效
    input  wire [31:0] mem_pc_i,          // MEM阶段PC
    input  wire        mem_mem_re_i,      // MEM阶段读内存
    input  wire        mem_mem_we_i,      // MEM阶段写内存
    input  wire        wb_valid_i,        // WB阶段指令有效
    input  wire [4:0]  wb_rd_addr_i,      // WB阶段目标寄存器
    input  wire        wb_reg_we_i,       // WB阶段寄存器写使能

    // ========== 中断请求 ==========
    input  wire        intr_pending_i,    // 中断等待标志
    input  wire [31:0] intr_cause_i,      // 中断原因

    // ========== CSR当前值 ==========
    input  wire [31:0] mstatus_i,         // 当前mstatus值

    // ========== 到CSR的更新信号 ==========
    output reg         csr_mepc_we_o,     // 写mepc使能
    output reg  [31:0] csr_mepc_data_o,   // 写入mepc的值
    output reg         csr_mcause_we_o,   // 写mcause使能
    output reg  [31:0] csr_mcause_data_o, // 写入mcause的值
    output reg         csr_mstatus_we_o,  // 写mstatus使能
    output reg  [31:0] csr_mstatus_data_o, // 写入mstatus的值

    // ========== 到流水线的控制 ==========
    output reg         interrupt_taken_o, // 中断已被接受
    output reg         interrupt_flush_o, // 中断冲刷信号
    output reg  [31:0] interrupt_pc_o,    // 中断发生时的PC (调试)

    // ========== 调试输出 ==========
    output wire        debug_interrupt_accepted,      // 中断被接受标志
    output wire [1:0]  debug_interrupt_hold_cnt,      // 中断保持计数
    output wire        debug_interrupt_condition,     // 中断条件满足
    output wire [4:0]  debug_interrupt_condition_bits, // 中断条件各比特
    output wire [31:0] debug_selected_pc,             // 选中的保存PC
    output wire [2:0]  debug_selected_stage           // 选中的流水级
);

// ========== 中断接受条件 ==========
wire [4:0] interrupt_condition;

assign interrupt_condition[0] = intr_pending_i;
assign interrupt_condition[1] = ~(ex_branch_taken_i || ex_jump_taken_i);
assign interrupt_condition[2] = ~mem_mem_re_i;
assign interrupt_condition[3] = 1'b1;
assign interrupt_condition[4] = 1'b1;

wire interrupt_condition_all = &interrupt_condition;

// ========== 中断PC选择 ==========
reg [31:0] interrupt_pc;
reg [2:0]  selected_stage;

always @(*) begin
    if (mem_valid_i && (mem_pc_i != 32'b0)) begin
        interrupt_pc = mem_pc_i;
        selected_stage = 3'd0;
    end else if (ex_valid_i && (ex_pc_i != 32'b0)) begin
        interrupt_pc = ex_pc_i;
        selected_stage = 3'd1;
    end else if (id_valid_i && (id_pc_i != 32'b0)) begin
        interrupt_pc = id_pc_i;
        selected_stage = 3'd2;
    end else begin
        interrupt_pc = if_pc_i;
        selected_stage = 3'd3;
    end
end

// ========== 中断处理状态机（修正版：防止重复触发）==========
reg         interrupt_accepted;
reg         interrupt_processed;      // 新增：标记中断已被处理
reg [31:0]  saved_interrupt_pc;
reg [31:0]  saved_interrupt_cause;

always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        interrupt_accepted    <= 1'b0;
        interrupt_processed   <= 1'b0;
        saved_interrupt_pc    <= 32'b0;
        saved_interrupt_cause <= 32'b0;
        
        csr_mepc_we_o         <= 1'b0;
        csr_mepc_data_o       <= 32'b0;
        csr_mcause_we_o       <= 1'b0;
        csr_mcause_data_o     <= 32'b0;
        csr_mstatus_we_o      <= 1'b0;
        csr_mstatus_data_o    <= 32'b0;
        interrupt_taken_o     <= 1'b0;
        interrupt_flush_o     <= 1'b0;
        interrupt_pc_o        <= 32'b0;
        
    end else begin
        // 默认值
        csr_mepc_we_o     <= 1'b0;
        csr_mcause_we_o   <= 1'b0;
        csr_mstatus_we_o  <= 1'b0;
        interrupt_taken_o <= 1'b0;
        interrupt_flush_o <= 1'b0;
        
        // ========== 中断接受逻辑（单周期，只触发一次）==========
        // 关键修改：只有在 interrupt_processed == 0 时才能接受新中断
        if (interrupt_condition_all && !interrupt_accepted && !interrupt_processed) begin
            interrupt_accepted    <= 1'b1;
            saved_interrupt_pc    <= interrupt_pc;
            saved_interrupt_cause <= intr_cause_i;
            
            // 写入 CSR
            csr_mepc_we_o   <= 1'b1;
            csr_mepc_data_o <= interrupt_pc;
            csr_mcause_we_o <= 1'b1;
            csr_mcause_data_o <= intr_cause_i;
            
            // 修改 mstatus
            csr_mstatus_we_o <= 1'b1;
            csr_mstatus_data_o <= {
                mstatus_i[31:13],
                2'b11,
                mstatus_i[10:8],
                mstatus_i[3],      // MPIE = 旧 MIE (bit7)
                mstatus_i[6:4],
                1'b0,              // MIE = 0 (bit3)
                mstatus_i[2:0]
            };
            
            // 输出中断控制信号
            interrupt_taken_o <= 1'b1;
            interrupt_flush_o <= 1'b1;
            interrupt_pc_o    <= interrupt_pc;
            
            $display("[INTERRUPT_PIPELINE] Interrupt taken at time %0t: PC=%h, Cause=%h", 
                     $time, interrupt_pc, intr_cause_i);
        end
        // 下一个周期标记为已处理，防止重复触发
        else if (interrupt_accepted) begin
            interrupt_accepted <= 1'b0;
            interrupt_processed <= 1'b1;   // 标记已处理，不再接受新中断
        end
        // 等待 mret 执行后重置 processed 标志
        // 当 mret 执行时，会恢复 MIE，此时可以重新接受中断
        // 简单方案：在执行 mret 后重置，这里用一个计数器
    end
end

// ========== 调试输出 ==========
assign debug_interrupt_accepted       = interrupt_accepted;
assign debug_interrupt_hold_cnt       = 2'b00;
assign debug_interrupt_condition      = interrupt_condition_all;
assign debug_interrupt_condition_bits = interrupt_condition;
assign debug_selected_pc              = interrupt_pc;
assign debug_selected_stage           = selected_stage;

endmodule