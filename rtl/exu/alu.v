// rtl/exu/alu.v (支持 M 扩展)
`timescale 1ns/1ps

// 模块: alu
// 功能: 算术逻辑单元 (ALU)，支持RISC-V I扩展和M扩展（乘除法）
// 描述:
//   该模块执行所有算术和逻辑运算。根据4位操作码(alu_op_i)选择运算类型。
//   支持加法、减法、移位、比较、逻辑运算以及有符号/无符号乘除和取模。
//
// 操作码定义 (alu_op_i):
//   4'b0000: ADD/ADDI      - 加法
//   4'b0001: SUB           - 减法
//   4'b0010: SLL/SLLI      - 逻辑左移
//   4'b0011: SLT/SLTI      - 有符号小于置位
//   4'b0100: SLTU/SLTIU    - 无符号小于置位
//   4'b0101: XOR/XORI      - 异或
//   4'b0110: OR/ORI/SRL/SRLI - 或 / 逻辑右移
//   4'b0111: AND/ANDI/SRA/SRAI - 与 / 算术右移
//   4'b1000: MUL           - 有符号乘法 (低32位)
//   4'b1001: MULH          - 有符号乘法 (高32位)
//   4'b1010: MULHSU        - 有符号乘无符号 (高32位)
//   4'b1011: MULHU         - 无符号乘法 (高32位)
//   4'b1100: DIV           - 有符号除法
//   4'b1101: DIVU          - 无符号除法
//   4'b1110: REM           - 有符号取模
//   4'b1111: REMU          - 无符号取模
// ============================================================================
module alu (
    // ========== 输入端口 ==========
    input  wire [31:0] op1_i,     // 操作数1 (源操作数1)
    input  wire [31:0] op2_i,     // 操作数2 (源操作数2或立即数)
    input  wire [3:0]  alu_op_i,  // ALU操作码 (4位，决定运算类型)
    
    // ========== 输出端口 ==========
    output reg  [31:0] result_o,  // 计算结果
    output wire        zero_o     // 零标志位 (result_o == 32'b0)
);

// ========== 内部信号 ==========
wire [31:0] add_result;    // 加法结果
wire [31:0] sub_result;    // 减法结果
wire [31:0] sll_result;    // 逻辑左移结果
wire [31:0] srl_result;    // 逻辑右移结果
wire [31:0] sra_result;    // 算术右移结果
wire        slt_result;    // 有符号小于比较结果
wire        sltu_result;   // 无符号小于比较结果
wire [31:0] xor_result;    // 异或结果
wire [31:0] or_result;     // 或结果
wire [31:0] and_result;    // 与结果

// ========== M 扩展乘除法信号 ==========
wire [63:0] mul_signed;        // 有符号乘法结果
wire [63:0] mul_unsigned;      // 无符号乘法结果
wire [31:0] div_result;        // 除法结果
wire [31:0] rem_result;        // 取模结果
wire        div_by_zero;       // 除零标志

// ========== 1. 加法和减法计算 ==========
assign add_result = op1_i + op2_i;
assign sub_result = op1_i - op2_i;

// ========== 2. 移位操作计算 ==========
assign sll_result = op1_i << op2_i[4:0];
assign srl_result = op1_i >> op2_i[4:0];
assign sra_result = $signed(op1_i) >>> op2_i[4:0];

// ========== 3. 比较操作计算 ==========
assign slt_result = ($signed(op1_i) < $signed(op2_i)) ? 1'b1 : 1'b0;
assign sltu_result = (op1_i < op2_i) ? 1'b1 : 1'b0;

// ========== 4. 逻辑操作计算 ==========
assign xor_result = op1_i ^ op2_i;
assign or_result  = op1_i | op2_i;
assign and_result = op1_i & op2_i;

// ========== 5. M 扩展乘除法计算 ==========
// 有符号乘法 (64位结果)
assign mul_signed = $signed(op1_i) * $signed(op2_i);

// 无符号乘法 (64位结果)
assign mul_unsigned = op1_i * op2_i;

// 除零检测
assign div_by_zero = (op2_i == 32'b0);

// 有符号除法 (除数为0时返回 -1)
assign div_result = div_by_zero ? 32'hFFFFFFFF : 
                    $signed(op1_i) / $signed(op2_i);

// 有符号取模 (除数为0时返回被除数)
assign rem_result = div_by_zero ? op1_i : 
                    $signed(op1_i) % $signed(op2_i);

// 无符号除法 (除数为0时返回 -1)
wire [31:0] divu_result = div_by_zero ? 32'hFFFFFFFF : 
                          op1_i / op2_i;

// 无符号取模 (除数为0时返回被除数)
wire [31:0] remu_result = div_by_zero ? op1_i : 
                          op1_i % op2_i;

// ========== 6. 根据 alu_op 选择输出结果 ==========
always @(*) begin
    case (alu_op_i)
        // ========== I 扩展指令 ==========
        4'b0000: result_o = add_result;      // ADD/ADDI
        4'b0001: result_o = sub_result;      // SUB
        4'b0010: result_o = sll_result;      // SLL/SLLI
        4'b0011: result_o = {31'b0, slt_result};  // SLT/SLTI
        4'b0100: result_o = {31'b0, sltu_result}; // SLTU/SLTIU
        4'b0101: result_o = xor_result;      // XOR/XORI
        4'b0110: result_o = or_result;       // OR/ORI/SRL/SRLI
        4'b0111: result_o = and_result;      // AND/ANDI/SRA/SRAI
        
        // ========== M 扩展乘除法指令 ==========
        4'b1000: result_o = mul_signed[31:0];     // MUL (低32位)
        4'b1001: result_o = mul_signed[63:32];    // MULH (有符号高32位)
        4'b1010: begin  // MULHSU: op1有符号, op2无符号
            result_o = $signed(op1_i) * $signed({1'b0, op2_i});
            result_o = result_o[63:32];
        end
        4'b1011: result_o = mul_unsigned[63:32];  // MULHU (无符号高32位)
        4'b1100: result_o = div_result;            // DIV (有符号除法)
        4'b1101: result_o = divu_result;           // DIVU (无符号除法)
        4'b1110: result_o = rem_result;            // REM (有符号取模)
        4'b1111: result_o = remu_result;           // REMU (无符号取模)
        
        default: result_o = add_result;
    endcase
end

// ========== 7. 生成零标志位 ==========
assign zero_o = (result_o == 32'b0) ? 1'b1 : 1'b0;

endmodule