// rtl/periph/i2c_master.v - I2C主机控制器
//I2C 的核心机制
// 4.1 起始条件（START）
// 定义：SCL 为高电平时，SDA 从高电平变为低电平。

// 作用：告诉总线上所有设备"通信要开始了，请大家注意"。

// 谁产生：只有主机可以产生起始条件。

// 4.2 停止条件（STOP）
// 定义：SCL 为高电平时，SDA 从低电平变为高电平。

// 作用：告诉总线上所有设备"通信结束了，总线空闲"。

// 谁产生：只有主机可以产生停止条件。

// 4.3 数据有效性
// 规则：SDA 上的数据只能在 SCL 为低电平时改变。当 SCL 为高电平时，SDA 必须保持稳定。

// 原因：从机在 SCL 高电平时读取 SDA 的值。如果 SDA 在高电平时变化，从机可能读到错误数据。

// 4.4 应答机制（ACK）
// 定义：每传输完 8 位数据后，接收方需要在第 9 个时钟周期回复一个应答。

// ACK（应答）：接收方把 SDA 拉低，表示"我收到了，请继续"。

// NACK（非应答）：接收方让 SDA 保持高电平，表示"我没收到"或"不要再发了"。

// 谁产生：接收方产生 ACK/NACK。写操作时是从机应答，读操作时是主机应答。

//写操作流程
// 起始条件 → 7位设备地址 → 读/写位(0=写) → ACK → 8位数据 → ACK → ... → 停止条件

// 具体步骤：
// 第1步：主机产生 START 条件
// 第2步：主机发送 7 位从机地址（例如 0x50）
// 第3步：主机发送 1 位 R/W 位（0 表示写）
// 第4步：从机在第 9 个时钟回复 ACK（拉低 SDA）
// 第5步：主机发送 8 位数据
// 第6步：从机在第 9 个时钟回复 ACK
// 第7步：重复第5-6步，可以连续发送多个字节
// 第8步：主机产生 STOP 条件

//读操作流程
// 起始条件 → 7位设备地址 → 读/写位(1=读) → ACK → 8位数据(从机发送) → ACK(主机) → ... → 停止条件

// 具体步骤：
// 第1步：主机产生 START 条件
// 第2步：主机发送 7 位从机地址
// 第3步：主机发送 1 位 R/W 位（1 表示读）
// 第4步：从机在第 9 个时钟回复 ACK
// 第5步：从机发送 8 位数据（主机读取）
// 第6步：主机在第 9 个时钟回复 ACK（表示还要继续读）
// 第7步：重复第5-6步
// 第8步：主机回复 NACK（表示不要再发了）
// 第9步：主机产生 STOP 条件

// 复合操作（先写地址再读数据）
// 很多设备需要先写寄存器地址，再读数据：

// text
// START → 设备地址(写) → ACK → 寄存器地址 → ACK → 
// START(重复) → 设备地址(读) → ACK → 数据(从机发) → NACK(主机) → STOP


//关键信号总结
// clk_tick	时钟分频脉冲，控制每个位的传输节奏
// bit_counter	记录当前传输到了第几位（0-8）
// sda_oe_reg	SDA输出使能（1=驱动，0=释放）
// sda_out_reg	SDA输出值（当使能时）
// sda_in	SDA输入值（从总线读入）
// ack_status	收到的应答状态（0=ACK，1=NACK）
// tx_ready	通知CPU可以写入下一字节
// rx_ready	通知CPU有数据可读


