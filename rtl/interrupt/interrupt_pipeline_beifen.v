// rtl/interrupt/interrupt_pipeline.v - 修复版（优先使用最深流水线阶段）
`timescale 1ns/1ps

module interrupt_pipeline (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 来自IFU的PC
    input  wire [31:0] if_pc_i,
    
    // 来自ID的指令信息
    input  wire        id_valid_i,        // ID阶段指令有效
    input  wire [31:0] id_pc_i,           // ID阶段PC
    
    // 来自EX的指令信息
    input  wire        ex_valid_i,        // EX阶段指令有效
    input  wire [31:0] ex_pc_i,           // EX阶段PC
    input  wire        ex_branch_taken_i, // EX分支跳转
    input  wire        ex_jump_taken_i,   // EX跳转
    
    // 来自MEM的指令信息
    input  wire        mem_valid_i,       // MEM阶段指令有效
    input  wire [31:0] mem_pc_i,          // MEM阶段PC
    input  wire        mem_mem_re_i,      // MEM读内存
    input  wire        mem_mem_we_i,      // MEM写内存
    
    // 来自WB的指令信息
    input  wire        wb_valid_i,        // WB阶段指令有效
    input  wire [4:0]  wb_rd_addr_i,      // WB目标寄存器
    input  wire        wb_reg_we_i,       // WB写寄存器
    
    // 中断请求
    input  wire        intr_pending_i,    // 中断请求
    input  wire [31:0] intr_cause_i,      // 中断原因
    
    // 到CSR的更新信号
    output reg         csr_mepc_we_o,     // 写MEPC
    output reg  [31:0] csr_mepc_data_o,   // MEPC数据
    output reg         csr_mcause_we_o,   // 写MCAUSE
    output reg  [31:0] csr_mcause_data_o, // MCAUSE数据
    
    // 到流水线的控制
    output reg         interrupt_taken_o, // 中断被接受（延长保持）
    output reg         interrupt_flush_o, // 冲刷流水线（延长保持）
    output reg  [31:0] interrupt_pc_o,    // 中断PC（用于MEPC）
    
    // ========== 新增调试输出 ==========
    output wire        debug_interrupt_accepted,    // 中断被接受标志
    output wire [1:0]  debug_interrupt_hold_cnt,    // 中断保持计数器
    output wire        debug_interrupt_condition,   // 中断条件满足
    output wire [4:0]  debug_interrupt_condition_bits, // 中断条件各bit
    output wire [31:0] debug_selected_pc,           // 被选中的PC
    output wire [2:0]  debug_selected_stage         // 哪个阶段被选中 (0=MEM,1=EX,2=ID,3=IF)
);

// ========== 中断接受条件 ==========
// 只有在流水线中没有异常且指令完整执行时才接受中断
wire [4:0] interrupt_condition;

assign interrupt_condition[0] = intr_pending_i;                              // 有中断请求
assign interrupt_condition[1] = ~(ex_branch_taken_i || ex_jump_taken_i);    // 没有分支/跳转冒险
assign interrupt_condition[2] = ~mem_mem_re_i;                              // 没有加载使用冒险
assign interrupt_condition[3] = 1'b1;                                       // 暂无条件
assign interrupt_condition[4] = 1'b1;                                       // 暂无条件

wire interrupt_condition_all = &interrupt_condition;

// ========== 中断PC选择（修改版：优先使用最深流水线阶段） ==========
// 优先级：MEM > EX > ID > IF
// 因为越深的阶段 PC 越稳定，且中断通常在指令边界被接受
reg [31:0] interrupt_pc;
reg [2:0]  selected_stage;  // 调试用

always @(*) begin
    // 优先选择最深的有效流水线阶段
    if (mem_valid_i && (mem_pc_i != 32'b0)) begin
        interrupt_pc = mem_pc_i;
        selected_stage = 3'd0;  // MEM
    end else if (ex_valid_i && (ex_pc_i != 32'b0)) begin
        interrupt_pc = ex_pc_i;
        selected_stage = 3'd1;  // EX
    end else if (id_valid_i && (id_pc_i != 32'b0)) begin
        interrupt_pc = id_pc_i;
        selected_stage = 3'd2;  // ID
    end else begin
        interrupt_pc = if_pc_i;
        selected_stage = 3'd3;  // IF
    end
end

// ========== 中断处理状态机（延长保持版本） ==========
reg         interrupt_accepted;
reg [1:0]   interrupt_hold_cnt;      // 中断信号保持计数器
reg [31:0]  saved_interrupt_pc;      // 保存的中断PC
reg [31:0]  saved_interrupt_cause;   // 保存的中断原因

always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        interrupt_accepted    <= 1'b0;
        interrupt_hold_cnt    <= 2'b00;
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
        
        // ========== 中断信号保持逻辑 ==========
        if (interrupt_hold_cnt > 0) begin
            interrupt_hold_cnt <= interrupt_hold_cnt - 1;
            interrupt_taken_o  <= 1'b1;
            interrupt_flush_o  <= 1'b1;
            interrupt_pc_o     <= saved_interrupt_pc;
        end
        
        // ========== 中断接受逻辑 ==========
        // 当条件满足且没有正在处理的中断时，接受中断
        if (interrupt_condition_all && !interrupt_accepted && (interrupt_hold_cnt == 0)) begin
            interrupt_accepted    <= 1'b1;
            saved_interrupt_pc    <= interrupt_pc;
            saved_interrupt_cause <= intr_cause_i;
            
            // 立即写入CSR（在同一个周期）
            csr_mepc_we_o   <= 1'b1;
            csr_mepc_data_o <= interrupt_pc;
            csr_mcause_we_o <= 1'b1;
            csr_mcause_data_o <= intr_cause_i;
            
            $display("[INTERRUPT_PIPELINE] Interrupt accepted at time %0t: PC=%h (stage=%d), Cause=%h", 
                     $time, interrupt_pc, selected_stage, intr_cause_i);
        end
        // 在下一个周期设置中断信号并保持
        else if (interrupt_accepted) begin
            interrupt_accepted <= 1'b0;
            // 设置中断信号保持2个完整周期，确保IFU能捕获
            interrupt_hold_cnt <= 2'b10;  // 保持2个周期
            interrupt_taken_o  <= 1'b1;
            interrupt_flush_o  <= 1'b1;
            interrupt_pc_o     <= saved_interrupt_pc;
            
            $display("[INTERRUPT_PIPELINE] Interrupt taken at time %0t, hold for 2 cycles", $time);
        end
    end
end

// ========== 调试输出 ==========
assign debug_interrupt_accepted      = interrupt_accepted;
assign debug_interrupt_hold_cnt      = interrupt_hold_cnt;
assign debug_interrupt_condition     = interrupt_condition_all;
assign debug_interrupt_condition_bits = interrupt_condition;
assign debug_selected_pc             = interrupt_pc;
assign debug_selected_stage          = selected_stage;

endmodule