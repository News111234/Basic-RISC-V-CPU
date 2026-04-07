// bus_arbiter.v - 支持 RAM、UART、GPIO、Timer
`timescale 1ns/1ps

module bus_arbiter (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // CPU内存接口
    input  wire        mem_re_i,
    input  wire        mem_we_i,
    input  wire [31:0] mem_addr_i,
    input  wire [31:0] mem_wdata_i,
    input  wire [2:0]  mem_width_i,
    
    output reg  [31:0] mem_rdata_o,
    output wire        mem_ready_o,
    
    // 数据RAM接口
    output wire        ram_re_o,
    output wire        ram_we_o,
    output wire [31:0] ram_addr_o,
    output wire [31:0] ram_wdata_o,
    output wire [2:0]  ram_width_o,
    input  wire [31:0] ram_rdata_i,
    input  wire        ram_ready_i,
    
    // UART接口
    output wire        uart_we_o,      // 写使能（锁存后输出）
    output wire        uart_re_o,      // 读使能
    output wire [31:0] uart_addr_o,
    output wire [31:0] uart_wdata_o,   // 写数据（锁存后输出）
    input  wire [31:0] uart_rdata_i,
    
    // ========== 新增GPIO接口 ==========
    output wire        gpio_we_o,
    output wire        gpio_re_o,
    output wire [31:0] gpio_addr_o,
    output wire [31:0] gpio_wdata_o,
    input  wire [31:0] gpio_rdata_i,
    
    // ========== 新增TIMER接口 ==========
    output wire        timer_we_o,
    output wire        timer_re_o,
    output wire [31:0] timer_addr_o,
    output wire [31:0] timer_wdata_o,
    input  wire [31:0] timer_rdata_i
);

// 地址空间划分
localparam RAM_BASE   = 32'h0000_0000;
localparam RAM_SIZE   = 32'h0001_0000;  // 64KB RAM
localparam UART_BASE  = 32'h1000_0000;
localparam UART_SIZE  = 32'h0000_1000;  // 4KB UART空间
localparam GPIO_BASE  = 32'h1000_1000;
localparam GPIO_SIZE  = 32'h0000_1000;  // 4KB GPIO空间
localparam TIMER_BASE = 32'h1000_2000;
localparam TIMER_SIZE = 32'h0000_1000;  // 4KB TIMER空间

// 地址判断
wire is_ram   = (mem_addr_i >= RAM_BASE) && (mem_addr_i < RAM_BASE + RAM_SIZE);
wire is_uart  = (mem_addr_i >= UART_BASE) && (mem_addr_i < UART_BASE + UART_SIZE);
wire is_gpio  = (mem_addr_i >= GPIO_BASE) && (mem_addr_i < GPIO_BASE + GPIO_SIZE);
wire is_timer = (mem_addr_i >= TIMER_BASE) && (mem_addr_i < TIMER_BASE + TIMER_SIZE);

// ========== RAM接口（组合逻辑） ==========
assign ram_re_o    = mem_re_i && is_ram;
assign ram_we_o    = mem_we_i && is_ram;
assign ram_addr_o  = mem_addr_i;
assign ram_wdata_o = mem_wdata_i;
assign ram_width_o = mem_width_i;

// ========== UART写逻辑（保留原锁存+超时机制） ==========
// 注意：原代码中 uart_addr_o 固定为 UART_BASE，uart_re_o 未赋值，这里补充 uart_re_o
reg         uart_we_latched;
reg  [31:0] uart_wdata_latched;
reg  [7:0]  uart_we_timeout;

// 读使能：只要地址在UART范围内且读请求有效
assign uart_re_o = mem_re_i && is_uart;
assign uart_addr_o = UART_BASE;

always @(posedge clk_i) begin
    if (!rst_n_i) begin
        uart_we_latched    <= 1'b0;
        uart_wdata_latched <= 32'b0;
        uart_we_timeout    <= 8'h0;
    end else begin
        // 锁存UART写信号和数据
        if (mem_we_i && is_uart) begin
            uart_we_latched    <= 1'b1;
            uart_wdata_latched <= mem_wdata_i;
            uart_we_timeout    <= 8'd5;
            $display("[BUS] UART Write锁存: Data=%h ('%c')", 
                     mem_wdata_i, mem_wdata_i[7:0]);
        end 
        // 当UART控制器确认接收后清除（假设bit0是tx_ready）
        else if (uart_we_latched && uart_rdata_i[0]) begin
            uart_we_latched <= 1'b0;
            uart_we_timeout <= 8'h0;
        end
        else if (uart_we_latched && (uart_we_timeout > 0)) begin
            uart_we_timeout <= uart_we_timeout - 1;
            if (uart_we_timeout == 1) begin
                uart_we_latched <= 1'b0;
                $display("[BUS] UART超时强制释放");
            end
        end
    end
end

assign uart_we_o    = uart_we_latched;
assign uart_wdata_o = uart_wdata_latched;

// ========== GPIO接口（组合逻辑，直连） ==========
assign gpio_we_o    = mem_we_i && is_gpio;
assign gpio_re_o    = mem_re_i && is_gpio;
assign gpio_addr_o  = mem_addr_i;
assign gpio_wdata_o = mem_wdata_i;

// ========== TIMER接口（组合逻辑，直连） ==========
assign timer_we_o   = mem_we_i && is_timer;
assign timer_re_o   = mem_re_i && is_timer;
assign timer_addr_o = mem_addr_i;
assign timer_wdata_o = mem_wdata_i;

// ========== 读数据选择（组合逻辑） ==========
always @(*) begin
    mem_rdata_o = 32'b0;
    if (is_ram) begin
        mem_rdata_o = ram_rdata_i;
    end else if (is_uart) begin
        mem_rdata_o = uart_rdata_i;
    end else if (is_gpio) begin
        mem_rdata_o = gpio_rdata_i;
    end else if (is_timer) begin
        mem_rdata_o = timer_rdata_i;
    end
end

// ========== 就绪信号 ==========
assign mem_ready_o = is_ram ? ram_ready_i : 1'b1;

endmodule