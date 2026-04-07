// rtl/interrupt/interrupt_controller.v
`timescale 1ns/1ps

module interrupt_controller (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 外部中断源
    input  wire        intr_software_i,   // 软件中断 (来自CLINT)
    input  wire        intr_timer_i,      // 定时器中断 (来自CLINT)
    input  wire        intr_external_i,   // 外部中断 (来自PLIC)
    
    // CSR接口
    input  wire [31:0] mie_i,             // 中断使能
    input  wire [31:0] mip_i,             // 中断待处理
    input  wire [31:0] mstatus_i,         // 状态寄存器
    input  wire [31:0] mtvec_i,           // 中断向量
    
    // 中断请求输出
    output wire        intr_pending_o,    // 有中断等待
    output wire [31:0] intr_cause_o,      // 中断原因
    output wire [31:0] intr_handler_addr_o // 中断处理程序地址
);

// ========== 中断优先级编码 ==========
// RISC-V特权规范：
// 中断ID: 11 = MEI, 7 = MTI, 3 = MSI
// 优先级: MEI > MTI > MSI (但软件可配置)

wire meip = mie_i[11] && mip_i[11];  // 外部中断使能且待处理
wire mtip = mie_i[7]  && mip_i[7];   // 定时器中断使能且待处理
wire msip = mie_i[3]  && mip_i[3];   // 软件中断使能且待处理

// 全局中断使能 (M-mode)
wire global_ie = mstatus_i[3];        // MIE位

// 中断优先级编码
reg [31:0] intr_cause;
reg        intr_valid;

always @(*) begin
    intr_valid = 1'b0;
    intr_cause = 32'b0;
    
    if (global_ie) begin
        // 按优先级检查中断
        if (meip) begin
            intr_valid = 1'b1;
            intr_cause = {1'b1, 31'd11};  // 机器外部中断
        end else if (mtip) begin
            intr_valid = 1'b1;
            intr_cause = {1'b1, 31'd7};   // 机器定时器中断
        end else if (msip) begin
            intr_valid = 1'b1;
            intr_cause = {1'b1, 31'd3};   // 机器软件中断
        end
    end
end

// 中断处理程序地址计算
// mtvec[1:0] 编码模式:
// 00: 直接模式 (所有中断跳转到同一地址)
// 01: 向量模式 (根据中断ID跳转)
wire [1:0] mtvec_mode = mtvec_i[1:0];
wire [31:0] mtvec_base = {mtvec_i[31:2], 2'b0};

reg [31:0] handler_addr;

always @(*) begin
    if (intr_valid) begin
        if (mtvec_mode == 2'b01) begin
            // 向量模式: base + cause*4
            handler_addr = mtvec_base + (intr_cause[4:0] << 2);
        end else begin
            // 直接模式: base
            handler_addr = mtvec_base;
        end
    end else begin
        handler_addr = 32'b0;
    end
end

assign intr_pending_o       = intr_valid;
assign intr_cause_o         = intr_cause;
assign intr_handler_addr_o  = handler_addr;

endmodule
