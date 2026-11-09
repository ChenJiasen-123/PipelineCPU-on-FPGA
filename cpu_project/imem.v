module imem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14,
    parameter INIT_FILE  = "batch_test.txt"   
)(
    input clka,
    input wea,                  
    input [ADDR_WIDTH-1:0] addra,
    input [DATA_WIDTH-1:0] dina,  
    output reg [DATA_WIDTH-1:0] douta
);
(* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    integer i;
    initial begin
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};          
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);   
    end

    // 修改为同步读写逻辑
    always @(posedge clka) begin
        if (wea) begin             // 如果写使能开启，则写入数据 
            mem[addra] <= dina;
        end
        douta <= mem[addra];       
    end

endmodule
