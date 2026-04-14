
# 保存现场
addi  sp, sp, -64
sw    ra, 0(sp)
sw    x10, 4(sp)
sw    x11, 8(sp)
sw    x12, 12(sp)
sw    x13, 16(sp)
sw    x14, 20(sp)

# 读取中断原因
csrrs x10, 0x342, x0       # x10 = mcause

# 判断是否是中断 (最高位为1)
blt   x10, x0, check_intr
nop
nop
jal   x0, isr_exit
nop
nop

check_intr:
# 检查是否是外部中断 (ID=11)
andi  x11, x10, 0x7ff      # 提取中断ID
addi  x12, x0, 11          # 外部中断ID=11
bne   x11, x12, isr_exit   # 不是外部中断则退出
nop
nop

# I2C中断处理
lui   x13, 0x10004         # x13 = I2C基地址
addi  x13, x13, 0x000

# 读取I2C状态寄存器
lw    x15, 0x010(x13)      # 读I2C_STATUS

# 清除中断标志
addi  x14, x0, 0x003       # 清除TX和RX中断标志
sw    x14, 0x018(x13)      # 写I2C_IRQ_FLAG

# 检查是否有NACK错误
andi  x15, x15, 0x008      # 提取ACK位(bit3)
beq   x15, x0, i2c_success # 如果没有NACK则成功
nop
nop

# NACK错误处理
addi  x15, x0, 0x000       # 失败标志=0
jal   x0, set_flag
nop
nop

i2c_success:
addi  x15, x0, 0x001       # 成功标志=1

set_flag:
sw    x15, 0x004(x0)       # 存标志位到地址0x0004

isr_exit:
# 恢复现场
lw    ra, 0(sp)
lw    x10, 4(sp)
lw    x11, 8(sp)
lw    x12, 12(sp)
lw    x13, 16(sp)
lw    x14, 20(sp)
addi  sp, sp, 64

# 返回
mret