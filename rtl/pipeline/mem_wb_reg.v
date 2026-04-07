// rtl/pipeline/mem_wb_reg.v (完整修改版)
`timescale 1ns/1ps

module mem_wb_reg (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire        stall_i,
    input  wire        flush_i,
    input  wire        intr_flush_i,
    
    input  wire [31:0] mem_alu_result_i,
    input  wire [31:0] mem_mem_rdata_i,
    input  wire [31:0] mem_pc_plus4_i,
    input  wire [4:0]  mem_rd_addr_i,
    
    input  wire [1:0]  mem_wb_sel_i,
    input  wire        mem_reg_we_i,
    
    input  wire [31:0] mem_csr_result_i,
    
    // ========== 新增：输入 load 标志 ==========
    input  wire        mem_mem_re_i,        // 来自 EX/MEM 寄存器的 mem_re
    
    output reg  [31:0] wb_alu_result_o,
    output reg  [31:0] wb_mem_rdata_o,
    output reg  [31:0] wb_pc_plus4_o,
    output reg  [4:0]  wb_rd_addr_o,
    
    output reg  [1:0]  wb_wb_sel_o,
    output reg         wb_reg_we_o,
    
    output reg  [31:0] wb_csr_result_o,
    
    // ========== 新增：输出 load 标志 ==========
    output reg         wb_mem_re_o          // 传递给 forwarding_unit
);

always @(posedge clk_i ) begin
    if (!rst_n_i) begin
        wb_alu_result_o <= 32'b0;
        wb_mem_rdata_o  <= 32'b0;
        wb_pc_plus4_o   <= 32'b0;
        wb_rd_addr_o    <= 5'b0;
        wb_wb_sel_o     <= 2'b0;
        wb_reg_we_o     <= 1'b0;
        wb_csr_result_o <= 32'b0;
        wb_mem_re_o     <= 1'b0;              // 新增
    end
    else if (flush_i || intr_flush_i) begin
        wb_alu_result_o <= 32'b0;
        wb_mem_rdata_o  <= 32'b0;
        wb_pc_plus4_o   <= 32'b0;
        wb_rd_addr_o    <= 5'b0;
        wb_wb_sel_o     <= 2'b0;
        wb_reg_we_o     <= 1'b0;
        wb_csr_result_o <= 32'b0;
        wb_mem_re_o     <= 1'b0;              // 新增
    end
    else if (!stall_i) begin
        wb_alu_result_o <= mem_alu_result_i;
        wb_mem_rdata_o  <= mem_mem_rdata_i;
        wb_pc_plus4_o   <= mem_pc_plus4_i;
        wb_rd_addr_o    <= mem_rd_addr_i;
        wb_wb_sel_o     <= mem_wb_sel_i;
        wb_reg_we_o     <= mem_reg_we_i;
        wb_csr_result_o <= mem_csr_result_i;
        wb_mem_re_o     <= mem_mem_re_i;     // 新增：传递 load 标志
    end
end

endmodule