// rtl/pipeline/if_id_reg.v (修改版)
`timescale 1ns/1ps

// ============================================================================
// 模块: if_id_reg
// 功能: IF/ID 流水线寄存器，连接取指阶段和译码阶段
// 描述:
//   该寄存器在时钟上升沿锁存IF阶段的PC和指令，传递给ID阶段。
//   支持停顿(stall)、常规冲刷(flush)和中断冲刷(intr_flush)。
//   冲刷时插入NOP指令(0x00000013, addi x0, x0, 0)，防止错误指令传播。
// ============================================================================
module if_id_reg (
    // ========== 系统接口 ==========
    input  wire        clk_i,          // 时钟信号
    input  wire        rst_n_i,        // 复位信号 (低电平有效)

    // ========== 流水线控制信号 ==========
    input  wire        stall_i,        // 停顿标志 (保持当前值)
    input  wire        flush_i,        // 常规冲刷标志 (分支/跳转)
    input  wire        intr_flush_i,   // 中断冲刷标志 (优先级高于常规冲刷)

    // ========== IF阶段输入 ==========
    input  wire [31:0] if_pc_i,        // IF阶段PC
    input  wire [31:0] if_instr_i,     // IF阶段指令

    // ========== ID阶段输出 ==========
    output reg  [31:0] id_pc_o,        // ID阶段PC
    output reg  [31:0] id_instr_o      // ID阶段指令
);

always @(posedge clk_i ) begin
    if (!rst_n_i) begin
        id_pc_o    <= 32'b0;
        id_instr_o <= 32'b0;
    end
    else if (flush_i || intr_flush_i) begin  // 合并冲刷信号
        id_pc_o    <= 32'b0;
        id_instr_o <= 32'h00000013;  // nop: addi x0, x0, 0
        if (intr_flush_i) begin
            $display("[IF_ID_REG] Time=%0tns: Flushed by interrupt", $time);
        end
    end
    else if (!stall_i) begin
        id_pc_o    <= if_pc_i;
        id_instr_o <= if_instr_i;
    end
end

endmodule