`include "lib/defines.vh"

/*
-阻塞赋值：属于顺序执行，即下一条语句执行前，当前语句一定会执行完毕，使用 = 作为赋值符
-非阻塞赋值：属于并行执行语句，即下一条语句的执行和当前语句的执行是同时进行的使用 <= 作为赋值符

-连续赋值：是 Verilog 数据流建模的基本语句，用于对 wire 型变量进行赋值
--assign 为关键词，任何已经声明 wire 变量的连续赋值语句都是以 assign 开头

-Z（高阻态）
-X（不确定状态）：
--需要通过初始化、消除冲突等方式排查和解决。
****************************************************************************************
*/

module IF(
    // 如果没有驱动元件连接到 wire 型变量，缺省值一般为 "Z"，即高阻态
    input wire clk,
    input wire rst,
    input wire [`StallBus-1:0] stall,

    // input wire flush,
    // input wire [31:0] new_pc,

    /*
     用来处理分支指令和跳转指令，内容的值在ID段生成
     如果 br_e = 1，则在流水线的下一周期，将 PC 设置为 br_addr
     如果 br_e = 0，则 PC 按正常的递增逻辑（PC + 4）继续运行
    */
    input wire [`BR_WD-1:0] br_bus, 
    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus, // 33 位

    /*
     主要与指令存储器进行交互
     控制从指令存储器中读取指令，或向寄存器中写入数据
    */
    output wire inst_sram_en,            // 存储器使能信号， 1 表示被使用
    output wire [3:0] inst_sram_wen,     // 指示是否写入数据以及写入哪些字节，一共四位，每一位表示存储器中的一个字节
    output wire [31:0] inst_sram_addr,   // 在取指阶段，将PC值通过此信号传给指令存储器获取指令
    output wire [31:0] inst_sram_wdata   // 写数据内容
);
    reg [31:0] pc_reg; 
    reg ce_reg; // 该值为 1 时，允许取指
    wire [31:0] next_pc;
    wire br_e;
    wire [31:0] br_addr;

    assign {
        br_e,
        br_addr
    } = br_bus;


    always @ (posedge clk) begin
        if (rst) begin
            pc_reg <= 32'hbfbf_fffc;
        end
        else if (stall[0]==`NoStop) begin
            pc_reg <= next_pc;
        end
    end

    always @ (posedge clk) begin
        if (rst) begin // 是否复位
            ce_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop) begin
            ce_reg <= 1'b1;
        end
    end
    // always @(posedge clk) begin
    //     $display("time : %0t, brbus = %h, if_to_id_bus = %h", $time, br_bus, if_to_id_bus);
    // end

    assign next_pc = br_e ? br_addr 
                   : pc_reg + 32'h4;

    
    assign inst_sram_en = ce_reg;
    assign inst_sram_wen = 4'b0;
    assign inst_sram_addr = pc_reg;
    assign inst_sram_wdata = 32'b0;
    assign if_to_id_bus = {
        ce_reg, // 1
        pc_reg  // 32
    };

endmodule