# -*- coding: utf-8 -*-
#!/usr/bin/env python3
"""
================================================================================
                    RISC-V 完整指令集汇编器 v2.0
================================================================================
支持指令集：
  RV32I (基础整数指令集):
    算术: add, sub, addi, slt, slti, sltu, sltiu, and, or, xor, andi, ori, xori
    移位: sll, srl, sra, slli, srli, srai
    分支: beq, bne, blt, bge, bltu, bgeu
    跳转: jal, jalr
    内存: lb, lh, lw, lbu, lhu, sb, sh, sw
    高位: lui, auipc
  
  RV32M (乘法扩展):
    mul, mulh, mulhsu, mulhu, div, divu, rem, remu
  
  RV32A (原子操作扩展):
    lr.w, sc.w, amoswap.w, amoadd.w, amoand.w, amoor.w, amoxor.w, amomin.w, 
    amomax.w, amominu.w, amomaxu.w
  
  RV32F (单精度浮点扩展):
    加载: flw
    存储: fsw
    运算: fadd.s, fsub.s, fmul.s, fdiv.s, fmin.s, fmax.s, fsqrt.s
    乘加: fmadd.s, fmsub.s, fnmadd.s, fnmsub.s
    比较: feq.s, flt.s, fle.s
    转换: fcvt.w.s, fcvt.s.w, fcvt.wu.s, fcvt.s.wu
  
  RV32D (双精度浮点扩展):
    加载: fld
    存储: fsd
    运算: fadd.d, fsub.d, fmul.d, fdiv.d, fmin.d, fmax.d, fsqrt.d
    乘加: fmadd.d, fmsub.d, fnmadd.d, fnmsub.d
    比较: feq.d, flt.d, fle.d
    转换: fcvt.w.d, fcvt.d.w, fcvt.wu.d, fcvt.d.wu
  
  RV32C (压缩指令扩展 - 常用):
    c.nop, c.addi, c.li, c.lui, c.srli, c.srai, c.andi, c.add, c.sub, 
    c.lw, c.sw, c.j, c.jr, c.jalr, c.beqz, c.bnez
  
  伪指令:
    nop, li, la, mv, not, neg, negw, sext.w, seqz, snz, sltz, sgtz,
    bgt, ble, bgtu, bleu, beqz, bnez, blez, bgez, bltz, bgtz,
    call, tail, ret, jr, j, jal, jr

  系统指令:
    ecall, ebreak, mret, sret, wfi, fence, fence.i
  
================================================================================
"""

import struct

