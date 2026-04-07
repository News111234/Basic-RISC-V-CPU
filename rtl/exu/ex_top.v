// rtl/exu/ex_top.v (修改版)
`timescale 1ns/1ps

module ex_top (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    input  wire [31:0] rs1_data_i,
    input  wire [31:0] rs2_data_i,
    input  wire [31:0] imm_i,
    input  wire [31:0] pc_i,

    input  wire [1:0]  wb_sel_i,
    input  wire        reg_we_i,
    input  wire [4:0]  rd_addr_i,
    
    input  wire [3:0]  alu_op_i,
    input  wire        alu_src_i,
    input  wire        branch_i,
    input  wire        jump_i,
    input  wire [2:0]  funct3_i,
    input  wire        mem_we_i,
    input  wire        mem_re_i,
    input  wire [2:0]  mem_width_i,
    
    input  wire [31:0] ex_forward_data_i,
    input  wire [31:0] mem_forward_data_i,



    input  wire [1:0]  forwardA_i,
    input  wire [1:0]  forwardB_i,

    input  wire [6:0]  opcode_i,
    
    // 新增：CSR结果输入
    input  wire [31:0] csr_result_i,      // 来自CSR控制器的结果
    
        // 新增：MEPC 输入（来自 CSR）
    input  wire [31:0] csr_mepc_i,
    
    // 新增：MRET 输入
    input  wire        mret_i,

    output wire [31:0] alu_result_o,
    output wire [31:0] mem_addr_o,
    output wire [31:0] mem_wdata_o,
    output wire        mem_we_o,
    output wire        mem_re_o,
    
    output wire        branch_taken_o,
    output wire [31:0] branch_target_o,
    output wire        jump_taken_o,
    output wire [31:0] jump_target_o,
    
    output wire [31:0] pc_plus4_o,
    
    output wire [31:0] ex_result_o,
    
    output wire [1:0]  wb_sel_o,
    output wire        reg_we_o,
    output wire [4:0]  rd_addr_o,
    output wire [2:0]  mem_width_o,

    output wire [31:0] op1_selected_o,
    output wire [31:0] op2_selected_o,
    
    // 新增：CSR结果输出
    output wire [31:0] ex_csr_result_o
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