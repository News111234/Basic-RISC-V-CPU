// rtl/periph/gpio.v - 修正版
`timescale 1ns/1ps

module gpio (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 总线接口
    input  wire        we_i,
    input  wire        re_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,
    
    // 外部引脚 (假设32位GPIO)
    input  wire [31:0] gpio_in_i,      // 输入引脚
    output wire [31:0] gpio_out_o,     // 输出引脚 
    output wire [31:0] gpio_oe_o,      // 输出使能 
    
    // 中断输出
    output wire        interrupt_o,

    output wire [31:0] debug_gpio_out,
output wire [31:0] debug_gpio_oe,
output wire [31:0] debug_gpio_in,
output wire [31:0] debug_gpio_if
);

// 寄存器地址偏移
localparam GPIO_OUT_ADDR = 8'h00;
localparam GPIO_OE_ADDR  = 8'h04;
localparam GPIO_IN_ADDR  = 8'h08;
localparam GPIO_IE_ADDR  = 8'h0C;
localparam GPIO_EDGE_ADDR= 8'h10;
localparam GPIO_IF_ADDR  = 8'h14;

// 内部寄存器
reg [31:0] gpio_out;
reg [31:0] gpio_oe;
reg [31:0] gpio_ie;      // 中断使能
reg [31:0] gpio_edge;    // 0=电平触发,1=边沿触发
reg [31:0] gpio_if;      // 中断标志

// 输入引脚同步 (简单两拍同步，避免亚稳态)
reg [31:0] gpio_in_sync1, gpio_in_sync2;
always @(posedge clk_i) begin
    gpio_in_sync1 <= gpio_in_i;
    gpio_in_sync2 <= gpio_in_sync1;
end
wire [31:0] gpio_in_sync = gpio_in_sync2;

// 边沿检测
reg [31:0] gpio_in_prev;
wire [31:0] rising_edge;
wire [31:0] falling_edge;

always @(posedge clk_i) begin
    gpio_in_prev <= gpio_in_sync;
end

assign rising_edge  = gpio_in_sync & ~gpio_in_prev;
assign falling_edge = ~gpio_in_sync & gpio_in_prev;
wire [31:0] any_edge = rising_edge | falling_edge;

// 中断产生逻辑
wire [31:0] interrupt_cond;
genvar i;
generate
    for (i = 0; i < 32; i = i + 1) begin : gen_intr
        assign interrupt_cond[i] = gpio_ie[i] && (
            (gpio_edge[i] && any_edge[i]) ||          // 边沿触发
            (!gpio_edge[i] && gpio_in_sync[i])        // 电平触发高电平
        );
    end
endgenerate

// 中断标志更新
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        gpio_if <= 32'b0;
    end else begin
        // 写1清除中断标志
        if (we_i && (addr_i[7:0] == GPIO_IF_ADDR)) begin
            gpio_if <= gpio_if & ~wdata_i;  // 清除写1的位
        end
        // 新中断条件满足时置位
        gpio_if <= gpio_if | interrupt_cond;
    end
end

// 总中断输出 (只要有任何中断标志且使能)
assign interrupt_o = |(gpio_if & gpio_ie);

// 寄存器写操作
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        gpio_out <= 32'b0;
        gpio_oe  <= 32'b0;
        gpio_ie  <= 32'b0;
        gpio_edge <= 32'b0;
    end else if (we_i) begin
        case (addr_i[7:0])
            GPIO_OUT_ADDR: gpio_out <= wdata_i;
            GPIO_OE_ADDR:  gpio_oe  <= wdata_i;
            GPIO_IE_ADDR:  gpio_ie  <= wdata_i;
            GPIO_EDGE_ADDR: gpio_edge <= wdata_i;
            // GPIO_IF_ADDR 写操作已在上面单独处理（清除标志）
            default: ;
        endcase
    end
end

// 读操作
always @(*) begin
    case (addr_i[7:0])
        GPIO_OUT_ADDR: rdata_o = gpio_out;
        GPIO_OE_ADDR:  rdata_o = gpio_oe;
        GPIO_IN_ADDR:  rdata_o = gpio_in_sync;
        GPIO_IE_ADDR:  rdata_o = gpio_ie;
        GPIO_EDGE_ADDR: rdata_o = gpio_edge;
        GPIO_IF_ADDR:  rdata_o = gpio_if;
        default:       rdata_o = 32'b0;
    endcase
end

// 输出引脚驱动 (使用 assign 连续赋值，端口已改为 wire)
assign gpio_out_o = gpio_out;
assign gpio_oe_o  = gpio_oe;

assign debug_gpio_out = gpio_out;
assign debug_gpio_oe  = gpio_oe;
assign debug_gpio_in  = gpio_in_sync;
assign debug_gpio_if  = gpio_if;


endmodule