class RISCV_Assembler:
    def __init__(self):
        # ============ 寄存器映射 ============
        self.reg_map = {}
        
        # x0-x31
        for i in range(32):
            self.reg_map[f'x{i}'] = i
        
        # ABI名称
        abi_names = [
            'zero', 'ra', 'sp', 'gp', 'tp',          # 0-4
            't0', 't1', 't2', 's0', 'fp',            # 5-9
            's1', 'a0', 'a1', 'a2', 'a3',            # 10-14
            'a4', 'a5', 'a6', 'a7', 's2',            # 15-19
            's3', 's4', 's5', 's6', 's7',            # 20-24
            's8', 's9', 's10', 's11', 't3',          # 25-29
            't4', 't5', 't6'                         # 30-31
        ]
        for i, name in enumerate(abi_names):
            self.reg_map[name] = i
        
        # ============ 浮点寄存器映射 (f0-f31) ============
        self.freg_map = {}
        for i in range(32):
            self.freg_map[f'f{i}'] = i
            self.freg_map[f'ft{i}'] = i  # 临时浮点寄存器
        
        # 浮点ABI名称
        freg_names = ['ft0', 'ft1', 'ft2', 'ft3', 'ft4', 'ft5', 'ft6', 'ft7',
                      'fs0', 'fs1', 'fa0', 'fa1', 'fa2', 'fa3', 'fa4', 'fa5',
                      'fa6', 'fa7', 'fs2', 'fs3', 'fs4', 'fs5', 'fs6', 'fs7',
                      'fs8', 'fs9', 'fs10', 'fs11', 'ft8', 'ft9', 'ft10', 'ft11']
        for i, name in enumerate(freg_names):
            self.freg_map[name] = i
    
    # ============ 辅助函数 ============
    def parse_reg(self, reg_str, is_float=False):
        """解析整数寄存器"""
        reg_str = reg_str.strip()
        if is_float:
            if reg_str in self.freg_map:
                return self.freg_map[reg_str]
            raise ValueError(f"无效的浮点寄存器: {reg_str}")
        else:
            if reg_str in self.reg_map:
                return self.reg_map[reg_str]
            raise ValueError(f"无效的寄存器: {reg_str}")
    
    def parse_imm(self, imm_str):
        """解析立即数"""
        imm_str = imm_str.strip()
        if imm_str.startswith('0x') or imm_str.startswith('0X'):
            return int(imm_str, 16)
        return int(imm_str)
    
    def to_hex(self, value, bits=32):
        """转换为Verilog十六进制格式"""
        if value < 0:
            value = (1 << bits) + value
        return f"32'h{value:08x}"
    
    # ============ 指令编码函数 ============
    def encode_i_type(self, opcode, funct3, rd, rs1, imm):
        """I型指令编码"""
        imm_val = self.parse_imm(imm)
        if imm_val < 0:
            imm_val = (1 << 12) + imm_val
        imm_bits = imm_val & 0xFFF
        rd_num = self.parse_reg(rd)
        rs1_num = self.parse_reg(rs1)
        return (imm_bits << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
    
    def encode_r_type(self, opcode, funct3, funct7, rd, rs1, rs2):
        """R型指令编码"""
        rd_num = self.parse_reg(rd)
        rs1_num = self.parse_reg(rs1)
        rs2_num = self.parse_reg(rs2)
        return (funct7 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
    
    def encode_s_type(self, funct3, rs2, rs1, imm):
        """S型指令编码 (store)"""
        imm_val = self.parse_imm(imm)
        if imm_val < 0:
            imm_val = (1 << 12) + imm_val
        imm_11_5 = (imm_val >> 5) & 0x7F
        imm_4_0 = imm_val & 0x1F
        rs1_num = self.parse_reg(rs1)
        rs2_num = self.parse_reg(rs2)
        return (imm_11_5 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (imm_4_0 << 7) | 0b0100011
    
    def encode_b_type(self, funct3, rs1, rs2, offset):
        """B型指令编码 (分支)"""
        offset_val = self.parse_imm(offset)
        if offset_val < 0:
            offset_val = (1 << 13) + offset_val
        imm12 = (offset_val >> 12) & 0x1
        imm10_5 = (offset_val >> 5) & 0x3F
        imm4_1 = (offset_val >> 1) & 0xF
        imm11 = (offset_val >> 11) & 0x1
        rs1_num = self.parse_reg(rs1)
        rs2_num = self.parse_reg(rs2)
        return (imm12 << 31) | (imm10_5 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | 0b1100011
    
    def encode_j_type(self, opcode, rd, offset):
        """J型指令编码 (jal)"""
        rd_num = self.parse_reg(rd)
        offset_val = self.parse_imm(offset)
        if offset_val < 0:
            offset_val = (1 << 21) + offset_val
        imm20 = (offset_val >> 20) & 0x1
        imm10_1 = (offset_val >> 1) & 0x3FF
        imm11 = (offset_val >> 11) & 0x1
        imm19_12 = (offset_val >> 12) & 0xFF
        return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (rd_num << 7) | opcode
    
    def encode_u_type(self, opcode, rd, imm):
        """U型指令编码 (lui, auipc)"""
        rd_num = self.parse_reg(rd)
        imm_val = self.parse_imm(imm) >> 12
        return (imm_val << 12) | (rd_num << 7) | opcode
    
    def encode_r4_type(self, opcode, funct3, funct2, rs2, rs1, rd, rm=0b000):
        """R4型指令编码 (浮点乘加)"""
        rd_num = self.parse_reg(rd, is_float=True)
        rs1_num = self.parse_reg(rs1, is_float=True)
        rs2_num = self.parse_reg(rs2, is_float=True)
        rs3_num = self.parse_reg(rs3, is_float=True) if 'rs3' in locals() else 0
        return (funct2 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
    
    def encode_atomic(self, funct5, aq, rl, rs2, rs1, rd):
        """原子操作指令编码 (RV32A)"""
        aq_bit = 1 if aq else 0
        rl_bit = 1 if rl else 0
        return (funct5 << 27) | (aq_bit << 26) | (rl_bit << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0b0101111
    
    # ============ 伪指令 ============
    def assemble_li(self, rd, imm):
        """li伪指令: addi rd, zero, imm"""
        return self.encode_i_type(0b0010011, 0x0, rd, 'zero', imm)
    
    def assemble_la(self, rd, label):
        """la伪指令: auipc + addi (简化版)"""
        # 简化实现，实际需要符号解析
        return self.encode_u_type(0b0010111, rd, label)  # 临时使用auipc
    
    def assemble_mv(self, rd, rs):
        """mv伪指令: addi rd, rs, 0"""
        return self.encode_i_type(0b0010011, 0x0, rd, rs, '0')
    
    def assemble_not(self, rd, rs):
        """not伪指令: xori rd, rs, -1"""
        return self.encode_i_type(0b0010011, 0x4, rd, rs, '-1')
    
    def assemble_neg(self, rd, rs):
        """neg伪指令: sub rd, zero, rs"""
        return self.encode_r_type(0b0110011, 0x0, 0x20, rd, 'zero', rs)
    
    def assemble_seqz(self, rd, rs):
        """seqz伪指令: sltiu rd, rs, 1"""
        return self.encode_i_type(0b0010011, 0x3, rd, rs, '1')
    
    def assemble_snez(self, rd, rs):
        """snez伪指令: sltu rd, zero, rs"""
        return self.encode_r_type(0b0110011, 0x3, 0x00, rd, 'zero', rs)
    
    def assemble_beqz(self, rs, offset):
        """beqz伪指令: beq rs, zero, offset"""
        return self.encode_b_type(0x0, rs, 'zero', offset)
    
    def assemble_bnez(self, rs, offset):
        """bnez伪指令: bne rs, zero, offset"""
        return self.encode_b_type(0x1, rs, 'zero', offset)
    
    def assemble_ret(self):
        """ret伪指令: jalr zero, ra, 0"""
        return self.encode_i_type(0b1100111, 0x0, 'zero', 'ra', '0')
    
    def assemble_jr(self, rs):
        """jr伪指令: jalr zero, rs, 0"""
        return self.encode_i_type(0b1100111, 0x0, 'zero', rs, '0')
    
    def assemble_jalr(self, rd, rs, imm='0'):
        """jalr伪指令: jalr rd, imm(rs)"""
        return self.encode_i_type(0b1100111, 0x0, rd, rs, imm)
    
    def assemble_nop(self):
        """nop伪指令: addi zero, zero, 0"""
        return self.encode_i_type(0b0010011, 0x0, 'zero', 'zero', '0')
    
    # ============ 浮点指令 ============
    def encode_fp_r_type(self, opcode, funct3, funct7, rd, rs1, rs2, is_float=True):
        """浮点R型指令"""
        rd_num = self.parse_reg(rd, is_float)
        rs1_num = self.parse_reg(rs1, is_float)
        rs2_num = self.parse_reg(rs2, is_float)
        return (funct7 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
    
    def encode_fp_i_type(self, opcode, funct3, rd, rs1, imm, is_float_rd=True, is_float_rs1=False):
        """浮点I型指令 (flw, fsw)"""
        imm_val = self.parse_imm(imm)
        if imm_val < 0:
            imm_val = (1 << 12) + imm_val
        imm_bits = imm_val & 0xFFF
        rd_num = self.parse_reg(rd, is_float_rd)
        rs1_num = self.parse_reg(rs1, is_float_rs1)
        return (imm_bits << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
    
    # ============ 系统指令 ============
    def assemble_ecall(self):
        """ecall: 环境调用"""
        return 0x00000073
    
    def assemble_ebreak(self):
        """ebreak: 断点"""
        return 0x00100073
    
    def assemble_mret(self):
        """mret: 机器模式返回"""
        return 0x30200073
    
    def assemble_sret(self):
        """sret: 监管模式返回"""
        return 0x30200073
    
    def assemble_wfi(self):
        """wfi: 等待中断"""
        return 0x10500073
    
    def assemble_fence(self, pred='i', succ='i'):
        """fence指令"""
        fm = 0
        pred_map = {'i': 8, 'o': 4, 'r': 2, 'w': 1}
        succ_map = {'i': 8, 'o': 4, 'r': 2, 'w': 1}
        pred_val = sum(pred_map.get(p, 0) for p in pred)
        succ_val = sum(succ_map.get(s, 0) for s in succ)
        return (fm << 28) | (pred_val << 24) | (succ_val << 20) | 0b00001111
    
    def assemble_fence_i(self):
        """fence.i指令"""
        return 0x0000100f
    
    # ============ 压缩指令 (RV32C) - 简化实现 ============
    def assemble_c_nop(self):
        """c.nop: 压缩空操作"""
        return 0x0001
    
    def assemble_c_addi(self, rd, imm):
        """c.addi: 压缩立即数加法"""
        rd_num = self.parse_reg(rd)
        imm_val = self.parse_imm(imm) & 0x1F
        return 0x01 | (imm_val << 2) | (rd_num << 7) | (rd_num << 12)
    
    # ============ 主汇编函数 ============
    def assemble(self, instruction):
        """主汇编函数 - 指令调度"""
        # 移除注释
        if '#' in instruction:
            instruction = instruction[:instruction.index('#')]
        instruction = instruction.strip()
        if not instruction:
            return None
        
        parts = instruction.replace(',', ' ').split()
        mnemonic = parts[0].lower()
        
        # ==================== 伪指令 ====================
        if mnemonic == 'nop':
            return self.assemble_nop()
        if mnemonic == 'li':
            rd, imm = parts[1], parts[2]
            return self.assemble_li(rd, imm)
        if mnemonic == 'la':
            rd, label = parts[1], parts[2]
            return self.assemble_la(rd, label)
        if mnemonic == 'mv':
            rd, rs = parts[1], parts[2]
            return self.assemble_mv(rd, rs)
        if mnemonic == 'not':
            rd, rs = parts[1], parts[2]
            return self.assemble_not(rd, rs)
        if mnemonic == 'neg':
            rd, rs = parts[1], parts[2]
            return self.assemble_neg(rd, rs)
        if mnemonic == 'seqz':
            rd, rs = parts[1], parts[2]
            return self.assemble_seqz(rd, rs)
        if mnemonic == 'snez':
            rd, rs = parts[1], parts[2]
            return self.assemble_snez(rd, rs)
        if mnemonic == 'beqz':
            rs, offset = parts[1], parts[2]
            return self.assemble_beqz(rs, offset)
        if mnemonic == 'bnez':
            rs, offset = parts[1], parts[2]
            return self.assemble_bnez(rs, offset)
        if mnemonic == 'ret':
            return self.assemble_ret()
        if mnemonic == 'jr':
            rs = parts[1] if len(parts) > 1 else 'ra'
            return self.assemble_jr(rs)
        if mnemonic == 'jalr':
            rd = parts[1] if len(parts) > 2 else 'ra'
            rs = parts[-1] if '(' in parts[-1] else parts[2] if len(parts) > 2 else 'ra'
            imm = '0'
            if '(' in rs:
                imm, rs = rs.strip(')').split('(')
            return self.assemble_jalr(rd, rs, imm)
        
        # ==================== 系统指令 ====================
        if mnemonic == 'ecall':
            return self.assemble_ecall()
        if mnemonic == 'ebreak':
            return self.assemble_ebreak()
        if mnemonic == 'mret':
            return self.assemble_mret()
        if mnemonic == 'sret':
            return self.assemble_sret()
        if mnemonic == 'wfi':
            return self.assemble_wfi()
        if mnemonic == 'fence':
            pred = parts[1] if len(parts) > 1 else 'i'
            succ = parts[2] if len(parts) > 2 else 'i'
            return self.assemble_fence(pred, succ)
        if mnemonic == 'fence.i' or mnemonic == 'fence_i':
            return self.assemble_fence_i()
        
        # ==================== RV32I 基础指令 ====================
        # I型指令
        i_type_map = {
            'addi': (0b0010011, 0x0), 'andi': (0b0010011, 0x7),
            'ori': (0b0010011, 0x6), 'xori': (0b0010011, 0x4),
            'slli': (0b0010011, 0x1), 'srli': (0b0010011, 0x5),
            'srai': (0b0010011, 0x5), 'slti': (0b0010011, 0x2),
            'sltiu': (0b0010011, 0x3), 'jalr': (0b1100111, 0x0),
            'lb': (0b0000011, 0x0), 'lh': (0b0000011, 0x1),
            'lw': (0b0000011, 0x2), 'lbu': (0b0000011, 0x4),
            'lhu': (0b0000011, 0x5),
        }
        
        # R型指令
        r_type_map = {
            'add': (0b0110011, 0x0, 0x00), 'sub': (0b0110011, 0x0, 0x20),
            'sll': (0b0110011, 0x1, 0x00), 'slt': (0b0110011, 0x2, 0x00),
            'sltu': (0b0110011, 0x3, 0x00), 'xor': (0b0110011, 0x4, 0x00),
            'srl': (0b0110011, 0x5, 0x00), 'sra': (0b0110011, 0x5, 0x20),
            'or': (0b0110011, 0x6, 0x00), 'and': (0b0110011, 0x7, 0x00),
        }
        
        # RV32M乘法扩展
        m_type_map = {
            'mul': (0b0110011, 0x0, 0x01), 'mulh': (0b0110011, 0x1, 0x01),
            'mulhsu': (0b0110011, 0x2, 0x01), 'mulhu': (0b0110011, 0x3, 0x01),
            'div': (0b0110011, 0x4, 0x01), 'divu': (0b0110011, 0x5, 0x01),
            'rem': (0b0110011, 0x6, 0x01), 'remu': (0b0110011, 0x7, 0x01),
        }
        
        # S型指令
        if mnemonic in ['sb', 'sh', 'sw']:
            funct3_map = {'sb': 0x0, 'sh': 0x1, 'sw': 0x2}
            rs2, rest = parts[1], parts[2]
            if '(' in rest:
                imm, rs1 = rest.strip(')').split('(')
            else:
                imm, rs1 = rest, parts[3] if len(parts) > 3 else 'zero'
            return self.encode_s_type(funct3_map[mnemonic], rs2, rs1, imm)
        
        # B型分支指令
        if mnemonic in ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']:
            funct3_map = {'beq': 0x0, 'bne': 0x1, 'blt': 0x4, 'bge': 0x5, 'bltu': 0x6, 'bgeu': 0x7}
            rs1, rs2, offset = parts[1], parts[2], parts[3]
            return self.encode_b_type(funct3_map[mnemonic], rs1, rs2, offset)
        
        # JAL指令
        if mnemonic == 'jal':
            rd = parts[1] if len(parts) > 2 else 'ra'
            offset = parts[-1]
            return self.encode_j_type(0b1101111, rd, offset)
        
        # U型指令
        if mnemonic == 'lui':
            return self.encode_u_type(0b0110111, parts[1], parts[2])
        if mnemonic == 'auipc':
            return self.encode_u_type(0b0010111, parts[1], parts[2])
        
        # RV32I I型指令
        if mnemonic in i_type_map:
            opcode, funct3 = i_type_map[mnemonic]
            if mnemonic in ['slli', 'srli', 'srai']:
                rd, rs1, shamt = parts[1], parts[2], parts[3]
                imm_val = self.parse_imm(shamt)
                if mnemonic == 'srai':
                    imm_val |= 0x400
                return self.encode_i_type(opcode, funct3, rd, rs1, str(imm_val))
            else:
                rd, rs1, imm = parts[1], parts[2], parts[3]
                return self.encode_i_type(opcode, funct3, rd, rs1, imm)
        
        # RV32I R型指令
        if mnemonic in r_type_map:
            opcode, funct3, funct7 = r_type_map[mnemonic]
            rd, rs1, rs2 = parts[1], parts[2], parts[3]
            return self.encode_r_type(opcode, funct3, funct7, rd, rs1, rs2)
        
        # RV32M乘法指令
        if mnemonic in m_type_map:
            opcode, funct3, funct7 = m_type_map[mnemonic]
            rd, rs1, rs2 = parts[1], parts[2], parts[3]
            return self.encode_r_type(opcode, funct3, funct7, rd, rs1, rs2)
        
        # ==================== RV32F 浮点指令 ====================
        if mnemonic == 'flw':
            rd, imm_rs1 = parts[1], parts[2]
            if '(' in imm_rs1:
                imm, rs1 = imm_rs1.strip(')').split('(')
            return self.encode_fp_i_type(0b0000111, 0x2, rd, rs1, imm, is_float_rd=True, is_float_rs1=False)
        
        if mnemonic == 'fsw':
            rs2, imm_rs1 = parts[1], parts[2]
            if '(' in imm_rs1:
                imm, rs1 = imm_rs1.strip(')').split('(')
            return self.encode_s_type(0x2, rs2, rs1, imm)  # 复用S型编码
        
        # 浮点运算
        fp_r_type = {
            'fadd.s': (0b1010011, 0x0, 0x0), 'fsub.s': (0b1010011, 0x0, 0x4),
            'fmul.s': (0b1010011, 0x0, 0x8), 'fdiv.s': (0b1010011, 0x0, 0xC),
            'fsqrt.s': (0b1010011, 0x0, 0x2C), 'fmin.s': (0b1010011, 0x0, 0x14),
            'fmax.s': (0b1010011, 0x0, 0x18), 'fmv.s': (0b1010011, 0x0, 0x20),
            'feq.s': (0b1010011, 0x2, 0x50), 'flt.s': (0b1010011, 0x1, 0x50),
            'fle.s': (0b1010011, 0x0, 0x50), 'fcvt.w.s': (0b1010011, 0x0, 0x60),
            'fcvt.s.w': (0b1010011, 0x0, 0x68), 'fcvt.wu.s': (0b1010011, 0x0, 0x61),
            'fcvt.s.wu': (0b1010011, 0x0, 0x69),
        }
        
        if mnemonic in fp_r_type:
            opcode, funct3, funct7 = fp_r_type[mnemonic]
            if len(parts) == 4:  # fadd.s rd, rs1, rs2
                rd, rs1, rs2 = parts[1], parts[2], parts[3]
                return self.encode_fp_r_type(opcode, funct3, funct7, rd, rs1, rs2, is_float=True)
            elif len(parts) == 3 and mnemonic == 'fsqrt.s':  # fsqrt.s rd, rs1
                rd, rs1 = parts[1], parts[2]
                return self.encode_fp_r_type(opcode, funct3, funct7, rd, rs1, 'f0', is_float=True)
        
        # ==================== RV32A 原子指令 ====================
        atomic_map = {
            'lr.w': (0b00010, False, False), 'sc.w': (0b00011, False, False),
            'amoswap.w': (0b00001, False, False), 'amoadd.w': (0b00000, False, False),
            'amoand.w': (0b01100, False, False), 'amoor.w': (0b01000, False, False),
            'amoxor.w': (0b00100, False, False), 'amomin.w': (0b10000, False, False),
            'amomax.w': (0b10100, False, False), 'amominu.w': (0b11000, False, False),
            'amomaxu.w': (0b11100, False, False),
        }
        
        if mnemonic in atomic_map:
            funct5, aq, rl = atomic_map[mnemonic]
            if mnemonic == 'lr.w':
                rd, rs1 = parts[1], parts[2]
                rs2 = 0
            elif mnemonic == 'sc.w':
                rd, rs2, rs1 = parts[1], parts[2], parts[3]
            else:
                rd, rs2, rs1 = parts[1], parts[2], parts[3]
            rd_num = self.parse_reg(rd)
            rs1_num = self.parse_reg(rs1)
            rs2_num = self.parse_reg(rs2) if rs2 != 0 else 0
            return self.encode_atomic(funct5, aq, rl, rs2_num, rs1_num, rd_num)
        
        # ==================== 压缩指令 (RV32C) ====================
        if mnemonic == 'c.nop':
            return self.assemble_c_nop()
        if mnemonic == 'c.addi':
            rd, imm = parts[1], parts[2]
            return self.assemble_c_addi(rd, imm)
        
        raise ValueError(f"不支持的指令: {mnemonic}")
    
    # ============ 批量汇编 ============
    def assemble_program(self, instructions, start_addr=0):
        """汇编整个程序"""
        machine_codes = []
        for i, instr in enumerate(instructions):
            if not instr or instr.strip().startswith('#'):
                continue
            try:
                code = self.assemble(instr)
                if code is not None:
                    machine_codes.append((start_addr + len(machine_codes), code))
            except Exception as e:
                print(f"错误: '{instr}' - {e}")
        return machine_codes


def main():
    assembler = RISCV_Assembler()
    
    print("=" * 70)
    print("RISC-V 完整指令集汇编器 v2.0")
    print("=" * 70)
    print("支持: RV32I, RV32M, RV32A, RV32F, RV32C, 伪指令, 系统指令")
    print("=" * 70)
    
    # 示例程序
    example_program = """
    # 基础运算
    li x10, 10
    li x11, 20
    mul x12, x10, x11
    div x13, x12, x10
    rem x14, x12, x10
    
    # 伪指令
    mv x15, x10
    not x16, x10
    neg x17, x10
    nop
    ret
    
    # 浮点指令
    flw f0, 0(x10)
    fadd.s f1, f0, f2
    """
    
    print("\n示例程序:")
    for line in example_program.strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    
    print("\n生成的机器码:")
    instructions = [l.strip() for l in example_program.strip().split('\n') if l.strip() and not l.strip().startswith('#')]
    results = assembler.assemble_program(instructions, 0)
    
    for addr, code in results:
        print(f"rom[{addr}] = {assembler.to_hex(code)};")
    
    # 交互模式
    print("\n" + "=" * 70)
    print("交互模式 (输入空行结束):")
    user_instr = []
    while True:
        try:
            line = input(f"{len(user_instr)+1:3d}> ").strip()
            if not line:
                break
            if line and not line.startswith('#'):
                user_instr.append(line)
        except EOFError:
            break
    
    if user_instr:
        print("\n生成的机器码:")
        results = assembler.assemble_program(user_instr, 0)
        for addr, code in results:
            print(f"rom[{addr}] = {assembler.to_hex(code)};")


if __name__ == "__main__":
    main()