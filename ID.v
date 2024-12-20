`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    
    output wire stallreq,                   // 暂时不用

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,      // 得到指令

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,

    // **********************************************
    // TODO(1): 完成EX到ID连线，处理数据相关
    input wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,
    // TODO(1): 完成MEM到ID连线，处理数据相关
    input wire [`MEM_TO_ID_WD-1:0] mem_to_id_bus,
    // **********************************************

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus 
);

    // 接收 IF 段的数据
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r; // 33
    wire [31:0] inst; // 32
    wire [31:0] id_pc; // 32
    wire ce; 

    // 写回寄存器
    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end
    
    assign inst = inst_sram_rdata; // ?????

    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    // rf register file
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus; // 38 位

    wire [5:0] opcode;
    // sa（移位量）,逻辑左移（SLL）、逻辑右移（SRL）和算术右移（SRA）
    wire [4:0] rs,rt,rd,sa; 
    // 功能码
    wire [5:0] func; 
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset; 
    wire [2:0] sel; // 选择信号，用于多路复用器选择输入

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;


    // 模块例化，将括号外的顶层信号通过连线连接到括号内的模块端口
    regfile u_regfile(
    	.clk    (clk    ), 
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),        
        .rdata2 (rdata2 ),          // .rdata 为输出信号，从顶层模块返回到 ID 模块
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );

    // ******************************************************
    // 1` |opcode 6|rs    5|rt    5|rd    5|sa    5|func   6|
    // 2` |opcode 6|rs    5|rt    5|offset                16|
    // 3` |opcode 6|rs    5|rt    5|imm                   16|
    // 4` |opcode 6|base  5|rt    5|rd    5|sa    5|func   6|
    // 5` |opcode 6|base  5|rt    5|imm                   16|
    // 6` |opcode 6|base  5|offset                        16|
    // 7` |opcode 6|code                         20|func   6|
    // 8` |opcode 6|instr_index                           26|
    // ******************************************************


    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];    
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    // ******************************************************
    // TODO(1): 完成EX到ID连线以及MEM到ID连线，处理数据相关
    wire ex_rf_we;
    wire [4:0] ex_rf_waddr;
    wire [31:0] ex_rf_wdata;

    wire mem_rf_we;
    wire [4:0] mem_rf_waddr;
    wire [31:0] mem_rf_wdata;

    wire [31:0] tdata1, tdata2; // 临时数据

    assign {
        ex_rf_we,
        ex_rf_waddr,
        ex_rf_wdata
    } = ex_to_id_bus;

    assign {
        mem_rf_we,
        mem_rf_waddr,
        mem_rf_wdata
    } = mem_to_id_bus;

    
    assign tdata1 = 
                ((ex_rf_we && (ex_rf_waddr == rs)) ? ex_rf_wdata : 32'b0)      | 
                ((mem_rf_we && (mem_rf_waddr == rs)) ? mem_rf_wdata : 32'b0)   |
                ((ex_rf_we && (ex_rf_waddr == rs)) || (mem_rf_we && (mem_rf_waddr == rs)) ? 32'b0 : rdata1);

    assign tdata2 = 
                ((ex_rf_we && (ex_rf_waddr == rt)) ? ex_rf_wdata : 32'b0)      | 
                ((mem_rf_we && (mem_rf_waddr == rt)) ? mem_rf_wdata : 32'b0)   |
                ((ex_rf_we && (ex_rf_waddr == rt)) || (mem_rf_we && (mem_rf_waddr == rt)) ? 32'b0 : rdata2);

    assign rdata1 = tdata1;
    assign rdata2 = tdata2;
    // 处理数据相关
    // ******************************************************


    wire inst_beq;
    // TODO (0): 添加运算指令
    // 算数运算指令
    /*
        当 opcode 为 6'b00_0000 时，func 用于进一步区分具体指令
        addiu: 将rs的值与有符号扩展至32位的立即数 imm 相加，写入rd
        sub:   将rs的值与rt中的值相减写入rd
        slt:   将rs的值与rt中的值进行有符号数比较,rs更小则rd=1，否则rd=0
        sltu:  将rs的值与rt中的值进行无符号数比较
    */
    wire inst_addiu, inst_sub, inst_slt, inst_sltu;
    
    // 逻辑运算指令
    /*
        and: 将rs的值与rt的值进行逻辑与运算，写入rd
        nor: 将rs的值与rt的值进行逻辑或运算，取反，写入rd
        or:  将rs的值与rt的值进行逻辑或运算，写入rd
        xor: 将rs的值与rt的值进行逻辑异或运算，写入rd
    */
    wire inst_and, inst_nor, inst_ori, inst_xor;
    
    // 逻辑移动指令, 参照sa（移位位数）
    /*
        lui:将16位立即数imm写入rt的高16位，rt的低16位置0
    */
    wire inst_sll, inst_srl, inst_sra, inst_lui;


    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    // TODO(0): 添加运算指令
    assign inst_beq     = op_d[6'b00_0100];
    
    // 算术运算指令
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_sub     = op_d[6'b00_0000];
    assign inst_slt     = op_d[6'b00_0000]; 
    assign inst_sltu    = op_d[6'b00_0000]; 

    // 逻辑运算指令
    assign inst_and     = op_d[6'b00_0000];
    assign inst_nor     = op_d[6'b00_0000];
    assign inst_xor     = op_d[6'b00_0000];
    assign inst_ori     = op_d[6'b00_1101];

    // 逻辑移动指令
    /*
        lui:将16位立即数imm写入rt的高16位，rt的低16位置0
    */
    assign inst_sll     = op_d[6'b00_0000];
    assign inst_srl     = op_d[6'b00_0000];
    assign inst_sra     = op_d[6'b00_0000];
    assign inst_lui     = op_d[6'b00_1111];

    
    // ALU 操作数来源
    // **************************************************
    // TODO(?): 修改 ALU 
    // rs to reg1   
    assign sel_alu_src1[0] = inst_ori | inst_addiu;

    // pc to reg1
    assign sel_alu_src1[1] = 1'b0;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = 1'b0;

    
    // rt to reg2
    assign sel_alu_src2[0] = 1'b0;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = 1'b0;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori;
    // *************************************************


    // TODO(0): 添加运算指令
    assign op_add = inst_addiu;
    assign op_sub = inst_sub;
    assign op_slt = inst_slt;
    assign op_sltu = inst_sltu;
    assign op_and = inst_and;
    assign op_nor = inst_nor;
    assign op_or = inst_ori;
    // assign op_or = 1'd1; // debug1
    assign op_xor = inst_xor;
    assign op_sll = inst_sll;
    assign op_srl = inst_srl;
    assign op_sra = inst_sra;   
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = 1'b0;

    // write enable
    assign data_ram_wen = 1'b0;


    // regfile store enable
    assign rf_we = inst_ori | inst_lui | inst_addiu;


    // TODO (?): 寄存器选择问题
    // store in [rd]
    assign sel_rf_dst[0] = 1'b0;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu;
    // store in [31]
    assign sel_rf_dst[2] = 1'b0;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    /*  
        sel_rf_res:
                决定寄存器文件的写回数据来源
            用途:
                在写回阶段选择不同的数据来源：
                0：写回 ALU 的计算结果。
                1：写回从数据存储器加载的数据（如 LW 指令）
    */
    assign sel_rf_res = 1'b0; 


    // 将data数据进行修改，防止出现X态
    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80 ALU Source 1 Selector
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rdata1,         // 63:32  
        rdata2          // 31:0
    };


    wire br_e;              // 分支使能信号，表示是否发生分支跳转
    wire [31:0] br_addr;    // 分支跳转的目标地址
    wire rs_eq_rt;          // rs 是否 == rt 
    wire rs_ge_z;           // rs 是否 >= 0
    wire rs_gt_z;           // rs 是否  > 0
    wire rs_le_z;           // rs 是否 <= 0
    wire rs_lt_z;           // rs 是否  < 0
    wire [31:0] pc_plus_4;  // 当前指令地址+4（即下一条指令的地址）


    assign pc_plus_4 = id_pc + 32'h4;

    assign rs_eq_rt = (rdata1 == rdata2);

    assign br_e = inst_beq & rs_eq_rt;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
    


endmodule