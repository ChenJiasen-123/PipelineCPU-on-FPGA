module DataMemory (
    input wire clka,
    input wire rstN,
    // --- CPU 接口 ---
    input wire wea,          // CPU 写使能
    input wire [31:0] addra, // CPU 传入的 32 位字节地址
    input wire [31:0] dina,  // CPU 写入的数据
    output wire [31:0] douta, // 输出给 CPU 的数据
    
    // --- Debug 调试接口 (UART) ---
    input wire dmem_dbg_en, 
    input wire dmem_wr_en,  
    input wire [31:0] dmem_dbg_addr, 
    input wire [31:0] dmem_wr_data, 
    output wire [31:0] dmem_rd_data
);

    reg dmem_dbg_en_sync;
    reg dmem_wr_en_sync;
    reg [31:0] dmem_dbg_addr_sync;
    reg [31:0] dmem_wr_data_sync;

    // 正相时钟同步调试信号，避免亚稳态
    always @(negedge clka or negedge rstN) begin
        if (~rstN) begin
            dmem_dbg_en_sync   <= 1'b0;
            dmem_wr_en_sync    <= 1'b0;
            dmem_dbg_addr_sync <= 32'b0;
            dmem_wr_data_sync  <= 32'b0;
        end else begin
            dmem_dbg_en_sync   <= dmem_dbg_en;
            dmem_wr_en_sync    <= dmem_wr_en;
            dmem_dbg_addr_sync <= dmem_dbg_addr;
            dmem_wr_data_sync  <= dmem_wr_data;
        end
    end

    // 32 位地址、数据与写使能的 MUX 切换
    wire [31:0] uram_addr_mux = dmem_dbg_en_sync ? dmem_dbg_addr_sync : addra;
    wire uram_wea             = dmem_dbg_en_sync ? dmem_wr_en_sync : wea;
    wire [31:0] uram_din      = dmem_dbg_en_sync ? dmem_wr_data_sync : dina;
    wire [31:0] memReadData;

    assign dmem_rd_data = memReadData;
    assign douta        = memReadData;

    // 实例化底层模块，不带任何带有 # 标记的参数列表
    dmem uram_inst (
        .clka  (~clka),             
        .wea   (uram_wea),
        .addra (uram_addr_mux[15:2]), 
        .dina  (uram_din),
        .douta (memReadData)
    );
    
    // 防御性逻辑：解决高位悬空警告，把没用到的高 16 位地址揉在一起做个 dummy 负载
    wire dummy_load = ^uram_addr_mux[31:16];

endmodule