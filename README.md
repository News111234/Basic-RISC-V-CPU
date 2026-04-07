# RISC-V-CPU

一个基于 RISC-V 指令集的五级流水线 CPU 设计，支持中断、UART、GPIO 和定时器外设。

## 特点

- **五级流水线**：取指(IF)、译码(ID)、执行(EX)、访存(MEM)、写回(WB)
- **RISC-V 基础整数指令集 (RV32I)** + **乘法扩展 (M)**
- **中断支持**：完整的中断响应与返回机制
- **外设支持**：
  - UART 串口通信
  - GPIO（输入/输出/中断）
  - 可编程定时器（中断）
- **仿真与验证**：
  - Modelsim 仿真，可直接观察波形
  - Vivado 综合与烧录，可部署到 FPGA

## 开发环境

| 工具 | 用途 |
|------|------|
| Modelsim | 仿真验证，观察波形 |
| Vivado | 综合、烧录 FPGA |
| Verilog | 硬件描述语言 |
| Python | 汇编转机器码工具 |

## 汇编转机器码工具

`python/riscv_arm.py` 是一个用 Python 编写的 RISC-V 汇编转机器码工具。

### 支持指令集

| 扩展 | 指令 |
|------|------|
| **RV32I** | add, sub, addi, slt, slti, sltu, sltiu, and, or, xor, andi, ori, xori, sll, srl, sra, slli, srli, srai, beq, bne, blt, bge, bltu, bgeu, jal, jalr, lb, lh, lw, lbu, lhu, sb, sh, sw, lui, auipc |
| **RV32M** | mul, mulh, mulhsu, mulhu, div, divu, rem, remu |
| **RV32A** | lr.w, sc.w, amoswap.w, amoadd.w, amoand.w, amoor.w, amoxor.w, amomin.w, amomax.w, amominu.w, amomaxu.w |
| **RV32F** | flw, fsw, fadd.s, fsub.s, fmul.s, fdiv.s, fmin.s, fmax.s, fsqrt.s, fmadd.s, fmsub.s, fnmadd.s, fnmsub.s, feq.s, flt.s, fle.s, fcvt.w.s, fcvt.s.w, fcvt.wu.s, fcvt.s.wu |
| **RV32D** | fld, fsd, fadd.d, fsub.d, fmul.d, fdiv.d, fmin.d, fmax.d, fsqrt.d, fmadd.d, fmsub.d, fnmadd.d, fnmsub.d, feq.d, flt.d, fle.d, fcvt.w.d, fcvt.d.w, fcvt.wu.d, fcvt.d.wu |
| **RV32C** | c.nop, c.addi, c.li, c.lui, c.srli, c.srai, c.andi, c.add, c.sub, c.lw, c.sw, c.j, c.jr, c.jalr, c.beqz, c.bnez |
| **伪指令** | nop, li, la, mv, not, neg, negw, sext.w, seqz, snz, sltz, sgtz, bgt, ble, bgtu, bleu, beqz, bnez, blez, bgez, bltz, bgtz, call, tail, ret, jr, j, jal |
| **系统指令** | ecall, ebreak, mret, sret, wfi, fence, fence.i |

### 使用方法

