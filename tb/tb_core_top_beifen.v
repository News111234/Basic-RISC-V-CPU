// tb/tb_core_top.v (修改版)
`timescale 1ns/1ps

module tb_core_top;

// 时钟和复位
reg clk;
reg rst_n;

// UART输出
wire uart_tx;

// 调试信号
wire [31:0] debug_if_pc;
wire [31:0] debug_if_instr;
wire [31:0] debug_id_rs1_data;
wire [31:0] debug_id_rs2_data;
wire [31:0] debug_ex_alu_result;
wire [31:0] debug_ex_mem_addr;
wire [31:0] debug_ex_mem_wdata;
wire        debug_ex_mem_we;
wire [2:0]  debug_ex_mem_width;
wire        debug_mem_bus_we;
wire [31:0] debug_mem_bus_addr;
wire [31:0] debug_mem_bus_wdata;
wire [31:0] debug_mem_bus_rdata;
wire        debug_bus_uart_we;
wire [31:0] debug_bus_uart_addr;
wire [31:0] debug_bus_uart_wdata;
//寄存器





wire [31:0] debug_x0;
wire [31:0] debug_x1;
wire [31:0] debug_x2;
wire [31:0] debug_x3;
wire [31:0] debug_x4;
wire [31:0] debug_x5_t0;
wire [31:0] debug_x6_t1;
wire [31:0] debug_x7_t2;
wire [31:0] debug_x8_t3;
wire [31:0] debug_x9_t4;
wire [31:0] debug_x10_a0;
wire [31:0] debug_x11_a1;
wire [31:0] debug_x12_a2;
wire [31:0] debug_x13;
wire [31:0] debug_x14;
wire [4:0]  debug_id_rs1_addr;
wire [4:0]  debug_id_rs2_addr;

// UART调试信号
wire [2:0]  debug_uart_state;
wire [31:0] debug_uart_baud_cnt;
wire [3:0]  debug_uart_bit_cnt;
wire [7:0]  debug_uart_shift_reg;

// FIFO调试信号
wire [7:0]  debug_uart_fifo_data0;
wire [7:0]  debug_uart_fifo_data1;
wire [7:0]  debug_uart_fifo_data2;
wire [7:0]  debug_uart_fifo_data3;
wire [7:0]  debug_uart_fifo_data4;
wire [7:0]  debug_uart_fifo_data5;
wire [7:0]  debug_uart_fifo_data6;
wire [7:0]  debug_uart_fifo_data7;
wire [7:0]  debug_uart_fifo_data8;
wire [7:0]  debug_uart_fifo_data9;
wire [7:0]  debug_uart_fifo_data10;
wire [7:0]  debug_uart_fifo_data11;
wire [7:0]  debug_uart_fifo_data12;
wire [7:0]  debug_uart_fifo_data13;
wire [7:0]  debug_uart_fifo_data14;
wire [7:0]  debug_uart_fifo_data15;

wire [3:0]  debug_uart_wr_ptr;
wire [3:0]  debug_uart_rd_ptr;
wire [4:0]  debug_uart_fifo_count;
wire        debug_uart_fifo_full;
wire        debug_uart_fifo_empty;
wire        debug_uart_fifo_we;
wire        debug_uart_fifo_re;

// 新增：CSR/中断调试信号
wire [31:0] debug_mstatus;
wire [31:0] debug_mie;
wire [31:0] debug_mtvec;
wire [31:0] debug_mepc;
wire [31:0] debug_mcause;
wire [31:0] debug_mip;
wire        debug_interrupt_pending;
wire        debug_interrupt_taken;

// 内部监控变量
integer last_pc;
reg [7:0] uart_char_count = 0;
reg [7:0] expected_chars[0:12];
reg simulation_complete = 0;

// 测试控制
reg [31:0] test_phase = 0;
reg        test_interrupt = 0;
reg [31:0] interrupt_count = 0;
//中断调试信号
wire [31:0] debug_csr_inst_pc;
wire        debug_csr_inst_valid;
wire [31:0] debug_csr_inst_instr;
wire        debug_csr_write;
wire [11:0] debug_csr_write_addr;
wire [31:0] debug_csr_write_data;
wire [31:0] debug_t0_value;
wire [31:0] debug_instr_4;
wire [31:0] debug_instr_5;
wire [31:0] debug_instr_6;
wire [31:0] debug_instr_7;
//2
// ID阶段
wire        debug_id_csr_inst;
wire [11:0] debug_id_csr_addr;
wire [2:0]  debug_id_csr_op;
wire [4:0]  debug_id_csr_zimm;

// ID/EX阶段
wire        debug_ex_csr_inst;
wire [11:0] debug_ex_csr_addr;
wire [2:0]  debug_ex_csr_op;
wire [4:0]  debug_ex_csr_zimm;

// CSR指令处理模块
wire [2:0]  debug_csr_inst_op;
wire [11:0] debug_csr_inst_addr;
wire [4:0]  debug_csr_inst_rs1;
wire [31:0] debug_csr_inst_rs1_data;
wire [31:0] debug_csr_inst_imm;
wire [31:0] debug_csr_inst_rdata;
wire        debug_csr_inst_we;
wire [11:0] debug_csr_inst_waddr;
wire [31:0] debug_csr_inst_wdata;
wire [31:0] debug_csr_inst_result;

wire        debug_timer_irq;// 定时器中断信号
wire [6:0]  debug_timer_counter; // 定时器计数器值
// 最终CSR写信号
wire        debug_final_csr_we;
wire [11:0] debug_final_csr_waddr;
wire [31:0] debug_final_csr_wdata;

// 中断处理单元的输出
wire        debug_intr_mepc_we;
wire [31:0] debug_intr_mepc_data;
wire        debug_intr_mcause_we;
wire [31:0] debug_intr_mcause_data;
wire        debug_intr_mstatus_we;
wire [31:0] debug_intr_mstatus_data;

wire [1:0]  debug_interrupt_hold_cnt;
wire        debug_interrupt_accepted;
wire        debug_interrupt_condition;
wire [4:0]  debug_interrupt_condition_bits;
wire debug_interrupt_taken_pipe;
// CSR寄存器文件接口
wire [31:0] debug_csr_reg_rdata;
wire        debug_csr_reg_we;
wire [11:0] debug_csr_reg_waddr;
wire [31:0] debug_csr_reg_wdata;

wire [31:0] debug_ex_csr_result;
wire [31:0] debug_ex_mem_csr_result;

//前递调试信号
 wire [1:0]  debug_forwardA;
wire [1:0]  debug_forwardB;
wire [4:0]  debug_id_ex_rs1;
wire [4:0]  debug_id_ex_rs2;
wire [4:0]  debug_ex_mem_rd;
wire        debug_ex_mem_reg_we;
wire [4:0]  debug_mem_wb_rd;
wire        debug_mem_wb_reg_we;
wire [31:0] debug_ex_mem_alu_result;
wire [31:0] debug_mem_forward_data;
wire [31:0] debug_op1_selected;
wire [31:0] debug_op2_selected;
wire [4:0]  debug_rs1_addr_id;
wire [4:0]  debug_rs2_addr_id;
wire [31:0] debug_rs1_data_id;
wire [31:0] debug_rs2_data_id;

//id/ex阶段的flush和stall信号
wire        debug_id_ex_flush;
wire        debug_id_ex_intr_flush;
wire        debug_id_ex_stall;


// ========== 新增：流水线控制调试信号 ==========
// Hazard Unit 调试信号
wire        debug_stall_if;           // IF阶段停滞
wire        debug_stall_id;           // ID阶段停滞
wire        debug_flush_if;           // IF阶段冲刷
wire        debug_flush_id;           // ID阶段冲刷
wire        debug_load_use_hazard;    // 加载-使用冒险
wire        debug_control_hazard;     // 控制冒险

// Hazard Unit 输入调试
wire [4:0]  debug_hazard_rs1_addr;    // ID阶段rs1
wire [4:0]  debug_hazard_rs2_addr;    // ID阶段rs2
wire [4:0]  debug_hazard_ex_rd_addr;  // EX阶段目标寄存器
wire        debug_hazard_ex_reg_we;   // EX阶段写使能
wire        debug_hazard_ex_mem_re;   // EX阶段是否是load
wire        debug_ex_mem_mem_re;

// Forwarding Unit 调试信号

wire [4:0]  debug_fwd_ex_mem_rd;      // EX/MEM阶段目标寄存器
wire        debug_fwd_ex_mem_reg_we;  // EX/MEM阶段写使能
wire [4:0]  debug_fwd_mem_wb_rd;      // MEM/WB阶段目标寄存器
wire        debug_fwd_mem_wb_reg_we;  // MEM/WB阶段写使能

// EX阶段操作数调试

wire [31:0] debug_ex_rs1_original;    // 原始rs1数据
wire [31:0] debug_ex_rs2_original;    // 原始rs2数据

// PC变化调试
wire [31:0] debug_next_pc;            // 下一个PC
wire        debug_pc_changed;         // PC是否变化

//GPIO和定时器调试信号
wire [31:0] debug_gpio_out;
wire [31:0] debug_gpio_oe;
wire [31:0] debug_gpio_in;
wire [31:0] debug_gpio_if;
wire        debug_gpio_interrupt;

 wire        debug_bus_gpio_we;
 wire        debug_bus_gpio_re;
 wire [31:0] debug_bus_gpio_addr;
 wire [31:0] debug_bus_gpio_wdata;
  wire [31:0] debug_bus_gpio_rdata;

wire [31:0] debug_timer_load;
wire [31:0] debug_timer_count;
wire        debug_timer_enable;
wire        debug_timer_irq_flag;
wire        debug_timer_interrupt;

// 实例化被测设计
core_top_sim uut (
    .clk_i                (clk),
    .rst_n_i              (rst_n),
    .uart_tx_o            (uart_tx),
    
    // 调试输出
    .debug_if_pc          (debug_if_pc),
    .debug_if_instr       (debug_if_instr),
    .debug_id_rs1_data    (debug_id_rs1_data),
    .debug_id_rs2_data    (debug_id_rs2_data),
    .debug_ex_alu_result  (debug_ex_alu_result),
    .debug_ex_mem_addr    (debug_ex_mem_addr),
    .debug_ex_mem_wdata   (debug_ex_mem_wdata),
    .debug_ex_mem_we      (debug_ex_mem_we),
    .debug_ex_mem_width   (debug_ex_mem_width),
    .debug_mem_bus_we     (debug_mem_bus_we),
    .debug_mem_bus_addr   (debug_mem_bus_addr),
    .debug_mem_bus_wdata  (debug_mem_bus_wdata),
    .debug_mem_bus_rdata (debug_mem_bus_rdata),
    .debug_bus_uart_we    (debug_bus_uart_we),
    .debug_bus_uart_addr  (debug_bus_uart_addr),
    .debug_bus_uart_wdata (debug_bus_uart_wdata),
    //寄存器




    .debug_x0             (debug_x0),
    .debug_x1             (debug_x1),
    .debug_x2             (debug_x2),
    .debug_x3             (debug_x3),
    .debug_x4             (debug_x4),
    .debug_x5_t0          (debug_x5_t0),
    .debug_x6_t1          (debug_x6_t1),
    .debug_x7_t2          (debug_x7_t2),
    .debug_x8_t3          (debug_x8_t3),
    .debug_x9_t4          (debug_x9_t4),
    .debug_x10_a0         (debug_x10_a0),
    .debug_x11_a1         (debug_x11_a1),
    .debug_x12_a2         (debug_x12_a2),
    .debug_x13            (debug_x13),
    .debug_x14            (debug_x14),
    
    .debug_id_rs1_addr    (debug_id_rs1_addr),
    .debug_id_rs2_addr    (debug_id_rs2_addr),

    // UART调试连接
    .debug_uart_state     (debug_uart_state),
    .debug_uart_baud_cnt  (debug_uart_baud_cnt),
    .debug_uart_bit_cnt   (debug_uart_bit_cnt),
    .debug_uart_shift_reg (debug_uart_shift_reg),

    // FIFO调试信号
    .debug_uart_fifo_data0 (debug_uart_fifo_data0),
    .debug_uart_fifo_data1 (debug_uart_fifo_data1),
    .debug_uart_fifo_data2 (debug_uart_fifo_data2),
    .debug_uart_fifo_data3 (debug_uart_fifo_data3),
    .debug_uart_fifo_data4 (debug_uart_fifo_data4),
    .debug_uart_fifo_data5 (debug_uart_fifo_data5),
    .debug_uart_fifo_data6 (debug_uart_fifo_data6),
    .debug_uart_fifo_data7 (debug_uart_fifo_data7),
    .debug_uart_fifo_data8 (debug_uart_fifo_data8),
    .debug_uart_fifo_data9 (debug_uart_fifo_data9),
    .debug_uart_fifo_data10 (debug_uart_fifo_data10),
    .debug_uart_fifo_data11 (debug_uart_fifo_data11),
    .debug_uart_fifo_data12 (debug_uart_fifo_data12),
    .debug_uart_fifo_data13 (debug_uart_fifo_data13),
    .debug_uart_fifo_data14 (debug_uart_fifo_data14),
    .debug_uart_fifo_data15 (debug_uart_fifo_data15),

    .debug_uart_wr_ptr     (debug_uart_wr_ptr),
    .debug_uart_rd_ptr     (debug_uart_rd_ptr),
    .debug_uart_fifo_count (debug_uart_fifo_count),
    .debug_uart_fifo_full  (debug_uart_fifo_full),
    .debug_uart_fifo_empty (debug_uart_fifo_empty),
    .debug_uart_fifo_we    (debug_uart_fifo_we),
    .debug_uart_fifo_re    (debug_uart_fifo_re),
    
    // CSR/中断调试
    .debug_mstatus         (debug_mstatus),
    .debug_mie             (debug_mie),
    .debug_mtvec           (debug_mtvec),
    .debug_mepc            (debug_mepc),
    .debug_mcause          (debug_mcause),
    .debug_mip             (debug_mip),
    .debug_interrupt_pending (debug_interrupt_pending),
    .debug_interrupt_taken (debug_interrupt_taken),
    //中断调试信号
      .debug_csr_inst_pc     (debug_csr_inst_pc),
    .debug_csr_inst_valid  (debug_csr_inst_valid),
    .debug_csr_inst_instr  (debug_csr_inst_instr),
    .debug_csr_write       (debug_csr_write),
    .debug_csr_write_addr  (debug_csr_write_addr),
    .debug_csr_write_data  (debug_csr_write_data),
    .debug_t0_value        (debug_t0_value),
    .debug_instr_4         (debug_instr_4),
    .debug_instr_5         (debug_instr_5),
    .debug_instr_6         (debug_instr_6),
    .debug_instr_7         (debug_instr_7),
//中断2
    .debug_id_csr_inst      (debug_id_csr_inst),
    .debug_id_csr_addr      (debug_id_csr_addr),
    .debug_id_csr_op        (debug_id_csr_op),
    .debug_id_csr_zimm      (debug_id_csr_zimm),
    
    .debug_ex_csr_inst      (debug_ex_csr_inst),
    .debug_ex_csr_addr      (debug_ex_csr_addr),
    .debug_ex_csr_op        (debug_ex_csr_op),
    .debug_ex_csr_zimm      (debug_ex_csr_zimm),
    

    .debug_csr_inst_op      (debug_csr_inst_op),
    .debug_csr_inst_addr    (debug_csr_inst_addr),
    .debug_csr_inst_rs1     (debug_csr_inst_rs1),
    .debug_csr_inst_rs1_data(debug_csr_inst_rs1_data),
    .debug_csr_inst_imm     (debug_csr_inst_imm),
    .debug_csr_inst_rdata   (debug_csr_inst_rdata),
    .debug_csr_inst_we      (debug_csr_inst_we),
    .debug_csr_inst_waddr   (debug_csr_inst_waddr),
    .debug_csr_inst_wdata   (debug_csr_inst_wdata),
    .debug_csr_inst_result  (debug_csr_inst_result),
    
    .debug_final_csr_we     (debug_final_csr_we),
    .debug_final_csr_waddr  (debug_final_csr_waddr),
    .debug_final_csr_wdata  (debug_final_csr_wdata),
    
    .debug_intr_mepc_we     (debug_intr_mepc_we),
    .debug_intr_mepc_data   (debug_intr_mepc_data),
    .debug_intr_mcause_we   (debug_intr_mcause_we),
    .debug_intr_mcause_data (debug_intr_mcause_data),
    .debug_intr_mstatus_we  (debug_intr_mstatus_we),
    .debug_intr_mstatus_data(debug_intr_mstatus_data),

        // 新增：interrupt_pipeline 调试信号
    .debug_interrupt_accepted     (debug_interrupt_accepted),
    .debug_interrupt_hold_cnt     (debug_interrupt_hold_cnt),
    .debug_interrupt_condition    (debug_interrupt_condition),
    .debug_interrupt_condition_bits(debug_interrupt_condition_bits),
    .debug_interrupt_taken_pipe    (debug_interrupt_taken_pipe),

    .debug_csr_reg_rdata    (debug_csr_reg_rdata),
    .debug_csr_reg_we       (debug_csr_reg_we),
    .debug_csr_reg_waddr    (debug_csr_reg_waddr),
    .debug_csr_reg_wdata    (debug_csr_reg_wdata),
    .debug_ex_csr_result     (debug_ex_csr_result),
    .debug_ex_mem_csr_result (debug_ex_mem_csr_result),
    .debug_timer_irq            (debug_timer_irq),
    .debug_timer_counter       (debug_timer_counter),

        .debug_forwardA         (debug_forwardA),
    .debug_forwardB         (debug_forwardB),
    .debug_id_ex_rs1        (debug_id_ex_rs1),
    .debug_id_ex_rs2        (debug_id_ex_rs2),
    .debug_ex_mem_rd        (debug_ex_mem_rd),
    .debug_ex_mem_reg_we    (debug_ex_mem_reg_we),
    .debug_ex_mem_mem_re    (debug_ex_mem_mem_re),
    .debug_mem_wb_rd        (debug_mem_wb_rd),
    .debug_mem_wb_reg_we    (debug_mem_wb_reg_we),
   
    .debug_ex_mem_alu_result(debug_ex_mem_alu_result),
    .debug_mem_forward_data (debug_mem_forward_data),
    .debug_op1_selected     (debug_op1_selected),
    .debug_op2_selected     (debug_op2_selected),
    .debug_rs1_addr_id      (debug_rs1_addr_id),
    .debug_rs2_addr_id      (debug_rs2_addr_id),
    .debug_rs1_data_id      (debug_rs1_data_id),
    .debug_rs2_data_id      (debug_rs2_data_id),
    .debug_id_ex_flush         (debug_id_ex_flush),
    .debug_id_ex_intr_flush    (debug_id_ex_intr_flush),
    .debug_id_ex_stall         (debug_id_ex_stall),

     // ========== 新增：流水线控制调试信号连接 ==========
    .debug_stall_if         (debug_stall_if),
    .debug_stall_id         (debug_stall_id),
    .debug_flush_if         (debug_flush_if),
    .debug_flush_id         (debug_flush_id),
    .debug_load_use_hazard  (debug_load_use_hazard),
    .debug_control_hazard   (debug_control_hazard),
    .debug_hazard_rs1_addr  (debug_hazard_rs1_addr),
    .debug_hazard_rs2_addr  (debug_hazard_rs2_addr),
    .debug_hazard_ex_rd_addr(debug_hazard_ex_rd_addr),
    .debug_hazard_ex_reg_we (debug_hazard_ex_reg_we),
    .debug_hazard_ex_mem_re (debug_hazard_ex_mem_re),
    .debug_fwd_ex_mem_rd    (debug_fwd_ex_mem_rd),
    .debug_fwd_ex_mem_reg_we(debug_fwd_ex_mem_reg_we),
    .debug_fwd_mem_wb_rd    (debug_fwd_mem_wb_rd),
    .debug_fwd_mem_wb_reg_we(debug_fwd_mem_wb_reg_we),
    .debug_ex_rs1_original  (debug_ex_rs1_original),
    .debug_ex_rs2_original  (debug_ex_rs2_original),
    .debug_next_pc          (debug_next_pc),
    .debug_pc_changed       (debug_pc_changed),

    // GPIO 调试
.debug_gpio_out      (debug_gpio_out),
.debug_gpio_oe       (debug_gpio_oe),
.debug_gpio_in       (debug_gpio_in),
.debug_gpio_if       (debug_gpio_if),
.debug_gpio_interrupt(debug_gpio_interrupt),

.debug_bus_gpio_we   (debug_bus_gpio_we),
.debug_bus_gpio_re   (debug_bus_gpio_re),
.debug_bus_gpio_addr (debug_bus_gpio_addr),
.debug_bus_gpio_wdata(debug_bus_gpio_wdata),
.debug_bus_gpio_rdata(debug_bus_gpio_rdata),

// Timer 调试
.debug_timer_load    (debug_timer_load),
.debug_timer_count   (debug_timer_count),
.debug_timer_enable  (debug_timer_enable),
.debug_timer_irq_flag(debug_timer_irq_flag),
.debug_timer_interrupt(debug_timer_interrupt)



);

// 时钟生成
initial begin
    clk = 0;
    forever #2.5 clk = ~clk; // 200MHz,5ns一个周期
end

// 复位生成
initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
    $display("[%0t] Reset released", $time);

    // 初始化期望的字符序列
    expected_chars[0] = "H";
    expected_chars[1] = "e";
    expected_chars[2] = "l";
    expected_chars[3] = "l";
    expected_chars[4] = "o";
    expected_chars[5] = " ";
    expected_chars[6] = "W";
    expected_chars[7] = "o";
    expected_chars[8] = "r";
    expected_chars[9] = "l";
    expected_chars[10] = "d";
    expected_chars[11] = "!";
    expected_chars[12] = "\n";
end



// 自动结束仿真
initial begin
    #10000000;  // 10ms超时
   
    $finish;
end

// ==========================================================================

// ==========================================================================



endmodule