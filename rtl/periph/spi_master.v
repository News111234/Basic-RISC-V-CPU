// ============================================================================
// 模块: spi_master
// 功能: SPI主机控制器 (Master Mode Only)
// 描述:
//   该模块实现SPI协议的主机功能，支持:
//   - 4种SPI模式 (CPOL/CPHA可配置)
//   - 可配置时钟分频 (SPI时钟 = 系统时钟 / (2 * clk_divider))
//   - 8位/16位数据传输
//   - MSB优先/LSB优先可配置
//   - 中断支持 (发送完成/接收完成)
//
// 寄存器映射:
//   REG_CTRL     (0x00) - 控制寄存器
//   REG_CLK_DIV  (0x04) - 时钟分频寄存器
//   REG_DATA     (0x08) - 数据寄存器
//   REG_STATUS   (0x0C) - 状态寄存器
//   REG_IRQ_FLAG (0x10) - 中断标志寄存器
// ============================================================================

`timescale 1ns/1ps

module spi_master (
    // ========== 系统接口 ==========
    input  wire        clk_i,          // 系统时钟 (200MHz, 周期5ns)
    input  wire        rst_n_i,        // 复位信号 (低电平有效)
    
    // ========== CPU总线接口 ==========
    input  wire        we_i,           // 写使能: 1表示CPU正在写入寄存器
    input  wire        re_i,           // 读使能: 1表示CPU正在读取寄存器
    input  wire [31:0] addr_i,         // 地址总线 (低8位用于寄存器选择)
    input  wire [31:0] wdata_i,        // CPU写入的数据
    output reg  [31:0] rdata_o,        // CPU读取的数据
    
    // ========== SPI物理接口 ==========
    output wire        sclk_o,         // SPI时钟输出 (连接到从机的SCLK)
    output wire        mosi_o,         // 主机数据输出 (连接到从机的MOSI)
    input  wire        miso_i,         // 主机数据输入 (连接到从机的MISO)
    output wire        cs_o,           // 片选输出 (低电平有效)
    
    // ========== 中断输出 ==========
    output reg         interrupt_o,    // 中断信号 (连接到中断控制器)
    
    // ========== 调试输出 ==========
    output wire [1:0]  debug_state_o,  // 状态机状态 (用于波形观察)
    output wire [7:0]  debug_tx_data_o,// 发送数据 (用于波形观察)
    output wire [7:0]  debug_rx_data_o // 接收数据 (用于波形观察)
);

// ============================================================================
// 第一部分: 寄存器地址定义
// ============================================================================
// 每个寄存器占用4字节地址空间，偏移量如下:
localparam REG_CTRL     = 8'h00;   // 控制寄存器 (地址偏移0x00)
localparam REG_CLK_DIV  = 8'h04;   // 时钟分频寄存器 (地址偏移0x04)
localparam REG_DATA     = 8'h08;   // 数据寄存器 (地址偏移0x08)
localparam REG_STATUS   = 8'h0C;   // 状态寄存器 (地址偏移0x0C)
localparam REG_IRQ_FLAG = 8'h10;   // 中断标志寄存器 (地址偏移0x10)

// ============================================================================
// 第二部分: 控制寄存器(REG_CTRL)位定义
// ============================================================================
// bit0: SPI_ENABLE - SPI总使能 (1=使能, 0=禁用)
// bit1: IRQ_ENABLE - 中断使能 (1=使能中断, 0=禁用中断)
// bit2: CPOL - 时钟极性 (0=空闲低电平, 1=空闲高电平)
// bit3: CPHA - 时钟相位 (0=第一个边沿采样, 1=第二个边沿采样)
// bit4: LSB_FIRST - 低位优先 (0=MSB优先, 1=LSB优先)
// bit5: DATA_16BIT - 16位模式 (0=8位传输, 1=16位传输)
// bit6: START_TX - 启动传输 (写1启动，硬件自动清零)
// bit7-bit31: 保留

// ============================================================================
// 第三部分: 状态寄存器(REG_STATUS)位定义
// ============================================================================
// bit0: TX_READY - 发送就绪 (1=可以写入新数据)
// bit1: RX_READY - 接收就绪 (1=有数据可读)
// bit2: TX_BUSY - 发送忙 (1=正在传输中)

// ============================================================================
// 第四部分: 内部控制寄存器
// ============================================================================
// 从REG_CTRL写入的配置位
reg         spi_enable;     // SPI总使能 (bit0)
reg         irq_enable;     // 中断使能 (bit1)
reg         cpol;           // 时钟极性 (bit2)
reg         cpha;           // 时钟相位 (bit3)
reg         lsb_first;      // 低位优先 (bit4)
reg         data_16bit;     // 16位模式 (bit5)
reg         start_tx;       // 启动传输脉冲 (bit6)

// 从REG_CLK_DIV写入的配置
reg  [15:0] clk_divider;    // 时钟分频系数
                            // SPI时钟频率 = 系统时钟 / (2 * clk_divider)
                            // 例如: 200MHz / (2 * 100) = 1MHz

// 从REG_DATA写入的数据
reg  [15:0] tx_data;        // 要发送的数据缓冲区

// 内部状态寄存器
reg  [15:0] clk_counter;    // 时钟分频计数器 (0 到 clk_divider-1)
reg  [15:0] rx_data;        // 接收到的数据缓冲区
reg         tx_busy;        // 传输忙标志 (1=正在传输)
reg         rx_ready;       // 接收就绪标志 (1=新数据已接收)
reg         tx_ready;       // 发送就绪标志 (1=可以写入新数据)

// 中断标志寄存器
reg         irq_flag_tx;    // 发送完成中断标志
reg         irq_flag_rx;    // 接收完成中断标志

// ============================================================================
// 第五部分: SPI状态机定义
// ============================================================================
localparam SPI_IDLE   = 2'b00;   // 空闲状态: CS=1, 等待启动命令
localparam SPI_START  = 2'b01;   // 起始状态: CS=0, 准备发送第一位
localparam SPI_TRANS  = 2'b10;   // 传输状态: 发送8/16位数据
localparam SPI_STOP   = 2'b11;   // 停止状态: CS=1, 传输结束

reg [1:0]  spi_state;           // 当前状态
reg [4:0]  bit_counter;         // 位计数器 (0-15, 记录已发送/接收的位数)

// SPI时钟和信号生成
reg        sclk_reg;            // SCLK输出寄存器
reg        mosi_reg;            // MOSI输出寄存器
reg        cs_reg;              // CS输出寄存器
reg        sclk_enable;         // SCLK内部使能信号 (用于产生50%占空比)
reg        sample_edge;         // 采样边沿指示 (1=此时应采样MISO)
reg        setup_edge;          // 设置边沿指示 (1=此时应设置MOSI)

// 内部信号
wire       sclk_tick;           // 时钟滴答信号 (每clk_divider个系统周期产生一个脉冲)
wire [15:0] bits_to_send;       // 实际要发送的数据 (根据data_16bit调整)
wire [4:0]  max_bits;           // 最大传输位数 (8或16)

// ============================================================================
// 第六部分: 辅助信号赋值
// ============================================================================
// 根据data_16bit决定最大传输位数
assign max_bits = data_16bit ? 5'd16 : 5'd8;

// 根据data_16bit调整要发送的数据宽度
assign bits_to_send = data_16bit ? tx_data : {8'b0, tx_data[7:0]};

// ============================================================================
// 第七部分: 时钟分频计数器
// ============================================================================
// 功能: 每clk_divider个系统时钟周期产生一个sclk_tick脉冲
// 工作原理:
//   - 空闲时(非传输状态) clk_counter = 0
//   - 传输期间每个时钟周期 clk_counter + 1
//   - 当 clk_counter >= clk_divider 时，产生sclk_tick脉冲并清零计数器
//
assign sclk_tick = (clk_counter >= clk_divider) && spi_enable;

always @(posedge clk_i) begin
    if (!rst_n_i) begin
        // 复位: 计数器清零
        clk_counter <= 16'b0;
    end else if (sclk_tick) begin
        // 达到分频目标: 产生脉冲并清零
        clk_counter <= 16'b0;
    end else if (spi_enable && (spi_state != SPI_IDLE)) begin
        // 传输期间: 每个时钟周期递增
        clk_counter <= clk_counter + 1;
    end else begin
        // 空闲或SPI未使能: 保持清零
        clk_counter <= 16'b0;
    end
end

// ============================================================================
// 第八部分: SPI时钟(SCLK)生成
// ============================================================================
// 功能: 产生SPI时钟信号
// 工作原理:
//   - 每个sclk_tick脉冲使sclk_enable翻转一次
//   - 每两次sclk_tick脉冲使sclk_reg翻转一次
//   - 空闲时sclk_reg根据CPOL设置
//
// 时序图 (clk_divider=100, CPOL=0):
//   sclk_tick:   ──┐     ┐     ┐
//                   └─────┘     └──  (每500ns一个脉冲)
//   sclk_enable: 0──┐  ┌─┐  ┌─┐
//                     └──┘  └──┘    (每500ns翻转)
//   sclk_reg:    0──┐  ┌─┐  ┌─┐
//                     └──┘  └──┘    (每1000ns翻转)
//   sclk_o:      0──┐  ┌─┐  ┌─┐
//                     └──┘  └──┘    (SPI时钟输出)
//
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        sclk_reg <= 1'b0;
    end else if (spi_enable && (spi_state == SPI_START || spi_state == SPI_TRANS)) begin
        // 传输期间: 每个sclk_tick翻转一次sclk_reg，在START和TRANS状态产生SCLK
        if (sclk_tick) begin
            sclk_reg <= ~sclk_reg;
        end
    end else begin
        // 空闲状态: 输出空闲电平(根据CPOL)
        sclk_reg <= cpol;
    end
end

// ============================================================================
// 第九部分: 采样边沿和设置边沿计算
// ============================================================================
// 功能: 根据CPHA确定数据采样和设置的边沿
// 
// CPHA=0 (模式0和2): 在SCLK的上升沿采样，下降沿设置
// CPHA=1 (模式1和3): 在SCLK的下降沿采样，上升沿设置
//
// 其中sclk_enable=1表示SCLK当前为高电平阶段
//
// 添加一个延迟寄存器用于边沿检测
reg sclk_o_d1;

always @(posedge clk_i) begin
    sclk_o_d1 <= sclk_reg;    // sclk_reg 就是 sclk_o
end

// 边沿检测
wire sclk_rising = sclk_reg && ~sclk_o_d1;   // 上升沿
wire sclk_falling = ~sclk_reg && sclk_o_d1;  // 下降沿

always @(*) begin
    if (cpha) begin
        // CPHA=1: 下降沿采样，上升沿设置
        sample_edge = sclk_falling;
        setup_edge = sclk_rising;
    end else begin
        // CPHA=0: 上升沿采样，下降沿设置
        sample_edge = sclk_rising;    //每1000ns有一个上升沿，1000ns为一个周期
        setup_edge = sclk_falling; 
    end
end
//
//术语	含义	谁做	什么时候做
//采样	读取MOSI线上的电平	从机	上升沿
//设置	把下一位数据放到MOSI线上	主机	下降沿

// ============================================================================
// 第十部分: SPI状态机 (核心)
// ============================================================================
// 状态转换图:
//   IDLE ──(start_tx=1)──? START ──(1个SCLK周期)──? TRANS
//     ▲                                              │
//     └──────────────(传输完成)?─────────────────────┘
//                           │
//                           ▼
//                        STOP ──(1个SCLK周期)──? IDLE
//
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        // 复位: 所有状态清零
        spi_state <= SPI_IDLE;
        tx_busy <= 1'b0;
        rx_ready <= 1'b0;
        tx_ready <= 1'b1;
        bit_counter <= 5'b0;
        mosi_reg <= 1'b0;
        cs_reg <= 1'b1;
        irq_flag_tx <= 1'b0;
        irq_flag_rx <= 1'b0;
        rx_data <= 16'b0;
    end else begin
        // 默认值: 每个周期开始时tx_ready为0，需要重新计算
        tx_ready <= 1'b0;
        
        case (spi_state)
            // ================================================================
            // IDLE状态: 空闲，等待启动命令
            // ================================================================
            SPI_IDLE: begin
                cs_reg <= 1'b1;              // CS=1 (不选中任何从机)
                tx_busy <= 1'b0;             // 不忙
                bit_counter <= 5'b0;         // 位计数器清零
                
                // 检查是否收到启动命令
                if (spi_enable && start_tx) begin
                    spi_state <= SPI_START;   // 进入START状态
                    tx_busy <= 1'b1;         // 标记忙
                    irq_flag_tx <= 1'b0;     // 清除发送中断标志
                    $display("[SPI] Starting transfer: data=%h, bits=%d", 
                             tx_data, max_bits);
                end else begin
                    tx_ready <= 1'b1;         // 准备好接收CPU写数据
                end
            end
            
            // ================================================================
            // START状态: 拉低CS，准备传输
            // ================================================================
            SPI_START: begin
                cs_reg <= 1'b0;              // CS=0 (选中从机)
                bit_counter <= 5'b0;         // 位计数器清零
                
                if (cpha) begin
                    // CPHA=1模式: 第一个边沿是设置边沿
                    // 需要在START状态输出第一位数据
                    if (setup_edge) begin
                        // 输出第一位数据
                        if (lsb_first) begin
                            mosi_reg <= bits_to_send[0];
                        end else begin
                            mosi_reg <= bits_to_send[max_bits-1];
                        end
                        spi_state <= SPI_TRANS;   // 进入TRANS状态
                    end
                end else begin
                    // CPHA=0模式: 第一个边沿是采样边沿
                    // 直接进入TRANS状态，在TRANS中设置第一位
                    if (sample_edge) begin
                        spi_state <= SPI_TRANS;
                    end
                end
            end
            
            // ================================================================
            // TRANS状态: 传输数据
            // ================================================================
            SPI_TRANS: begin
                // --- 设置边沿: 输出数据到MOSI ---
                if (setup_edge && (bit_counter < max_bits)) begin
                    if (bit_counter == 0 && cpha == 1'b0) begin
                        // CPHA=0模式: 第一位数据已经在START状态设置过了
                        // 这里什么都不做
                    end else begin
                        // 输出当前位数据
                        if (lsb_first) begin
                            mosi_reg <= bits_to_send[bit_counter];
                        end else begin
                            mosi_reg <= bits_to_send[max_bits - 1 - bit_counter];
                        end
                    end
                end
                
                // --- 采样边沿: 从MISO读取数据 ---
                if (sample_edge && (bit_counter < max_bits)) begin
                    // 读取从机发送的当前位
                    if (lsb_first) begin
                        rx_data[bit_counter] <= miso_i;
                    end else begin
                        rx_data[max_bits - 1 - bit_counter] <= miso_i;
                    end
                    bit_counter <= bit_counter + 1;   // 位计数器加1
                end
                
                // --- 传输完成检查 ---
                if (bit_counter == max_bits) begin
                    // 所有位传输完成
                    spi_state <= SPI_STOP;            // 进入STOP状态
                    rx_ready <= 1'b1;                 // 标记接收就绪
                    irq_flag_rx <= 1'b1;              // 产生接收中断
                    $display("[SPI] Transfer complete: rx_data=%h", rx_data);
                end
            end
            
            // ================================================================
            // STOP状态: 拉高CS，结束传输
            // ================================================================
            SPI_STOP: begin
                cs_reg <= 1'b1;              // CS=1 (释放从机)
                spi_state <= SPI_IDLE;       // 回到IDLE状态
                tx_busy <= 1'b0;             // 清除忙标志
                tx_ready <= 1'b1;            // 准备好接收新数据
                irq_flag_tx <= 1'b1;         // 产生发送完成中断
            end
        endcase
    end
end

// ============================================================================
// 第十一部分: 寄存器写操作
// ============================================================================
// CPU通过we_i信号写入SPI寄存器
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        // 复位: 所有寄存器恢复默认值
        spi_enable <= 1'b0;
        irq_enable <= 1'b0;
        cpol <= 1'b0;
        cpha <= 1'b0;
        lsb_first <= 1'b0;
        data_16bit <= 1'b0;
        start_tx <= 1'b0;
        clk_divider <= 16'd100;      // 默认分频100 → 1MHz SPI时钟
        tx_data <= 16'b0;
        irq_flag_tx <= 1'b0;
        irq_flag_rx <= 1'b0;
    end else if (we_i) begin
        // CPU写操作: 根据地址选择目标寄存器
        case (addr_i[7:0])
            REG_CTRL: begin
                // 写控制寄存器
                spi_enable  <= wdata_i[0];      // bit0: SPI使能
                irq_enable  <= wdata_i[1];      // bit1: 中断使能
                cpol        <= wdata_i[2];      // bit2: 时钟极性
                cpha        <= wdata_i[3];      // bit3: 时钟相位
                lsb_first   <= wdata_i[4];      // bit4: 低位优先
                data_16bit  <= wdata_i[5];      // bit5: 16位模式
                if (wdata_i[6]) begin
                    start_tx <= 1'b1;           // bit6: 启动传输(写1启动)
                end
            end
            
            REG_CLK_DIV: begin
                // 写时钟分频寄存器
                clk_divider <= wdata_i[15:0];
            end
            
            REG_DATA: begin
                // 写数据寄存器
                // 根据data_16bit决定写入宽度
                tx_data <= data_16bit ? wdata_i[15:0] : {8'b0, wdata_i[7:0]};
            end
            
            REG_IRQ_FLAG: begin
                // 写中断标志寄存器 (写1清除中断)
                if (wdata_i[0]) irq_flag_tx <= 1'b0;
                if (wdata_i[1]) irq_flag_rx <= 1'b0;
            end
        endcase
    end else begin
        // 非写操作: start_tx自动清零 (单周期脉冲)
        start_tx <= 1'b0;
    end
end

// ============================================================================
// 第十二部分: 寄存器读操作
// ============================================================================
// CPU通过re_i信号读取SPI寄存器
always @(*) begin
    case (addr_i[7:0])
        REG_CTRL: begin
            // 读控制寄存器: 返回当前配置
            rdata_o = {26'b0, data_16bit, lsb_first, cpha, cpol, irq_enable, spi_enable};
        end
        REG_CLK_DIV: begin
            // 读时钟分频寄存器
            rdata_o = {16'b0, clk_divider};
        end
        REG_DATA: begin
            // 读数据寄存器: 返回接收到的数据
            rdata_o = data_16bit ? {16'b0, rx_data} : {24'b0, rx_data[7:0]};
        end
        REG_STATUS: begin
            // 读状态寄存器
            rdata_o = {29'b0, tx_busy, rx_ready, tx_ready};
        end
        REG_IRQ_FLAG: begin
            // 读中断标志寄存器
            rdata_o = {30'b0, irq_flag_rx, irq_flag_tx};
        end
        default: begin
            // 无效地址: 返回0
            rdata_o = 32'b0;
        end
    endcase
end

// ============================================================================
// 第十三部分: 中断输出
// ============================================================================
// 中断条件: 中断使能 且 (有发送完成中断 或 有接收完成中断)
always @(posedge clk_i) begin
    interrupt_o <= (irq_enable) && ((irq_flag_tx) || (irq_flag_rx));
end

// ============================================================================
// 第十四部分: 输出引脚赋值
// ============================================================================
assign sclk_o = sclk_reg;    // SPI时钟输出
assign mosi_o = mosi_reg;    // SPI数据输出
assign cs_o   = cs_reg;      // SPI片选输出

// ============================================================================
// 第十五部分: 调试输出
// ============================================================================
assign debug_state_o = spi_state;        // 状态机状态
assign debug_tx_data_o = tx_data[7:0];   // 发送数据(低8位)
assign debug_rx_data_o = rx_data[7:0];   // 接收数据(低8位)

endmodule