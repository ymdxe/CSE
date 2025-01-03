`include "lib/defines.vh"
module hilo_reg (
    input wire rst,
    input wire clk,
    
    // 写端口
    input wire we,
    input wire [31:0] hi_in,
    input wire [31:0] lo_in,

    // 读端口
    output wire [31:0] hi_out,
    output wire [31:0] lo_out
);

    reg [31:0] HI; // HI寄存器
    reg [31:0] LO; // LO寄存器

    always @ (posedge clk) begin
        if (rst) begin
            HI <= 32'b0;
            LO <= 32'b0;
        end
        else if (we) begin
            HI <= hi_in;
            LO <= lo_in;
        end
    end

    assign hi_out = HI;
    assign lo_out = LO;
    // HILO寄存器读取逻辑
    // always @(posedge clk) begin
    //     hi_out <= HI; 
    //     lo_out <= LO; 
    // end


endmodule