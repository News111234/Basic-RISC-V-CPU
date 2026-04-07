// ================================================
// 模块: data_ram
// 功能: 数据存储器（单端口，同步读写）
// 支持：SB/SH/SW, LB/LH/LW, LBU/LHU
// ================================================
`timescale 1ns/1ps

module data_ram (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    input  wire        we_i,
    input  wire        re_i,
    input  wire [2:0]  width_i,    // 000=SB/LB/LBU, 001=SH/LH/LHU, 010=SW/LW
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    
    output reg  [31:0] rdata_o,
    output wire        ready_o
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
