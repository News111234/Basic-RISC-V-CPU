// rtl/id/imm_gen.v (修改版)
`timescale 1ns/1ps

module imm_gen (
    input  wire [31:0] instr_i,
    output reg  [31:0] imm_o
);

wire [6:0] opcode = instr_i[6:0];
reg [20:0] jal_imm;
reg [19:0] combined_imm;

always @(*) begin
    case (opcode)
        // I-type指令
        7'b0010011,  // I-type立即数运算
        7'b0000011,  // LOAD指令
        7'b1100111:  // JALR指令
        begin
            imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
        end
        
        // S-type指令
        7'b0100011:  // STORE指令
        begin
            imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        end
        
        // B-type指令
        7'b1100011:  // BRANCH指令
        begin
            imm_o = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], 
                     instr_i[11:8], 1'b0};
        end
        
        // U-type指令
        7'b0110111,  // LUI
        7'b0010111:  // AUIPC
        begin
            imm_o = {instr_i[31:12], 12'b0};
        end
        
        // J-type指令
        7'b1101111:  // JAL
        begin
            combined_imm[19:0] = {
                instr_i[31],      // bit19 (imm[20])
                instr_i[19:12],   // bits18-11 (imm[19:12])
                instr_i[20],      // bit10 (imm[11])
                instr_i[30:21]    // bits9-0 (imm[10:1])
            };
            imm_o = {{12{combined_imm[19]}}, combined_imm};
        end
        
        // SYSTEM指令 (包括CSR)
        7'b1110011:  // SYSTEM
        begin
            // CSR指令的立即数是zimm[4:0] (零扩展)
            // 或者用于ECALL/EBREAK等，立即数为0
            if (instr_i[14:12] != 3'b000) begin
                // CSR指令：zimm[4:0]来自rs1字段
                imm_o = {27'b0, instr_i[19:15]};
            end else begin
                imm_o = 32'b0;
            end
        end
        
        default: 
        begin
            imm_o = 32'b0;
        end
    endcase
end

endmodule
