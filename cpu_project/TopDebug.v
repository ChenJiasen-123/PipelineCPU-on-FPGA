    module TopDebug (
        input clk,
        input rst,
        //UART
        input uart_rxd,
        output uart_txd,
        // Mode selection: 0 = Single-cycle CPU, 1 = Pipeline CPU
        input pipeline_mode,

        // 7-seg outputs (位�??/段�?�组)
        output [7:0] p7_0,
        output [7:0] p7_1,
        output [7:0] p7_2
        );
        // UART 收发模块实例�?
        wire [7:0] rx_data;
        wire       rx_valid;
        wire [7:0] tx_data;
        wire       tx_start;
        wire       tx_busy;
        
        // 物理降频：流水线模式 50MHz，单周期模式 25MHz
        reg [31:0] clk_count = 0;
        reg cpu_clk_raw = 0; // 改名为 raw，表示原始生成的逻辑信号
        wire divide_threshold = pipeline_mode ? 0 : 1; // 流水线模式: 50MHz, 单周期: 25MHz

        always @(posedge clk or negedge rst) begin 
           if (!rst) begin
                clk_count <= 0;
                cpu_clk_raw <= 0;
           end else if (clk_count >= divide_threshold) begin
                clk_count <= 0;
                cpu_clk_raw <= ~cpu_clk_raw;
            end else begin
                clk_count <= clk_count + 1;
            end
        end

        wire cpu_clk; // 声明�? wire
        BUFG u_bufg_cpu_clk (
            .I(cpu_clk_raw), // 输入：普通寄存器信号
            .O(cpu_clk)      // 输出：正式的全局时钟
        );
    
        UartRx #(.CLK_FREQ(100_000_000), .BAUD(115200)) uUartRx (
            .clk      (clk),
            .rst_n    (rst),
            .rx_pin   (uart_rxd),
            .rx_data  (rx_data),
            .rx_valid (rx_valid)
        );
    
        UartTx #(.CLK_FREQ(100_000_000), .BAUD(115200)) uUartTx (
            .clk      (clk),
            .rst_n    (rst),
            .tx_data  (tx_data),
            .tx_start (tx_start),
            .tx_busy  (tx_busy),
            .tx_pin   (uart_txd)
        );
        
       //DebugController 实例�?
        wire        cpu_halt;
        wire        cpu_step;
        wire        cpu_reset;
        wire [4:0]  dbg_reg_addr;
        wire [31:0] dbg_reg_data;
        wire [31:0] dbg_pc;
        wire        inst_dbg_en, inst_wr_en;
        wire [31:0] inst_dbg_addr, inst_wr_data, inst_rd_data;
        wire        dmem_dbg_en, dmem_wr_en;
        wire [31:0] dmem_dbg_addr, dmem_wr_data, dmem_rd_data;
        wire        ecall_halt;
        wire        cpu_halt_internal;
        reg [47:0]  cycle_count = 48'b0;
        reg         run_started = 1'b0;
    
        DebugController uDebugCtrl (
            .clk           (clk),
            .rst_n         (rst),
            // UART 接口
            .rx_data       (rx_data),
            .rx_valid      (rx_valid),
            .tx_data       (tx_data),
            .tx_start      (tx_start),
            .tx_busy       (tx_busy),
            // CPU 控制
            .cpu_halt      (cpu_halt),
            .cpu_step      (cpu_step),
            .cpu_reset     (cpu_reset),
            .cpu_ecall     (ecall_halt),
            // 寄存器调试
            .dbg_reg_addr  (dbg_reg_addr),
            .dbg_reg_data  (dbg_reg_data),
            // 内存调试
            .inst_dbg_en   (inst_dbg_en),
            .inst_wr_en    (inst_wr_en),
            .inst_dbg_addr (inst_dbg_addr),
            .inst_wr_data  (inst_wr_data),
            .inst_rd_data  (inst_rd_data),
            .dmem_dbg_en   (dmem_dbg_en),
            .dmem_wr_en    (dmem_wr_en),
            .dmem_dbg_addr (dmem_dbg_addr),
            .dmem_wr_data  (dmem_wr_data),
            .dmem_rd_data  (dmem_rd_data),
            // PC
            .dbg_pc        (dbg_pc)
        );
        
        // CPU with Mode Selection (Single-cycle or Pipeline)
        CPUTopWithModeSelect u_cpu (
            .clk           (cpu_clk),
            .rst_n         (rst),
            .pipeline_mode (pipeline_mode),
            .cpu_halt      (cpu_halt),
            .cpu_step      (cpu_step),
            .cpu_dbg_reset (cpu_reset),
            .dbg_reg_addr  (dbg_reg_addr),
            .dbg_reg_data  (dbg_reg_data),
            .inst_dbg_en   (inst_dbg_en),
            .inst_wr_en    (inst_wr_en),
            .inst_dbg_addr (inst_dbg_addr),
            .inst_wr_data  (inst_wr_data),
            .inst_rd_data  (inst_rd_data),
            .dmem_dbg_en   (dmem_dbg_en),
            .dmem_wr_en    (dmem_wr_en),
            .dmem_dbg_addr (dmem_dbg_addr),
            .dmem_wr_data  (dmem_wr_data),
            .dmem_rd_data  (dmem_rd_data),
            .dbg_pc        (dbg_pc),
            .ecall_halt    (ecall_halt)
        );

        assign cpu_halt_internal = cpu_halt | ecall_halt;

        // =================================================================
        // ⏱️ 优化的微秒（us）转换计时秒表逻辑（无乘法、无除法，完美适配时序）
        // =================================================================
        reg [31:0] clk_p_cnt   = 32'b0; // 周期小计数器
        reg [31:0] display_val = 32'b0; // 最终送给数码管的值（单位：0.1微秒）
        reg        run_started = 1'b0;
        wire [31:0] cnt_threshold = pipeline_mode ? 32'd9 : 32'd4; // 50MHz: 10周期, 25MHz: 5周期

        always @(posedge cpu_clk or negedge rst) begin
            if (!rst) begin
                clk_p_cnt   <= 32'b0;
                display_val <= 32'b0;
                run_started <= 1'b0;
            end else begin
                // 当 CPU 第一次脱离 halt 状态且 PC 开始离开 0 时，启动秒表
                run_started <= run_started | (!cpu_halt_internal && dbg_pc != 32'd0);
                
                if (run_started && !cpu_halt_internal) begin
                    // 核心高效率转换（自适应不同时钟频率）：
                    // 流水线模式 (50MHz)：1 个周期 = 20ns，10 个周期 = 200ns = 2 个 0.1微秒
                    // 单周期模式 (25MHz)：1 个周期 = 40ns，5 个周期 = 200ns = 2 个 0.1微秒
                    if (clk_p_cnt == cnt_threshold) begin
                        clk_p_cnt   <= 32'd0;
                        display_val <= display_val + 32'd2; // 时间直接加 0.2 微秒
                    end else begin
                        clk_p_cnt   <= clk_p_cnt + 1'b1;
                    end
                end
            end
        end

        // =================================================================
        // 📺 实例化数码管驱动模块
        // =================================================================
        // ⚠️ 注意：数码管扫描时钟必须接原始的板载原始 clk (100MHz)，
        // 这样动态扫描刷新率才够高，人眼看起来才不会闪烁！
        top_display u_top_display (
            .clk      (clk),         // 👈 修改这里：用 100MHz 原始主时钟驱动扫描
            .value    (display_val), // 👈 传进去的是以 0.1微秒为单位的计数值
            .p7_0     (p7_0),        // 位选
            .p7_1     (p7_1),        // 左组段选
            .p7_2     (p7_2)         // 右组段选
        );
    
    endmodule