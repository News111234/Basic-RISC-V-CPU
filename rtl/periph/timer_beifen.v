// rtl/periph/timer.v - 可编程定时器（支持中断）
`timescale 1ns/1ps

module timer (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 总线接口
    input  wire        we_i,
    input  wire        re_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,
    
    // 中断输出
    output reg         interrupt_o,

    output wire [31:0] debug_load_value,
output wire [31:0] debug_counter,
output wire        debug_enable,
output wire        debug_irq_flag
);

// 寄存器地址偏移
localparam TIMER_CTRL    = 8'h00;   // 控制寄存器
localparam TIMER_LOAD    = 8'h04;   // 自动重装载值(写入后，计数器会立即加载此值)
localparam TIMER_COUNT   = 8'h08;   // 当前计数值（只读）
localparam TIMER_IER     = 8'h0C;   // 中断使能

// 控制寄存器位定义
// bit0: 使能计数 (1=运行, 0=停止)
// bit1: 自动重装载 (1=自动重装, 0=单次)
// bit2: 中断标志 (写1清除)

reg        enable;          // 计数器使能
reg        auto_reload;     // 自动重装载
reg        irq_flag;        // 中断标志
reg        irq_enable;      // 中断使能
reg [31:0] load_value;      // 重装载值
reg [31:0] counter;         // 当前计数值
reg        just_loaded;  // 标记刚加载，避免立即中断,避免复位阶段刚结束就触发中断

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
            TIMER_LOAD:  load_value <= wdata_i;
            TIMER_IER:   irq_enable <= wdata_i[0];
            default: ;
        endcase
    end else begin
        // 计数器递减逻辑
        if (enable && (counter > 0)) begin
            counter <= counter - 1;
        end else if (enable && (counter == 0)) begin
            // 计数器到零
            if (auto_reload) begin
                counter <= load_value;
            end else begin
                enable <= 1'b0;   // 单次模式自动停止
            end
            irq_flag <= 1'b1;     // 产生中断标志
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