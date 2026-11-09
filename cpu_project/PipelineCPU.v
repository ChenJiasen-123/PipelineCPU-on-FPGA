module PipelineCPU (
    input         clk,
    input         rst_n,
    input         cpu_step,
    input         cpu_halt,
    input         cpu_dbg_reset,

    input  [4:0]  dbg_reg_addr,
    output [31:0] dbg_reg_data,

    input         inst_dbg_en,
    input         inst_wr_en,
    input  [31:0] inst_dbg_addr,
    input  [31:0] inst_wr_data,
    output [31:0] inst_rd_data,

    input         dmem_dbg_en,
    input         dmem_wr_en,
    input  [31:0] dmem_dbg_addr,
    input  [31:0] dmem_wr_data,
    output [31:0] dmem_rd_data,

    output        dmem_we,
    output [31:0] dmem_addr,
    output [31:0] dmem_din,
    input  [31:0] dmem_rdata,

    output [31:0] dbg_pc,
    output        ecall_halt
);

    // 复位与外部 halt 信号合并
    wire rst_combined = rst_n & ~cpu_dbg_reset;

    // ========== IF 阶段 ==========
    wire [31:0] if_inst;
    wire [31:0] if_pc;
    wire        pc_redirect;
    wire [31:0] pc_target;

    // 流水线寄存器：IF/ID
    reg [31:0] if_id_inst;
    reg [31:0] if_id_pc;

    // IFetch 负责取指和指令调试访问
    IFetch ifetch_inst (
        .clk          (clk),
        .rst_n        (rst_combined),
        .pc_redirect  (pc_redirect),
        .pc_target    (pc_target),
        .cpu_halt     (cpu_halt | load_use_stall),
        .inst_dbg_en  (inst_dbg_en),
        .inst_wr_en   (inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data (inst_wr_data),
        .inst_rd_data (inst_rd_data),
        .pc_current   (if_pc),
        .inst         (if_inst)
    );

    // ID 阶段信号
    wire [31:0] id_imm;
    wire [31:0] id_reg_read1;
    wire [31:0] id_reg_read2;
    wire [31:0] id_inst = if_id_inst;
    wire [4:0]  id_rs1 = id_inst[19:15];
    wire [4:0]  id_rs2 = id_inst[24:20];
    wire [4:0]  id_rd  = id_inst[11:7];
    wire [2:0]  id_funct3 = id_inst[14:12];

    wire        id_branch;
    wire        id_aluSrc;
    wire        id_memRead;
    wire        id_memWrite;
    wire        id_memToReg;
    wire        id_regWrite;
    wire [1:0]  id_ALUOp;
    wire        id_funct7_5;
    wire        id_countones;
    wire        id_rdcycle;
    wire        id_jal;
    wire        id_jalr;
    wire        id_ecall;

    control ctrl_id (
        .inst      (id_inst),
        .branch    (id_branch),
        .aluSrc    (id_aluSrc),
        .memRead   (id_memRead),
        .memWrite  (id_memWrite),
        .memToReg  (id_memToReg),
        .regWrite  (id_regWrite),
        .ALUOp     (id_ALUOp),
        .funct7_5  (id_funct7_5),
        .count_ones(id_countones),
        .rdcycle   (id_rdcycle),
        .jal       (id_jal),
        .jalr      (id_jalr),
        .ecall     (id_ecall)
    );

    imm_process imm_id (
        .m_code(id_inst),
        .imm(id_imm)
    );

    register regfile_inst (
        .clk       (clk),
        .rst_n     (rst_combined),
        .writeReg  (mem_wb_regWrite),
        .rs1       (id_rs1),
        .rs2       (id_rs2),
        .rd        (mem_wb_rd),
        .writeData (mem_wb_write_data),
        .readData1 (id_reg_read1),
        .readData2 (id_reg_read2),
        .dbg_reg_addr(dbg_reg_addr),
        .dbg_reg_data(dbg_reg_data)
    );

    // IF/ID -> ID/EX 流水线寄存器
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_imm;
    reg [31:0] id_ex_reg_data1;
    reg [31:0] id_ex_reg_data2;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg [6:0]  id_ex_opcode;
    reg [1:0]  id_ex_ALUOp;
    reg        id_ex_branch;
    reg        id_ex_aluSrc;
    reg        id_ex_memRead;
    reg        id_ex_memWrite;
    reg        id_ex_memToReg;
    reg        id_ex_regWrite;
    reg        id_ex_funct7_5;
    reg        id_ex_countones;
    reg        id_ex_rdcycle;
    reg        id_ex_jal;
    reg        id_ex_jalr;
    reg        id_ex_is_lui;
    reg        id_ex_is_auipc;
    reg        id_ex_ecall;

    // 在 ID 阶段判断 LUI 和 AUIPC
    wire id_is_lui = (id_inst[6:0] == 7'b0110111);
    wire id_is_auipc = (id_inst[6:0] == 7'b0010111);

    // EX/MEM 流水线寄存器
    reg        ex_mem_regWrite;
    reg        ex_mem_memRead;
    reg        ex_mem_memWrite;
    reg        ex_mem_memToReg;
    reg        ex_mem_is_jal;
    reg        ex_mem_is_jalr;
    reg        ex_mem_is_lui;
    reg        ex_mem_is_auipc;
    reg        ex_mem_ecall;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_imm;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_value;
    reg [4:0]  ex_mem_rd;

    // MEM/WB 流水线寄存器
    reg        mem_wb_regWrite;
    reg        mem_wb_memToReg;
    reg        mem_wb_is_jal;
    reg        mem_wb_is_jalr;
    reg        mem_wb_is_lui;
    reg        mem_wb_is_auipc;
    reg        mem_wb_ecall;
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_imm;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg [31:0] cycle_count = 32'b0;

    // 数据冒险 Forwarding 控制
    wire ex_mem_forwardA = ex_mem_regWrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1) && !ex_mem_memToReg;
    wire ex_mem_forwardB = ex_mem_regWrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2) && !ex_mem_memToReg;
    wire mem_wb_forwardA = mem_wb_regWrite && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1) && !(ex_mem_forwardA);
    wire mem_wb_forwardB = mem_wb_regWrite && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2) && !(ex_mem_forwardB);

    wire [31:0] ex_src1 = ex_mem_forwardA ? ex_mem_alu_result :
                          mem_wb_forwardA ? mem_wb_write_data : id_ex_reg_data1;
    wire [31:0] ex_src2 = ex_mem_forwardB ? ex_mem_alu_result :
                          mem_wb_forwardB ? mem_wb_write_data : id_ex_reg_data2;

    wire [31:0] ex_op2 = id_ex_aluSrc ? id_ex_imm : ex_src2;

    // ALU 计算
    wire [31:0] ex_alu_result;
    alu alu_ex (
        .op1        (ex_src1),
        .op2        (ex_op2),
        .alu_op     (id_ex_ALUOp),
        .funct3     (id_ex_funct3),
        .funct7_5   (id_ex_funct7_5),
        .count_ones (id_ex_countones),
        .res        (ex_alu_result)
    );

    // LUI/AUIPC 的真实写回值：EX 阶段直接生成，保证后续转发正确
    wire [31:0] ex_special_result = id_ex_is_lui   ? id_ex_imm :
                                    id_ex_is_auipc ? (id_ex_pc + id_ex_imm) :
                                    id_ex_rdcycle  ? cycle_count :
                                                      ex_alu_result;

    // Branch/JAL/JALR 目标计算
    wire [31:0] ex_pc_plus_imm = id_ex_pc + id_ex_imm;
    wire [31:0] ex_jalr_target = {ex_alu_result[31:1], 1'b0};
    wire branch_eq = (ex_src1 == ex_src2);
    wire branch_lt_signed = ($signed(ex_src1) < $signed(ex_src2));
    wire branch_ge_signed = ($signed(ex_src1) >= $signed(ex_src2));
    wire branch_lt_unsigned = (ex_src1 < ex_src2);
    wire branch_ge_unsigned = (ex_src1 >= ex_src2);

    wire ex_branch_taken = id_ex_branch && (
        ((id_ex_funct3 == 3'b000) && branch_eq) ||
        ((id_ex_funct3 == 3'b001) && !branch_eq) ||
        ((id_ex_funct3 == 3'b100) && branch_lt_signed) ||
        ((id_ex_funct3 == 3'b101) && branch_ge_signed) ||
        ((id_ex_funct3 == 3'b110) && branch_lt_unsigned) ||
        ((id_ex_funct3 == 3'b111) && branch_ge_unsigned)
    );

    assign pc_redirect = id_ex_jal | id_ex_jalr | ex_branch_taken;
    assign pc_target   = id_ex_jalr ? ex_jalr_target : ex_pc_plus_imm;
    wire control_hazard_flush = pc_redirect;

    // Load-use 冒险检测：如果当前指令需要的寄存器刚从 load 来，那么插入 stall
    wire load_use_stall = id_ex_memRead && (
        ((id_ex_rd == id_rs1) && (id_rs1 != 5'b0)) ||
        ((id_ex_rd == id_rs2) && (id_rs2 != 5'b0))
    );

    // 当前流水线中是否存在 ecall 指令
    assign ecall_halt = id_ex_ecall || ex_mem_ecall || mem_wb_ecall;

    // EX/MEM 阶段更新
    always @(posedge clk or negedge rst_combined) begin
        if (!rst_combined) begin
            ex_mem_regWrite <= 1'b0;
            ex_mem_memRead  <= 1'b0;
            ex_mem_memWrite <= 1'b0;
            ex_mem_memToReg <= 1'b0;
            ex_mem_is_jal   <= 1'b0;
            ex_mem_is_jalr  <= 1'b0;
            ex_mem_is_lui   <= 1'b0;
            ex_mem_is_auipc <= 1'b0;
            ex_mem_pc       <= 32'b0;
            ex_mem_imm      <= 32'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_value <= 32'b0;
            ex_mem_rd       <= 5'b0;
        end else if (cpu_halt) begin
            // 外部 halt 时保持流水线状态
            ex_mem_regWrite <= ex_mem_regWrite;
            ex_mem_memRead  <= ex_mem_memRead;
            ex_mem_memWrite <= ex_mem_memWrite;
            ex_mem_memToReg <= ex_mem_memToReg;
            ex_mem_is_jal   <= ex_mem_is_jal;
            ex_mem_is_jalr  <= ex_mem_is_jalr;
            ex_mem_is_lui   <= ex_mem_is_lui;
            ex_mem_is_auipc <= ex_mem_is_auipc;
            ex_mem_pc       <= ex_mem_pc;
            ex_mem_imm      <= ex_mem_imm;
            ex_mem_alu_result <= ex_mem_alu_result;
            ex_mem_store_value <= ex_mem_store_value;
            ex_mem_rd       <= ex_mem_rd;
        end else begin
            ex_mem_regWrite <= id_ex_regWrite;
            ex_mem_memRead  <= id_ex_memRead;
            ex_mem_memWrite <= id_ex_memWrite;
            ex_mem_memToReg <= id_ex_memToReg;
            ex_mem_is_jal   <= id_ex_jal;
            ex_mem_is_jalr  <= id_ex_jalr;
            ex_mem_is_lui   <= id_ex_is_lui;
            ex_mem_is_auipc <= id_ex_is_auipc;
            ex_mem_ecall    <= id_ex_ecall;
            ex_mem_pc       <= id_ex_pc;
            ex_mem_imm      <= id_ex_imm;
            ex_mem_alu_result <= ex_special_result;
            ex_mem_store_value <= ex_src2;
            ex_mem_rd       <= id_ex_rd;
        end
    end

    // MEM/WB 阶段更新
    always @(posedge clk or negedge rst_combined) begin
        if (!rst_combined) begin
            mem_wb_regWrite <= 1'b0;
            mem_wb_memToReg <= 1'b0;
            mem_wb_is_jal   <= 1'b0;
            mem_wb_is_jalr  <= 1'b0;
            mem_wb_is_lui   <= 1'b0;
            mem_wb_is_auipc <= 1'b0;
            mem_wb_ecall    <= 1'b0;
            mem_wb_pc       <= 32'b0;
            mem_wb_imm      <= 32'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_rd       <= 5'b0;
        end else if (cpu_halt) begin
            mem_wb_regWrite <= mem_wb_regWrite;
            mem_wb_memToReg <= mem_wb_memToReg;
            mem_wb_is_jal   <= mem_wb_is_jal;
            mem_wb_is_jalr  <= mem_wb_is_jalr;
            mem_wb_is_lui   <= mem_wb_is_lui;
            mem_wb_is_auipc <= mem_wb_is_auipc;
            mem_wb_pc       <= mem_wb_pc;
            mem_wb_imm      <= mem_wb_imm;
            mem_wb_alu_result <= mem_wb_alu_result;
            mem_wb_mem_data <= mem_wb_mem_data;
            mem_wb_rd       <= mem_wb_rd;
        end else begin
            mem_wb_regWrite <= ex_mem_regWrite;
            mem_wb_memToReg <= ex_mem_memToReg;
            mem_wb_is_jal   <= ex_mem_is_jal;
            mem_wb_is_jalr  <= ex_mem_is_jalr;
            mem_wb_is_lui   <= ex_mem_is_lui;
            mem_wb_is_auipc <= ex_mem_is_auipc;
            mem_wb_ecall    <= ex_mem_ecall;
            mem_wb_pc       <= ex_mem_pc;
            mem_wb_imm      <= ex_mem_imm;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= dmem_rdata;
            mem_wb_rd       <= ex_mem_rd;
        end
    end

    // IF/ID 阶段更新与分支、load-use、ecall flush 逻辑
    always @(posedge clk or negedge rst_combined) begin
        if (!rst_combined) begin
            if_id_inst <= 32'b0;
            if_id_pc   <= 32'b0;
        end else if (cpu_halt) begin
            if_id_inst <= if_id_inst;
            if_id_pc   <= if_id_pc;
        end else if (load_use_stall) begin
            if_id_inst <= if_id_inst;
            if_id_pc   <= if_id_pc;
        end else if (control_hazard_flush) begin
            if_id_inst <= 32'h00000013; // NOP flush on branch/JAL/JALR misprediction
            if_id_pc   <= 32'b0;
        end else begin
            if_id_inst <= if_inst;
            if_id_pc   <= if_pc;
        end
    end

    // ID/EX 阶段更新
    always @(posedge clk or negedge rst_combined) begin
        if (!rst_combined) begin
            id_ex_pc        <= 32'b0;
            id_ex_imm       <= 32'b0;
            id_ex_reg_data1 <= 32'b0;
            id_ex_reg_data2 <= 32'b0;
            id_ex_rs1       <= 5'b0;
            id_ex_rs2       <= 5'b0;
            id_ex_rd        <= 5'b0;
            id_ex_funct3    <= 3'b0;
            id_ex_opcode    <= 7'b0;
            id_ex_branch    <= 1'b0;
            id_ex_aluSrc    <= 1'b0;
            id_ex_memRead   <= 1'b0;
            id_ex_memWrite  <= 1'b0;
            id_ex_memToReg  <= 1'b0;
            id_ex_regWrite  <= 1'b0;
            id_ex_funct7_5  <= 1'b0;
            id_ex_jal       <= 1'b0;
            id_ex_jalr      <= 1'b0;
            id_ex_is_lui    <= 1'b0;
            id_ex_is_auipc  <= 1'b0;
            id_ex_rdcycle   <= 1'b0;
            id_ex_ecall     <= 1'b0;
        end else if (cpu_halt) begin
            id_ex_pc        <= id_ex_pc;
            id_ex_imm       <= id_ex_imm;
            id_ex_reg_data1 <= id_ex_reg_data1;
            id_ex_reg_data2 <= id_ex_reg_data2;
            id_ex_rs1       <= id_ex_rs1;
            id_ex_rs2       <= id_ex_rs2;
            id_ex_rd        <= id_ex_rd;
            id_ex_funct3    <= id_ex_funct3;
            id_ex_opcode    <= id_ex_opcode;
            id_ex_ALUOp     <= id_ex_ALUOp;
            id_ex_branch    <= id_ex_branch;
            id_ex_aluSrc    <= id_ex_aluSrc;
            id_ex_memRead   <= id_ex_memRead;
            id_ex_memWrite  <= id_ex_memWrite;
            id_ex_memToReg  <= id_ex_memToReg;
            id_ex_regWrite  <= id_ex_regWrite;
            id_ex_funct7_5  <= id_ex_funct7_5;
            id_ex_jal       <= id_ex_jal;
            id_ex_jalr      <= id_ex_jalr;
            id_ex_is_lui    <= id_ex_is_lui;
            id_ex_is_auipc  <= id_ex_is_auipc;
            id_ex_rdcycle   <= id_ex_rdcycle;
            id_ex_ecall     <= id_ex_ecall;
        end else if (load_use_stall) begin
            // Insert bubble into EX stage while freezing IF/ID
            id_ex_pc        <= 32'b0;
            id_ex_imm       <= 32'b0;
            id_ex_reg_data1 <= 32'b0;
            id_ex_reg_data2 <= 32'b0;
            id_ex_rs1       <= 5'b0;
            id_ex_rs2       <= 5'b0;
            id_ex_rd        <= 5'b0;
            id_ex_funct3    <= 3'b0;
            id_ex_opcode    <= 7'b0;
            id_ex_ALUOp     <= 2'b0;
            id_ex_branch    <= 1'b0;
            id_ex_aluSrc    <= 1'b0;
            id_ex_memRead   <= 1'b0;
            id_ex_memWrite  <= 1'b0;
            id_ex_memToReg  <= 1'b0;
            id_ex_regWrite  <= 1'b0;
            id_ex_funct7_5  <= 1'b0;
            id_ex_jal       <= 1'b0;
            id_ex_jalr      <= 1'b0;
            id_ex_is_lui    <= 1'b0;
            id_ex_is_auipc  <= 1'b0;
            id_ex_rdcycle   <= 1'b0;
            id_ex_ecall     <= 1'b0;
        end else if (control_hazard_flush) begin
            id_ex_pc        <= 32'b0;
            id_ex_imm       <= 32'b0;
            id_ex_reg_data1 <= 32'b0;
            id_ex_reg_data2 <= 32'b0;
            id_ex_rs1       <= 5'b0;
            id_ex_rs2       <= 5'b0;
            id_ex_rd        <= 5'b0;
            id_ex_funct3    <= 3'b0;
            id_ex_opcode    <= 7'b0;
            id_ex_ALUOp     <= 2'b0;
            id_ex_branch    <= 1'b0;
            id_ex_aluSrc    <= 1'b0;
            id_ex_memRead   <= 1'b0;
            id_ex_memWrite  <= 1'b0;
            id_ex_memToReg  <= 1'b0;
            id_ex_regWrite  <= 1'b0;
            id_ex_funct7_5  <= 1'b0;
            id_ex_jal       <= 1'b0;
            id_ex_jalr      <= 1'b0;
            id_ex_is_lui    <= 1'b0;
            id_ex_is_auipc  <= 1'b0;
            id_ex_rdcycle   <= 1'b0;
            id_ex_ecall     <= 1'b0;
        end else begin
            id_ex_pc        <= if_id_pc;
            id_ex_imm       <= id_imm;
            id_ex_reg_data1 <= id_reg_read1;
            id_ex_reg_data2 <= id_reg_read2;
            id_ex_rs1       <= id_rs1;
            id_ex_rs2       <= id_rs2;
            id_ex_rd        <= id_rd;
            id_ex_funct3    <= id_funct3;
            id_ex_opcode    <= id_inst[6:0];
            id_ex_ALUOp     <= id_ALUOp;
            id_ex_branch    <= id_branch;
            id_ex_aluSrc    <= id_aluSrc;
            id_ex_memRead   <= id_memRead;
            id_ex_memWrite  <= id_memWrite;
            id_ex_memToReg  <= id_memToReg;
            id_ex_regWrite  <= id_regWrite;
            id_ex_funct7_5  <= id_funct7_5;
            id_ex_jal       <= id_jal;
            id_ex_jalr      <= id_jalr;
            id_ex_is_lui    <= id_is_lui;
            id_ex_is_auipc  <= id_is_auipc;
            id_ex_rdcycle   <= id_rdcycle;
            id_ex_ecall     <= id_ecall;
        end
    end

    // MEM 阶段输出给 DataMemory
    assign dmem_we  = ex_mem_memWrite;
    assign dmem_addr= ex_mem_alu_result;
    assign dmem_din = ex_mem_store_value;
    assign dmem_rd_data = dmem_rdata;

    // WB 阶段写回数据选择
    wire [31:0] mem_wb_write_data =
        mem_wb_is_lui   ? mem_wb_imm :
        mem_wb_is_auipc ? (mem_wb_pc + mem_wb_imm) :
        mem_wb_is_jal   ? (mem_wb_pc + 32'd4) :
        mem_wb_is_jalr  ? (mem_wb_pc + 32'd4) :
        (mem_wb_memToReg ? mem_wb_mem_data : mem_wb_alu_result);

    // dbg_pc 输出当前 ID 阶段的 PC，兼容单周期显示意义
    assign dbg_pc = if_id_pc;

    // 是否有 ecall 在流水线中
    assign ecall_halt = id_ex_ecall || ex_mem_ecall || mem_wb_ecall;

    always @(posedge clk or negedge rst_combined) begin
        if (!rst_combined)
            cycle_count <= 32'b0;
        else
            cycle_count <= cycle_count + 32'd1;
    end

endmodule
