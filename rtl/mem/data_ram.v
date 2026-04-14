// ================================================
// 模块: data_ram
// 功能: 数据存储器（单端口，同步读写）
// 支持：SB/SH/SW, LB/LH/LW, LBU/LHU
// ================================================
`timescale 1ns/1ps

// ============================================================================
// 模块: data_ram
// 功能: 数据存储器 (RAM)，支持字节/半字/字读写
// 描述:
//   该模块实现一个单端口同步写、异步读的数据存储器。
//   支持有符号和无符号的加载指令(LB/LH/LW/LBU/LHU)，
//   以及存储指令(SB/SH/SW)。
//
//   地址空间: 256个32位字 (深度256，地址范围 0x0000_0000 - 0x0000_03FC)
//   写操作: 时钟上升沿触发，支持部分字节/半字写入
//   读操作: 组合逻辑，根据width_i进行符号扩展或零扩展
//
//   width_i编码:
//     3'b000: SB/LB/LBU  - 字节访问
//     3'b001: SH/LH/LHU  - 半字访问
//     3'b010: SW/LW      - 字访问
//     3'b100: LBU        - 无符号字节加载
//     3'b101: LHU        - 无符号半字加载
// ============================================================================
module data_ram (
    // ========== 系统接口 ==========
    input  wire        clk_i,          // 时钟信号
    input  wire        rst_n_i,        // 复位信号 (低电平有效)

    // ========== 控制信号 ==========
    input  wire        we_i,           // 写使能
    input  wire        re_i,           // 读使能
    input  wire [2:0]  width_i,        // 访问宽度
    input  wire [31:0] addr_i,         // 访问地址
    input  wire [31:0] wdata_i,        // 写数据

    // ========== 输出端口 ==========
    output reg  [31:0] rdata_o,        // 读数据 (符号扩展或零扩展)
    output wire        ready_o         // 就绪信号 (始终为1)
);

parameter DEPTH = 256;            // 256 x 32-bit words
parameter ADDR_WIDTH = 8;

reg [31:0] mem [0:DEPTH-1];
integer i;

// ========== 初始化 RAM ==========
initial begin
    for ( i = 0; i < DEPTH; i = i + 1) begin
        mem[i] = 32'h0;
    end
    // 可选：预置测试数据
    mem[0] = 32'h12345678;
    mem[1] = 32'h87654321;
end

// ========== 写操作（时序）==========
always @(posedge clk_i ) begin
    if (!rst_n_i) begin
        // 复位时不强制清零（由 initial 完成），或可显式清零
        // 实际 FPGA 中 initial 不综合，此处仅用于仿真
    end else if (we_i && (addr_i[31:2] < DEPTH)) begin
        case (width_i)
            3'b000: begin // SB
                case (addr_i[1:0])
                    2'b00: mem[addr_i[31:2]][7:0]   <= wdata_i[7:0];
                    2'b01: mem[addr_i[31:2]][15:8]  <= wdata_i[7:0];
                    2'b10: mem[addr_i[31:2]][23:16] <= wdata_i[7:0];
                    2'b11: mem[addr_i[31:2]][31:24] <= wdata_i[7:0];
                endcase
            end
            
            3'b001: begin // SH
                case (addr_i[1])
                    1'b0: mem[addr_i[31:2]][15:0]  <= wdata_i[15:0];
                    1'b1: mem[addr_i[31:2]][31:16] <= wdata_i[15:0];
                endcase
            end
            
            3'b010: begin // SW
                mem[addr_i[31:2]] <= wdata_i;
            end
            
            default: ; // 无效宽度，忽略
        endcase
    end
end

// ========== 读操作（组合）==========
always @(*) begin
    if (re_i && (addr_i[31:2] < DEPTH)) begin
        case (width_i)
            // 有符号加载
            3'b000: begin // LB
                case (addr_i[1:0])
                    2'b00: rdata_o = {{24{mem[addr_i[31:2]][7]}},  mem[addr_i[31:2]][7:0]};
                    2'b01: rdata_o = {{24{mem[addr_i[31:2]][15]}}, mem[addr_i[31:2]][15:8]};
                    2'b10: rdata_o = {{24{mem[addr_i[31:2]][23]}}, mem[addr_i[31:2]][23:16]};
                    2'b11: rdata_o = {{24{mem[addr_i[31:2]][31]}}, mem[addr_i[31:2]][31:24]};
                endcase
            end
            
            3'b001: begin // LH
                case (addr_i[1])
                    1'b0: rdata_o = {{16{mem[addr_i[31:2]][15]}}, mem[addr_i[31:2]][15:0]};
                    1'b1: rdata_o = {{16{mem[addr_i[31:2]][31]}}, mem[addr_i[31:2]][31:16]};
                endcase
            end
            
            3'b010: begin // LW
                rdata_o = mem[addr_i[31:2]];
            end
            
            // 无符号加载
            3'b100: begin // LBU
                case (addr_i[1:0])
                    2'b00: rdata_o = {24'b0, mem[addr_i[31:2]][7:0]};
                    2'b01: rdata_o = {24'b0, mem[addr_i[31:2]][15:8]};
                    2'b10: rdata_o = {24'b0, mem[addr_i[31:2]][23:16]};
                    2'b11: rdata_o = {24'b0, mem[addr_i[31:2]][31:24]};
                endcase
            end
            
            3'b101: begin // LHU
                case (addr_i[1])
                    1'b0: rdata_o = {16'b0, mem[addr_i[31:2]][15:0]};
                    1'b1: rdata_o = {16'b0, mem[addr_i[31:2]][31:16]};
                endcase
            end
            
            default: rdata_o = 32'b0;
        endcase
    end else begin
        rdata_o = 32'b0;
    end
end

assign ready_o = 1'b1;

endmodule
