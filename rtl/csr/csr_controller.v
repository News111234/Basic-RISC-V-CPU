// rtl/csr/csr_controller.v
`timescale 1ns/1ps

// ============================================================================
// 模块: csr_controller
// 功能: 控制和状态寄存器(CSR)指令的执行控制器
// 描述:
//   该模块接收来自译码阶段的CSR指令信息，并根据RISC-V特权架构规范
//   计算CSR的写数据和写使能信号。它负责处理CSRRW, CSRRS, CSRRC及其
//   立即数版本(CSRRWI, CSRRSI, CSRRCI)共6种CSR操作。
//
//   核心逻辑: 根据操作码(csr_op_i)，将源操作数(rs1或立即数)与当前
//   CSR值(csr_rdata_i)进行运算，生成新的CSR写回值。
//   指令的最终结果(csr_result_o)总是读取到的CSR旧值。
// ============================================================================
module csr_controller (
    // ========== 系统接口 ==========
    input  wire        clk_i,          // 时钟信号
    input  wire        rst_n_i,        // 复位信号 (低电平有效)

    // ========== 来自ID阶段的CSR指令信息 ==========
    input  wire        csr_inst_valid_i, // CSR指令有效标志
    input  wire [2:0]  csr_op_i,       // CSR操作类型 (3'b001-3'b111)
    input  wire [11:0] csr_addr_i,     // CSR地址 (12位)
    input  wire [4:0]  csr_rs1_addr_i, // rs1寄存器地址 (用于寄存器版本)
    input  wire [31:0] csr_imm_i,      // 立即数 (用于立即数版本)

    // ========== 来自寄存器堆的数据 ==========
    input  wire [31:0] rs1_data_i,     // rs1寄存器的值

    // ========== 来自CSR寄存器文件的数据 ==========
    input  wire [31:0] csr_rdata_i,    // 当前读出的CSR值

    // ========== 到CSR寄存器文件的写控制 ==========
    output reg         csr_we_o,       // CSR写使能
    output reg  [11:0] csr_waddr_o,    // CSR写地址
    output reg  [31:0] csr_wdata_o,    // CSR写数据

    // ========== 到EX阶段的输出 ==========
    output reg  [31:0] csr_result_o,   // CSR指令的结果 (用于写回寄存器堆)

    // ========== 调试输出 ==========
    output wire [31:0] debug_csr_result_o // 调试: CSR指令结果
);

// ========== CSR操作类型定义 ==========
localparam CSR_OP_NONE   = 3'b000;
localparam CSR_OP_RW     = 3'b001;  // CSRRW
localparam CSR_OP_RS     = 3'b010;  // CSRRS
localparam CSR_OP_RC     = 3'b011;  // CSRRC
localparam CSR_OP_RWI    = 3'b101;  // CSRRWI
localparam CSR_OP_RSI    = 3'b110;  // CSRRSI
localparam CSR_OP_RCI    = 3'b111;  // CSRRCI

// ========== CSR写数据计算 ==========
wire [31:0] rs1_val = rs1_data_i;
wire [31:0] imm_val = csr_imm_i;
wire [4:0]  rs1_addr = csr_rs1_addr_i;

// 对于立即数版本，zimm[4:0]在csr_imm_i的低5位
wire [4:0]  zimm = csr_imm_i[4:0];

reg [31:0] csr_write_val;
reg        do_csr_write;

always @(*) begin
    csr_write_val = 32'b0;
    do_csr_write = 1'b0;
    
    case (csr_op_i)
        CSR_OP_RW: begin  // CSRRW: csr = x[rs1]
            do_csr_write = csr_inst_valid_i && (rs1_addr != 5'b0);
            csr_write_val = rs1_val;
        end
        
        CSR_OP_RS: begin  // CSRRS: csr = csr | x[rs1]
            do_csr_write = csr_inst_valid_i && (rs1_addr != 5'b0);
            csr_write_val = csr_rdata_i | rs1_val;
        end
        
        CSR_OP_RC: begin  // CSRRC: csr = csr & ~x[rs1]
            do_csr_write = csr_inst_valid_i && (rs1_addr != 5'b0);
            csr_write_val = csr_rdata_i & (~rs1_val);
        end
        
        CSR_OP_RWI: begin // CSRRWI: csr = zimm
            do_csr_write = csr_inst_valid_i && (zimm != 5'b0);
            csr_write_val = {27'b0, zimm};
        end
        
        CSR_OP_RSI: begin // CSRRSI: csr = csr | zimm
            do_csr_write = csr_inst_valid_i && (zimm != 5'b0);
            csr_write_val = csr_rdata_i | {27'b0, zimm};
        end
        
        CSR_OP_RCI: begin // CSRRCI: csr = csr & ~zimm
            do_csr_write = csr_inst_valid_i && (zimm != 5'b0);
            csr_write_val = csr_rdata_i & (~{27'b0, zimm});
        end
        
        default: begin
            do_csr_write = 1'b0;
            csr_write_val = 32'b0;
        end
    endcase
end

// ========== CSR写控制 ==========
always @(*) begin
    csr_we_o    = do_csr_write;
    csr_waddr_o = csr_addr_i;
    csr_wdata_o = csr_write_val;
end

// ========== CSR指令结果 ==========
// CSR指令的结果总是CSR的旧值
always @(*) begin
    csr_result_o = csr_rdata_i;
end

assign debug_csr_result_o = csr_result_o;

endmodule