// rtl/periph/uart_ctrl.v - 循环发送Hello World版本
`timescale 1ns/1ps

// ============================================================================
// 模块: uart_ctrl
// 功能: UART控制器，带FIFO缓冲，实现串口数据发送
// 描述:
//   该模块实现UART发送控制器，具有以下特性:
//   - 内置16字节FIFO，减少CPU干预
//   - 自动波特率生成 (可配置)
//   - 状态寄存器提供FIFO状态和发送状态
//   - 支持中断(预留)
//
//   寄存器地址映射:
//     0x00: TX_DATA - 发送数据寄存器 (写入即入FIFO)
//     0x04: STATUS  - 状态寄存器 (只读)
//     0x08: CTRL    - 控制寄存器 (bit0: tx_enable, bit1: tx_irq_enable)
//     0x0C: BAUD_DIV - 波特率分频系数
//
//   状态寄存器位定义:
//     [0]: tx_ready    - 发送器空闲
//     [1]: tx_busy     - 正在发送
//     [2]: fifo_not_full - FIFO未满
//     [3]: fifo_empty  - FIFO空
//     [4]: fifo_full   - FIFO满
//     [7:5]: fifo_count - FIFO中的数据个数
// ============================================================================
module uart_ctrl #(
    parameter CLK_FREQ = 200_000_000,      // 时钟频率 (Hz)
    parameter BAUD_RATE = 115200,          // 波特率
    parameter FIFO_DEPTH = 16,             // FIFO深度
    parameter FIFO_ADDR_WIDTH = 4          // FIFO地址宽度
) (
    // ========== 系统接口 ==========
    input  wire        clk_i,             // 时钟信号
    input  wire        rst_n_i,           // 复位信号 (低电平有效)

    // ========== CPU总线接口 ==========
    input  wire        we_i,              // 写使能
    input  wire [31:0] addr_i,            // 寄存器地址
    input  wire [31:0] wdata_i,           // 写数据
    output reg  [31:0] rdata_o,           // 读数据

    // ========== 串口物理接口 ==========
    output wire        tx_pin_o,          // 串口TX引脚

    // ========== 调试输出 ==========
    output wire [1:0]  debug_state_o,     // 调试: UART状态机
    output wire [31:0] debug_baud_cnt_o,  // 调试: 波特率计数器
    output wire [3:0]  debug_bit_cnt_o,   // 调试: 位计数器
    output wire [7:0]  debug_shift_reg_o, // 调试: 移位寄存器
    output wire [7:0]  tx_data_o,         // 调试: 发送数据
    output wire        tx_valid_o,        // 调试: 发送有效
    // ... (debug_fifo_data1_o 到 debug_fifo_data15_o)
    // ========== FIFO调试信号 ==========
    output wire [7:0]  debug_fifo_data0_o,
    output wire [7:0]  debug_fifo_data1_o,
    output wire [7:0]  debug_fifo_data2_o,
    output wire [7:0]  debug_fifo_data3_o,
    output wire [7:0]  debug_fifo_data4_o,
    output wire [7:0]  debug_fifo_data5_o,
    output wire [7:0]  debug_fifo_data6_o,
    output wire [7:0]  debug_fifo_data7_o,
    output wire [7:0]  debug_fifo_data8_o,
    output wire [7:0]  debug_fifo_data9_o,
    output wire [7:0]  debug_fifo_data10_o,
    output wire [7:0]  debug_fifo_data11_o,
    output wire [7:0]  debug_fifo_data12_o,
    output wire [7:0]  debug_fifo_data13_o,
    output wire [7:0]  debug_fifo_data14_o,
    output wire [7:0]  debug_fifo_data15_o,

    output wire        debug_fifo_we_reg_o, // 调试: FIFO写使能
    output wire [3:0]  debug_wr_ptr_o,     // 调试: 写指针
    output wire [3:0]  debug_rd_ptr_o,     // 调试: 读指针
    output wire [4:0]  debug_fifo_count_o, // 调试: FIFO计数
    output wire        debug_fifo_full_o,  // 调试: FIFO满
    output wire        debug_fifo_empty_o, // 调试: FIFO空
    output wire        debug_fifo_we_o,    // 调试: FIFO写
    output wire        debug_fifo_re_o,    // 调试: FIFO读
    output wire [7:0]  debug_fifo_out_data_o, // 调试: FIFO输出
    output wire        direct_transfer_o,  // 调试: 直通标志
    output wire [7:0]  data_to_send_o,     // 调试: 待发送数据
    output wire        tx_ready_o          // 调试: 发送器就绪
);

// ========== 寄存器地址定义 ==========
localparam REG_TX_DATA  = 32'h0;
localparam REG_STATUS   = 32'h4;
localparam REG_CTRL     = 32'h8;
localparam REG_BAUD_DIV = 32'hC;

// ========== 内部信号声明 ==========
wire        tx_ready;
reg         tx_valid_reg;
reg  [7:0]  tx_data_reg;

// FIFO信号
reg  [7:0]  fifo_mem [0:FIFO_DEPTH-1];
reg  [FIFO_ADDR_WIDTH-1:0] wr_ptr;
reg  [FIFO_ADDR_WIDTH-1:0] rd_ptr;
reg  [FIFO_ADDR_WIDTH:0]   fifo_count;
wire        fifo_full;
wire        fifo_empty;

// 控制寄存器
reg         tx_enable;
reg         tx_irq_enable;
reg  [15:0] baud_divider;

// 写事务检测逻辑
reg        we_active;
reg [31:0] active_wdata;
reg        write_processed;
reg        debug_fifo_we_reg;

// 带环绕的指针
wire [FIFO_ADDR_WIDTH-1:0] next_wr_ptr;
wire [FIFO_ADDR_WIDTH-1:0] next_rd_ptr;

// 计算下一个写指针（带环绕）
assign next_wr_ptr = (wr_ptr == FIFO_DEPTH-1) ? {(FIFO_ADDR_WIDTH){1'b0}} : (wr_ptr + 1);

// 计算下一个读指针（带环绕）
assign next_rd_ptr = (rd_ptr == FIFO_DEPTH-1) ? {(FIFO_ADDR_WIDTH){1'b0}} : (rd_ptr + 1);

// ========== UART发送状态机 ==========
reg [2:0] uart_state;
localparam UART_IDLE      = 3'b000;
localparam UART_SENDING   = 3'b001;
localparam UART_COMPLETE  = 3'b010;
localparam UART_CLEANUP   = 3'b011;

// ========== 精确时间控制 ==========
localparam REAL_CYCLES_PER_BIT = (CLK_FREQ + BAUD_RATE/2) / BAUD_RATE;
localparam REAL_CYCLES_PER_CHAR = 10 * REAL_CYCLES_PER_BIT;

reg [31:0] send_cycle_counter;
reg        char_sending;

integer i;

// 字符计数器相关信号
reg [4:0] char_write_count;
reg [4:0] char_read_count;
reg       char_limit_reached;
reg       read_loop_enabled;

// ============================================================================
// 1. 写事务检测和FIFO管理
// ============================================================================

assign fifo_full  = (fifo_count == FIFO_DEPTH);
assign fifo_empty = (fifo_count == 0);

always @(posedge clk_i) begin
    if (!rst_n_i) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        fifo_count <= 0;
        tx_data_reg <= 8'b0;
        tx_valid_reg <= 1'b0;
        uart_state <= UART_IDLE;
        send_cycle_counter <= 0;
        char_sending <= 1'b0;
        
        we_active <= 1'b0;
        active_wdata <= 32'h0;
        write_processed <= 1'b0;
        debug_fifo_we_reg <= 1'b0;

        char_write_count <= 5'b0;
        char_read_count <= 5'b0;
        char_limit_reached <= 1'b0;
        read_loop_enabled <= 1'b0;
        
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            fifo_mem[i] <= 8'b0;
        end
    end else begin
        debug_fifo_we_reg <= 1'b0;
        
        // 写事务检测
        if (we_i && !we_active) begin
            we_active <= 1'b1;
            active_wdata <= wdata_i;
            write_processed <= 1'b0;
        end
        
        if (!we_i && we_active) begin
            we_active <= 1'b0;
            write_processed <= 1'b0;
        end
        
        // FIFO写操作
        if (we_active && !write_processed && 
            (addr_i[3:0] == REG_TX_DATA[3:0]) && 
            tx_enable && !fifo_full && !char_limit_reached) begin

            fifo_mem[wr_ptr] <= wdata_i[7:0];
            wr_ptr <= next_wr_ptr;
            fifo_count <= fifo_count + 1;
            write_processed <= 1'b1;
            debug_fifo_we_reg <= 1'b1;

            // 更新字符写入计数器
            if (char_write_count < 5'd12) begin
                char_write_count <= char_write_count + 5'b1;
            end else begin
                char_write_count <= 5'd12;
                char_limit_reached <= 1'b1;
            end
        end
        
        // UART发送状态机
        case (uart_state)
            UART_IDLE: begin
                tx_valid_reg <= 1'b0;
                send_cycle_counter <= 0;
                char_sending <= 1'b0;

                if (tx_ready && (fifo_count != 0) && tx_enable) begin
                    tx_data_reg <= fifo_mem[rd_ptr];
                    tx_valid_reg <= 1'b1;
                    uart_state <= UART_SENDING;
                    char_sending <= 1'b1;
                end
            end
            
            UART_SENDING: begin
                tx_valid_reg <= 1'b1;
                send_cycle_counter <= send_cycle_counter + 1;
                
                if (send_cycle_counter >= REAL_CYCLES_PER_CHAR) begin
                    tx_valid_reg <= 1'b0;
                    uart_state <= UART_COMPLETE;
                end
            end
            
            UART_COMPLETE: begin
                tx_valid_reg <= 1'b0;
                
                if (tx_ready) begin
                    char_sending <= 1'b0;
                    
                    // 处理字符读取计数和循环逻辑
                    if (char_read_count < 5'd12) begin
                        // 正常读取下一个字符
                        char_read_count <= char_read_count + 5'b1;
                        rd_ptr <= next_rd_ptr;
                        fifo_count <= fifo_count - 1;
                    end else begin
                        // 第13个字符发送完成，重置开始循环
                        char_read_count <= 5'b0;
                        rd_ptr <= 5'b0;
                        
                        // 关键：重置fifo_count为13，表示可以重新开始读取
                        fifo_count <= 5'd13;
                        read_loop_enabled <= 1'b1;
                    end
                    
                    // 决定下一个状态
                    if (fifo_count > 1 || read_loop_enabled) begin
                        uart_state <= UART_CLEANUP;
                    end else begin
                        uart_state <= UART_IDLE;
                    end
                end
            end
            
            UART_CLEANUP: begin
                tx_valid_reg <= 1'b0;
                
                if (tx_ready && (fifo_count != 0) && tx_enable) begin
                    tx_data_reg <= fifo_mem[rd_ptr];
                    tx_valid_reg <= 1'b1;
                    send_cycle_counter <= 0;
                    uart_state <= UART_SENDING;
                    char_sending <= 1'b1;
                end else begin
                    uart_state <= UART_IDLE;
                end
            end
            
            default: begin
                uart_state <= UART_IDLE;
                tx_valid_reg <= 1'b0;
                char_sending <= 1'b0;
            end
        endcase
    end
end

// ============================================================================
// 2. UART发送器实例化
// ============================================================================

uart_tx #(
    .CLK_FREQ  (CLK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) u_uart_tx (
    .clk_i      (clk_i),
    .rst_n_i    (rst_n_i),
    .tx_data_i  (tx_data_reg),
    .tx_valid_i (tx_valid_reg),
    .tx_ready_o (tx_ready),
    .tx_pin_o   (tx_pin_o),
    .debug_state_o     (debug_state_o),
    .debug_baud_cnt_o  (debug_baud_cnt_o),
    .debug_bit_cnt_o   (debug_bit_cnt_o),
    .debug_shift_reg_o (debug_shift_reg_o)
);

// ============================================================================
// 3. 寄存器读写接口
// ============================================================================

initial begin
    tx_enable = 1'b1;
    tx_irq_enable = 1'b0;
    baud_divider = CLK_FREQ / BAUD_RATE;
end

always @(posedge clk_i) begin
    if (!rst_n_i) begin
        tx_enable <= 1'b1;
        tx_irq_enable <= 1'b0;
        baud_divider <= CLK_FREQ / BAUD_RATE;
        rdata_o <= 32'b0;
    end else begin
        rdata_o <= {24'b0,
                   fifo_count,
                   1'b0,
                   fifo_full,
                   fifo_empty,
                   !fifo_full,
                   char_sending,
                   1'b0,
                   tx_ready,
                   tx_valid_reg};
        
        if (we_i) begin
            case (addr_i[3:0])
                REG_TX_DATA[3:0]: begin
                    // 已在FIFO部分处理
                end
                
                REG_CTRL[3:0]: begin
                    tx_enable <= wdata_i[0];
                    tx_irq_enable <= wdata_i[1];
                end
                
                REG_BAUD_DIV[3:0]: begin
                    baud_divider <= wdata_i[15:0];
                end
            endcase
        end
    end
end

// ============================================================================
// 4. 调试信号连接
// ============================================================================

assign tx_data_o = tx_data_reg;
assign tx_valid_o = tx_valid_reg;
assign tx_ready_o = tx_ready;

assign debug_fifo_data0_o = fifo_mem[0];
assign debug_fifo_data1_o = fifo_mem[1];
assign debug_fifo_data2_o = fifo_mem[2];
assign debug_fifo_data3_o = fifo_mem[3];
assign debug_fifo_data4_o = fifo_mem[4];
assign debug_fifo_data5_o = fifo_mem[5];
assign debug_fifo_data6_o = fifo_mem[6];
assign debug_fifo_data7_o = fifo_mem[7];
assign debug_fifo_data8_o = fifo_mem[8];
assign debug_fifo_data9_o = fifo_mem[9];
assign debug_fifo_data10_o = fifo_mem[10];
assign debug_fifo_data11_o = fifo_mem[11];
assign debug_fifo_data12_o = fifo_mem[12];
assign debug_fifo_data13_o = fifo_mem[13];
assign debug_fifo_data14_o = fifo_mem[14];
assign debug_fifo_data15_o = fifo_mem[15];

assign debug_fifo_we_reg_o = debug_fifo_we_reg;

assign debug_wr_ptr_o = wr_ptr;
assign debug_rd_ptr_o = rd_ptr;
assign debug_fifo_count_o = fifo_count;
assign debug_fifo_full_o = fifo_full;
assign debug_fifo_empty_o = fifo_empty;

assign debug_fifo_we_o = debug_fifo_we_reg;
assign debug_fifo_re_o = (uart_state == UART_SENDING) && (send_cycle_counter >= REAL_CYCLES_PER_CHAR) && tx_ready;

assign debug_fifo_out_data_o = fifo_mem[rd_ptr];

assign direct_transfer_o = 1'b0;
assign data_to_send_o = 8'b0;

endmodule