`timescale 1ns/1ps


module i2c_master (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 总线接口
    input  wire        we_i,
    input  wire        re_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,
    
    // I2C物理接口
    inout  wire        sda_io,      // 数据线（双向）
    inout  wire        scl_io,      // 时钟线（双向）
    
    // 中断输出
    output reg         interrupt_o,
    
    // 调试输出
    output wire [2:0]  debug_state_o,
    output wire [7:0]  debug_tx_data_o,
    output wire [7:0]  debug_rx_data_o,
    output wire        debug_ack_o
);

// ========== 寄存器地址定义 ==========
localparam REG_CTRL     = 8'h00;   // 控制寄存器
localparam REG_CLK_DIV  = 8'h04;   // 时钟分频寄存器
localparam REG_TX_DATA  = 8'h08;   // 发送数据寄存器
localparam REG_RX_DATA  = 8'h0C;   // 接收数据寄存器
localparam REG_STATUS   = 8'h10;   // 状态寄存器
localparam REG_ADDR     = 8'h14;   // 从设备地址寄存器
localparam REG_IRQ_FLAG = 8'h18;   // 中断标志寄存器

// ========== 控制寄存器位定义 ==========
// bit0:  I2C使能
// bit1:  中断使能
// bit2:  启动传输 (写1启动，自动清零)
// bit3:  停止传输 (写1停止)
// bit4:  读/写 (0=写, 1=读)
// bit5:  应答使能 (接收时是否发送ACK)

// ========== 状态寄存器位定义 ==========
// bit0:  忙标志
// bit1:  发送就绪
// bit2:  接收就绪
// bit3:  应答标志 (0=ACK, 1=NACK)

// ========== 内部寄存器 ==========
reg         i2c_enable;
reg         irq_enable;
reg         start_cmd;
reg         stop_cmd;
reg         rw_cmd;          // 0=写, 1=读
reg         ack_enable;

reg  [15:0] clk_divider;
reg  [7:0]  tx_data;
reg  [7:0]  rx_data;
reg  [6:0]  slave_addr;

reg         tx_busy;
reg         rx_ready;
reg         tx_ready;
reg         ack_status;      // 0=ACK, 1=NACK

reg         irq_flag_tx;
reg         irq_flag_rx;
reg         irq_flag_nack;

// I2C状态机
localparam I2C_IDLE        = 3'b000;   // 空闲状态
localparam I2C_START       = 3'b001;   // 起始状态
localparam I2C_SEND_ADDR   = 3'b010;   // 发送地址+读/写位
localparam I2C_SEND_DATA   = 3'b011;   // 发送数据
localparam I2C_RECV_DATA   = 3'b100;   // 接收数据
localparam I2C_SEND_ACK    = 3'b101;   // 发送应答
localparam I2C_RECV_ACK    = 3'b110;   // 接收应答
localparam I2C_STOP        = 3'b111;   // 停止状态

reg [2:0]  i2c_state;
reg [3:0]  bit_counter;
reg        scl_reg;
reg        sda_out_reg;
reg        sda_oe_reg;      // SDA输出使能
reg        scl_oe_reg;      // SCL输出使能
reg        scl_in;
reg        sda_in;

// 时钟分频计数器
reg [15:0] clk_counter;
reg        clk_tick;

// ========== 三态缓冲控制 ==========
assign sda_io = sda_oe_reg ? sda_out_reg : 1'bz;    //z是高阻态
assign scl_io = scl_oe_reg ? scl_reg : 1'bz;

// 输入采样
always @(posedge clk_i) begin
    scl_in <= scl_io;
    sda_in <= sda_io;
end

// ========== 时钟分频 ==========
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        clk_counter <= 16'b0;
        clk_tick <= 1'b0;
    end else if (i2c_enable && (i2c_state != I2C_IDLE)) begin
        if (clk_counter >= clk_divider) begin
            clk_counter <= 16'b0;
            clk_tick <= 1'b1;
        end else begin
            clk_counter <= clk_counter + 1;
            clk_tick <= 1'b0;                      // 其他周期为0
        end
    end else begin
        clk_counter <= 16'b0;
        clk_tick <= 1'b0;
    end
end

// ========== I2C时钟生成 ==========
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        scl_reg <= 1'b1;
        scl_oe_reg <= 1'b0;
    end else if (i2c_enable && (i2c_state != I2C_IDLE)) begin
        scl_oe_reg <= 1'b1;
        if (clk_tick) begin
            scl_reg <= ~scl_reg;
        end
    end else begin
        scl_reg <= 1'b1;
        scl_oe_reg <= 1'b0;
    end
end

// ========== I2C状态机 ==========
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        i2c_state <= I2C_IDLE;
        tx_busy <= 1'b0;
        rx_ready <= 1'b0;
        tx_ready <= 1'b1;
        bit_counter <= 4'b0;
        sda_out_reg <= 1'b1;
        sda_oe_reg <= 1'b0;
        ack_status <= 1'b0;
        irq_flag_tx <= 1'b0;
        irq_flag_rx <= 1'b0;
        irq_flag_nack <= 1'b0;
        rx_data <= 8'b0;
    end else begin
        tx_ready <= 1'b0;
        
        case (i2c_state)
        //1.空闲状态
I2C_IDLE: begin
    sda_oe_reg <= 1'b0;      // 释放SDA总线（高阻态）
    sda_out_reg <= 1'b1;     // 输出高电平（释放时）
    tx_busy <= 1'b0;         // 不忙
    bit_counter <= 4'b0;     // 位计数器清零
    
    if (i2c_enable && start_cmd) begin
        i2c_state <= I2C_START;   // 收到启动命令，进入START状态
        tx_busy <= 1'b1;          // 标记忙
    end else begin
        tx_ready <= 1'b1;         // 准备好接收CPU的新数据
    end
end
                 //START(产生起始条件)
            I2C_START: begin
                // 产生START条件：SCL高时SDA从高变低
    if (scl_reg) begin           // 等待SCL为高电平
        sda_oe_reg <= 1'b1;      // 开始驱动SDA
        sda_out_reg <= 1'b0;     // 拉低SDA（START条件）
        i2c_state <= I2C_SEND_ADDR;  // 进入发送地址状态
    end
            end
//  I2C 协议规定：START 条件是 SCL 为高时 SDA 从高变低

// 代码先检查 scl_reg 是否为高

// 然后把 SDA 拉低，产生 START 条件

// 完成后立即进入 SEND_ADDR 状态        发送设备地址


            I2C_SEND_ADDR: begin
                // 发送7位地址 + R/W位
               if (clk_tick && scl_reg) begin      // 每个SCL周期发送1位
        if (bit_counter < 7) begin
            // 发送7位地址（从高位到低位）
            sda_out_reg <= slave_addr[6 - bit_counter];
            bit_counter <= bit_counter + 1;
        end else if (bit_counter == 7) begin
            // 发送第8位：R/W位（0=写，1=读）
            sda_out_reg <= rw_cmd;
            bit_counter <= bit_counter + 1;
        end else if (bit_counter == 8) begin
            // 8位发送完毕，释放SDA准备接收ACK
            sda_oe_reg <= 1'b0;          // 释放SDA
            i2c_state <= I2C_RECV_ACK;   // 进入接收ACK状态
                    end
                end
            end
//  总共发送 8 位：7位地址 + 1位读写位

// 每发送1位，bit_counter 加1

// 发送完8位后，释放 SDA 总线，让从机可以发送 ACK           

//发送数据
            I2C_SEND_DATA: begin
                // 发送数据字节
                if (clk_tick && scl_reg) begin
                    if (bit_counter < 8) begin
                          // 发送8位数据（从高位到低位）
                        sda_out_reg <= tx_data[7 - bit_counter];
                        bit_counter <= bit_counter + 1;
                    end else if (bit_counter == 8) begin
                          // 8位发送完毕，释放SDA准备接收ACK
                        sda_oe_reg <= 1'b0;
                        bit_counter <= bit_counter + 1;
                        i2c_state <= I2C_RECV_ACK;
                    end
                end
            end
            // 发送 8 位数据（从高位 bit7 到低位 bit0）

// 每发送1位，bit_counter 加1

// 发送完8位后，释放 SDA，进入 RECV_ACK 等待从机应答


            //接收数据
            I2C_RECV_DATA: begin
                // 接收数据字节
                if (clk_tick && scl_reg) begin
                    if (bit_counter < 8) begin
                        // 接收8位数据（从高位到低位）
                        rx_data[7 - bit_counter] <= sda_in;
                        bit_counter <= bit_counter + 1;
                    end else if (bit_counter == 8) begin
                       // 8位接收完毕，准备发送ACK
                        // 发送ACK
                        sda_oe_reg <= 1'b1;
                        sda_out_reg <= ~ack_enable; // 发送ACK或NACK
                        bit_counter <= bit_counter + 1;
                        i2c_state <= I2C_SEND_ACK;
                    end
                end
            end



            //接收应答
            I2C_RECV_ACK: begin
                // 接收ACK
                if (clk_tick && scl_reg) begin
                    ack_status <= sda_in;   // 读取从机发来的ACK
                    bit_counter <= 4'b0;
                    
                    if (sda_in == 1'b1) begin
                        // NACK
                        irq_flag_nack <= 1'b1;  // 产生NACK中断
                        $display("[I2C] NACK received");
                        if (stop_cmd) begin
                            i2c_state <= I2C_STOP;
                        end else begin
                            i2c_state <= I2C_IDLE;
                        end
                    end else begin
                        // ACK
                        if (rw_cmd) begin
                            // 读模式：继续接收数据
                            if (stop_cmd) begin
                                i2c_state <= I2C_STOP;
                                rx_ready <= 1'b1;
                                irq_flag_rx <= 1'b1;
                            end else begin
                                i2c_state <= I2C_RECV_DATA;
                                bit_counter <= 4'b0;
                            end
                        end 
                        else if (bit_counter == 9) begin
                             
                                i2c_state <= I2C_STOP;
                                irq_flag_tx <= 1'b1;
                                bit_counter <= 4'b0;
                              end
                        
                        else begin
                            // 写模式：发送数据
                            if (stop_cmd) begin
                                i2c_state <= I2C_STOP;
                                irq_flag_tx <= 1'b1;
                            end else begin
                                i2c_state <= I2C_SEND_DATA;
                                bit_counter <= 4'b0;
                                tx_ready <= 1'b1;
                            end
                        end
                    end
                end
            end
        
//             在第9个时钟周期读取 SDA 线

// 如果 SDA=0，表示 ACK（从机应答了）

// 如果 SDA=1，表示 NACK（从机没应答）

// 收到 ACK 后，根据是读还是写，进入不同的状态

            //发送应答
            I2C_SEND_ACK: begin
                // 发送ACK完成，准备接收下一字节或停止
                if (clk_tick && scl_reg) begin
                    if (stop_cmd) begin
                        i2c_state <= I2C_STOP;
                        rx_ready <= 1'b1;
                        irq_flag_rx <= 1'b1;
                    end else begin
                        i2c_state <= I2C_RECV_DATA;
                        bit_counter <= 4'b0;
                    end
                end
            end
            
            I2C_STOP: begin
                // 产生STOP条件：SCL高时SDA从低变高
                sda_oe_reg <= 1'b1;
                sda_out_reg <= 1'b1;
                if (scl_reg && (sda_out_reg == 1'b1)) begin
                    i2c_state <= I2C_IDLE;
                    tx_busy <= 1'b0;
                    $display("[I2C] STOP condition generated");
                end
            end
// STOP 条件是 SCL 为高时 SDA 从低变高
// 代码先把 SDA 拉高
// 当 SCL 为高且 SDA 为高时，停止条件完成
// 回到 IDLE 状态
        endcase
    end
end


// ========== 寄存器写操作 ==========
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        i2c_enable <= 1'b0;
        irq_enable <= 1'b0;
        start_cmd <= 1'b0;
        stop_cmd <= 1'b0;
        rw_cmd <= 1'b0;
        ack_enable <= 1'b1;
        clk_divider <= 16'd1000;  // 100kHz默认
        tx_data <= 8'b0;
        slave_addr <= 7'b0;
        irq_flag_tx <= 1'b0;
        irq_flag_rx <= 1'b0;
        irq_flag_nack <= 1'b0;
    end else if (we_i) begin
        case (addr_i[7:0])
            REG_CTRL: begin
                i2c_enable <= wdata_i[0];
               if (wdata_i[1] == 1'b1) begin  //写入1之后直接锁存
        irq_enable <= 1'b1;
    end
                if (wdata_i[2]) start_cmd <= 1'b1;
                if (wdata_i[3]) stop_cmd <= 1'b1;
                rw_cmd <= wdata_i[4];
                ack_enable <= wdata_i[5];
            end
            
            REG_CLK_DIV: begin
                clk_divider <= wdata_i[15:0];
            end
            
            REG_TX_DATA: begin
                tx_data <= wdata_i[7:0];
            end
            
            REG_ADDR: begin
                slave_addr <= wdata_i[6:0];
            end
            
            REG_IRQ_FLAG: begin
                if (wdata_i[0]) irq_flag_tx <= 1'b0;
                if (wdata_i[1]) irq_flag_rx <= 1'b0;
                if (wdata_i[2]) irq_flag_nack <= 1'b0;
            end
        endcase
    end else begin
        start_cmd <= 1'b0;
        stop_cmd <= 1'b0;
    end
end

// ========== 寄存器读操作 ==========
always @(*) begin
    case (addr_i[7:0])
        REG_CTRL:    rdata_o = {26'b0, ack_enable, rw_cmd, stop_cmd, start_cmd, irq_enable, i2c_enable};
        REG_CLK_DIV: rdata_o = {16'b0, clk_divider};
        REG_TX_DATA: rdata_o = {24'b0, tx_data};
        REG_RX_DATA: rdata_o = {24'b0, rx_data};
        REG_STATUS:  rdata_o = {28'b0, ack_status, rx_ready, tx_ready, tx_busy};
        REG_ADDR:    rdata_o = {25'b0, slave_addr};
        REG_IRQ_FLAG: rdata_o = {29'b0, irq_flag_nack, irq_flag_rx, irq_flag_tx};
        default:     rdata_o = 32'b0;
    endcase
end

// ========== 中断输出 ==========
always @(posedge clk_i) begin
    interrupt_o <= (irq_enable) && (irq_flag_tx || irq_flag_rx || irq_flag_nack);
end

// ========== 调试输出 ==========
assign debug_state_o = i2c_state;
assign debug_tx_data_o = tx_data;
assign debug_rx_data_o = rx_data;
assign debug_ack_o = ack_status;

endmodule