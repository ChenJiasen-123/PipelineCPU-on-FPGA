// -----------------------------------------------------------------------------
// Module      : dmem
// Author      : Yuhui Bai
// Description : Single-port synchronous Block RAM (BRAM).
//               Replacement of Vivado blk_mem_gen IP.
//               Size: Depth = 2^ADDR_WIDTH, Width = DATA_WIDTH.
//               Content Init: Set INIT_FILE parameter to a hex file path, or let it empty.
//               Complete the following code
// -----------------------------------------------------------------------------

module dmem(
    input clka,
    input wea,
    input [14:0] addra,
    input [31:0] dina,
    output reg [31:0] douta
);

    // Must use Block RAM attribute to ensure synthesis as BRAM，Otherwise may run out of resources or cause timing issues
    (* ram_style = "block" *) reg [31:0] mem [0:(2**15)-1];

    // Initialization
    integer i;
    initial begin
        for (i = 0; i < 2**15; i = i + 1)
            mem[i] = {32{1'b0}};            
    end

    always @(posedge clka) begin
        if ( wea ) begin
            mem[addra] <= dina;
            douta <= dina;
        end else begin
            douta      <= mem[addra];
        end
    end

endmodule