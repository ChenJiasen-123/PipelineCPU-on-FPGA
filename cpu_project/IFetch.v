module IFetch(
    input clk, rst_n,
    input pc_redirect,
    input [31:0] pc_target,
    
    // ==== ???? Debug ???  ====
    input cpu_halt,             // 1=??? PC ???? 
    input inst_dbg_en,          // 1=???????? 
    input inst_wr_en,           // 1=????��??? 
    input [31:0] inst_dbg_addr, // ?????? 
    input [31:0] inst_wr_data,  // ��?????? 
    output [31:0] inst_rd_data, // ???????? 
    output [31:0] pc_current,
    output [31:0] inst
);
    reg [31:0] pc_fetch;
    reg [31:0] pc_exec;
    reg flush_inst;

    // ==== 1. ??????????  ====
    reg inst_dbg_en_sync, inst_wr_en_sync;
    reg [31:0] inst_dbg_addr_sync, inst_wr_data_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inst_dbg_en_sync   <= 1'b0; 
            inst_wr_en_sync    <= 1'b0; 
            inst_dbg_addr_sync <= 32'b0; 
            inst_wr_data_sync  <= 32'b0; 
        end else begin
            inst_dbg_en_sync   <= inst_dbg_en; 
            inst_wr_en_sync    <= inst_wr_en; 
            inst_dbg_addr_sync <= inst_dbg_addr;
            inst_wr_data_sync  <= inst_wr_data;
        end
    end

    // ==== 2. ?????��????��? ====
    wire [13:0] cpu_addr = cpu_halt ? pc_exec[15:2] : pc_fetch[15:2];
    wire [13:0] rom_addr = inst_dbg_en_sync ? inst_dbg_addr_sync[15:2] : cpu_addr;
    wire rom_wea = inst_dbg_en_sync & inst_wr_en_sync; 
    wire [31:0] inst_dout;

    // ==== 3. IMem ?????  ====
    imem #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (14),
        .INIT_FILE  ("batch_test.txt") 
    ) uimem (  
        .clka  (clk), 
        .wea   (rom_wea),     
        .addra (rom_addr),  
        .dina  (inst_wr_data_sync), 
        .douta (inst_dout)         
    );

    assign inst_rd_data = inst_dout;                       // ???????
    assign inst = flush_inst ? 32'h00000013 : inst_dout;  // kill one wrong-path instruction after taken control flow
    assign pc_current = pc_exec;
    
    // ==== 4. ???????? PC/flush ???? ====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_fetch <= 32'h0;
            pc_exec <= 32'h0;
            flush_inst <= 1'b0;
        end else if (cpu_halt) begin
            pc_fetch <= pc_fetch;
            pc_exec <= pc_exec;
            flush_inst <= flush_inst;
        end else begin
            // inst_dout read this cycle belongs to pc_fetch, so expose that as the executing PC.
            pc_exec <= pc_fetch;

            if (pc_redirect) begin
                // Redirect the next fetch to the target computed from the executing instruction PC.
                pc_fetch <= pc_target;
                flush_inst <= 1'b1;
            end else begin
                pc_fetch <= pc_fetch + 32'd4;
                flush_inst <= 1'b0;
            end
        end
    end
endmodule
