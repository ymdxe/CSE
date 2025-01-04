`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    // TODO (1): 处理数据相关
    output wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,        // 处理数据相关

    // TODO (2): 内存相关, 将有关内存操作传到MEM，对具体的内存操作位数进行处理
    input wire [`LOAD_SRAM_DATA_WD-1:0] load_sram_id_data,
    input wire [`STORE_SRAM_DATA_WD-1:0] store_sram_id_data,
    output wire [`LOAD_SRAM_DATA_WD-1:0] load_sram_ex_data,
    output wire [`STORE_SRAM_DATA_WD-1:0] store_sram_ex_data,

    output wire ex_find_load, // 用于load暂停请求

    // TODO (3): 处理load相关
    output wire [3:0] data_ram_sel, // 选择写入内存的字节

    // TODO (4): hilo
    input wire [`ID_HILO_EX_WD-1:0] id_hilo_ex_bus,
    output wire [`EX_HILO_ID_WD-1:0] ex_hilo_id_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

    reg [`LOAD_SRAM_DATA_WD-1:0] load_sram_id_data_r;
    reg [`STORE_SRAM_DATA_WD-1:0] store_sram_id_data_r;    

    // ? 为什么在上升沿的时候赋值，而不是定义成wire类型在顶层模块进行赋值
    //  如果直接用 wire，信号在组合逻辑的传播过程中可能会产生毛刺（瞬态的高低电平波动），导致下一级电路误触发
    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;    
    reg [`ID_HILO_EX_WD-1:0] id_hilo_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            load_sram_id_data_r <= `LOAD_SRAM_DATA_WD'b0;
            store_sram_id_data_r <= `STORE_SRAM_DATA_WD'b0;
            id_hilo_ex_bus_r <= `ID_HILO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            load_sram_id_data_r <= `LOAD_SRAM_DATA_WD'b0;
            store_sram_id_data_r <= `STORE_SRAM_DATA_WD'b0;
            id_hilo_ex_bus_r <= `ID_HILO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
            load_sram_id_data_r <= load_sram_id_data;
            store_sram_id_data_r <= store_sram_id_data;
            id_hilo_ex_bus_r <= id_hilo_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;

    assign {
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;



    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    // always @ (*) begin
    //    $display("time : %0t, rdata1 = %h, rdata2 = %h", $time, rf_rdata1, rf_rdata2);
    // end


    alu u_alu(
    	.alu_control (alu_op      ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    // ********************************************************************************************
    // TODO (2): 更改sram信息
    wire [3:0] byte_sel;
    // wire [3:0] data_ram_sel; // 选择写入内存的字节

    decoder_2_4 u0_decoder_2_4(
        .in     (ex_result[1:0]   ),
        .out    (byte_sel         )
    );

    wire inst_sb, inst_sh, inst_sw;
    wire inst_lb, inst_lh, inst_lw, inst_lbu, inst_lhu;

    assign {
        inst_sb,
        inst_sh,
        inst_sw
    } = store_sram_id_data_r;

    assign {
        inst_lb,
        inst_lbu,
        inst_lh,
        inst_lhu,
        inst_lw
    } = load_sram_id_data_r;

    // TODO (2): 进行暂停处理
    // assign stall[2] = inst_lb | inst_lh | inst_lw | inst_lbu | inst_lhu ? `Stop : `NoStop;
    assign ex_find_load = (inst_lb | inst_lh | inst_lw | inst_lbu | inst_lhu) ? `Stop : `NoStop;
    // assign ex_find_load = sel_rf_res;

    assign data_ram_sel = inst_sb | inst_lb | inst_lbu ? byte_sel :
                          inst_sh | inst_lh | inst_lhu ?  {{2{byte_sel[2]}},{2{byte_sel[0]}}} :
                          inst_sw | inst_lw ? 4'b1111 : 4'b0000;
    assign data_sram_en = data_ram_en;
    // assign data_sram_wen = {{data_ram_wen}} & data_ram_sel;
    assign data_sram_wen = inst_sw ? 4'b1111:
                    inst_sb & alu_result[1:0]==2'b00 ? 4'b0001:
                    inst_sb & alu_result[1:0]==2'b01 ? 4'b0010:
                    inst_sb & alu_result[1:0]==2'b10 ? 4'b0100:
                    inst_sb & alu_result[1:0]==2'b11 ? 4'b1000:
                    inst_sh & alu_result[1:0]==2'b00 ? 4'b0011:
                    inst_sh & alu_result[1:0]==2'b10 ? 4'b1100:
                    4'b0000;
    assign data_sram_addr = ex_result;
    assign data_sram_wdata = inst_sb ? {4{rf_rdata2[7:0]}} :        // 字节
                             inst_sh ? {2{rf_rdata2[15:0]}} :       // 半字
                             inst_sw ? rf_rdata2 : 32'b0;           // 字

    assign load_sram_ex_data = {
        inst_lb,
        inst_lbu,
        inst_lh,
        inst_lhu,
        inst_lw
    };

    assign store_sram_ex_data = {
        inst_sb,
        inst_sh,
        inst_sw
    };
    // ********************************************************************************************^    
    
    // *****************************************************
    // TODO (1): 连接至 ID
    // 写回寄存器
    // 将是否写回寄存器、写回寄存器地址、写回寄存器数据送到 ID 段
    assign ex_to_id_bus = {
        rf_we,
        rf_waddr,
        ex_result
    }; // 38 位

    // WB_TO_ID part
    // *****************************************************^

    assign data_ram_wen = data_sram_wen;
    // always @ (posedge clk) begin
    //     $display("data_sram_wen = %h", data_sram_wen);
    // end

    // HILO part
    wire inst_mfhi, inst_mflo, inst_mthi, inst_mtlo;
    wire inst_mult, inst_multu, inst_div_u, inst_divu_u;

    wire [31:0] hi_data, lo_data, hi_wdata, lo_wdata;
    wire hi_we, lo_we;


    assign {
        inst_mfhi,
        inst_mflo,
        inst_mthi,
        inst_mtlo,
        inst_mult,
        inst_multu,
        inst_div_u,
        inst_divu_u,
        hi_data,
        lo_data
    } = id_hilo_ex_bus_r;

    assign ex_hilo_id_bus = {
        hi_we,
        lo_we,
        hi_wdata,
        lo_wdata
    };

    assign ex_result =  inst_mfhi ? hi_data :
                        inst_mflo ? lo_data :
                        alu_result;

    assign ex_to_mem_bus = {
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37       是否写回寄存器
        rf_waddr,       // 36:32    写回寄存器地址
        ex_result       // 31:0     
    };
    // MUL part
    wire [63:0] mul_result;
    wire mul_signed; // 有符号乘法标记

    // TODO (0): 增加乘法源操作数
    wire [31:0] mul_opdata1, mul_opdata2;
    assign mul_opdata1 = rf_rdata1;
    assign mul_opdata2 = rf_rdata2;
    assign mul_signed = inst_mult;

    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (mul_signed     ),
        .ina        (mul_opdata1    ), // 乘法源操作数1
        .inb        (mul_opdata2    ), // 乘法源操作数2
        .result     (mul_result     ) // 乘法结果 64bit
    );

    // DIV part
    wire [63:0] div_result;
    wire inst_div, inst_divu;
    wire div_ready_i;
    reg stallreq_for_div;
    assign stallreq_for_ex = stallreq_for_div;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;

    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );

    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // mul_result 和 div_result 可以直接使用

    assign hi_we = inst_mthi | inst_mult | inst_multu | inst_div_u | inst_divu_u;
    assign lo_we = inst_mtlo | inst_mult | inst_multu | inst_div_u | inst_divu_u;

    assign hi_wdata = inst_mthi ? rf_rdata1 :
                      inst_mult | inst_multu ? mul_result[63:32] :
                      inst_div_u | inst_divu_u ? div_result[63:32] :
                      32'b0;
    assign lo_wdata = inst_mtlo ? rf_rdata1 :
                      inst_mult | inst_multu ? mul_result[31:0] :
                      inst_div_u | inst_divu_u ? div_result[31:0] :
                      32'b0;
    
endmodule