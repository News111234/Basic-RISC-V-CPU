// csr_regfile.v - 修改版，支持独立的 mepc、mcause、mstatus 写入
`timescale 1ns/1ps

module csr_regfile (
    input  wire        clk_i,
    input  wire        rst_n_i,
    
    // CSR读端口
    input  wire [11:0] csr_addr_i,
    output reg  [31:0] csr_rdata_o,
    
    // ========== 独立写端口（不再合并）==========
    // 普通 CSR 指令写
    input  wire        csr_inst_we_i,
    input  wire [11:0] csr_inst_waddr_i,
    input  wire [31:0] csr_inst_wdata_i,
    
    // 中断响应写 mepc
    input  wire        csr_mepc_we_i,
    input  wire [31:0] csr_mepc_data_i,
    
    // 中断响应写 mcause
    input  wire        csr_mcause_we_i,
    input  wire [31:0] csr_mcause_data_i,
    
    // 中断响应写 mstatus
    input  wire        csr_mstatus_we_i,
    input  wire [31:0] csr_mstatus_data_i,
    
    // 中断接口
    input  wire        intr_software_i,
    input  wire        intr_timer_i,
    input  wire        intr_external_i,
    
    output reg  [31:0] mtvec_o,
    output reg  [31:0] mepc_o,
    output reg  [31:0] mcause_o,
    output reg  [31:0] mie_o,
    output reg  [31:0] mstatus_o,
    output reg  [31:0] mip_o,
    
    // 调试输出
    output wire [31:0] debug_mstatus_o,
    output wire [31:0] debug_mie_o,
    output wire [31:0] debug_mtvec_o,
    output wire [31:0] debug_mepc_o,
    output wire [31:0] debug_mcause_o
);

// ========== CSR地址定义 ==========
localparam CSR_MSTATUS = 12'h300;
localparam CSR_MISA    = 12'h301;
localparam CSR_MIE     = 12'h304;
localparam CSR_MTVEC   = 12'h305;
localparam CSR_MSCRATCH = 12'h340;
localparam CSR_MEPC    = 12'h341;
localparam CSR_MCAUSE  = 12'h342;
localparam CSR_MTVAL   = 12'h343;
localparam CSR_MIP     = 12'h344;

// ========== CSR寄存器定义 ==========
reg [31:0] mstatus;
reg [31:0] misa;
reg [31:0] mie;
reg [31:0] mtvec;
reg [31:0] mscratch;
reg [31:0] mepc;
reg [31:0] mcause;
reg [31:0] mtval;
reg [31:0] mip;

// 只读寄存器
wire [31:0] mvendorid = 32'h0;
wire [31:0] marchid   = 32'h1;
wire [31:0] mimpid    = 32'h0;
wire [31:0] mhartid   = 32'h0;

// ========== 中断待处理位更新 ==========
wire [31:0] mip_next;
assign mip_next[3]  = intr_software_i;
assign mip_next[7]  = intr_timer_i;
assign mip_next[11] = intr_external_i;
assign mip_next[31:12] = 20'b0;
assign mip_next[2:0] = 3'b0;
assign mip_next[6:4] = 3'b0;
assign mip_next[10:8] = 3'b0;

// ========== 多端口写操作 ==========
always @(posedge clk_i) begin
    if (!rst_n_i) begin
        mstatus   <= 32'h00001800;
        misa      <= 32'h40000100;
        mie       <= 32'b0;
        mtvec     <= 32'b0;
        mscratch  <= 32'b0;
        mepc      <= 32'b0;
        mcause    <= 32'b0;
        mtval     <= 32'b0;
        mip       <= 32'b0;
    end else begin
        // 更新 mip（组合逻辑的wire赋值，但需要存储在寄存器中供读取）
        mip <= mip_next;
        
        // ========== 独立写端口（可同时写入） ==========
        
        // 1. 中断响应写 mepc
        if (csr_mepc_we_i) begin
            mepc <= csr_mepc_data_i;
            $display("[CSR] MEPC write: %h", csr_mepc_data_i);
        end
        
        // 2. 中断响应写 mcause
        if (csr_mcause_we_i) begin
            mcause <= csr_mcause_data_i;
            $display("[CSR] MCAUSE write: %h", csr_mcause_data_i);
        end
        
        // 3. 中断响应写 mstatus
        if (csr_mstatus_we_i) begin
            mstatus <= csr_mstatus_data_i;
            $display("[CSR] MSTATUS write: %h (MIE=%b, MPIE=%b, MPP=%b)", 
                     csr_mstatus_data_i, csr_mstatus_data_i[3], 
                     csr_mstatus_data_i[7], csr_mstatus_data_i[12:11]);
        end
        
        // 4. 普通 CSR 指令写
        if (csr_inst_we_i) begin
            case (csr_inst_waddr_i)
                CSR_MSTATUS: mstatus   <= csr_inst_wdata_i;
                CSR_MIE:     mie       <= csr_inst_wdata_i;
                CSR_MTVEC:   mtvec     <= csr_inst_wdata_i;
                CSR_MSCRATCH: mscratch <= csr_inst_wdata_i;
                CSR_MEPC:    mepc      <= csr_inst_wdata_i;
                CSR_MCAUSE:  mcause    <= csr_inst_wdata_i;
                CSR_MTVAL:   mtval     <= csr_inst_wdata_i;
                default: ;
            endcase
        end
    end
end

// ========== CSR读操作 ==========
always @(*) begin
    case (csr_addr_i)
        CSR_MSTATUS:   csr_rdata_o = mstatus;
        CSR_MISA:      csr_rdata_o = misa;
        CSR_MIE:       csr_rdata_o = mie;
        CSR_MTVEC:     csr_rdata_o = mtvec;
        CSR_MSCRATCH:  csr_rdata_o = mscratch;
        CSR_MEPC:      csr_rdata_o = mepc;
        CSR_MCAUSE:    csr_rdata_o = mcause;
        CSR_MTVAL:     csr_rdata_o = mtval;
        CSR_MIP:       csr_rdata_o = mip;
        default:       csr_rdata_o = 32'b0;
    endcase
end

// ========== 输出连接 ==========
always @(*) begin
    mtvec_o   = mtvec;
    mepc_o    = mepc;
    mcause_o  = mcause;
    mie_o     = mie;
    mstatus_o = mstatus;
    mip_o     = mip;
end

// 调试输出
assign debug_mstatus_o = mstatus;
assign debug_mie_o     = mie;
assign debug_mtvec_o   = mtvec;
assign debug_mepc_o    = mepc;
assign debug_mcause_o  = mcause;

endmodule