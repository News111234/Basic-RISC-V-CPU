// rtl/id/regfile.v (增强调试版)
`timescale 1ns/1ps

// ============================================================================
// 模块: regfile
// 功能: 通用寄存器堆，包含32个32位寄存器 (x0-x31)
// 描述:
//   该模块实现RISC-V架构定义的32个通用寄存器。
//   特性:
//   1. 两个读端口，一个写端口
//   2. x0寄存器硬连线为0，写入无效
//   3. 写操作在时钟上升沿触发
//   4. 读操作是组合逻辑，支持读后写转发(当读地址等于写地址且写使能有效时，
//      直接返回正在写入的新值，避免RAW冒险)
//   5. 提供所有寄存器的调试输出
// ============================================================================
module regfile (
    // ========== 系统接口 ==========
    input  wire        clk,           // 时钟信号
    input  wire        rst_n,         // 复位信号 (低电平有效)

    // ========== 读端口1 ==========
    input  wire [4:0]  raddr1_i,      // 读地址1
    output reg  [31:0] rdata1_o,      // 读数据1

    // ========== 读端口2 ==========
    input  wire [4:0]  raddr2_i,      // 读地址2
    output reg  [31:0] rdata2_o,      // 读数据2

    // ========== 写端口 ==========
    input  wire        we_i,          // 写使能
    input  wire [4:0]  waddr_i,       // 写地址
    input  wire [31:0] wdata_i,       // 写数据

    // ========== 调试输出 (所有32个寄存器的值) ==========
    output wire [31:0] debug_x0_o,  debug_x1_o,  debug_x2_o,  debug_x3_o,
    output wire [31:0] debug_x4_o,  debug_x5_o,  debug_x6_o,  debug_x7_o,
    output wire [31:0] debug_x8_o,  debug_x9_o,  debug_x10_o, debug_x11_o,
    output wire [31:0] debug_x12_o, debug_x13_o, debug_x14_o, debug_x15_o,
    output wire [31:0] debug_x16_o, debug_x17_o, debug_x18_o, debug_x19_o,
    output wire [31:0] debug_x20_o, debug_x21_o, debug_x22_o, debug_x23_o,
    output wire [31:0] debug_x24_o, debug_x25_o, debug_x26_o, debug_x27_o,
    output wire [31:0] debug_x28_o, debug_x29_o, debug_x30_o, debug_x31_o
);

reg [31:0] registers [0:31];
integer i;

// 读取逻辑 - 修正调试输出
always @(*) begin
    // 读端口1
    if (raddr1_i == 5'b0) begin
        rdata1_o = 32'b0;  // x0始终为0
    end else if (we_i && (raddr1_i == waddr_i)) begin
        rdata1_o = wdata_i;  // 转发：读取即将写入的新值
        
    end else begin
        rdata1_o = registers[raddr1_i];
     
    end
    
    // 读端口2
    if (raddr2_i == 5'b0) begin
        rdata2_o = 32'b0;
    end else if (we_i && (raddr2_i == waddr_i)) begin
        rdata2_o = wdata_i;  // 转发：读取即将写入的新值
     
    end else begin
        rdata2_o = registers[raddr2_i];
      
    end
end

// 写入逻辑
always @(posedge clk ) begin
    if (!rst_n) begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] <= 32'b0;
        end
    end else if (we_i && waddr_i != 5'b0) begin  // 不能写x0
        registers[waddr_i] <= wdata_i;
   
    end
end

// 所有寄存器的调试输出
assign debug_x0_o  = registers[0];
assign debug_x1_o  = registers[1];
assign debug_x2_o  = registers[2];
assign debug_x3_o  = registers[3];
assign debug_x4_o  = registers[4];
assign debug_x5_o  = registers[5];
assign debug_x6_o  = registers[6];
assign debug_x7_o  = registers[7];
assign debug_x8_o  = registers[8];
assign debug_x9_o  = registers[9];
assign debug_x10_o = registers[10];
assign debug_x11_o = registers[11];
assign debug_x12_o = registers[12];
assign debug_x13_o = registers[13];
assign debug_x14_o = registers[14];
assign debug_x15_o = registers[15];
assign debug_x16_o = registers[16];
assign debug_x17_o = registers[17];
assign debug_x18_o = registers[18];
assign debug_x19_o = registers[19];
assign debug_x20_o = registers[20];
assign debug_x21_o = registers[21];
assign debug_x22_o = registers[22];
assign debug_x23_o = registers[23];
assign debug_x24_o = registers[24];
assign debug_x25_o = registers[25];
assign debug_x26_o = registers[26];
assign debug_x27_o = registers[27];
assign debug_x28_o = registers[28];
assign debug_x29_o = registers[29];
assign debug_x30_o = registers[30];
assign debug_x31_o = registers[31];

endmodule