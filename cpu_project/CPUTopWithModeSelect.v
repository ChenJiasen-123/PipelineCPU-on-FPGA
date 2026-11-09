// Top-level CPU module with mode selection
// Supports switching between single-cycle and 5-stage pipeline CPU
module CPUTopWithModeSelect (
    input clk,
    input rst_n,
    
    // Mode selection: 0 = Single-cycle, 1 = Pipeline
    input pipeline_mode,
    
    // --- Debug Ports ---
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
    output [31:0] dbg_pc,
    output        ecall_halt
);

    // Single-cycle CPU outputs
    wire [31:0] dbg_reg_data_single;
    wire [31:0] inst_rd_data_single;
    wire [31:0] dbg_pc_single;
    
    // Pipeline CPU outputs
    wire [31:0] dbg_reg_data_pipeline;
    wire [31:0] inst_rd_data_pipeline;
    wire [31:0] dbg_pc_pipeline;
    wire        ecall_halt_single;
    wire        ecall_halt_pipeline;

    // Shared data memory request signals
    wire        dmem_we_single;
    wire [31:0] dmem_addr_single;
    wire [31:0] dmem_din_single;
    wire        dmem_we_pipeline;
    wire [31:0] dmem_addr_pipeline;
    wire [31:0] dmem_din_pipeline;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_din;
    wire        rst_combined = rst_n & ~cpu_dbg_reset;

    // Instantiate Single-cycle CPU
    CPUTop single_cycle_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_step(cpu_step),
        .cpu_halt(cpu_halt),
        .cpu_dbg_reset(cpu_dbg_reset),
        .dbg_reg_addr(dbg_reg_addr),
        .dbg_reg_data(dbg_reg_data_single),
        .inst_dbg_en(inst_dbg_en),
        .inst_wr_en(inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data(inst_wr_data),
        .inst_rd_data(inst_rd_data_single),
        .dmem_dbg_en(dmem_dbg_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data(dmem_wr_data),
        .dmem_rd_data(dmem_rd_data),
        .dmem_we(dmem_we_single),
        .dmem_addr(dmem_addr_single),
        .dmem_din(dmem_din_single),
        .dmem_rdata(dmem_rdata),
        .dbg_pc(dbg_pc_single),
        .ecall_halt(ecall_halt_single)
    );
    
    // Instantiate Pipeline CPU
    PipelineCPU pipeline_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_step(cpu_step),
        .cpu_halt(cpu_halt),
        .cpu_dbg_reset(cpu_dbg_reset),
        .dbg_reg_addr(dbg_reg_addr),
        .dbg_reg_data(dbg_reg_data_pipeline),
        .inst_dbg_en(inst_dbg_en),
        .inst_wr_en(inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data(inst_wr_data),
        .inst_rd_data(inst_rd_data_pipeline),
        .dmem_dbg_en(dmem_dbg_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data(dmem_wr_data),
        .dmem_we(dmem_we_pipeline),
        .dmem_addr(dmem_addr_pipeline),
        .dmem_din(dmem_din_pipeline),
        .dmem_rdata(dmem_rdata),
        .dbg_pc(dbg_pc_pipeline),
        .ecall_halt(ecall_halt_pipeline)
    );
    
    assign dmem_we   = pipeline_mode ? dmem_we_pipeline   : dmem_we_single;
    assign dmem_addr = pipeline_mode ? dmem_addr_pipeline : dmem_addr_single;
    assign dmem_din  = pipeline_mode ? dmem_din_pipeline  : dmem_din_single;

    DataMemory shared_dmem (
        .clka           (clk),
        .rstN           (rst_combined),
        .wea            (dmem_we),
        .addra          (dmem_addr),
        .dina           (dmem_din),
        .douta          (dmem_rdata),
        .dmem_dbg_en    (dmem_dbg_en),
        .dmem_wr_en     (dmem_wr_en),
        .dmem_dbg_addr  (dmem_dbg_addr),
        .dmem_wr_data   (dmem_wr_data),
        .dmem_rd_data   (dmem_rd_data)
    );

    // Output multiplexing based on mode selection
    assign dbg_reg_data = pipeline_mode ? dbg_reg_data_pipeline : dbg_reg_data_single;
    assign inst_rd_data = pipeline_mode ? inst_rd_data_pipeline : inst_rd_data_single;
    assign dbg_pc = pipeline_mode ? dbg_pc_pipeline : dbg_pc_single;
    assign ecall_halt = pipeline_mode ? ecall_halt_pipeline : ecall_halt_single;

endmodule
