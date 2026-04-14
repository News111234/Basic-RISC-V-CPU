// rtl/csr/csr_instructions.v
`timescale 1ns/1ps

// ============================================================================
// 模块: csr_instructions
// 功能: CSR指令的处理单元 (与csr_controller功能高度相似，为独立模块)
// 描述:
//   该模块是csr_controller的另一个实现，功能完全一致。
//   它接收CSR指令信息，生成对CSR寄存器文件的写使能和写数据，
//   并产生CSR指令的结果。推测是为流水线解耦或特定集成而设计的备选/封装模块。
// ============================================================================
module csr_instructions (
    // ========== 系统接口 ==========
    input  wire        clk_i,          // 时钟信号
    input  wire        rst_n_i,        // 复位信号 (低电平有效)

    // ========== 来自ID阶段的CSR指令信息 ==========
    input  wire        csr_inst_valid_i, // CSR指令有效标志
    input  wire [2:0]  csr_op_i,       // CSR操作类型
    input  wire [11:0] csr_addr_i,     // CSR地址
    input  wire [4:0]  rs1_addr_i,     // rs1寄存器地址
    input  wire [31:0] rs1_data_i,     // rs1寄存器的值
    input  wire [31:0] imm_i,          // 立即数

    // ========== 来自CSR寄存器文件的数据 ==========
    input  wire [31:0] csr_rdata_i,    // 当前读出的CSR值

    // ========== 到CSR寄存器文件的写控制 ==========
    output reg         csr_we_o,       // CSR写使能
    output reg  [11:0] csr_waddr_o,    // CSR写地址
    output reg  [31:0] csr_wdata_o,    // CSR写数据

    // ========== 到EX阶段的输出 ==========
    output reg  [31:0] csr_result_o,   // CSR指令的结果 (用于写回)

    // ========== 调试输出 ==========
    output wire [31:0] debug_csr_op_type_o, // 调试: CSR操作类型
    output wire        debug_csr_we_o,      // 调试: CSR写使能
    output wire [11:0] debug_csr_addr_o     // 调试: CSR地址
);

// ========== CSR操作类型定义 ==========
// RISC-V特权规范定义的CSR指令类型
localparam CSR_OP_NONE   = 3'b000;  // 非CSR指令或ECALL/EBREAK
localparam CSR_OP_RW     = 3'b001;  // CSRRW  - 原子读/写CSR
localparam CSR_OP_RS     = 3'b010;  // CSRRS  - 原子读和置位CSR
localparam CSR_OP_RC     = 3'b011;  // CSRRC  - 原子读和清除CSR
localparam CSR_OP_RWI    = 3'b101;  // CSRRWI - 原子读/写CSR（立即数）
localparam CSR_OP_RSI    = 3'b110;  // CSRRSI - 原子读和置位CSR（立即数）
localparam CSR_OP_RCI    = 3'b111;  // CSRRCI - 原子读和清除CSR（立即数）

// ========== 立即数提取 ==========
// 对于CSR立即数指令，zimm[4:0]来自rs1字段或imm的低5位
wire [4:0] zimm = rs1_addr_i;  // 来自rs1字段（对于CSRRWI/CSRRSI/CSRRCI）

// 判断是否是立即数版本的CSR指令
wire is_imm_csr = csr_op_i[2];  // 如果最高位为1，是立即数版本

// ========== CSR写数据计算 ==========
reg [31:0] csr_write_val;
reg        do_csr_write;

always @(*) begin
    // 默认值
    csr_write_val = 32'b0;
    do_csr_write = 1'b0;
    
    if (csr_inst_valid_i) begin
        case (csr_op_i)
            // CSRRW: csr = x[rs1]
            CSR_OP_RW: begin
                do_csr_write = (rs1_addr_i != 5'b0);  // rs1=x0时不写
                csr_write_val = rs1_data_i;
            end
            
            // CSRRS: csr = csr | x[rs1]
            CSR_OP_RS: begin
                do_csr_write = (rs1_addr_i != 5'b0);  // rs1=x0时不写
                csr_write_val = csr_rdata_i | rs1_data_i;
            end
            
            // CSRRC: csr = csr & ~x[rs1]
            CSR_OP_RC: begin
                do_csr_write = (rs1_addr_i != 5'b0);  // rs1=x0时不写
                csr_write_val = csr_rdata_i & (~rs1_data_i);
            end
            
            // CSRRWI: csr = zimm
            CSR_OP_RWI: begin
                do_csr_write = (zimm != 5'b0);  // zimm=0时不写
                csr_write_val = {27'b0, zimm};
            end
            
            // CSRRSI: csr = csr | zimm
            CSR_OP_RSI: begin
                do_csr_write = (zimm != 5'b0);  // zimm=0时不写
                csr_write_val = csr_rdata_i | {27'b0, zimm};
            end
            
            // CSRRCI: csr = csr & ~zimm
            CSR_OP_RCI: begin
                do_csr_write = (zimm != 5'b0);  // zimm=0时不写
                csr_write_val = csr_rdata_i & (~{27'b0, zimm});
            end
            
            default: begin
                do_csr_write = 1'b0;
                csr_write_val = 32'b0;
            end
        endcase
    end
end

// ========== CSR写控制输出 ==========
always @(*) begin
    csr_we_o    = do_csr_write;
    csr_waddr_o = csr_addr_i;
    csr_wdata_o = csr_write_val;
end

// ========== CSR指令结果 ==========
// CSR指令的结果总是CSR的旧值（读出的值）
always @(*) begin
    csr_result_o = csr_rdata_i;
end

// ========== 调试输出 ==========
assign debug_csr_op_type_o = {29'b0, csr_op_i};
assign debug_csr_we_o      = csr_we_o;
assign debug_csr_addr_o    = csr_addr_i;

endmodule