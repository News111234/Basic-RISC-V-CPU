// rtl/exu/ex_top.v (修改版)
`timescale 1ns/1ps

// 模块: ex_top
// 功能: 执行阶段顶层模块，集成ALU、分支单元、跳转逻辑和前递处理
// 描述:
//   该模块是流水线执行阶段的核心，负责:
//   1. 接收来自ID/EX寄存器的指令信息和操作数
//   2. 根据前递控制(forwardA_i/forwardB_i)选择正确的操作数
//   3. 调用ALU执行运算
//   4. 调用分支单元判断分支条件
//   5. 处理JAL/JALR/MRET跳转，计算跳转目标
//   6. 根据wb_sel_i选择最终结果(ALU/内存/PC+4/CSR)
//   7. 生成内存访问的地址、写数据和宽度
// ============================================================================
module ex_top (
    // ========== 系统接口 ==========
    input  wire        clk_i,          // 时钟信号
    input  wire        rst_n_i,        // 复位信号 (低电平有效)

    // ========== 来自ID/EX寄存器的数据 ==========
    input  wire [31:0] rs1_data_i,     // rs1原始数据
    input  wire [31:0] rs2_data_i,     // rs2原始数据
    input  wire [31:0] imm_i,          // 立即数
    input  wire [31:0] pc_i,           // 当前PC值

    // ========== 控制信号 ==========
    input  wire [1:0]  wb_sel_i,       // 写回选择信号
    input  wire        reg_we_i,       // 寄存器写使能
    input  wire [4:0]  rd_addr_i,      // 目标寄存器地址
    input  wire [3:0]  alu_op_i,       // ALU操作码
    input  wire        alu_src_i,      // ALU源操作数2选择 (0: rs2, 1: imm)
    input  wire        branch_i,       // 分支指令标志
    input  wire        jump_i,         // 跳转指令标志 (JAL/JALR)
    input  wire [2:0]  funct3_i,       // funct3字段 (用于分支)
    input  wire        mem_we_i,       // 内存写使能
    input  wire        mem_re_i,       // 内存读使能
    input  wire [2:0]  mem_width_i,    // 内存访问宽度
    input  wire [6:0]  opcode_i,       // 指令操作码 (用于区分JAL/JALR)

    // ========== 前递数据输入 ==========
    input  wire [31:0] ex_forward_data_i,   // 来自EX/MEM阶段的前递数据
    input  wire [31:0] mem_forward_data_i,  // 来自MEM/WB阶段的前递数据
    input  wire [1:0]  forwardA_i,          // 操作数1前递选择
    input  wire [1:0]  forwardB_i,          // 操作数2前递选择

    // ========== CSR和中断相关 ==========
    input  wire [31:0] csr_result_i,    // 来自CSR控制器的结果
    input  wire [31:0] csr_mepc_i,      // 来自CSR的mepc值 (用于MRET)
    input  wire        mret_i,          // MRET指令标志

    // ========== 输出到EX/MEM寄存器 ==========
    output wire [31:0] alu_result_o,    // ALU计算结果
    output wire [31:0] mem_addr_o,      // 内存访问地址
    output wire [31:0] mem_wdata_o,     // 内存写数据
    output wire        mem_we_o,        // 内存写使能
    output wire        mem_re_o,        // 内存读使能
    output wire [2:0]  mem_width_o,     // 内存访问宽度

    // ========== 分支/跳转输出 ==========
    output wire        branch_taken_o,  // 分支是否跳转
    output wire [31:0] branch_target_o, // 分支目标地址
    output wire        jump_taken_o,    // 跳转是否发生 (JAL/JALR/MRET)
    output wire [31:0] jump_target_o,   // 跳转目标地址

    // ========== 流水线控制输出 ==========
    output wire [31:0] pc_plus4_o,      // PC + 4 (用于JAL返回地址)
    output wire [31:0] ex_result_o,     // 执行阶段结果 (根据wb_sel选择)
    output wire [1:0]  wb_sel_o,        // 写回选择 (透传)
    output wire        reg_we_o,        // 寄存器写使能 (透传)
    output wire [4:0]  rd_addr_o,       // 目标寄存器地址 (透传)

    // ========== 调试输出 ==========
    output wire [31:0] op1_selected_o,  // 调试: 选择后的操作数1
    output wire [31:0] op2_selected_o,  // 调试: 选择后的操作数2
    output wire [31:0] ex_csr_result_o  // 调试: CSR结果
);
// ========== 前递选择 ==========
wire [31:0] op1_selected;
wire [31:0] op2_selected;

assign op1_selected = (forwardA_i == 2'b01) ? ex_forward_data_i :
                      (forwardA_i == 2'b10) ? mem_forward_data_i :
                      rs1_data_i;

assign op2_selected = (forwardB_i == 2'b01) ? ex_forward_data_i :
                      (forwardB_i == 2'b10) ? mem_forward_data_i :
                      rs2_data_i;

// 监测
assign op1_selected_o = op1_selected;
assign op2_selected_o = op2_selected;

// ========== ALU 输入 ==========
wire [31:0] alu_op1 = op1_selected;
wire [31:0] alu_op2 = alu_src_i ? imm_i : op2_selected;

// ========== ALU 实例化 ==========
wire [31:0] alu_result;
wire        alu_zero;

alu u_alu (
    .op1_i     (alu_op1),
    .op2_i     (alu_op2),
    .alu_op_i  (alu_op_i),
    .result_o  (alu_result),
    .zero_o    (alu_zero)
);

// ========== 分支单元 ==========
branch u_branch (
    .rs1_data_i      (op1_selected),
    .rs2_data_i      (op2_selected),
    .pc_i            (pc_i),
    .imm_i           (imm_i),
    .funct3_i        (funct3_i),
    .branch_i        (branch_i),
    .alu_zero_i      (alu_zero),
    .branch_taken_o  (branch_taken_o),
    .branch_target_o (branch_target_o)
);

// ========== 跳转逻辑 ==========
wire jump_taken = jump_i|| mret_i;  // MRET 也算跳转

wire [31:0] jal_target  = pc_i + imm_i;
wire [31:0] jalr_target = (op1_selected + imm_i) & 32'hfffffffe;

//  关键：MRET 的目标地址来自 MEPC
wire [31:0] jump_target = mret_i ? csr_mepc_i :
                          (opcode_i == 7'b1101111) ? jal_target :
                          (opcode_i == 7'b1100111) ? jalr_target :
                          32'b0;

assign jump_taken_o  = jump_taken;
assign jump_target_o = jump_target;

// ========== EX结果选择 ==========
// 根据写回选择信号，决定输出哪个结果
reg [31:0] ex_result;

always @(*) begin
    case (wb_sel_i)
        2'b00:   ex_result = alu_result;      // ALU结果
        2'b01:   ex_result = 32'b0;           // 内存数据（在MEM阶段获取）
        2'b10:   ex_result = pc_plus4_o;      // PC+4
        2'b11:   ex_result = csr_result_i;    // CSR结果
        default: ex_result = alu_result;
    endcase
end

// ========== 输出连接 ==========
assign alu_result_o   = alu_result;
assign mem_addr_o     = alu_result;
assign mem_wdata_o    = (mem_width_i == 3'b000) ? {24'b0, op2_selected[7:0]} :
                        (mem_width_i == 3'b001) ? {16'b0, op2_selected[15:0]} :
                        op2_selected;    

assign mem_we_o       = mem_we_i;
assign mem_re_o       = mem_re_i;
assign pc_plus4_o     = pc_i + 32'h4;
assign mem_width_o    = mem_width_i;

assign ex_result_o    = ex_result;
assign wb_sel_o       = wb_sel_i;
assign reg_we_o       = reg_we_i;
assign rd_addr_o      = rd_addr_i;

// 新增
assign ex_csr_result_o = csr_result_i;

endmodule