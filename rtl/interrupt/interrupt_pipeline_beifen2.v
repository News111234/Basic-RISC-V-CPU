// rtl/interrupt/interrupt_pipeline.v - 修正版（单周期中断响应）
`timescale 1ns/1ps

module interrupt_pipeline (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 来自IFU的PC
    input  wire [31:0] if_pc_i,
    
    // 来自ID的指令信息
    input  wire        id_valid_i,
    input  wire [31:0] id_pc_i,
    
    // 来自EX的指令信息
    input  wire        ex_valid_i,
    input  wire [31:0] ex_pc_i,
    input  wire        ex_branch_taken_i,
    input  wire        ex_jump_taken_i,
    
    // 来自MEM的指令信息
    input  wire        mem_valid_i,
    input  wire [31:0] mem_pc_i,
    input  wire        mem_mem_re_i,
    input  wire        mem_mem_we_i,
    
    // 来自WB的指令信息
    input  wire        wb_valid_i,
    input  wire [4:0]  wb_rd_addr_i,
    input  wire        wb_reg_we_i,
    
    // 中断请求
    input  wire        intr_pending_i,
    input  wire [31:0] intr_cause_i,
    
    // 到CSR的更新信号
    output reg         csr_mepc_we_o,
    output reg  [31:0] csr_mepc_data_o,
    output reg         csr_mcause_we_o,
    output reg  [31:0] csr_mcause_data_o,
    
    // 到流水线的控制
    output reg         interrupt_taken_o,
    output reg         interrupt_flush_o,
    output reg  [31:0] interrupt_pc_o,
    
    // 调试输出
    output wire        debug_interrupt_accepted,
    output wire [1:0]  debug_interrupt_hold_cnt,
    output wire        debug_interrupt_condition,
    output wire [4:0]  debug_interrupt_condition_bits,
    output wire [31:0] debug_selected_pc,
    output wire [2:0]  debug_selected_stage
);

// ========== 中断接受条件 ==========
wire [4:0] interrupt_condition;

assign interrupt_condition[0] = intr_pending_i;
assign interrupt_condition[1] = ~(ex_branch_taken_i || ex_jump_taken_i);
assign interrupt_condition[2] = ~mem_mem_re_i;
assign interrupt_condition[3] = 1'b1;
assign interrupt_condition[4] = 1'b1;

wire interrupt_condition_all = &interrupt_condition;

// ========== 中断PC选择（优先级：MEM > EX > ID > IF）==========
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

// ========== 中断处理状态机（修正版：单周期响应）==========
reg         interrupt_accepted;
reg [31:0]  saved_interrupt_pc;
reg [31:0]  saved_interrupt_cause;

always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        interrupt_accepted    <= 1'b0;
        saved_interrupt_pc    <= 32'b0;
        saved_interrupt_cause <= 32'b0;
        
        csr_mepc_we_o         <= 1'b0;
        csr_mepc_data_o       <= 32'b0;
        csr_mcause_we_o       <= 1'b0;
        csr_mcause_data_o     <= 32'b0;
        interrupt_taken_o     <= 1'b0;
        interrupt_flush_o     <= 1'b0;
        interrupt_pc_o        <= 32'b0;
        
    end else begin
        // 默认值
        csr_mepc_we_o     <= 1'b0;
        csr_mcause_we_o   <= 1'b0;
        interrupt_taken_o <= 1'b0;
        interrupt_flush_o <= 1'b0;
        
        // ========== 中断接受逻辑（单周期）==========
        if (interrupt_condition_all && !interrupt_accepted) begin
            interrupt_accepted    <= 1'b1;
            saved_interrupt_pc    <= interrupt_pc;
            saved_interrupt_cause <= intr_cause_i;
            
            // 本周期写入CSR
            csr_mepc_we_o   <= 1'b1;
            csr_mepc_data_o <= interrupt_pc;
            csr_mcause_we_o <= 1'b1;
            csr_mcause_data_o <= intr_cause_i;
            
            // 本周期输出中断控制信号（单周期脉冲）
            interrupt_taken_o <= 1'b1;
            interrupt_flush_o <= 1'b1;
            interrupt_pc_o    <= interrupt_pc;
            
            $display("[INTERRUPT_PIPELINE] Interrupt taken at time %0t: PC=%h, Cause=%h", 
                     $time, interrupt_pc, intr_cause_i);
        end
        // 下一个周期清除 accepted 标志
        else if (interrupt_accepted) begin
            interrupt_accepted <= 1'b0;
            $display("[INTERRUPT_PIPELINE] Interrupt accepted flag cleared at time %0t", $time);
        end
    end
end

// ========== 调试输出 ==========
assign debug_interrupt_accepted       = interrupt_accepted;
assign debug_interrupt_hold_cnt       = 2'b00;  // 不再使用保持计数器
assign debug_interrupt_condition      = interrupt_condition_all;
assign debug_interrupt_condition_bits = interrupt_condition;
assign debug_selected_pc              = interrupt_pc;
assign debug_selected_stage           = selected_stage;

endmodule