
`timescale 1ns/1ps

module pc_reg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        interrupt_pending,  // 新增中断信号
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);

always @(posedge clk ) begin
    if (!rst_n) begin
        pc <= 32'h0000_0000;
    end 
    else if (!stall || interrupt_pending) begin // 中断时强制更新 PC
        pc <= next_pc;
    end
end

endmodule