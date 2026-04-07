// rtl/periph/timer.v - 修正版（正确的中断逻辑）
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