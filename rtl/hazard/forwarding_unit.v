`timescale 1ns/1ps

// 模块: forwarding_unit
// 功能: 前递单元 (数据转发)，解决流水线的数据冒险
// 描述:
//   该模块检测EX阶段当前指令的源寄存器(rs1/rs2)是否与后续阶段
//   (MEM/WB或EX/MEM)的目标寄存器(rd)存在依赖关系。
//   如果存在依赖且目标寄存器不是x0，则产生前递控制信号(forwardA_o/forwardB_o)，
//   通知EX阶段从后续阶段的结果中直接获取数据，避免流水线停顿。
//
// 前递优先级:
//   1. 优先使用MEM/WB阶段的数据 (最新)
//   2. 其次使用EX/MEM阶段的数据，但排除load指令 (因为load数据在MEM阶段才就绪)
//
// 前递选择编码:
//   2'b00: 无前递，使用ID/EX寄存器的原始值
//   2'b01: 前递来自EX/MEM阶段的结果 (alu_result)
//   2'b10: 前递来自MEM/WB阶段的结果 (mem_rdata或alu_result)
// ============================================================================
module forwarding_unit (
    // ========== 来自ID/EX寄存器的源寄存器地址 ==========
    input  wire [4:0] id_ex_rs1_addr_i,  // ID/EX阶段指令的rs1地址
    input  wire [4:0] id_ex_rs2_addr_i,  // ID/EX阶段指令的rs2地址

    // ========== 来自EX/MEM寄存器的信息 ==========
    input  wire [4:0] ex_mem_rd_addr_i,  // EX/MEM阶段指令的目标寄存器地址
    input  wire       ex_mem_reg_we_i,   // EX/MEM阶段寄存器写使能
    input  wire       ex_mem_mem_re_i,   // EX/MEM阶段是否为load指令 (用于排除)

    // ========== 来自MEM/WB寄存器的信息 ==========
    input  wire [4:0] mem_wb_rd_addr_i,  // MEM/WB阶段指令的目标寄存器地址
    input  wire       mem_wb_reg_we_i,   // MEM/WB阶段寄存器写使能

    // ========== 流水线控制 ==========
    input  wire       stall_i,           // 流水线停顿标志 (停顿期间不产生前递)

    // ========== 前递选择输出 ==========
    output reg  [1:0] forwardA_o,        // 操作数1的前递选择
    output reg  [1:0] forwardB_o,        // 操作数2的前递选择

    // ========== 调试输出 ==========
    output wire [4:0] debug_ex_mem_rd_addr_o,  // 调试: EX/MEM目标寄存器地址
    output wire       debug_ex_mem_reg_we_o,   // 调试: EX/MEM写使能
    output wire [4:0] debug_mem_wb_rd_addr_o,  // 调试: MEM/WB目标寄存器地址
    output wire       debug_mem_wb_reg_we_o    // 调试: MEM/WB写使能
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