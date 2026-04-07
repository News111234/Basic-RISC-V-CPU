// ================================================
// Module: mem_ctrl
// Function: Memory Access Controller with Alignment Check
// ================================================
`timescale 1ns/1ps

module mem_ctrl (
    input  wire [31:0] alu_result_i,
    input  wire [31:0] wdata_i,
    input  wire        mem_we_i,
    input  wire        mem_re_i,
    input  wire [2:0]  mem_width_i,
    
    output wire [31:0] mem_addr_o,
    output wire [31:0] mem_wdata_o,
    output wire        mem_we_o,
    output wire        mem_re_o,
    output wire [2:0]  mem_width_o,
    
    output wire        mem_misalign_o,
    output wire        mem_error_o
);

// ========== 地址对齐检查 ==========
wire misalign = (mem_width_i == 3'b010 && alu_result_i[1:0] != 2'b00) || // LW/SW
                (mem_width_i == 3'b001 && alu_result_i[0]   != 1'b0);    // LH/SH

// ========== 输出信号 ==========
assign mem_addr_o   = alu_result_i;
assign mem_wdata_o  = wdata_i;          // data_ram 会自行处理字节/半字写入
assign mem_we_o     = mem_we_i && !misalign;
assign mem_re_o     = mem_re_i && !misalign;
assign mem_width_o  = mem_width_i;

// ========== 异常信号 ==========
assign mem_misalign_o = misalign;
assign mem_error_o    = (mem_we_i || mem_re_i) && (alu_result_i[31:28] != 4'h0); // 假设有效地址为 0x0000_0000 ~ 0x0FFF_FFFF

endmodule