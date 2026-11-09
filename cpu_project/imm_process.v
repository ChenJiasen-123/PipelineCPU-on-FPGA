module imm_process (
    input  [31:0] m_code,  //RISC-V32I machine code
    output reg [31:0] imm      //immediate number
);
always@(*)begin
case(m_code[6:0])

7'b0000011,7'b0010011,7'b1100111:
      imm={{20{m_code[31]}},m_code[31:20]};
7'b0100011:
      imm={{20{m_code[31]}},m_code[31:25],m_code[11:7]};
7'b1100011:
      imm={{20{m_code[31]}},m_code[7],m_code[30:25],m_code[11:8],1'b0};
7'b0110111, 7'b0010111: 
            imm = {m_code[31:12], 12'b0};
 7'b1101111:  
            imm = {{12{m_code[31]}}, m_code[19:12], m_code[20], m_code[30:21], 1'b0};
        
default:  
            imm = 32'b0;
        

endcase
end
endmodule
