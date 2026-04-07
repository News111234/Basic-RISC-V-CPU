// rtl/pipeline/ex_mem_reg.v (修改版)
`timescale 1ns/1ps

module ex_mem_reg (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire        stall_i,
    input  wire        flush_i,
    input  wire        intr_flush_i,    // 新增：中断冲刷
    
    input  wire [31:0] ex_alu_result_i,
    input  wire [31:0] ex_mem_addr_i,
    input  wire [31:0] ex_mem_wdata_i,
    input  wire [31:0] ex_pc_plus4_i,
    input  wire [4:0]  ex_rd_addr_i,
    
    input  wire        ex_mem_we_i,
    input  wire        ex_mem_re_i,
    input  wire [2:0]  ex_mem_width_i,
    input  wire [1:0]  ex_wb_sel_i,
    input  wire        ex_reg_we_i,
    
    // 新增：CSR结果
    input  wire [31:0] ex_csr_result_i,
    
    output reg  [31:0] mem_alu_result_o,
    output reg  [31:0] mem_mem_addr_o,
    output reg  [31:0] mem_mem_wdata_o,
    output reg  [31:0] mem_pc_plus4_o,
    output reg  [4:0]  mem_rd_addr_o,
    
    output reg         mem_mem_we_o,
    output reg         mem_mem_re_o,
    output reg  [2:0]  mem_mem_width_o,
    output reg  [1:0]  mem_wb_sel_o,
    output reg         mem_reg_we_o,
    
    // 新增：CSR结果输出
    output reg  [31:0] mem_csr_result_o
);

always @(posedge clk_i ) begin
    if (!rst_n_i) begin
        mem_alu_result_o <= 32'b0;
        mem_mem_addr_o   <= 32'b0;
        mem_mem_wdata_o  <= 32'b0;
        mem_pc_plus4_o   <= 32'b0;
        mem_rd_addr_o    <= 5'b0;
        
        mem_mem_we_o     <= 1'b0;
        mem_mem_re_o     <= 1'b0;
        mem_mem_width_o  <= 3'b0;
        mem_wb_sel_o     <= 2'b0;
        mem_reg_we_o     <= 1'b0;
        
        mem_csr_result_o <= 32'b0;
    end
    else if (flush_i || intr_flush_i) begin
        mem_alu_result_o <= 32'b0;
        mem_mem_addr_o   <= 32'b0;
        mem_mem_wdata_o  <= 32'b0;
        mem_pc_plus4_o   <= 32'b0;
        mem_rd_addr_o    <= 5'b0;
        
        mem_mem_we_o     <= 1'b0;
        mem_mem_re_o     <= 1'b0;
        mem_mem_width_o  <= 3'b0;
        mem_wb_sel_o     <= 2'b0;
        mem_reg_we_o     <= 1'b0;
        
        mem_csr_result_o <= 32'b0;
    end
    else if (!stall_i) begin
        mem_alu_result_o <= ex_alu_result_i;
        mem_mem_addr_o   <= ex_mem_addr_i;
        mem_mem_wdata_o  <= ex_mem_wdata_i;
        mem_pc_plus4_o   <= ex_pc_plus4_i;
        mem_rd_addr_o    <= ex_rd_addr_i;
        
        mem_mem_we_o     <= ex_mem_we_i;
        mem_mem_re_o     <= ex_mem_re_i;
        mem_mem_width_o  <= ex_mem_width_i;
        mem_wb_sel_o     <= ex_wb_sel_i;
        mem_reg_we_o     <= ex_reg_we_i;
        
        mem_csr_result_o <= ex_csr_result_i;
    end
end

endmodule