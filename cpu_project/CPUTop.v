module CPUTop (
    input clk,
    input rst_n,
    
    // --- Debug Ports ---
    input         cpu_step,      // 1=??????? (???? cpu_halt=1 ???��) 
    input         cpu_halt,      // 1=??? CPU ??? 
    input         cpu_dbg_reset, // 1=????????�� (???????) 

    // Debug: Register read
    input  [4:0]  dbg_reg_addr,  // ??????????? 
    output [31:0] dbg_reg_data,  // ???????????? 

    // Debug: Instruction memory read/write
    input         inst_dbg_en,   // ???????????? 
    input         inst_wr_en,    // ??????��??? 
    input  [31:0] inst_dbg_addr, // ???????? 
    input  [31:0] inst_wr_data,  // ???��?????? 
    output [31:0] inst_rd_data,  // ?????????? 

    // Debug: Data memory read/write
    input         dmem_dbg_en,   // ????????????? 
    input         dmem_wr_en,    // ???????��??? 
    input  [31:0] dmem_dbg_addr, // ????????? 
    input  [31:0] dmem_wr_data,  // ????��?????? 
    output [31:0] dmem_rd_data,  // ??????????? 

    output        dmem_we,
    output [31:0] dmem_addr,
    output [31:0] dmem_din,
    input  [31:0] dmem_rdata,

    // Debug: PC
    output [31:0] dbg_pc,         // ???? PC ??? 
    output        ecall_halt
);
    // Internal signals
    wire [31:0] inst;
    wire [31:0] pc;
    wire [31:0] imm;
    wire branch, aluSrc, memRead, memWrite, memToReg, regWrite;
    wire [1:0] ALUOp;
    wire [31:0] reg_read1, reg_read2;
    wire [31:0] alu_op2;
    wire [31:0] alu_result;
    wire [31:0] mem_data = dmem_rdata;
    wire [31:0] write_back_data;
    reg  [31:0] cycle_count = 32'b0;
    wire cpu_exec_en;
    wire reg_write_en;
    wire load_wait = 1'b0;
    wire [6:0] opcode;
    wire funct7_5;
    wire id_countones;
    wire rdcycle;
    wire jal;
    wire jalr;
    wire ecall;
    wire branch_taken;
    wire pc_redirect;
    wire [31:0] pc_target;

    // final write enable/data/rd that go to register file
    wire writeReg_final;
    wire [4:0] rd_final;
    wire [31:0] write_back_data_final;
    
    // Instruction field extraction
    wire [4:0] rs1 = inst[19:15];
    wire [4:0] rs2 = inst[24:20];
    wire [4:0] rd  = inst[11:7];
    wire [2:0] funct3 = inst[14:12];
    assign opcode = inst[6:0];
    
    // debug: PC ????? UART Debug
    assign dbg_pc = pc;
    wire rst_combined = rst_n & ~cpu_dbg_reset;
    // The project test program uses gp = 0x4000 and performs lw/sw at
    // 0(gp), 4(gp), 8(gp), 12(gp).  Blocking data-memory writes at >=0x4000
    // makes those sw instructions disappear, so keep normal CPU accesses
    // routed to data memory for now.
    assign reg_write_en = regWrite;
    assign dmem_we = memWrite;
    assign dmem_addr = alu_result;
    assign dmem_din = reg_read2;
    assign dmem_rd_data = dmem_rdata;
    assign ecall_halt = ecall;
    assign dmem_re = memRead;
    
    
    // ===== Instruction Fetch =====
    IFetch ifetch_inst (
        .clk    (clk),
        .rst_n  (rst_combined),
        .pc_redirect (pc_redirect),
        .pc_target   (pc_target),
        
         // --- ???? Debug ??????? ---
        .cpu_halt       (cpu_halt | load_wait),      
        .inst_dbg_en    (inst_dbg_en),      
        .inst_wr_en     (inst_wr_en),       
        .inst_dbg_addr  (inst_dbg_addr),    
        .inst_wr_data   (inst_wr_data),     
        .inst_rd_data   (inst_rd_data),     
        .pc_current     (pc),
        .inst   (inst)
    );
    

    // ===== Control Unit =====
    control ctrl_inst (
        .inst      (inst),
        .branch    (branch),
        .aluSrc    (aluSrc),
        .memRead   (memRead),
        .memWrite  (memWrite),
        .memToReg  (memToReg),
        .regWrite  (regWrite),
        .ALUOp     (ALUOp),
        .funct7_5  (funct7_5),
        .count_ones (id_countones),
        .rdcycle   (rdcycle),
        .jal       (jal),
        .jalr      (jalr),
        .ecall     (ecall)
    );

    // ===== Immediate Generator =====
    imm_process imm_gen_inst (
        .m_code  (inst),
        .imm     (imm)
    );

    // ===== Register File =====
    register reg_inst (
        .clk       (clk),
        .rst_n         (rst_combined),
        .writeReg      (reg_write_en),
        .rs1           (rs1),
        .rs2           (rs2),
        .rd            (rd),
        .writeData     (write_back_data),
        .readData1     (reg_read1),
        .readData2     (reg_read2),

        // --- ???? Debug ??????? ---
        .dbg_reg_addr  (dbg_reg_addr),  
        .dbg_reg_data  (dbg_reg_data)
    );

    // ===== ALU Source Multiplexer =====
    assign alu_op2 = aluSrc ? imm : reg_read2;
    // ===== ALU =====
    alu alu_inst (
        .op1     (reg_read1),
        .op2     (alu_op2),
        .alu_op  (ALUOp),
        .funct3  (funct3),
        .funct7_5(funct7_5),
        .count_ones (id_countones),
        .res     (alu_result)
    );

    // ===== Branch Compare / PC Redirect =====
    wire branch_eq = (reg_read1 == reg_read2);
    wire branch_lt_signed = ($signed(reg_read1) < $signed(reg_read2));
    wire branch_ge_signed = ($signed(reg_read1) >= $signed(reg_read2));
    wire branch_lt_unsigned = (reg_read1 < reg_read2);
    wire branch_ge_unsigned = (reg_read1 >= reg_read2);
    wire [31:0] pc_plus_4 = pc + 32'd4;
    wire [31:0] pc_plus_imm = pc + imm;
    wire [31:0] jalr_target = {alu_result[31:1], 1'b0};

    assign branch_taken = branch && (
        ((funct3 == 3'b000) && branch_eq) ||
        ((funct3 == 3'b001) && !branch_eq) ||
        ((funct3 == 3'b100) && branch_lt_signed) ||
        ((funct3 == 3'b101) && branch_ge_signed) ||
        ((funct3 == 3'b110) && branch_lt_unsigned) ||
        ((funct3 == 3'b111) && branch_ge_unsigned)
    );
    assign pc_redirect = jal | jalr | branch_taken;
    assign pc_target = jalr ? jalr_target : pc_plus_imm;

    // NOTE: DataMemory is instantiated at the top-level wrapper so both CPU variants share the same BRAM.

    // ===== Write Back Multiplexer =====
    // Handle special writeback cases: LUI (opcode 0110111) -> imm
    // AUIPC (0010111) -> pc + imm
    // JAL/JALR -> pc + 4
    wire is_lui   = (opcode == 7'b0110111);
    wire is_auipc = (opcode == 7'b0010111);
    wire is_jal   = (opcode == 7'b1101111);
    wire is_jalr  = (opcode == 7'b1100111);
    assign write_back_data = is_lui ? imm :
                             is_auipc ? pc_plus_imm :
                             rdcycle ? cycle_count :
                             (is_jal || is_jalr) ? pc_plus_4 :
                             (memToReg ? mem_data : alu_result);

    always @(posedge clk or negedge rst_combined) begin
        if (!rst_combined)
            cycle_count <= 32'b0;
        else
            cycle_count <= cycle_count + 32'd1;
    end

endmodule
