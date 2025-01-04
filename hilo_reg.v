`include "lib/defines.vh"

module hilo_reg (
    // input wire rst,
    input wire clk,
    
    // 写端口
    input wire hi_we,
    input wire lo_we,
    input wire [31:0] hi_in,
    input wire [31:0] lo_in,

    // 读端口
    output wire [31:0] hi_out,
    output wire [31:0] lo_out
);

    reg [31:0] HI_REG; // HI寄存器
    reg [31:0] LO_REG; // LO寄存器

    always @ (posedge clk) begin
        if (hi_we & lo_we) begin
            HI_REG <= hi_in;
            LO_REG <= lo_in;
        end
        else if (hi_we) begin
            HI_REG <= hi_in;
        end
        else if (lo_we) begin
            LO_REG <= lo_in;
        end
    end

    assign hi_out = HI_REG;
    assign lo_out = LO_REG;


endmodule