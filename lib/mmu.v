`include "defines.vh"

/*
    Memory Management Unit，MMU
    主要是根据输入的物理地址 addr_i 进行段区判断和地址转换，转换成物理地址，从内存中取值    
    通过对输入地址的前 3 位段区信息进行解析，这个模块主要
    处理 MIPS 体系结构中常见的 KSEG0、KSEG1 和其他段地址空间的映射

    -MIPS 架构的地址空间通常被划分为多个段，各段有不同的功能：
    --KSEG0（0x8000_0000 ~ 0x9FFF_FFFF）：直接映射物理地址，无需缓存
    --KSEG1（0xA000_0000 ~ 0xBFFF_FFFF）：直接映射物理地址，无缓存
    --其他段：包括用户段、内核段等，可能需要更复杂的映射
    **************************************************************
*/

module mmu (
    input wire[31:0] addr_i,
    output wire [31:0] addr_o
);
    wire [2:0] addr_head_i, addr_head_o;
    wire kseg0, kseg1, other_seg;

    assign addr_head_i = addr_i[31:29];
    
    assign kseg0 = addr_head_i == 3'b100; // 判断是否属于 KSEG0 段（最高 3 位为 100）
    assign kseg1 = addr_head_i == 3'b101; // 判断是否属于 KSEG1 段（最高 3 位为 101）

    assign other_seg = ~kseg0 & ~kseg1;

    assign addr_head_o = {3{kseg0}}&3'b000 
                       | {3{kseg1}}&3'b000               // KSEG0 和 KSEG1 段地址为000
                       | {3{other_seg}}&addr_head_i;     // 保持不变
    
    assign addr_o = {addr_head_o, addr_i[28:0]};

endmodule