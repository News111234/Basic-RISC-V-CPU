#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
                    RISC-V 完整汇编器 - 最终版 v3
================================================================================
修复：
  - 修复标签后只有注释的情况
  - 优化指令提取逻辑
  - 完善空行和纯注释行的处理
================================================================================
"""

import re
import sys

class FullRISCVAssembler:
    def __init__(self):
        # 寄存器映射
        self.reg_map = {}
        for i in range(32):
            self.reg_map[f'x{i}'] = i
        
        abi_names = ['zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2', 's0', 'fp',
                     's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 's2',
                     's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10', 's11', 't3',
                     't4', 't5', 't6']
        for i, name in enumerate(abi_names):
            self.reg_map[name] = i
        
        # CSR寄存器映射
        self.csr_map = {
            'mstatus': 0x300, 'misa': 0x301, 'mie': 0x304, 'mtvec': 0x305,
            'mscratch': 0x340, 'mepc': 0x341, 'mcause': 0x342, 'mtval': 0x343,
            'mip': 0x344, 'sstatus': 0x100, 'sie': 0x104, 'stvec': 0x105,
            'sscratch': 0x140, 'sepc': 0x141, 'scause': 0x142, 'stval': 0x143,
            'sip': 0x144, 'satp': 0x180,
        }
        
        # 常量定义表
        self.constants = {}
        
        # 标签地址表
        self.labels = {}
        
        # 当前地址
        self.current_addr = 0
        
        # 输出结果
        self.results = []
    
    def remove_comments(self, line):
        """移除注释，支持 # 和 // 两种格式"""
        # 移除 // 注释
        if '//' in line:
            line = line[:line.index('//')]
        # 移除 # 注释
        if '#' in line:
            line = line[:line.index('#')]
        return line.strip()
    
    def parse_reg(self, reg_str):
        reg_str = reg_str.strip()
        if reg_str in self.reg_map:
            return self.reg_map[reg_str]
        raise ValueError(f"无效寄存器: {reg_str}")
    
    def parse_imm(self, imm_str, allow_label=False):
        imm_str = imm_str.strip()
        
        # 常量替换
        if imm_str in self.constants:
            return self.constants[imm_str]
        
        # 标签（返回字符串，稍后解析）
        if allow_label and re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', imm_str):
            return imm_str
        
        # 十六进制
        if imm_str.startswith('0x') or imm_str.startswith('0X'):
            return int(imm_str, 16)
        
        # 十六进制负数
        if imm_str.startswith('-0x') or imm_str.startswith('-0X'):
            return -int(imm_str[3:], 16)
        
        # 二进制
        if imm_str.startswith('0b') or imm_str.startswith('0B'):
            return int(imm_str[2:], 2)
        
        # 十进制
        try:
            return int(imm_str)
        except ValueError:
            if allow_label:
                return imm_str
            raise ValueError(f"无效立即数: {imm_str}")
    
    def parse_memory(self, mem_str):
        """解析内存操作数，支持十六进制偏移"""
        mem_str = mem_str.strip()
        
        # 替换常量
        for name, val in self.constants.items():
            if name in mem_str:
                mem_str = mem_str.replace(name, str(val))
        
        # 匹配格式: 0(x10), 0x00C(x10), -8(x2), 4(sp), (x1)
        match = re.match(r'^(-?0x[0-9a-fA-F]+|-?\d+)?\((\w+)\)$', mem_str)
        if match:
            imm_str = match.group(1) if match.group(1) else '0'
            reg = match.group(2)
            return imm_str, reg
        
        # 也支持没有括号的情况（如直接寄存器）
        if re.match(r'^[xst][0-9]+$', mem_str) or mem_str in self.reg_map:
            return '0', mem_str
        
        raise ValueError(f"无效内存操作数: {mem_str}")
    
    def encode_i_type(self, opcode, funct3, rd, rs1, imm, use_label=False):
        imm_val = self.parse_imm(imm, allow_label=use_label)
        if isinstance(imm_val, str):
            return ('label', imm_val, opcode, funct3, rd, rs1)
        
        if imm_val < 0:
            imm_val = (1 << 12) + imm_val
        imm_bits = imm_val & 0xFFF
        rd_num = self.parse_reg(rd)
        rs1_num = self.parse_reg(rs1)
        return (imm_bits << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
    
    def encode_r_type(self, opcode, funct3, funct7, rd, rs1, rs2):
        rd_num = self.parse_reg(rd)
        rs1_num = self.parse_reg(rs1)
        rs2_num = self.parse_reg(rs2)
        return (funct7 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
    
    def encode_s_type(self, funct3, rs2, rs1, imm):
        imm_val = self.parse_imm(imm)
        if isinstance(imm_val, str):
            raise ValueError(f"存储指令不能使用标签: {imm}")
        
        if imm_val < 0:
            imm_val = (1 << 12) + imm_val
        imm_11_5 = (imm_val >> 5) & 0x7F
        imm_4_0 = imm_val & 0x1F
        rs1_num = self.parse_reg(rs1)
        rs2_num = self.parse_reg(rs2)
        return (imm_11_5 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (imm_4_0 << 7) | 0b0100011
    
    def encode_u_type(self, opcode, rd, imm):
        rd_num = self.parse_reg(rd)
        imm_val = self.parse_imm(imm)
        if isinstance(imm_val, str):
            raise ValueError(f"U型指令不能使用标签: {imm}")
        imm_upper = imm_val >> 12
        return (imm_upper << 12) | (rd_num << 7) | opcode
    
    def encode_b_type(self, funct3, rs1, rs2, offset):
        offset_val = self.parse_imm(offset, allow_label=True)
        if isinstance(offset_val, str):
            return ('branch_label', offset_val, funct3, rs1, rs2)
        
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
        offset_val = self.parse_imm(offset, allow_label=True)
        if isinstance(offset_val, str):
            return ('jump_label', offset_val, opcode, rd)
        
        rd_num = self.parse_reg(rd)
        if offset_val < 0:
            offset_val = (1 << 21) + offset_val
        imm20 = (offset_val >> 20) & 0x1
        imm10_1 = (offset_val >> 1) & 0x3FF
        imm11 = (offset_val >> 11) & 0x1
        imm19_12 = (offset_val >> 12) & 0xFF
        return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (rd_num << 7) | opcode
    
    def encode_csr_type(self, funct3, rd, csr, rs1=None, uimm=None):
        csr_str = csr.strip()
        if csr_str in self.constants:
            csr_num = self.constants[csr_str]
        else:
            csr_num = self.parse_imm(csr_str)
        rd_num = self.parse_reg(rd)
        if rs1 is not None:
            rs1_num = self.parse_reg(rs1)
            return (csr_num << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | 0b1110011
        else:
            uimm_val = self.parse_imm(uimm) & 0x1F
            return (csr_num << 20) | (uimm_val << 15) | (funct3 << 12) | (rd_num << 7) | 0b1110011
    
    def is_valid_instruction(self, line):
        """判断是否是有效指令（不是注释、不是空行）"""
        line = line.strip()
        if not line:
            return False
        if line.startswith('//') or line.startswith('#'):
            return False
        # 检查是否是数据定义
        if line.startswith('.byte') or line.startswith('.word') or \
           line.startswith('.ascii') or line.startswith('.asciz') or \
           line.startswith('.space') or line.startswith('.org') or \
           line.startswith('.align') or line.startswith('.equ'):
            return True
        # 检查是否以冒号结尾（纯标签行）
        if line.endswith(':'):
            return False
        return True
    
    def assemble_instruction(self, line):
        """汇编单条指令，返回编码或待解析标记"""
        # 移除注释
        line = self.remove_comments(line)
        if not line:
            return None
        
        # 分割指令
        parts = re.split(r'[,\s]+', line)
        mnemonic = parts[0].lower()
        
        # ========== 伪指令 ==========
        if mnemonic == 'nop':
            return 0x00000013
        
        if mnemonic == 'ret':
            return self.encode_i_type(0b1100111, 0x0, 'zero', 'ra', '0')
        
        if mnemonic == 'jr':
            rs = parts[1] if len(parts) > 1 else 'ra'
            return self.encode_i_type(0b1100111, 0x0, 'zero', rs, '0')
        
        if mnemonic == 'j':
            return self.encode_j_type(0b1101111, 'zero', parts[1])
        
        if mnemonic == 'jal':
            if len(parts) == 2:
                return self.encode_j_type(0b1101111, 'ra', parts[1])
            else:
                return self.encode_j_type(0b1101111, parts[1], parts[2])
        
        if mnemonic == 'jalr':
            if len(parts) == 3:
                rd, rs = parts[1], parts[2]
                imm = '0'
            elif len(parts) == 2:
                rd, rs = 'ra', parts[1]
                imm = '0'
            else:
                rd, rs = parts[1], parts[2]
                imm = '0'
            if '(' in rs:
                imm, rs = self.parse_memory(rs)
            return self.encode_i_type(0b1100111, 0x0, rd, rs, imm)
        
        # call 伪指令: jal ra, label
        if mnemonic == 'call':
            return self.encode_j_type(0b1101111, 'ra', parts[1])
        
        # tail 伪指令: jal zero, label
        if mnemonic == 'tail':
            return self.encode_j_type(0b1101111, 'zero', parts[1])
        
        # la 伪指令: auipc rd, label (简化)
        if mnemonic == 'la':
            return self.encode_u_type(0b0010111, parts[1], '0')
        
        # ========== 分支伪指令 ==========
        if mnemonic == 'beqz':
            rs, offset = parts[1], parts[2]
            return self.encode_b_type(0x0, rs, 'zero', offset)
        if mnemonic == 'bnez':
            rs, offset = parts[1], parts[2]
            return self.encode_b_type(0x1, rs, 'zero', offset)
        if mnemonic == 'blez':
            rs, offset = parts[1], parts[2]
            return self.encode_b_type(0x4, 'zero', rs, offset)
        if mnemonic == 'bgez':
            rs, offset = parts[1], parts[2]
            return self.encode_b_type(0x5, rs, 'zero', offset)
        if mnemonic == 'bltz':
            rs, offset = parts[1], parts[2]
            return self.encode_b_type(0x4, rs, 'zero', offset)
        if mnemonic == 'bgtz':
            rs, offset = parts[1], parts[2]
            return self.encode_b_type(0x5, 'zero', rs, offset)
        
        # ========== U型指令 ==========
        if mnemonic == 'lui':
            return self.encode_u_type(0b0110111, parts[1], parts[2])
        if mnemonic == 'auipc':
            return self.encode_u_type(0b0010111, parts[1], parts[2])
        
        # ========== I型指令 ==========
        i_type_map = {
            'addi': (0b0010011, 0x0), 'andi': (0b0010011, 0x7),
            'ori': (0b0010011, 0x6), 'xori': (0b0010011, 0x4),
            'slli': (0b0010011, 0x1), 'srli': (0b0010011, 0x5),
            'srai': (0b0010011, 0x5), 'slti': (0b0010011, 0x2),
            'sltiu': (0b0010011, 0x3),
            'lb': (0b0000011, 0x0), 'lh': (0b0000011, 0x1),
            'lw': (0b0000011, 0x2), 'lbu': (0b0000011, 0x4),
            'lhu': (0b0000011, 0x5),
        }
        
        if mnemonic in i_type_map:
            opcode, funct3 = i_type_map[mnemonic]
            if mnemonic in ['lb', 'lh', 'lw', 'lbu', 'lhu']:
                rd, mem = parts[1], parts[2]
                imm, rs1 = self.parse_memory(mem)
                return self.encode_i_type(opcode, funct3, rd, rs1, imm)
            elif mnemonic in ['slli', 'srli', 'srai']:
                rd, rs1, shamt = parts[1], parts[2], parts[3]
                imm_val = self.parse_imm(shamt)
                if mnemonic == 'srai':
                    imm_val |= 0x400
                return self.encode_i_type(opcode, funct3, rd, rs1, str(imm_val))
            else:
                rd, rs1, imm = parts[1], parts[2], parts[3]
                return self.encode_i_type(opcode, funct3, rd, rs1, imm, use_label=(mnemonic == 'jalr'))
        
        # ========== R型指令 ==========
        r_type_map = {
            'add': (0b0110011, 0x0, 0x00), 'sub': (0b0110011, 0x0, 0x20),
            'sll': (0b0110011, 0x1, 0x00), 'slt': (0b0110011, 0x2, 0x00),
            'sltu': (0b0110011, 0x3, 0x00), 'xor': (0b0110011, 0x4, 0x00),
            'srl': (0b0110011, 0x5, 0x00), 'sra': (0b0110011, 0x5, 0x20),
            'or': (0b0110011, 0x6, 0x00), 'and': (0b0110011, 0x7, 0x00),
        }
        
        if mnemonic in r_type_map:
            opcode, funct3, funct7 = r_type_map[mnemonic]
            rd, rs1, rs2 = parts[1], parts[2], parts[3]
            return self.encode_r_type(opcode, funct3, funct7, rd, rs1, rs2)
        
        # ========== S型指令 ==========
        if mnemonic in ['sb', 'sh', 'sw']:
            funct3_map = {'sb': 0x0, 'sh': 0x1, 'sw': 0x2}
            rs2, mem = parts[1], parts[2]
            imm, rs1 = self.parse_memory(mem)
            return self.encode_s_type(funct3_map[mnemonic], rs2, rs1, imm)
        
        # ========== B型指令 ==========
        if mnemonic in ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']:
            funct3_map = {'beq': 0x0, 'bne': 0x1, 'blt': 0x4, 'bge': 0x5, 'bltu': 0x6, 'bgeu': 0x7}
            rs1, rs2, offset = parts[1], parts[2], parts[3]
            return self.encode_b_type(funct3_map[mnemonic], rs1, rs2, offset)
        
        # ========== CSR指令 ==========
        if mnemonic == 'csrrw':
            return self.encode_csr_type(0x1, parts[1], parts[2], rs1=parts[3])
        if mnemonic == 'csrrs':
            return self.encode_csr_type(0x2, parts[1], parts[2], rs1=parts[3])
        if mnemonic == 'csrrc':
            return self.encode_csr_type(0x3, parts[1], parts[2], rs1=parts[3])
        if mnemonic == 'csrrwi':
            return self.encode_csr_type(0x5, parts[1], parts[2], uimm=parts[3])
        if mnemonic == 'csrrsi':
            return self.encode_csr_type(0x6, parts[1], parts[2], uimm=parts[3])
        if mnemonic == 'csrrci':
            return self.encode_csr_type(0x7, parts[1], parts[2], uimm=parts[3])
        
        # CSR伪指令
        if mnemonic == 'csrr':
            return self.encode_csr_type(0x2, parts[1], parts[2], rs1='zero')
        if mnemonic == 'csrw':
            return self.encode_csr_type(0x1, 'zero', parts[1], rs1=parts[2])
        if mnemonic == 'csrs':
            return self.encode_csr_type(0x2, 'zero', parts[1], rs1=parts[2])
        if mnemonic == 'csrc':
            return self.encode_csr_type(0x3, 'zero', parts[1], rs1=parts[2])
        if mnemonic == 'csrwi':
            return self.encode_csr_type(0x5, 'zero', parts[1], uimm=parts[2])
        if mnemonic == 'csrsi':
            return self.encode_csr_type(0x6, 'zero', parts[1], uimm=parts[2])
        if mnemonic == 'csrci':
            return self.encode_csr_type(0x7, 'zero', parts[1], uimm=parts[2])
        
        # ========== 系统指令 ==========
        if mnemonic == 'ecall':
            return 0x00000073
        if mnemonic == 'ebreak':
            return 0x00100073
        if mnemonic == 'mret':
            return 0x30200073
        if mnemonic == 'sret':
            return 0x30200073
        if mnemonic == 'wfi':
            return 0x10500073
        
        # ========== li 伪指令 ==========
        if mnemonic == 'li':
            rd, imm = parts[1], parts[2]
            imm_val = self.parse_imm(imm)
            if isinstance(imm_val, int):
                if -2048 <= imm_val <= 2047:
                    return self.encode_i_type(0b0010011, 0x0, rd, 'zero', imm)
                else:
                    upper = (imm_val + 0x800) >> 12
                    return self.encode_u_type(0b0110111, rd, str(upper << 12))
        
        # ========== mv 伪指令 ==========
        if mnemonic == 'mv':
            rd, rs = parts[1], parts[2]
            return self.encode_i_type(0b0010011, 0x0, rd, rs, '0')
        
        # ========== not 伪指令 ==========
        if mnemonic == 'not':
            rd, rs = parts[1], parts[2]
            return self.encode_i_type(0b0010011, 0x4, rd, rs, '-1')
        
        # ========== neg 伪指令 ==========
        if mnemonic == 'neg':
            rd, rs = parts[1], parts[2]
            return self.encode_r_type(0b0110011, 0x0, 0x20, rd, 'zero', rs)
        
        raise ValueError(f"不支持的指令: {mnemonic}")
    
    def is_label_line(self, line):
        """判断是否是标签行"""
        # 先移除注释
        clean_line = self.remove_comments(line)
        if not clean_line:
            return False
        
        # 检查是否以冒号结尾（单独标签行）
        if clean_line.endswith(':'):
            return True
        
        # 检查行首是否有标签（标签: 指令）
        match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*):', clean_line)
        return match is not None
    
    def extract_label(self, line):
        """提取标签名"""
        clean_line = self.remove_comments(line)
        if not clean_line:
            return None
        
        # 单独标签行
        if clean_line.endswith(':'):
            return clean_line[:-1].strip()
        
        # 行首标签
        match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*):', clean_line)
        if match:
            return match.group(1)
        
        return None
    
    def extract_instruction(self, line):
        """提取指令（去除行首标签和注释）"""
        # 先移除注释
        no_comment = self.remove_comments(line)
        if not no_comment:
            return None
        
        # 如果有行首标签，移除它
        match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*):\s*(.*)$', no_comment)
        if match:
            instr = match.group(2).strip()
            # 如果提取后是空字符串或者是注释，返回None
            if not instr or instr.startswith('//') or instr.startswith('#'):
                return None
            return instr
        
        # 没有标签，返回原指令
        return no_comment
    
    def process_equ(self, line):
        line = self.remove_comments(line)
        if not line:
            return False
        
        match = re.match(r'\.equ\s+(\w+)\s*,\s*(.+)', line)
        if match:
            name = match.group(1)
            value_str = match.group(2).strip()
            self.constants[name] = self.parse_imm(value_str)
            return True
        return False
    
    def process_data(self, line):
        """处理数据定义"""
        line_stripped = self.remove_comments(line)
        if not line_stripped:
            return False
        
        # .byte
        if line_stripped.startswith('.byte'):
            data_str = line_stripped[5:].strip()
            for part in data_str.split(','):
                val = self.parse_imm(part.strip())
                self.results.append((self.current_addr, val, f".byte {part.strip()}"))
                self.current_addr += 1
            return True
        
        # .word
        if line_stripped.startswith('.word'):
            data_str = line_stripped[5:].strip()
            for part in data_str.split(','):
                val = self.parse_imm(part.strip())
                self.results.append((self.current_addr, val, f".word {part.strip()}"))
                self.current_addr += 4
            return True
        
        # .ascii
        if line_stripped.startswith('.ascii'):
            match = re.search(r'\.ascii\s+"([^"]*)"', line_stripped)
            if match:
                for ch in match.group(1):
                    self.results.append((self.current_addr, ord(ch), ".ascii"))
                    self.current_addr += 1
            return True
        
        # .asciz
        if line_stripped.startswith('.asciz'):
            match = re.search(r'\.asciz\s+"([^"]*)"', line_stripped)
            if match:
                for ch in match.group(1):
                    self.results.append((self.current_addr, ord(ch), ".asciz"))
                    self.current_addr += 1
                self.results.append((self.current_addr, 0, ".asciz null"))
                self.current_addr += 1
            return True
        
        # .space
        if line_stripped.startswith('.space'):
            match = re.match(r'\.space\s+(\d+)', line_stripped)
            if match:
                size = int(match.group(1))
                self.results.append((self.current_addr, size, f".space {size} bytes"))
                self.current_addr += size
            return True
        
        return False
    
    def resolve_label(self, result, addr):
        """解析标签，返回实际编码"""
        if isinstance(result, tuple):
            if result[0] == 'label':
                _, label, opcode, funct3, rd, rs1 = result
                if label in self.labels:
                    offset = self.labels[label] - addr
                    if offset < 0:
                        offset = (1 << 12) + offset
                    imm_bits = offset & 0xFFF
                    rd_num = self.parse_reg(rd)
                    rs1_num = self.parse_reg(rs1)
                    return (imm_bits << 20) | (rs1_num << 15) | (funct3 << 12) | (rd_num << 7) | opcode
                else:
                    raise ValueError(f"未定义的标签: {label}")
            
            elif result[0] == 'branch_label':
                _, label, funct3, rs1, rs2 = result
                if label in self.labels:
                    offset = self.labels[label] - addr
                    if offset < 0:
                        offset = (1 << 13) + offset
                    imm12 = (offset >> 12) & 0x1
                    imm10_5 = (offset >> 5) & 0x3F
                    imm4_1 = (offset >> 1) & 0xF
                    imm11 = (offset >> 11) & 0x1
                    rs1_num = self.parse_reg(rs1)
                    rs2_num = self.parse_reg(rs2)
                    return (imm12 << 31) | (imm10_5 << 25) | (rs2_num << 20) | (rs1_num << 15) | (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | 0b1100011
                else:
                    raise ValueError(f"未定义的标签: {label}")
            
            elif result[0] == 'jump_label':
                _, label, opcode, rd = result
                if label in self.labels:
                    offset = self.labels[label] - addr
                    rd_num = self.parse_reg(rd)
                    if offset < 0:
                        offset = (1 << 21) + offset
                    imm20 = (offset >> 20) & 0x1
                    imm10_1 = (offset >> 1) & 0x3FF
                    imm11 = (offset >> 11) & 0x1
                    imm19_12 = (offset >> 12) & 0xFF
                    return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (rd_num << 7) | opcode
                else:
                    raise ValueError(f"未定义的标签: {label}")
        
        return result
    
    def assemble_program(self, lines, start_addr=0):
        """汇编整个程序（两遍扫描）"""
        self.current_addr = start_addr
        self.results = []
        self.constants = {}
        self.labels = {}
        
        # 第一遍：收集常量定义和标签地址
        temp_addr = start_addr
        for line in lines:
            # 处理 .equ
            if self.process_equ(line):
                continue
            
            # 处理 .org
            clean_line = self.remove_comments(line)
            if clean_line and clean_line.startswith('.org'):
                match = re.match(r'\.org\s+(.+)', clean_line)
                if match:
                    addr_str = match.group(1).strip()
                    temp_addr = self.parse_imm(addr_str)
                continue
            
            # 处理 .align
            if clean_line and clean_line.startswith('.align'):
                match = re.match(r'\.align\s+(\d+)', clean_line)
                if match:
                    align = int(match.group(1))
                    if temp_addr % (1 << align) != 0:
                        temp_addr = ((temp_addr >> align) + 1) << align
                continue
            
            # 处理标签
            if self.is_label_line(line):
                label = self.extract_label(line)
                if label:
                    self.labels[label] = temp_addr
                # 检查同一行是否有指令
                instr = self.extract_instruction(line)
                if instr:
                    # 有指令，地址增加4
                    temp_addr += 4
                continue
            
            # 跳过纯注释行
            if not clean_line:
                continue
            if clean_line.startswith('//') or clean_line.startswith('#'):
                continue
            
            # 处理数据定义（计算地址但不存储结果）
            if clean_line.startswith('.byte'):
                data_str = clean_line[5:].strip()
                for part in data_str.split(','):
                    temp_addr += 1
                continue
            if clean_line.startswith('.word'):
                data_str = clean_line[5:].strip()
                for part in data_str.split(','):
                    temp_addr += 4
                continue
            if clean_line.startswith('.ascii'):
                match = re.search(r'\.ascii\s+"([^"]*)"', clean_line)
                if match:
                    temp_addr += len(match.group(1))
                continue
            if clean_line.startswith('.asciz'):
                match = re.search(r'\.asciz\s+"([^"]*)"', clean_line)
                if match:
                    temp_addr += len(match.group(1)) + 1
                continue
            if clean_line.startswith('.space'):
                match = re.match(r'\.space\s+(\d+)', clean_line)
                if match:
                    temp_addr += int(match.group(1))
                continue
            
            # 普通指令，占用4字节
            temp_addr += 4
        
        # 重置地址
        self.current_addr = start_addr
        
        # 第二遍：生成机器码
        for line in lines:
            # 跳过 .equ
            if self.process_equ(line):
                continue
            
            clean_line = self.remove_comments(line)
            
            # 处理 .org
            if clean_line and clean_line.startswith('.org'):
                match = re.match(r'\.org\s+(.+)', clean_line)
                if match:
                    addr_str = match.group(1).strip()
                    self.current_addr = self.parse_imm(addr_str)
                continue
            
            # 处理 .align
            if clean_line and clean_line.startswith('.align'):
                match = re.match(r'\.align\s+(\d+)', clean_line)
                if match:
                    align = int(match.group(1))
                    if self.current_addr % (1 << align) != 0:
                        self.current_addr = ((self.current_addr >> align) + 1) << align
                continue
            
            # 处理数据定义
            if self.process_data(line):
                continue
            
            # 跳过纯注释行
            if not clean_line:
                continue
            if clean_line.startswith('//') or clean_line.startswith('#'):
                continue
            
            # 处理标签行（提取指令）
            if self.is_label_line(line):
                instr = self.extract_instruction(line)
                if not instr:
                    continue
                # 汇编指令
                try:
                    result = self.assemble_instruction(instr)
                    if result is not None:
                        code = self.resolve_label(result, self.current_addr)
                        self.results.append((self.current_addr, code, instr))
                        self.current_addr += 4
                except Exception as e:
                    print(f"警告: '{instr}' - {e}")
                continue
            
            # 普通指令
            try:
                result = self.assemble_instruction(clean_line)
                if result is not None:
                    code = self.resolve_label(result, self.current_addr)
                    self.results.append((self.current_addr, code, clean_line))
                    self.current_addr += 4
            except Exception as e:
                print(f"警告: '{clean_line}' - {e}")
        
        return self.results


def parse_start_address(prompt="请输入起始地址"):
    while True:
        try:
            addr_input = input(f"{prompt} (直接回车使用默认 0x100): ").strip()
            if not addr_input:
                return 0x100
            if addr_input.startswith('0x') or addr_input.startswith('0X'):
                return int(addr_input, 16)
            elif addr_input.startswith('0b') or addr_input.startswith('0B'):
                return int(addr_input[2:], 2)
            else:
                return int(addr_input)
        except ValueError:
            print("输入无效，请输入有效的数字（如: 0, 0x0, 100, 0x100）")


def main():
    print("=" * 70)
    print("RISC-V 完整汇编器 - 最终版 v3")
    print("支持: 所有RV32I指令, CSR指令, 伪指令, 数据定义, 标签跳转, 十六进制")
    print("注释: 支持 # 和 // 两种格式")
    print("标签: 支持单独一行或同一行（标签: 指令）")
    print("=" * 70)
    
    # 读取汇编代码
    if len(sys.argv) > 1:
        try:
            with open(sys.argv[1], 'r') as f:
                lines = f.readlines()
            print(f"从文件读取: {sys.argv[1]}")
        except Exception as e:
            print(f"读取文件失败: {e}")
            sys.exit(1)
    else:
        print("请输入汇编代码（输入空行结束）:")
        print("-" * 70)
        lines = []
        while True:
            try:
                line = input()
                if line.strip() == '' and len(lines) > 0:
                    break
                lines.append(line)
            except EOFError:
                break
    
    # 获取起始地址
    start_addr = parse_start_address()
    print(f"\n起始地址: 0x{start_addr:x}")
    
    # 汇编
    assembler = FullRISCVAssembler()
    results = assembler.assemble_program(lines, start_addr)
    
    print("\n" + "=" * 70)
    print("生成的机器码:")
    print("=" * 70)
    
    if not results:
        print("没有生成任何机器码")
        return
    
    # 统计
    instr_count = 0
    data_bytes = 0
    
    for addr, code, comment in results:
        rom_index = addr // 4
        
        if isinstance(code, int) and code <= 0xFFFFFFFF:
            if comment.startswith('.space'):
                size = code
                start_rom = addr // 4
                end_rom = (addr + size - 1) // 4
                if start_rom == end_rom:
                    print(f"rom[{start_rom:4d}] = 32'h00000000;  // {comment}")
                else:
                    print(f"rom[{start_rom:4d}] ... rom[{end_rom:4d}] = 32'h00000000;  // {comment}")
                data_bytes += size
            else:
                print(f"rom[{rom_index:4d}] = 32'h{code:08x};  // {comment}")
                instr_count += 1
        else:
            print(f"rom[{rom_index:4d}] = 32'h{code:08x};  // {comment}")
            data_bytes += 1
    
    print("\n" + "=" * 70)
    print(f"完成！共生成 {instr_count} 条指令, {data_bytes} 字节数据")
    print("=" * 70)


if __name__ == "__main__":
    main()
     #运行的话在终端输入指令:python riscv_asm3.py spi_test.s