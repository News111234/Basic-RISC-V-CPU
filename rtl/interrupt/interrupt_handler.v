// rtl/interrupt/interrupt_handler.v
`timescale 1ns/1ps

module interrupt_handler (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 来自流水线的控制
    input  wire        flush_pipeline_i,   // 冲刷流水线
    input  wire        interrupt_taken_i,  // 中断被接受
    
    // 来自中断控制器的信息
    input  wire        intr_pending_i,     // 有中断等待
    input  wire [31:0] intr_cause_i,       // 中断原因
    input  wire [31:0] intr_handler_addr_i, // 中断处理程序地址
    
    // 来自CSR的信息
    input  wire [31:0] mepc_i,              // 异常PC
    input  wire [31:0] mstatus_i,           // 状态寄存器
    
    // 到IFU的跳转信号
    output reg         intr_jump_o,         // 中断跳转
    output reg  [31:0] intr_target_pc_o,    // 中断目标PC
    
    // 到CSR的更新信号
    output reg         csr_mepc_we_o,       // 写MEPC
    output reg  [31:0] csr_mepc_data_o,     // MEPC数据
    output reg         csr_mcause_we_o,     // 写MCAUSE
    output reg  [31:0] csr_mcause_data_o,   // MCAUSE数据
    output reg         csr_mstatus_we_o,    // 写MSTATUS
    output reg  [31:0] csr_mstatus_data_o,  // MSTATUS数据
    
    // 到流水线的控制
    output reg         interrupt_flush_o,   // 冲刷流水线
    output wire        interrupt_handling_o // 正在处理中断
);

// ========== 状态定义 ==========
localparam IDLE      = 2'b00;
localparam PENDING   = 2'b01;
localparam HANDLING  = 2'b10;
localparam COMPLETE  = 2'b11;

reg [1:0] state;
reg [1:0] next_state;

// ========== 中断检测 ==========
reg        intr_pending_reg;
reg [31:0] intr_cause_reg;
reg [31:0] intr_handler_reg;
reg [31:0] current_pc_reg;

always @(posedge clk_i ) begin
    if (!rst_n_i) begin
        intr_pending_reg <= 1'b0;
        intr_cause_reg   <= 32'b0;
        intr_handler_reg <= 32'b0;
        current_pc_reg   <= 32'b0;
    end else begin
        // 锁存中断信息
        if (intr_pending_i && (state == IDLE)) begin
            intr_pending_reg <= 1'b1;
            intr_cause_reg   <= intr_cause_i;
            intr_handler_reg <= intr_handler_addr_i;
            current_pc_reg   <= mepc_i;  // 保存当前PC
        end
        
        // 中断处理后清除
        if (interrupt_taken_i || (state == COMPLETE)) begin
            intr_pending_reg <= 1'b0;
        end
    end
end

// ========== 状态机 ==========
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (intr_pending_reg) begin
                next_state = PENDING;
            end
        end
        
        PENDING: begin
            next_state = HANDLING;
        end
        
        HANDLING: begin
            next_state = COMPLETE;
        end
        
        COMPLETE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

always @(posedge clk_i ) begin
    if (!rst_n_i) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// ========== 输出控制 ==========
always @(*) begin
    // 默认值
    intr_jump_o        = 1'b0;
    intr_target_pc_o   = 32'b0;
    csr_mepc_we_o      = 1'b0;
    csr_mepc_data_o    = 32'b0;
    csr_mcause_we_o    = 1'b0;
    csr_mcause_data_o  = 32'b0;
    csr_mstatus_we_o   = 1'b0;
    csr_mstatus_data_o = 32'b0;
    interrupt_flush_o  = 1'b0;
    
    case (state)
        PENDING: begin
            // 准备中断处理
            // csr_mepc_we_o     = 1'b1;
            // csr_mepc_data_o   = current_pc_reg;
            // csr_mcause_we_o   = 1'b1;
            // csr_mcause_data_o = intr_cause_reg;
            
            // 准备修改MSTATUS
            csr_mstatus_we_o   = 1'b1;
            // 保存当前MIE到MPIE，清除MIE
            csr_mstatus_data_o[3] = 1'b0;                    // MIE = 0
            csr_mstatus_data_o[7] = mstatus_i[3];            // MPIE = old MIE
            csr_mstatus_data_o[12:11] = 2'b11;               // MPP = 3 (M-mode)
            csr_mstatus_data_o[31:13] = mstatus_i[31:13];    // 其他位不变
        end
        
        HANDLING: begin
            // 执行中断跳转
            intr_jump_o      = 1'b1;
            intr_target_pc_o = intr_handler_reg;
            interrupt_flush_o = 1'b1;
        end
        
        default: begin
            // 其他状态无操作
        end
    endcase
end

assign interrupt_handling_o = (state != IDLE);

endmodule
