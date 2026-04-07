// rtl/pipeline/if_id_reg.v (修改版)
`timescale 1ns/1ps

module if_id_reg (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire        stall_i,
    input  wire        flush_i,         // 常规冲刷（分支/跳转）
    input  wire        intr_flush_i,    // 新增：中断冲刷
    
    input  wire [31:0] if_pc_i,
    input  wire [31:0] if_instr_i,
    
    output reg  [31:0] id_pc_o,
    output reg  [31:0] id_instr_o
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