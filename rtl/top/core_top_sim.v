// top/core_top_sim.v (完整修复版 - 移除 interrupt_handler 相关代码)
`timescale 1ns/1ps

module core_top_sim (
    input  wire        clk_i,
    input  wire        rst_n_i,
    output wire        uart_tx_o,

    // ========== 调试输出端口 ==========
    output wire [31:0] debug_if_pc,
    output wire [31:0] debug_if_instr,
    output wire [31:0] debug_id_rs1_data,
    output wire [31:0] debug_id_rs2_data,
    output wire [31:0] debug_ex_alu_result,
    output wire [31:0] debug_ex_mem_addr,
    output wire [31:0] debug_ex_mem_wdata,
    output wire        debug_ex_mem_we,
    output wire [2:0]  debug_ex_mem_width,
    
    output wire        debug_mem_bus_we,
    output wire [31:0] debug_mem_bus_addr,
    output wire [31:0] debug_mem_bus_wdata,
    output wire [31:0] debug_mem_bus_rdata,

    output wire        debug_bus_uart_we,
    output wire [31:0] debug_bus_uart_addr,
    output wire [31:0] debug_bus_uart_wdata,
    
    output wire [4:0]  debug_id_rs1_addr,
    output wire [4:0]  debug_id_rs2_addr,
    
    //寄存器
    output wire [31:0] debug_x0,
    output wire [31:0] debug_x1,
    output wire [31:0] debug_x2,
    output wire [31:0] debug_x3,
    output wire [31:0] debug_x4,
    output wire [31:0] debug_x5_t0,
    output wire [31:0] debug_x6_t1,
    output wire [31:0] debug_x7_t2,
    output wire [31:0] debug_x8_t3,
    output wire [31:0] debug_x9_t4,
    output wire [31:0] debug_x10_a0,
    output wire [31:0] debug_x11_a1,
    output wire [31:0] debug_x12_a2,
    output wire [31:0] debug_x13,
    output wire [31:0] debug_x14,

    output wire [2:0]  debug_uart_state,
    output wire [31:0] debug_uart_baud_cnt,
    output wire [3:0]  debug_uart_bit_cnt,
    output wire [7:0]  debug_uart_shift_reg,
    
    output wire [7:0]  debug_uart_fifo_data0,
    output wire [7:0]  debug_uart_fifo_data1,
    output wire [7:0]  debug_uart_fifo_data2,
    output wire [7:0]  debug_uart_fifo_data3,
    output wire [7:0]  debug_uart_fifo_data4,
    output wire [7:0]  debug_uart_fifo_data5,
    output wire [7:0]  debug_uart_fifo_data6,
    output wire [7:0]  debug_uart_fifo_data7,
    output wire [7:0]  debug_uart_fifo_data8,
    output wire [7:0]  debug_uart_fifo_data9,
    output wire [7:0]  debug_uart_fifo_data10,
    output wire [7:0]  debug_uart_fifo_data11,
    output wire [7:0]  debug_uart_fifo_data12,
    output wire [7:0]  debug_uart_fifo_data13,
    output wire [7:0]  debug_uart_fifo_data14,
    output wire [7:0]  debug_uart_fifo_data15,

    output wire [3:0]  debug_uart_wr_ptr,
    output wire [3:0]  debug_uart_rd_ptr,
    output wire [4:0]  debug_uart_fifo_count,
    output wire        debug_uart_fifo_full,
    output wire        debug_uart_fifo_empty,
    output wire        debug_uart_fifo_we,
    output wire        debug_uart_fifo_re,
    
    // CSR/中断调试输出
    output wire [31:0] debug_mstatus,
    output wire [31:0] debug_mie,
    output wire [31:0] debug_mtvec,
    output wire [31:0] debug_mepc,
    output wire [31:0] debug_mcause,
    output wire [31:0] debug_mip,
    output wire        debug_interrupt_pending,
    output wire        debug_interrupt_taken,

    //中断调试
    output wire [31:0] debug_csr_inst_pc,
    output wire        debug_csr_inst_valid,
    output wire [31:0] debug_csr_inst_instr,
    output wire        debug_csr_write,
    output wire [11:0] debug_csr_write_addr,
    output wire [31:0] debug_csr_write_data,
    output wire [31:0] debug_t0_value,
    output wire [31:0] debug_instr_4,
    output wire [31:0] debug_instr_5,
    output wire [31:0] debug_instr_6,
    output wire [31:0] debug_instr_7,

    output wire [31:0] debug_ex_csr_result,
    output wire [31:0] debug_ex_mem_csr_result,

    //定时计数
    output wire [6:0] debug_timer_counter,
    output wire        debug_timer_irq,

    // ID阶段
    output wire        debug_id_csr_inst,
    output wire [11:0] debug_id_csr_addr,
    output wire [2:0]  debug_id_csr_op,
    output wire [4:0]  debug_id_csr_zimm,
    
    // ID/EX阶段
    output wire        debug_ex_csr_inst,
    output wire [11:0] debug_ex_csr_addr,
    output wire [2:0]  debug_ex_csr_op,
    output wire [4:0]  debug_ex_csr_zimm,
    
    // CSR指令处理模块
    output wire [2:0]  debug_csr_inst_op,
    output wire [11:0] debug_csr_inst_addr,
    output wire [4:0]  debug_csr_inst_rs1,
    output wire [31:0] debug_csr_inst_rs1_data,
    output wire [31:0] debug_csr_inst_imm,
    output wire [31:0] debug_csr_inst_rdata,
    output wire        debug_csr_inst_we,
    output wire [11:0] debug_csr_inst_waddr,
    output wire [31:0] debug_csr_inst_wdata,
    output wire [31:0] debug_csr_inst_result,
    
    // 最终CSR写信号
    output wire        debug_final_csr_we,
    output wire [11:0] debug_final_csr_waddr,
    output wire [31:0] debug_final_csr_wdata,
    
    output wire        debug_interrupt_taken_pipe,

    output wire [1:0]  debug_interrupt_hold_cnt,
    output wire        debug_interrupt_accepted,
    output wire        debug_interrupt_condition,
    output wire [4:0]  debug_interrupt_condition_bits,
    output wire [31:0] debug_selected_pc,
    output wire [2:0]  debug_selected_stage,
    
    // CSR寄存器文件接口
    output wire [31:0] debug_csr_reg_rdata,
    output wire        debug_csr_reg_we,
    output wire [11:0] debug_csr_reg_waddr,
    output wire [31:0] debug_csr_reg_wdata,
   
    //前递调试信号
    output wire [1:0]  debug_forwardA,
    output wire [1:0]  debug_forwardB,
    output wire [4:0]  debug_id_ex_rs1,
    output wire [4:0]  debug_id_ex_rs2,

    output wire [4:0]  debug_ex_mem_rd,
    output wire        debug_ex_mem_reg_we,
    output wire        debug_ex_mem_mem_re,

    output wire [4:0]  debug_mem_wb_rd,
    output wire        debug_mem_wb_reg_we,
    
    output wire [31:0] debug_ex_mem_alu_result,
    output wire [31:0] debug_mem_forward_data,
    output wire [31:0] debug_op1_selected,
    output wire [31:0] debug_op2_selected,
    output wire [4:0]  debug_rs1_addr_id,
    output wire [4:0]  debug_rs2_addr_id,
    output wire [31:0] debug_rs1_data_id,
    output wire [31:0] debug_rs2_data_id,

    output wire        debug_id_ex_flush,
    output wire        debug_id_ex_intr_flush,
    output wire        debug_id_ex_stall,

    // Hazard Unit 调试信号
    output wire        debug_stall_if,
    output wire        debug_stall_id,
    output wire        debug_flush_if,
    output wire        debug_flush_id,
    output wire        debug_load_use_hazard,
    output wire        debug_control_hazard,
    
    output wire [4:0]  debug_hazard_rs1_addr,
    output wire [4:0]  debug_hazard_rs2_addr,
    output wire [4:0]  debug_hazard_ex_rd_addr,
    output wire        debug_hazard_ex_reg_we,
    output wire        debug_hazard_ex_mem_re,
    
    output wire [4:0]  debug_fwd_ex_mem_rd,
    output wire        debug_fwd_ex_mem_reg_we,
    output wire [4:0]  debug_fwd_mem_wb_rd,
    output wire        debug_fwd_mem_wb_reg_we,
    
    output wire [31:0] debug_ex_op1,
    output wire [31:0] debug_ex_op2,
    output wire [31:0] debug_ex_rs1_original,
    output wire [31:0] debug_ex_rs2_original,
    
    output wire [31:0] debug_next_pc,
    output wire        debug_pc_changed,

    // GPIO 调试信号
    output wire [31:0] debug_gpio_out,
    output wire [31:0] debug_gpio_oe,
    output wire [31:0] debug_gpio_in,
    output wire [31:0] debug_gpio_if,
    output wire        debug_gpio_interrupt,

    output wire        debug_bus_gpio_we,
    output wire        debug_bus_gpio_re,
    output wire [31:0] debug_bus_gpio_addr,
    output wire [31:0] debug_bus_gpio_wdata,
    output wire [31:0] debug_bus_gpio_rdata,

    // Timer 调试信号
    output wire [31:0] debug_timer_load,
    output wire [31:0] debug_timer_count,
    output wire        debug_timer_enable,
    output wire        debug_timer_irq_flag,
    output wire        debug_timer_interrupt
);

// ==========================================================================
// CSR地址常量定义
// ==========================================================================
localparam CSR_MSTATUS = 12'h300;
localparam CSR_MIE     = 12'h304;
localparam CSR_MTVEC   = 12'h305;
localparam CSR_MEPC    = 12'h341;
localparam CSR_MCAUSE  = 12'h342;
localparam CSR_MIP     = 12'h344;

// ==========================================================================
// 内部信号声明
// ==========================================================================

// GPIO外部引脚
wire [31:0] gpio_in_test;
wire [31:0] gpio_out_test;
wire [31:0] gpio_oe_test;
wire        gpio_interrupt;
wire [31:0] gpio_out_val;
wire [31:0] gpio_oe_val;
wire [31:0] gpio_in_val;
wire [31:0] gpio_if_val;

// 定时器中断
wire        timer_interrupt;
wire [31:0] timer_load_val;
wire [31:0] timer_count_val;
wire        timer_enable;
wire        timer_irq_flag;

// IFU
wire [31:0] if_pc;
wire [31:0] if_instr;
wire [31:0] pc_plus4;

// IF/ID
wire [31:0] if_id_pc;
wire [31:0] if_id_instr;

// ID
wire [31:0] id_rs1_data;
wire [31:0] id_rs2_data;
wire [31:0] id_imm;
wire [4:0]  id_rs1_addr;
wire [4:0]  id_rs2_addr;
wire [4:0]  id_rd_addr;
wire [3:0]  id_alu_op;
wire        id_alu_src;
wire        id_mem_we;
wire        id_mem_re;
wire [1:0]  id_wb_sel;
wire        id_reg_we;
wire        id_branch;
wire        id_jump;
wire [2:0]  id_funct3;
wire [2:0]  id_mem_width;
wire [6:0]  id_opcode;

wire        id_csr_inst;
wire [11:0] id_csr_addr;
wire [2:0]  id_csr_op;
wire [4:0]  id_csr_zimm;

// ID/EX
wire [31:0] id_ex_pc;
wire [31:0] id_ex_rs1_data;
wire [31:0] id_ex_rs2_data;
wire [31:0] id_ex_imm;
wire [4:0]  id_ex_rs1_addr;
wire [4:0]  id_ex_rs2_addr;
wire [4:0]  id_ex_rd_addr;
wire [3:0]  id_ex_alu_op;
wire        id_ex_alu_src;
wire        id_ex_mem_we;
wire        id_ex_mem_re;
wire [1:0]  id_ex_wb_sel;
wire        id_ex_reg_we;
wire        id_ex_branch;
wire        id_ex_jump;
wire [2:0]  id_ex_funct3;
wire [2:0]  id_ex_mem_width;
wire [6:0]  id_ex_opcode;
wire        id_ex_mret;
wire        id_ex_csr_inst;
wire [11:0] id_ex_csr_addr;
wire [2:0]  id_ex_csr_op;
wire [4:0]  id_ex_csr_zimm;

// EX
wire [31:0] ex_alu_result;
wire [31:0] ex_mem_addr;
wire [31:0] ex_mem_wdata;
wire        ex_mem_we;
wire        ex_mem_re;
wire [2:0]  ex_mem_width;
wire        ex_branch_taken;
wire        ex_jump_taken;
wire [31:0] ex_branch_target;
wire [31:0] ex_jump_target;
wire [31:0] ex_pc_plus4;
wire [31:0] ex_result;
wire [1:0]  ex_wb_sel;
wire        ex_reg_we;
wire [4:0]  ex_rd_addr;
wire [31:0] op1_selected;
wire [31:0] op2_selected;
wire [31:0] ex_csr_result;
wire [31:0] forward_mem_data;

// EX/MEM
wire [31:0] ex_mem_alu_result;
wire [31:0] ex_mem_mem_addr;
wire [31:0] ex_mem_mem_wdata;
wire        ex_mem_mem_we;
wire        ex_mem_mem_re;
wire [2:0]  ex_mem_mem_width;
wire [31:0] ex_mem_pc_plus4;
wire [4:0]  ex_mem_rd_addr;
wire [1:0]  ex_mem_wb_sel;
wire        ex_mem_reg_we;
wire [31:0] ex_mem_csr_result;
wire [4:0]  ex_mem_rd_addr_for_hazard;
wire        ex_mem_reg_we_for_hazard;
wire        ex_mem_mem_re_for_hazard;

// MEM
wire [31:0] mem_alu_result;
wire [31:0] mem_mem_rdata;
wire [31:0] mem_pc_plus4;
wire [4:0]  mem_rd_addr;
wire [1:0]  mem_wb_sel;
wire        mem_reg_we;
wire [31:0] mem_csr_result;

// MEM/WB
wire [31:0] wb_alu_result;
wire [31:0] wb_mem_rdata;
wire [31:0] wb_pc_plus4;
wire [4:0]  wb_rd_addr;
wire [1:0]  wb_wb_sel;
wire        wb_reg_we;
wire [31:0] wb_csr_result;
wire        mem_wb_mem_re;

// WB
wire [31:0] wb_data;
wire        wb_reg_we_out;
wire [4:0]  wb_rd_addr_out;

// MEM Bus Interface
wire        mem_bus_re;
wire        mem_bus_we;
wire [31:0] mem_bus_addr;
wire [31:0] mem_bus_wdata;
wire [2:0]  mem_bus_width;
wire [31:0] mem_bus_rdata;
wire        mem_bus_ready;

// Bus Signals
wire        bus_ram_re;
wire        bus_ram_we;
wire [31:0] bus_ram_addr;
wire [31:0] bus_ram_wdata;
wire [2:0]  bus_ram_width;
wire [31:0] bus_ram_rdata;
wire        bus_ram_ready;

wire        bus_uart_we;
wire        bus_uart_re;
wire [31:0] bus_uart_addr;
wire [31:0] bus_uart_wdata;
wire [31:0] bus_uart_rdata;

wire        bus_gpio_we;
wire        bus_gpio_re;
wire [31:0] bus_gpio_addr;
wire [31:0] bus_gpio_wdata;
wire [31:0] bus_gpio_rdata;

wire        bus_timer_we;
wire        bus_timer_re;
wire [31:0] bus_timer_addr;
wire [31:0] bus_timer_wdata;
wire [31:0] bus_timer_rdata;

wire [7:0] tx_data;
wire       tx_valid;
wire [15:0] debug_fifo_out_data_o;
wire       direct_transfer_o;
wire [7:0] data_to_send_o;
wire       tx_ready;
wire       debug_fifo_we_reg;

// Hazard & Forwarding
wire [1:0] forwardA;
wire [1:0] forwardB;
wire       stall_if;
wire       stall_id;
wire       flush_if;
wire       flush_id;
wire       stall_ex;
wire       stall_mem;
wire       stall_wb;
wire       flush_ex;
wire       flush_mem;
wire       flush_wb;

wire        hazard_load_use;
wire        hazard_control;
wire [4:0]  hazard_rs1_addr;
wire [4:0]  hazard_rs2_addr;
wire [4:0]  hazard_ex_rd_addr;
wire        hazard_ex_reg_we;
wire        hazard_ex_mem_re;

wire [4:0]  fwd_ex_mem_rd;
wire        fwd_ex_mem_reg_we;
wire [4:0]  fwd_mem_wb_rd;
wire        fwd_mem_wb_reg_we;

// ==========================================================================
// 中断相关信号
// ==========================================================================

wire       intr_software = 1'b0;
wire       intr_timer;
wire       intr_external = gpio_interrupt;

wire [31:0] csr_rdata;
wire [31:0] mtvec;
wire [31:0] mepc;
wire [31:0] mcause;
wire [31:0] mie;
wire [31:0] mstatus;
wire [31:0] mip;

wire        id_mret;

wire        csr_inst_valid;
wire [2:0]  csr_op;
wire [11:0] csr_addr;
wire [4:0]  csr_rs1_addr;
wire [31:0] csr_rs1_data;
wire [31:0] csr_imm;
wire [31:0] csr_inst_result;
wire        csr_inst_we;
wire [11:0] csr_inst_waddr;
wire [31:0] csr_inst_wdata;

wire        csr_we;
wire [11:0] csr_waddr;
wire [31:0] csr_wdata;
wire [31:0] csr_result;

wire        intr_pending;
wire [31:0] intr_cause;
wire [31:0] intr_handler_addr;

wire        pipe_csr_mepc_we;
wire [31:0] pipe_csr_mepc_data;
wire        pipe_csr_mcause_we;
wire [31:0] pipe_csr_mcause_data;
wire        pipe_csr_mstatus_we;
wire [31:0] pipe_csr_mstatus_data;

wire        interrupt_taken_pipe;
wire        interrupt_flush_pipe;
wire [31:0] interrupt_pc_pipe;
wire        intr_flush_if;
wire        intr_flush_id;
wire        intr_flush_ex;
wire        intr_flush_mem;
wire        intr_flush_wb;

// ==========================================================================
// 实例化所有模块
// ==========================================================================

data_ram u_data_ram (
    .clk_i     (clk_i),
    .rst_n_i   (rst_n_i),
    .we_i      (bus_ram_we),
    .re_i      (bus_ram_re),
    .width_i   (bus_ram_width),
    .addr_i    (bus_ram_addr),
    .wdata_i   (bus_ram_wdata),
    .rdata_o   (bus_ram_rdata),
    .ready_o   (bus_ram_ready)
);

assign stall_ex  = 1'b0;
assign stall_mem = 1'b0;
assign stall_wb  = 1'b0;
assign flush_ex  = ex_branch_taken || ex_jump_taken;
assign flush_mem = 1'b0;
assign flush_wb  = 1'b0;

ifu_top u_ifu_top (
    .clk              (clk_i),
    .rst_n            (rst_n_i),
    .stall_i          (stall_if || intr_flush_if),
    .branch_taken_i   (ex_branch_taken),
    .jump_taken_i     (ex_jump_taken),
    .branch_target_i  (ex_branch_target),
    .jump_target_i    (ex_jump_target),
    .interrupt_pending_i(interrupt_taken_pipe),
    .mtvec_i           (mtvec),
    .instr            (if_instr),
    .pc               (if_pc),
    .pc_plus4         (pc_plus4)
);

if_id_reg u_if_id_reg (
    .clk_i           (clk_i),
    .rst_n_i         (rst_n_i),
    .stall_i         (stall_id),
    .flush_i         (flush_id),
    .intr_flush_i    (intr_flush_id),
    .if_pc_i         (if_pc),
    .if_instr_i      (if_instr),
    .id_pc_o         (if_id_pc),
    .id_instr_o      (if_id_instr)
);

id_top u_id_top (
    .clk           (clk_i),
    .rst_n         (rst_n_i),
    .instr         (if_id_instr),
    .pc            (if_id_pc),
    .wb_we_i       (wb_reg_we_out),
    .wb_rd_addr_i  (wb_rd_addr_out),
    .wb_rd_data_i  (wb_data),
    .rs1_data_o    (id_rs1_data),
    .rs2_data_o    (id_rs2_data),
    .imm_o         (id_imm),
    .rs1_addr_o    (id_rs1_addr),
    .rs2_addr_o    (id_rs2_addr),
    .rd_addr_o     (id_rd_addr),
    .alu_op_o      (id_alu_op),
    .alu_src_o     (id_alu_src),
    .mem_we_o      (id_mem_we),
    .mem_re_o      (id_mem_re),
    .wb_sel_o      (id_wb_sel),
    .reg_we_o      (id_reg_we),
    .branch_o      (id_branch),
    .jump_o        (id_jump),
    .funct3_o      (id_funct3),
    .opcode_o      (id_opcode),
    .mem_width_o   (id_mem_width),
    .mret_o        (id_mret),
    .csr_inst_o    (id_csr_inst),
    .csr_addr_o    (id_csr_addr),
    .csr_op_o      (id_csr_op),
    .csr_zimm_o    (id_csr_zimm),
    .debug_x0_o    (debug_x0),
    .debug_x1_o    (debug_x1),
    .debug_x2_o    (debug_x2),
    .debug_x3_o    (debug_x3),
    .debug_x4_o    (debug_x4),
    .debug_x5_o    (debug_x5_t0),
    .debug_x6_o    (debug_x6_t1),
    .debug_x7_o    (debug_x7_t2),
    .debug_x8_o    (debug_x8_t3),
    .debug_x9_o    (debug_x9_t4),
    .debug_x10_o   (debug_x10_a0),
    .debug_x11_o   (debug_x11_a1),
    .debug_x12_o   (debug_x12_a2),
    .debug_x13_o   (debug_x13),
    .debug_x14_o   (debug_x14)
);

id_ex_reg u_id_ex_reg (
    .clk_i           (clk_i),
    .rst_n_i         (rst_n_i),
    .stall_i         (stall_id),
    .flush_i         (flush_id),
    .intr_flush_i    (intr_flush_ex),
    .id_pc_i         (if_id_pc),
    .id_rs1_data_i   (id_rs1_data),
    .id_rs2_data_i   (id_rs2_data),
    .id_imm_i        (id_imm),
    .id_rs1_addr_i   (id_rs1_addr),
    .id_rs2_addr_i   (id_rs2_addr),
    .id_rd_addr_i    (id_rd_addr),
    .id_alu_op_i     (id_alu_op),
    .id_alu_src_i    (id_alu_src),
    .id_mem_we_i     (id_mem_we),
    .id_mem_re_i     (id_mem_re),
    .id_mem_width_i  (id_mem_width),
    .id_wb_sel_i     (id_wb_sel),
    .id_reg_we_i     (id_reg_we),
    .id_branch_i     (id_branch),
    .id_jump_i       (id_jump),
    .id_funct3_i     (id_funct3),
    .id_opcode_i     (id_opcode),
    .id_csr_inst_i   (id_csr_inst),
    .id_csr_addr_i   (id_csr_addr),
    .id_csr_op_i     (id_csr_op),
    .id_csr_zimm_i   (id_csr_zimm),
    .ex_pc_o         (id_ex_pc),
    .ex_rs1_data_o   (id_ex_rs1_data),
    .ex_rs2_data_o   (id_ex_rs2_data),
    .ex_imm_o        (id_ex_imm),
    .ex_rs1_addr_o   (id_ex_rs1_addr),
    .ex_rs2_addr_o   (id_ex_rs2_addr),
    .ex_rd_addr_o    (id_ex_rd_addr),
    .ex_alu_op_o     (id_ex_alu_op),
    .ex_alu_src_o    (id_ex_alu_src),
    .ex_mem_we_o     (id_ex_mem_we),
    .ex_mem_re_o     (id_ex_mem_re),
    .ex_mem_width_o  (id_ex_mem_width),
    .ex_wb_sel_o     (id_ex_wb_sel),
    .ex_reg_we_o     (id_ex_reg_we),
    .ex_branch_o     (id_ex_branch),
    .ex_jump_o       (id_ex_jump),
    .ex_funct3_o     (id_ex_funct3),
    .ex_opcode_o     (id_ex_opcode),
    .id_mret_i       (id_mret),
    .ex_mret_o       (id_ex_mret),
    .ex_csr_inst_o   (id_ex_csr_inst),
    .ex_csr_addr_o   (id_ex_csr_addr),
    .ex_csr_op_o     (id_ex_csr_op),
    .ex_csr_zimm_o   (id_ex_csr_zimm)
);

hazard_unit u_hazard_unit (
    .clk_i            (clk_i),
    .rst_n_i          (rst_n_i),
    .id_rs1_addr_i    (id_rs1_addr),
    .id_rs2_addr_i    (id_rs2_addr),
    .id_ex_rd_addr_i  (id_ex_rd_addr),
    .id_ex_reg_we_i   (id_ex_reg_we),
    .id_ex_mem_re_i   (id_ex_mem_re),
    .ex_mem_rd_addr_i (ex_mem_rd_addr_for_hazard),
    .ex_mem_reg_we_i  (ex_mem_reg_we_for_hazard),
    .ex_mem_mem_re_i  (ex_mem_mem_re_for_hazard),
    .branch_taken_i   (ex_branch_taken),
    .jump_taken_i     (ex_jump_taken),
    .interrupt_taken_i(interrupt_taken_pipe),
    .interrupt_flush_i(interrupt_flush_pipe),
    .stall_if_o       (stall_if),
    .stall_id_o       (stall_id),
    .flush_if_o       (flush_if),
    .flush_id_o       (flush_id),
    .intr_flush_if_o  (intr_flush_if),
    .intr_flush_id_o  (intr_flush_id),
    .intr_flush_ex_o  (intr_flush_ex),
    .intr_flush_mem_o (intr_flush_mem),
    .intr_flush_wb_o  (intr_flush_wb),
    .debug_load_use_hazard_o (hazard_load_use),
    .debug_control_hazard_o  (hazard_control),
    .debug_id_rs1_addr_o     (hazard_rs1_addr),
    .debug_id_rs2_addr_o     (hazard_rs2_addr),
    .debug_id_ex_rd_addr_o   (hazard_ex_rd_addr),
    .debug_id_ex_reg_we_o    (hazard_ex_reg_we),
    .debug_id_ex_mem_re_o    (hazard_ex_mem_re)
);

forwarding_unit u_forwarding_unit (
    .id_ex_rs1_addr_i   (id_ex_rs1_addr),
    .id_ex_rs2_addr_i   (id_ex_rs2_addr),
    .ex_mem_rd_addr_i   (ex_mem_rd_addr),
    .ex_mem_reg_we_i    (ex_mem_reg_we),
    .ex_mem_mem_re_i    (ex_mem_mem_re),
    .mem_wb_rd_addr_i   (wb_rd_addr),
    .mem_wb_reg_we_i    (wb_reg_we),
    .stall_i            (stall_id),
    .forwardA_o         (forwardA),
    .forwardB_o         (forwardB),
    .debug_ex_mem_rd_addr_o (fwd_ex_mem_rd),
    .debug_ex_mem_reg_we_o  (fwd_ex_mem_reg_we),
    .debug_mem_wb_rd_addr_o (fwd_mem_wb_rd),
    .debug_mem_wb_reg_we_o  (fwd_mem_wb_reg_we)
);

ex_top u_ex_top (
    .clk_i              (clk_i),
    .rst_n_i            (rst_n_i),
    .rs1_data_i         (id_ex_rs1_data),
    .rs2_data_i         (id_ex_rs2_data),
    .imm_i              (id_ex_imm),
    .pc_i               (id_ex_pc),
    .wb_sel_i           (id_ex_wb_sel),
    .reg_we_i           (id_ex_reg_we),
    .rd_addr_i          (id_ex_rd_addr),
    .alu_op_i           (id_ex_alu_op),
    .alu_src_i          (id_ex_alu_src),
    .branch_i           (id_ex_branch),
    .jump_i             (id_ex_jump),
    .funct3_i           (id_ex_funct3),
    .mem_we_i           (id_ex_mem_we),
    .mem_re_i           (id_ex_mem_re),
    .mem_width_i        (id_ex_mem_width),
    .ex_forward_data_i  (ex_mem_alu_result),
    .mem_forward_data_i (forward_mem_data),
    .forwardA_i         (forwardA),
    .forwardB_i         (forwardB),
    .opcode_i           (id_ex_opcode),
    .csr_result_i       (csr_result),
    .alu_result_o       (ex_alu_result),
    .mem_addr_o         (ex_mem_addr),
    .mem_wdata_o        (ex_mem_wdata),
    .mem_we_o           (ex_mem_we),
    .mem_re_o           (ex_mem_re),
    .branch_taken_o     (ex_branch_taken),
    .branch_target_o    (ex_branch_target),
    .jump_taken_o       (ex_jump_taken),
    .jump_target_o      (ex_jump_target),
    .pc_plus4_o         (ex_pc_plus4),
    .ex_result_o        (ex_result),
    .wb_sel_o           (ex_wb_sel),
    .reg_we_o           (ex_reg_we),
    .rd_addr_o          (ex_rd_addr),
    .mem_width_o        (ex_mem_width),
    .op1_selected_o     (op1_selected),
    .op2_selected_o     (op2_selected),
    .ex_csr_result_o    (ex_csr_result),
    .csr_mepc_i         (mepc),
    .mret_i             (id_ex_mret)
);

ex_mem_reg u_ex_mem_reg (
    .clk_i              (clk_i),
    .rst_n_i            (rst_n_i),
    .stall_i            (stall_mem),
    .flush_i            (flush_mem),
    .intr_flush_i       (intr_flush_mem),
    .ex_alu_result_i    (ex_alu_result),
    .ex_mem_addr_i      (ex_mem_addr),
    .ex_mem_wdata_i     (ex_mem_wdata),
    .ex_pc_plus4_i      (ex_pc_plus4),
    .ex_rd_addr_i       (ex_rd_addr),
    .ex_mem_we_i        (ex_mem_we),
    .ex_mem_re_i        (ex_mem_re),
    .ex_mem_width_i     (ex_mem_width),
    .ex_wb_sel_i        (ex_wb_sel),
    .ex_reg_we_i        (ex_reg_we),
    .ex_csr_result_i    (ex_csr_result),
    .mem_alu_result_o   (ex_mem_alu_result),
    .mem_mem_addr_o     (ex_mem_mem_addr),
    .mem_mem_wdata_o    (ex_mem_mem_wdata),
    .mem_pc_plus4_o     (ex_mem_pc_plus4),
    .mem_rd_addr_o      (ex_mem_rd_addr),
    .mem_mem_we_o       (ex_mem_mem_we),
    .mem_mem_re_o       (ex_mem_mem_re),
    .mem_mem_width_o    (ex_mem_mem_width),
    .mem_wb_sel_o       (ex_mem_wb_sel),
    .mem_reg_we_o       (ex_mem_reg_we),
    .mem_csr_result_o   (ex_mem_csr_result)
);

mem_top_fpga u_mem_top (
    .clk_i             (clk_i),
    .rst_n_i           (rst_n_i),
    .alu_result_i      (ex_mem_alu_result),
    .wdata_i           (ex_mem_mem_wdata),
    .mem_we_i          (ex_mem_mem_we),
    .mem_re_i          (ex_mem_mem_re),
    .mem_width_i       (ex_mem_mem_width),
    .pc_plus4_i        (ex_mem_pc_plus4),
    .reg_we_i          (ex_mem_reg_we),
    .wb_sel_i          (ex_mem_wb_sel),
    .rd_addr_i         (ex_mem_rd_addr),
    .pc_plus4_o        (mem_pc_plus4),
    .reg_we_o          (mem_reg_we),
    .wb_sel_o          (mem_wb_sel),
    .rd_addr_o         (mem_rd_addr),
    .bus_re_o          (mem_bus_re),
    .bus_we_o          (mem_bus_we),
    .bus_addr_o        (mem_bus_addr),
    .bus_wdata_o       (mem_bus_wdata),
    .bus_width_o       (mem_bus_width),
    .bus_rdata_i       (mem_bus_rdata),
    .bus_ready_i       (mem_bus_ready),
    .mem_exception_o   ()
);

mem_wb_reg u_mem_wb_reg (
    .clk_i            (clk_i),
    .rst_n_i          (rst_n_i),
    .stall_i          (stall_wb),
    .flush_i          (flush_wb),
    .intr_flush_i     (intr_flush_wb),
    .mem_alu_result_i (ex_mem_alu_result),
    .mem_mem_rdata_i  (mem_bus_rdata),
    .mem_pc_plus4_i   (mem_pc_plus4),
    .mem_rd_addr_i    (mem_rd_addr),
    .mem_wb_sel_i     (mem_wb_sel),
    .mem_reg_we_i     (mem_reg_we),
    .mem_csr_result_i (ex_mem_csr_result),
    .mem_mem_re_i     (ex_mem_mem_re),
    .wb_mem_re_o      (mem_wb_mem_re),
    .wb_alu_result_o  (wb_alu_result),
    .wb_mem_rdata_o   (wb_mem_rdata),
    .wb_pc_plus4_o    (wb_pc_plus4),
    .wb_rd_addr_o     (wb_rd_addr),
    .wb_wb_sel_o      (wb_wb_sel),
    .wb_reg_we_o      (wb_reg_we),
    .wb_csr_result_o  (wb_csr_result)
);

wb_top u_wb_top (
    .clk_i          (clk_i),
    .rst_n_i        (rst_n_i),
    .alu_result_i   (wb_alu_result),
    .mem_rdata_i    (wb_mem_rdata),
    .pc_plus4_i     (wb_pc_plus4),
    .csr_result_i   (wb_csr_result),
    .wb_sel_i       (wb_wb_sel),
    .reg_we_i       (wb_reg_we),
    .rd_addr_i      (wb_rd_addr),
    .wb_data_o      (wb_data),
    .reg_we_o       (wb_reg_we_out),
    .rd_addr_o      (wb_rd_addr_out)
);

bus_arbiter u_bus_arbiter (
    .clk_i          (clk_i),
    .rst_n_i        (rst_n_i),
    .mem_re_i       (mem_bus_re),
    .mem_we_i       (mem_bus_we),
    .mem_addr_i     (mem_bus_addr),
    .mem_wdata_i    (mem_bus_wdata),
    .mem_width_i    (mem_bus_width),
    .mem_rdata_o    (mem_bus_rdata),
    .mem_ready_o    (mem_bus_ready),
    .ram_re_o       (bus_ram_re),
    .ram_we_o       (bus_ram_we),
    .ram_addr_o     (bus_ram_addr),
    .ram_wdata_o    (bus_ram_wdata),
    .ram_width_o    (bus_ram_width),
    .ram_rdata_i    (bus_ram_rdata),
    .ram_ready_i    (bus_ram_ready),
    .uart_we_o      (bus_uart_we),
    .uart_re_o      (bus_uart_re),
    .uart_addr_o    (bus_uart_addr),
    .uart_wdata_o   (bus_uart_wdata),
    .uart_rdata_i   (bus_uart_rdata),
    .gpio_we_o      (bus_gpio_we),
    .gpio_re_o      (bus_gpio_re),
    .gpio_addr_o    (bus_gpio_addr),
    .gpio_wdata_o   (bus_gpio_wdata),
    .gpio_rdata_i   (bus_gpio_rdata),
    .timer_we_o     (bus_timer_we),
    .timer_re_o     (bus_timer_re),
    .timer_addr_o   (bus_timer_addr),
    .timer_wdata_o  (bus_timer_wdata),
    .timer_rdata_i  (bus_timer_rdata)
);

uart_ctrl #(
    .CLK_FREQ(200_000_000),
    .BAUD_RATE(115200)
) u_uart_ctrl (
    .clk_i                  (clk_i),
    .rst_n_i                (rst_n_i),
    .we_i                   (bus_uart_we),
    .addr_i                 (bus_uart_addr),
    .wdata_i                (bus_uart_wdata),
    .rdata_o                (bus_uart_rdata),
    .tx_pin_o               (uart_tx_o),
    .tx_data_o              (tx_data),
    .tx_valid_o             (tx_valid),
    .debug_fifo_out_data_o  (debug_fifo_out_data_o),
    .direct_transfer_o      (direct_transfer_o),
    .data_to_send_o         (data_to_send_o),
    .tx_ready_o             (tx_ready),
    .debug_fifo_we_reg_o    (debug_fifo_we_reg),
    .debug_state_o          (debug_uart_state),
    .debug_baud_cnt_o       (debug_uart_baud_cnt),
    .debug_bit_cnt_o        (debug_uart_bit_cnt),
    .debug_shift_reg_o      (debug_uart_shift_reg),
    .debug_fifo_data0_o     (debug_uart_fifo_data0),
    .debug_fifo_data1_o     (debug_uart_fifo_data1),
    .debug_fifo_data2_o     (debug_uart_fifo_data2),
    .debug_fifo_data3_o     (debug_uart_fifo_data3),
    .debug_fifo_data4_o     (debug_uart_fifo_data4),
    .debug_fifo_data5_o     (debug_uart_fifo_data5),
    .debug_fifo_data6_o     (debug_uart_fifo_data6),
    .debug_fifo_data7_o     (debug_uart_fifo_data7),
    .debug_fifo_data8_o     (debug_uart_fifo_data8),
    .debug_fifo_data9_o     (debug_uart_fifo_data9),
    .debug_fifo_data10_o    (debug_uart_fifo_data10),
    .debug_fifo_data11_o    (debug_uart_fifo_data11),
    .debug_fifo_data12_o    (debug_uart_fifo_data12),
    .debug_fifo_data13_o    (debug_uart_fifo_data13),
    .debug_fifo_data14_o    (debug_uart_fifo_data14),
    .debug_fifo_data15_o    (debug_uart_fifo_data15),
    .debug_wr_ptr_o         (debug_uart_wr_ptr),
    .debug_rd_ptr_o         (debug_uart_rd_ptr),
    .debug_fifo_count_o     (debug_uart_fifo_count),
    .debug_fifo_full_o      (debug_uart_fifo_full),
    .debug_fifo_empty_o     (debug_uart_fifo_empty),
    .debug_fifo_we_o        (debug_uart_fifo_we),
    .debug_fifo_re_o        (debug_uart_fifo_re)
);

gpio u_gpio (
    .clk_i        (clk_i),
    .rst_n_i      (rst_n_i),
    .we_i         (bus_gpio_we),
    .re_i         (bus_gpio_re),
    .addr_i       (bus_gpio_addr),
    .wdata_i      (bus_gpio_wdata),
    .rdata_o      (bus_gpio_rdata),
    .gpio_in_i    (gpio_in_test),
    .gpio_out_o   (gpio_out_test),
    .gpio_oe_o    (gpio_oe_test),
    .interrupt_o  (gpio_interrupt),
    .debug_gpio_out  (gpio_out_val),
    .debug_gpio_oe   (gpio_oe_val),
    .debug_gpio_in   (gpio_in_val),
    .debug_gpio_if   (gpio_if_val)
);

timer u_timer (
    .clk_i        (clk_i),
    .rst_n_i      (rst_n_i),
    .we_i         (bus_timer_we),
    .re_i         (bus_timer_re),
    .addr_i       (bus_timer_addr),
    .wdata_i      (bus_timer_wdata),
    .rdata_o      (bus_timer_rdata),
    .interrupt_o  (timer_interrupt),
    .debug_load_value (timer_load_val),
    .debug_counter    (timer_count_val),
    .debug_enable     (timer_enable),
    .debug_irq_flag   (timer_irq_flag)
);

assign intr_timer = timer_interrupt;
assign debug_timer_irq = timer_interrupt;
assign debug_timer_counter = 7'b0;

csr_regfile u_csr_regfile (
    .clk_i              (clk_i),
    .rst_n_i            (rst_n_i),
    .csr_addr_i         (id_ex_csr_addr),
    .csr_rdata_o        (csr_rdata),

       // 独立写端口
    .csr_inst_we_i      (csr_inst_we),
    .csr_inst_waddr_i   (csr_inst_waddr),
    .csr_inst_wdata_i   (csr_inst_wdata),
    
    .csr_mepc_we_i      (pipe_csr_mepc_we),
    .csr_mepc_data_i    (pipe_csr_mepc_data),
    
    .csr_mcause_we_i    (pipe_csr_mcause_we),
    .csr_mcause_data_i  (pipe_csr_mcause_data),
    
    .csr_mstatus_we_i   (pipe_csr_mstatus_we),
    .csr_mstatus_data_i (pipe_csr_mstatus_data),
    
    .intr_software_i    (intr_software),
    .intr_timer_i       (intr_timer),
    .intr_external_i    (intr_external),
    .mtvec_o            (mtvec),
    .mepc_o             (mepc),
    .mcause_o           (mcause),
    .mie_o              (mie),
    .mstatus_o          (mstatus),
    .mip_o              (mip),
    .debug_mstatus_o    (debug_mstatus),
    .debug_mie_o        (debug_mie),
    .debug_mtvec_o      (debug_mtvec),
    .debug_mepc_o       (debug_mepc),
    .debug_mcause_o     (debug_mcause)
);

assign csr_inst_valid = id_ex_csr_inst;
assign csr_op         = id_ex_csr_op;
assign csr_addr       = id_ex_csr_addr;
assign csr_rs1_addr   = id_ex_rs1_addr;
assign csr_rs1_data   = op1_selected;
assign csr_imm        = id_ex_imm;
assign debug_mip      = mip;

csr_instructions u_csr_instructions (
    .clk_i              (clk_i),
    .rst_n_i            (rst_n_i),
    .csr_inst_valid_i   (csr_inst_valid),
    .csr_op_i           (csr_op),
    .csr_addr_i         (csr_addr),
    .rs1_addr_i         (csr_rs1_addr),
    .rs1_data_i         (csr_rs1_data),
    .imm_i              (csr_imm),
    .csr_rdata_i        (csr_rdata),
    .csr_we_o           (csr_inst_we),
    .csr_waddr_o        (csr_inst_waddr),
    .csr_wdata_o        (csr_inst_wdata),
    .csr_result_o       (csr_inst_result),
    .debug_csr_op_type_o(),
    .debug_csr_we_o     (),
    .debug_csr_addr_o   ()
);

interrupt_controller u_interrupt_controller (
    .clk_i              (clk_i),
    .rst_n_i            (rst_n_i),
    .intr_software_i    (intr_software),
    .intr_timer_i       (intr_timer),
    .intr_external_i    (intr_external),
    .mie_i              (mie),
    .mip_i              (mip),
    .mstatus_i          (mstatus),
    .mtvec_i            (mtvec),
    .intr_pending_o     (intr_pending),
    .intr_cause_o       (intr_cause),
    .intr_handler_addr_o(intr_handler_addr)
);

interrupt_pipeline u_interrupt_pipeline (
    .clk_i              (clk_i),
    .rst_n_i            (rst_n_i),
    .if_pc_i            (if_pc),
    .id_valid_i         (|if_id_instr),
    .id_pc_i            (if_id_pc),
    .ex_valid_i         (|id_ex_opcode),
    .ex_pc_i            (id_ex_pc),
    .ex_branch_taken_i  (ex_branch_taken),
    .ex_jump_taken_i    (ex_jump_taken),
    .mem_valid_i        (ex_mem_mem_we || ex_mem_mem_re),
    .mem_pc_i           (ex_mem_pc_plus4 - 4),
    .mem_mem_re_i       (ex_mem_mem_re),
    .mem_mem_we_i       (ex_mem_mem_we),
    .wb_valid_i         (wb_reg_we_out),
    .wb_rd_addr_i       (wb_rd_addr_out),
    .wb_reg_we_i        (wb_reg_we_out),
    .intr_pending_i     (intr_pending),
    .intr_cause_i       (intr_cause),
    .mstatus_i          (mstatus),
    .csr_mepc_we_o      (pipe_csr_mepc_we),
    .csr_mepc_data_o    (pipe_csr_mepc_data),
    .csr_mcause_we_o    (pipe_csr_mcause_we),
    .csr_mcause_data_o  (pipe_csr_mcause_data),
    .csr_mstatus_we_o   (pipe_csr_mstatus_we),
    .csr_mstatus_data_o (pipe_csr_mstatus_data),
    .interrupt_taken_o  (interrupt_taken_pipe),
    .interrupt_flush_o  (interrupt_flush_pipe),
    .interrupt_pc_o     (interrupt_pc_pipe),
    .debug_interrupt_accepted     (debug_interrupt_accepted),
    .debug_interrupt_hold_cnt     (debug_interrupt_hold_cnt),
    .debug_interrupt_condition    (debug_interrupt_condition),
    .debug_interrupt_condition_bits(debug_interrupt_condition_bits),
    .debug_selected_pc            (debug_selected_pc),
    .debug_selected_stage         (debug_selected_stage)
);

// ==========================================================================
// CSR写信号合并
// ==========================================================================
wire [31:0] final_csr_wdata;
wire [11:0] final_csr_waddr;
wire        final_csr_we;

// assign final_csr_we    = csr_inst_we ||
//                          pipe_csr_mepc_we || pipe_csr_mcause_we || pipe_csr_mstatus_we;

// assign final_csr_waddr = pipe_csr_mepc_we ? CSR_MEPC :
//                          pipe_csr_mcause_we ? CSR_MCAUSE :
//                          pipe_csr_mstatus_we ? CSR_MSTATUS :
//                          csr_inst_waddr;

// assign final_csr_wdata = pipe_csr_mepc_we ? pipe_csr_mepc_data :
//                          pipe_csr_mcause_we ? pipe_csr_mcause_data :
//                          pipe_csr_mstatus_we ? pipe_csr_mstatus_data :
//                          csr_inst_wdata;

assign debug_interrupt_taken_pipe = interrupt_taken_pipe;

// assign csr_we    = final_csr_we;
// assign csr_waddr = final_csr_waddr;
// assign csr_wdata = final_csr_wdata;

assign csr_result = csr_inst_result;
assign debug_ex_csr_result = ex_csr_result;
assign debug_ex_mem_csr_result = ex_mem_csr_result;

// ==========================================================================
// 调试信号连接
// ==========================================================================
assign debug_if_pc          = if_pc;
assign debug_if_instr       = if_instr;
assign debug_id_rs1_data    = id_rs1_data;
assign debug_id_rs2_data    = id_rs2_data;
assign debug_id_rs1_addr    = id_rs1_addr;
assign debug_id_rs2_addr    = id_rs2_addr;
assign debug_ex_alu_result  = ex_alu_result;
assign debug_ex_mem_addr    = ex_mem_addr;
assign debug_ex_mem_wdata   = ex_mem_wdata;
assign debug_ex_mem_we      = ex_mem_we;
assign debug_ex_mem_width   = ex_mem_width;
assign debug_mem_bus_we     = mem_bus_we;
assign debug_mem_bus_addr   = mem_bus_addr;
assign debug_mem_bus_wdata  = mem_bus_wdata;
assign debug_mem_bus_rdata  = mem_bus_rdata;
assign debug_bus_uart_we    = bus_uart_we;
assign debug_bus_uart_addr  = bus_uart_addr;
assign debug_bus_uart_wdata = bus_uart_wdata;
assign debug_interrupt_pending = intr_pending;
assign debug_interrupt_taken   = interrupt_taken_pipe;

assign debug_csr_inst_pc = id_ex_pc;
assign debug_csr_inst_instr = {id_ex_opcode, 25'b0};
assign debug_csr_write = csr_we;
assign debug_csr_write_addr = csr_waddr;
assign debug_csr_write_data = csr_wdata;
assign debug_t0_value = id_rs1_data;
assign debug_instr_4 = (if_pc == 32'h10) ? if_instr : 32'b0;
assign debug_instr_5 = (if_pc == 32'h14) ? if_instr : 32'b0;
assign debug_instr_6 = (if_pc == 32'h18) ? if_instr : 32'b0;
assign debug_instr_7 = (if_pc == 32'h1C) ? if_instr : 32'b0;

assign debug_id_csr_inst = id_csr_inst;
assign debug_id_csr_addr = id_csr_addr;
assign debug_id_csr_op = id_csr_op;
assign debug_id_csr_zimm = id_csr_zimm;
assign debug_ex_csr_inst = id_ex_csr_inst;
assign debug_ex_csr_addr = id_ex_csr_addr;
assign debug_ex_csr_op = id_ex_csr_op;
assign debug_ex_csr_zimm = id_ex_csr_zimm;
assign debug_id_ex_flush = flush_id;
assign debug_id_ex_intr_flush = intr_flush_ex;
assign debug_id_ex_stall = stall_id;

assign ex_mem_rd_addr_for_hazard = ex_mem_rd_addr;
assign ex_mem_reg_we_for_hazard = ex_mem_reg_we;
assign ex_mem_mem_re_for_hazard = ex_mem_mem_re;
assign forward_mem_data = mem_wb_mem_re ? wb_mem_rdata : wb_alu_result;

assign debug_csr_inst_valid = csr_inst_valid;
assign debug_csr_inst_op = csr_op;
assign debug_csr_inst_addr = csr_addr;
assign debug_csr_inst_rs1 = csr_rs1_addr;
assign debug_csr_inst_rs1_data = csr_rs1_data;
assign debug_csr_inst_imm = csr_imm;
assign debug_csr_inst_rdata = csr_rdata;
assign debug_csr_inst_we = csr_inst_we;
assign debug_csr_inst_waddr = csr_inst_waddr;
assign debug_csr_inst_wdata = csr_inst_wdata;
assign debug_csr_inst_result = csr_inst_result;

assign debug_final_csr_we = final_csr_we;
assign debug_final_csr_waddr = final_csr_waddr;
assign debug_final_csr_wdata = final_csr_wdata;

assign debug_csr_reg_rdata = csr_rdata;
assign debug_csr_reg_we = csr_we;
assign debug_csr_reg_waddr = csr_waddr;
assign debug_csr_reg_wdata = csr_wdata;

assign debug_forwardA = forwardA;
assign debug_forwardB = forwardB;
assign debug_id_ex_rs1 = id_ex_rs1_addr;
assign debug_id_ex_rs2 = id_ex_rs2_addr;
assign debug_ex_mem_rd = ex_mem_rd_addr;
assign debug_ex_mem_reg_we = ex_mem_reg_we;
assign debug_ex_mem_mem_re = ex_mem_mem_re;
assign debug_mem_wb_rd = wb_rd_addr;
assign debug_mem_wb_reg_we = wb_reg_we;
assign debug_ex_mem_alu_result = ex_mem_alu_result;
assign debug_mem_forward_data = wb_alu_result;
assign debug_op1_selected = op1_selected;
assign debug_op2_selected = op2_selected;
assign debug_rs1_addr_id = id_rs1_addr;
assign debug_rs2_addr_id = id_rs2_addr;
assign debug_rs1_data_id = id_rs1_data;
assign debug_rs2_data_id = id_rs2_data;

assign debug_stall_if         = stall_if;
assign debug_stall_id         = stall_id;
assign debug_flush_if         = flush_if;
assign debug_flush_id         = flush_id;
assign debug_load_use_hazard  = hazard_load_use;
assign debug_control_hazard   = hazard_control;
assign debug_hazard_rs1_addr  = hazard_rs1_addr;
assign debug_hazard_rs2_addr  = hazard_rs2_addr;
assign debug_hazard_ex_rd_addr = hazard_ex_rd_addr;
assign debug_hazard_ex_reg_we = hazard_ex_reg_we;
assign debug_hazard_ex_mem_re = hazard_ex_mem_re;
assign debug_fwd_ex_mem_rd    = fwd_ex_mem_rd;
assign debug_fwd_ex_mem_reg_we = fwd_ex_mem_reg_we;
assign debug_fwd_mem_wb_rd    = fwd_mem_wb_rd;
assign debug_fwd_mem_wb_reg_we = fwd_mem_wb_reg_we;
assign debug_ex_rs1_original  = id_ex_rs1_data;
assign debug_ex_rs2_original  = id_ex_rs2_data;
assign debug_next_pc          = (ex_branch_taken ? ex_branch_target :
                                 ex_jump_taken ? ex_jump_target :
                                 (stall_if ? if_pc : if_pc + 4));
assign debug_pc_changed       = (if_pc != debug_next_pc);

assign debug_gpio_out      = gpio_out_val;
assign debug_gpio_oe       = gpio_oe_val;
assign debug_gpio_in       = gpio_in_val;
assign debug_gpio_if       = gpio_if_val;
assign debug_gpio_interrupt = gpio_interrupt;
assign debug_bus_gpio_we   = bus_gpio_we;
assign debug_bus_gpio_re   = bus_gpio_re;
assign debug_bus_gpio_addr = bus_gpio_addr;
assign debug_bus_gpio_wdata = bus_gpio_wdata;
assign debug_bus_gpio_rdata = bus_gpio_rdata;

assign debug_timer_load     = timer_load_val;
assign debug_timer_count    = timer_count_val;
assign debug_timer_enable   = timer_enable;
assign debug_timer_irq_flag = timer_irq_flag;
assign debug_timer_interrupt = timer_interrupt;

// ==========================================================================
// 仿真监控
// ==========================================================================
integer cycle_counter = 0;
reg [31:0] last_pc = 0;

always @(posedge clk_i) begin
    if (rst_n_i) begin
        cycle_counter <= cycle_counter + 1;
        
        if (if_pc !== last_pc) begin
            last_pc <= if_pc;
            if (cycle_counter < 500) begin
                $display("[%0t] Cycle %0d: PC=%h, Instr=%h", 
                        $time, cycle_counter, if_pc, if_instr);
            end
        end
        
        if (intr_pending) begin
            $display("[%0t] Cycle %0d: *** INTERRUPT PENDING *** cause=%h", 
                    $time, cycle_counter, intr_cause);
        end
        
        if (interrupt_taken_pipe) begin
            $display("[%0t] Cycle %0d: *** INTERRUPT TAKEN *** handler=%h mepc=%h", 
                    $time, cycle_counter, intr_handler_addr, mepc);
        end
        
        if (cycle_counter == 10) begin
            $display("[%0t] CSR Status: mtvec=%h, mie=%h, mstatus=%h", 
                    $time, mtvec, mie, mstatus);
        end
        
        if (csr_we) begin
            $display("[%0t] Cycle %0d: CSR Write: addr=%h data=%h", 
                    $time, cycle_counter, csr_waddr, csr_wdata);
        end
        
        if (bus_uart_we) begin
            $display("[%0t] Cycle %0d: UART WRITE: Addr=%h, Data=%h ('%c')", 
                    $time, cycle_counter, bus_uart_addr, bus_uart_wdata, 
                    bus_uart_wdata[7:0]);
        end
        
        if (stall_if || stall_id || flush_if || flush_id || 
            intr_flush_if || intr_flush_id) begin
            $display("[%0t] Cycle %0d: Pipeline Control: stall_if=%b, stall_id=%b, flush_if=%b, flush_id=%b, intr_flush_if=%b",
                    $time, cycle_counter, stall_if, stall_id, flush_if, flush_id, intr_flush_if);
        end
        
        if (if_instr == 32'h30200073) begin
            $display("[%0t] Cycle %0d: *** MRET INSTRUCTION ***", 
                    $time, cycle_counter);
        end
        
        if (bus_uart_we && bus_uart_wdata[7:0] == 8'h2A) begin
            $display("[%0t] Cycle %0d: *** INTERRUPT HANDLER EXECUTED: sent '*' ***", 
                    $time, cycle_counter);
        end
    end else begin
        cycle_counter <= 0;
        last_pc <= 32'b0;
    end
end

endmodule