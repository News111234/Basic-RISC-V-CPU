// rtl/mem/mem_top_fpga.v  带总线接口的MEM阶段（FPGA专用）
`timescale 1ns/1ps

module mem_top_fpga (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // 来自EX/MEM寄存器
    input  wire [31:0] alu_result_i,   // 内存地址
    input  wire [31:0] wdata_i,        // 写数据
    input  wire        mem_we_i,       // 内存写使能
    input  wire        mem_re_i,       // 内存读使能
    input  wire [2:0]  mem_width_i,    // 访问宽度
    input  wire [31:0] pc_plus4_i,     // 用于WB
    
    input  wire        reg_we_i,       // 寄存器写使能
    input  wire [1:0]  wb_sel_i,       // 写回选择
    input  wire [4:0]  rd_addr_i,      // 目标寄存器地址
    
    // 输出到MEM/WB寄存器
    output wire [31:0] pc_plus4_o,
    output wire        reg_we_o,
    output wire [1:0]  wb_sel_o,
    output wire [4:0]  rd_addr_o,
    
    // 总线接口（连接到bus_arbiter）
    output wire        bus_re_o,
    output wire        bus_we_o,
    output wire [31:0] bus_addr_o,
    output wire [31:0] bus_wdata_o,
    output wire [2:0]  bus_width_o,
    input  wire [31:0] bus_rdata_i,    // 从总线读回的数据
    input  wire        bus_ready_i,    // 总线就绪信号（用于RAM）
    
    // 异常输出（可选）
    output wire        mem_exception_o
);

// 直接传递信号到总线
assign bus_re_o    = mem_re_i;
assign bus_we_o    = mem_we_i;
assign bus_addr_o  = alu_result_i;
assign bus_wdata_o = wdata_i;
assign bus_width_o = mem_width_i;

// 输出到下一阶段
assign pc_plus4_o      = pc_plus4_i;
assign reg_we_o        = reg_we_i;
assign wb_sel_o        = wb_sel_i;
assign rd_addr_o       = rd_addr_i;
assign mem_exception_o = 1'b0;  // 暂不支持异常

endmodule