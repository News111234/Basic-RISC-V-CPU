// rtl/periph/timer.v - 修正版（正确的中断逻辑）
`timescale 1ns/1ps

// ============================================================================
// 模块: timer
// 功能: 定时器，提供递减计数和中断功能
// 描述:
//   该模块实现一个32位递减定时器:
//   - 写入LOAD寄存器设置计数初值
//   - 使能后每个时钟周期计数器减1
//   - 计数器减到0时触发中断
//   - 支持单次模式和自动重载模式
//
//   寄存器地址映射:
//     0x00: TIMER_CTRL  - 控制寄存器 (bit0: enable, bit1: auto_reload, bit2: clr_irq)
//     0x04: TIMER_LOAD  - 加载寄存器 (写入初值)
//     0x08: TIMER_COUNT - 当前计数值 (只读)
//     0x0C: TIMER_IER   - 中断使能寄存器 (bit0: irq_enable)
// ============================================================================
module timer (
    // ========== 系统接口 ==========
    input  wire        clk_i,          // 时钟信号
    input  wire        rst_n_i,        // 复位信号 (低电平有效)

    // ========== 总线接口 ==========
    input  wire        we_i,           // 写使能
    input  wire        re_i,           // 读使能
    input  wire [31:0] addr_i,         // 寄存器地址
    input  wire [31:0] wdata_i,        // 写数据
    output reg  [31:0] rdata_o,        // 读数据

    // ========== 中断输出 ==========
    output reg         interrupt_o,    // 定时器中断信号

    // ========== 调试输出 ==========
    output wire [31:0] debug_load_value, // 调试: 加载值
    output wire [31:0] debug_counter,    // 调试: 当前计数值
    output wire        debug_enable,     // 调试: 使能标志
    output wire        debug_irq_flag    // 调试: 中断标志
);

// 寄存器地址偏移
localparam TIMER_CTRL    = 8'h00;
localparam TIMER_LOAD    = 8'h04;
localparam TIMER_COUNT   = 8'h08;
localparam TIMER_IER     = 8'h0C;

reg        enable;
reg        auto_reload;
reg        irq_flag;
reg        irq_enable;
reg [31:0] load_value;
reg [31:0] counter;
reg        just_loaded;  // 新增：标记刚加载，避免立即中断

// 写操作
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        enable      <= 1'b0;
        auto_reload <= 1'b0;
        irq_flag    <= 1'b0;
        irq_enable  <= 1'b0;
        load_value  <= 32'b0;
        counter     <= 32'b0;
        just_loaded <= 1'b0;
    end else if (we_i) begin
        case (addr_i[7:0])
            TIMER_CTRL: begin
                enable      <= wdata_i[0];
                auto_reload <= wdata_i[1];
                if (wdata_i[2]) irq_flag <= 1'b0;   // 写1清除中断标志
            end
            TIMER_LOAD: begin
                load_value <= wdata_i;
                // 如果定时器未使能，写 LOAD 时同步加载计数器
                if (!enable) begin
                    counter <= wdata_i;
                    just_loaded <= 1'b1;
                end
            end
            TIMER_IER:   irq_enable <= wdata_i[0];
            default: ;
        endcase
    end else begin
        // 清除 just_loaded 标志
        just_loaded <= 1'b0;
        
        // 计数器递减逻辑（修正版）
        if (enable && (counter > 1)) begin
            counter <= counter - 1;
        end else if (enable && (counter == 1)) begin
            // 从 1 减到 0，触发中断
            counter <= 0;
            irq_flag <= 1'b1;     // 只有真正从 1 减到 0 才触发中断
        end else if (enable && (counter == 0)) begin
            // 已经在 0，需要重装
            if (auto_reload && !just_loaded) begin
                counter <= load_value;
                // 注意：重装后如果 load_value == 1，下次减到 0 会触发中断
                // 如果 load_value == 0，需要特殊处理避免无限中断
                if (load_value == 0) begin
                    // 如果 load_value = 0，禁用定时器或立即再触发？按规范应停止
                    enable <= 1'b0;
                end
            end else if (!auto_reload) begin
                enable <= 1'b0;   // 单次模式自动停止
            end
        end
    end
end

// 读操作
always @(*) begin
    case (addr_i[7:0])
        TIMER_CTRL:  rdata_o = {29'b0, irq_flag, auto_reload, enable};
        TIMER_LOAD:  rdata_o = load_value;
        TIMER_COUNT: rdata_o = counter;
        TIMER_IER:   rdata_o = {31'b0, irq_enable};
        default:     rdata_o = 32'b0;
    endcase
end

// 中断输出
always @(posedge clk_i) begin
    interrupt_o <= irq_flag && irq_enable;
end

assign debug_load_value = load_value;
assign debug_counter    = counter;
assign debug_enable     = enable;
assign debug_irq_flag   = irq_flag;

endmodule