// rtl/wbu/wb_mux.v (修改版)
`timescale 1ns/1ps

module wb_mux (
    // ========== 数据输入端口 ==========
    input  wire [31:0] alu_result_i,   // 来自执行阶段：ALU计算结果
    input  wire [31:0] mem_rdata_i,    // 来自访存阶段：内存读取数据
    input  wire [31:0] pc_plus4_i,     // 来自执行阶段：PC+4值
    input  wire [31:0] csr_data_i,     // 来自CSR模块：控制和状态寄存器数据
    
    // ========== 控制信号输入 ==========
    input  wire [1:0]  wb_sel_i,       // 写回选择信号
    
    // ========== 输出端口 ==========
    output reg  [31:0] wb_data_o       // 输出：写回寄存器的数据
);

// ========== 写回选择信号编码说明 ==========
// wb_sel_i 的2位编码含义：
// 2'b00: ALU计算结果  -> R-type指令，I-type算术指令
// 2'b01: 内存读取数据  -> 加载指令（LW, LH, LB等）
// 2'b10: PC + 4       -> 跳转指令（JAL, JALR）的返回地址
// 2'b11: CSR数据      -> CSR指令（CSRRW, CSRRS等）

// ========== 写回数据选择逻辑 ==========
always @(*) begin
    case (wb_sel_i)
        2'b00: begin
            wb_data_o = alu_result_i;  // ALU结果
        end
        
        2'b01: begin
            wb_data_o = mem_rdata_i;   // 内存读取数据
        end
        
        2'b10: begin
            wb_data_o = pc_plus4_i;    // PC+4（返回地址）
        end
        
        2'b11: begin
            wb_data_o = csr_data_i;    // CSR数据
        end
        
        default: begin
            wb_data_o = 32'b0;          // 安全默认值
        end
    endcase
end

endmodule