```bash
cd python
python riscv_arm.py
操作步骤：

逐条输入汇编指令，每输入一条按一次回车

如需结束输入，再按一次回车（不输入任何内容）

程序会提示输入起始地址（默认 0），直接回车或输入数字

程序输出连续格式的机器码，可直接复制粘贴到指令存储器（inst_rom_hello.v）

示例：

text
请输入汇编指令 (直接回车结束):
> addi x1, x0, 10
> sw x1, 0(x0)
> 
请输入起始地址 (默认 0): 0

机器码 (可直接复制到指令存储器):
32'h00a00093,
32'h00102023,
快速开始
1. 仿真（Modelsim）
bash
# 打开 Modelsim，进入项目目录
# 编译所有 .v 文件
# 运行仿真 tb_core_top
在波形窗口中添加需要观察的信号，运行仿真即可。

2. 烧录（Vivado）
bash
# 打开 Vivado，创建新项目
# 添加所有 rtl 文件夹下的 .v 文件
# 综合、实现、生成比特流
# 下载到 FPGA 开发板
文件结构
text
Basic-RISC-V-CPU/
├── rtl/               # 所有 RTL 源文件
│   ├── bus/           # 总线仲裁器
│   ├── csr/           # CSR 寄存器
│   ├── exu/           # 执行单元
│   ├── hazard/        # 冒险检测与前递
│   ├── id/            # 译码阶段
│   ├── ifu/           # 取指阶段
│   ├── interrupt/     # 中断控制器
│   ├── mem/           # 访存阶段
│   ├── periph/        # 外设（UART/GPIO/Timer）
│   ├── pipeline/      # 流水线寄存器
│   └── top/           # 顶层模块
├── python/            # 汇编转机器码工具
│   └── riscv_arm.py
├── tb/                # 测试平台
└── docs/              # 文档
地址映射
外设	基址	大小
RAM	0x0000_0000	64KB
UART	0x1000_0000	4KB
GPIO	0x1000_1000	4KB
TIMER	0x1000_2000	4KB
联系方式
作者：Yi Fengxin

单位：北京航空航天大学

邮箱：

1596215367@qq.com

1596215367@buaa.edu.cn

许可证
本项目仅供学习交流使用。


# RISC-V-CPU

A 5-stage pipeline RISC-V CPU design with interrupt support, UART, GPIO, and Timer peripherals.

## Features

- **5-Stage Pipeline**: IF, ID, EX, MEM, WB
- **RISC-V Base Integer Instruction Set (RV32I)** + **Multiplication Extension (M)**
- **Interrupt Support**: Complete interrupt handling and return mechanism
- **Peripherals**:
  - UART Serial Communication
  - GPIO (Input/Output/Interrupt)
  - Programmable Timer (Interrupt)
- **Simulation & Deployment**:
  - Modelsim simulation for waveform observation
  - Vivado synthesis and FPGA programming

## Development Environment

| Tool | Purpose |
|------|---------|
| Modelsim | Simulation and waveform observation |
| Vivado | Synthesis and FPGA programming |
| Verilog | Hardware description language |
| Python | Assembly to machine code converter |

## Assembly to Machine Code Converter

`python/riscv_arm.py` is a Python tool that converts RISC-V assembly to machine code.

### Supported Instruction Sets

| Extension | Instructions |
|-----------|--------------|
| **RV32I** | add, sub, addi, slt, slti, sltu, sltiu, and, or, xor, andi, ori, xori, sll, srl, sra, slli, srli, srai, beq, bne, blt, bge, bltu, bgeu, jal, jalr, lb, lh, lw, lbu, lhu, sb, sh, sw, lui, auipc |
| **RV32M** | mul, mulh, mulhsu, mulhu, div, divu, rem, remu |
| **RV32A** | lr.w, sc.w, amoswap.w, amoadd.w, amoand.w, amoor.w, amoxor.w, amomin.w, amomax.w, amominu.w, amomaxu.w |
| **RV32F** | flw, fsw, fadd.s, fsub.s, fmul.s, fdiv.s, fmin.s, fmax.s, fsqrt.s, fmadd.s, fmsub.s, fnmadd.s, fnmsub.s, feq.s, flt.s, fle.s, fcvt.w.s, fcvt.s.w, fcvt.wu.s, fcvt.s.wu |
| **RV32D** | fld, fsd, fadd.d, fsub.d, fmul.d, fdiv.d, fmin.d, fmax.d, fsqrt.d, fmadd.d, fmsub.d, fnmadd.d, fnmsub.d, feq.d, flt.d, fle.d, fcvt.w.d, fcvt.d.w, fcvt.wu.d, fcvt.d.wu |
| **RV32C** | c.nop, c.addi, c.li, c.lui, c.srli, c.srai, c.andi, c.add, c.sub, c.lw, c.sw, c.j, c.jr, c.jalr, c.beqz, c.bnez |
| **Pseudo** | nop, li, la, mv, not, neg, negw, sext.w, seqz, snz, sltz, sgtz, bgt, ble, bgtu, bleu, beqz, bnez, blez, bgez, bltz, bgtz, call, tail, ret, jr, j, jal |
| **System** | ecall, ebreak, mret, sret, wfi, fence, fence.i |

### Usage

```bash
cd python
python riscv_arm.py
Steps:

Enter assembly instructions one by one, press Enter after each instruction

Press Enter again (without typing anything) to finish input

Enter the starting address (default is 0) or press Enter to accept default

The tool outputs continuous machine code format, ready to copy into inst_rom_hello.v

Example:

text
Enter assembly instruction (press Enter to finish):
> addi x1, x0, 10
> sw x1, 0(x0)
> 
Enter starting address (default 0): 0

Machine code (ready to copy into instruction memory):
32'h00a00093,
32'h00102023,
Quick Start
1. Simulation (Modelsim)
bash
# Open Modelsim and navigate to the project directory
# Compile all .v files
# Run simulation with tb_core_top
Add desired signals to the waveform window and run the simulation.

2. Programming (Vivado)
bash
# Open Vivado and create a new project
# Add all .v files from the rtl folder
# Run synthesis, implementation, and generate bitstream
# Download to FPGA board
File Structure
text
Basic-RISC-V-CPU/
├── rtl/               # All RTL source files
│   ├── bus/           # Bus arbiter
│   ├── csr/           # CSR registers
│   ├── exu/           # Execution unit
│   ├── hazard/        # Hazard detection & forwarding
│   ├── id/            # Instruction decode
│   ├── ifu/           # Instruction fetch
│   ├── interrupt/     # Interrupt controller
│   ├── mem/           # Memory access
│   ├── periph/        # Peripherals (UART/GPIO/Timer)
│   ├── pipeline/      # Pipeline registers
│   └── top/           # Top module
├── python/            # Assembly to machine code converter
│   └── riscv_arm.py
├── tb/                # Testbench
└── docs/              # Documentation
Memory Map
Peripheral	Base Address	Size
RAM	0x0000_0000	64KB
UART	0x1000_0000	4KB
GPIO	0x1000_1000	4KB
TIMER	0x1000_2000	4KB
Contact
Author: Yi Fengxin

Affiliation: Beihang University

Email:

1596215367@qq.com

1596215367@buaa.edu.cn

License
This project is for educational purposes only.