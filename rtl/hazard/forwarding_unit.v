`timescale 1ns/1ps

module forwarding_unit (
    input  wire [4:0] id_ex_rs1_addr_i,
    input  wire [4:0] id_ex_rs2_addr_i,
    
    input  wire [4:0] ex_mem_rd_addr_i,
    input  wire       ex_mem_reg_we_i,
    input  wire       ex_mem_mem_re_i,   // EX/MEM 阶段是否是 load
    
    input  wire [4:0] mem_wb_rd_addr_i,
    input  wire       mem_wb_reg_we_i,
    
    input  wire       stall_i,
    
    output reg [1:0] forwardA_o,
    output reg [1:0] forwardB_o,

       // ========== 新增调试输出 ==========
    output wire [4:0] debug_ex_mem_rd_addr_o,
    output wire       debug_ex_mem_reg_we_o,
    output wire [4:0] debug_mem_wb_rd_addr_o,
    output wire       debug_mem_wb_reg_we_o
);

assign debug_ex_mem_rd_addr_o = ex_mem_rd_addr_i;
assign debug_ex_mem_reg_we_o = ex_mem_reg_we_i;
assign debug_mem_wb_rd_addr_o = mem_wb_rd_addr_i;
assign debug_mem_wb_reg_we_o = mem_wb_reg_we_i;

always @(*) begin
    if (stall_i) begin
        forwardA_o = 2'b00;
        forwardB_o = 2'b00;
    end else begin
        forwardA_o = 2'b00;
        forwardB_o = 2'b00;
        
        // 优先检查 MEM/WB 阶段（最新数据）
        if (mem_wb_reg_we_i && (mem_wb_rd_addr_i != 5'b0)) begin
            if (mem_wb_rd_addr_i == id_ex_rs1_addr_i)
                forwardA_o = 2'b10;
            if (mem_wb_rd_addr_i == id_ex_rs2_addr_i)
                forwardB_o = 2'b10;
        end
        
        // 再检查 EX/MEM 阶段（非 load 指令）
        if (ex_mem_reg_we_i && (ex_mem_rd_addr_i != 5'b0) && !ex_mem_mem_re_i) begin
            if (ex_mem_rd_addr_i == id_ex_rs1_addr_i)
                forwardA_o = 2'b01;
            if (ex_mem_rd_addr_i == id_ex_rs2_addr_i)
                forwardB_o = 2'b01;
        end
    end
end

endmodule