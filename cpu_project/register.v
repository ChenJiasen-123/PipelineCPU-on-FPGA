module register (
    input clk,
    input rst_n,
    input writeReg,
    input [4:0] rs1,                
    input [4:0] rs2,
    input [4:0] rd,
    input [31:0] writeData,
    
    input  [4:0]  dbg_reg_addr, 
    output [31:0] dbg_reg_data,  

    output [31:0] readData1,
    output [31:0] readData2
);
    reg [31:0] regs [0:31]; 
    
    // 异步读逻辑：始终保持 x0 为 0
    assign dbg_reg_data = (dbg_reg_addr == 5'd0) ? 32'b0 : regs[dbg_reg_addr];
    assign readData1    = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
    assign readData2    = (rs2 == 5'b0) ? 32'b0 : regs[rs2];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 收到复位信号时，将所有寄存器清零
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (writeReg && rd != 5'b0) begin
            regs[rd] <= writeData;
        end
        regs[3] <= 16'h4000;
    end
    
endmodule
