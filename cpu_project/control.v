module control(
input [31:0] inst,
output reg branch, aluSrc, memRead, memWrite, memToReg, 
output reg regWrite,
output reg [1:0] ALUOp,
output reg funct7_5,
output reg count_ones,
output reg rdcycle,
output reg jal,
output reg jalr,
output reg ecall
    );
wire [6:0] opcode; 
assign opcode=inst[6:0]; 
// complete your code here
always@(*)begin
    branch   = 1'b0;
    aluSrc   = 1'b0;
    memRead  = 1'b0;
    memWrite = 1'b0;
    memToReg = 1'b0;
    regWrite = 1'b0;
    ALUOp    = 2'b00;
    funct7_5 = 1'b0;
    count_ones = 1'b0;
    rdcycle = 1'b0;
    jal=1'b0;
    jalr=1'b0;
    ecall=1'b0;
case(opcode)
            7'b0110011: begin //R-type
                aluSrc   = 1'b0;
                regWrite = 1'b1;
                ALUOp    = 2'b10;
                funct7_5 = inst[30];
            end

           
            7'b0010011: begin//I type
                aluSrc   = 1'b1;
                regWrite = 1'b1;
                ALUOp    = 2'b10;
                // Only shift-right-immediate uses funct7[5] as SRA/SRLI selector.
                // For ADDI and other I-type ALU immediate instructions, this bit is part of the immediate.
                if (inst[14:12] == 3'b101) begin
                    funct7_5 = inst[30];
                    if (inst[31:25] == 7'b0010000)
                        count_ones = inst[29];
                    else
                        count_ones = 1'b0;
                end
                else
                    funct7_5 = 1'b0;
            end

            
            7'b0000011: begin //lw
                aluSrc   = 1'b1;
                memRead  = 1'b1;
                memToReg = 1'b1;
                regWrite = 1'b1;
                ALUOp    = 2'b00;
            end

          
            7'b0100011: begin//S type
                aluSrc   = 1'b1;
                memWrite = 1'b1;
                ALUOp    = 2'b00;
            end
                // LUI: write immediate to rd
            7'b0110111: begin
                regWrite = 1'b1;
                ALUOp    = 2'b00;
            end
            // AUIPC: write PC+imm to rd (handled in CPUTop writeback selection)
            7'b0010111: begin
                regWrite = 1'b1;
                ALUOp    = 2'b00;
            end
            // JAL: write PC+4 to rd (handle d in CPUTop writeback selection)
            7'b1101111: begin
                regWrite = 1'b1;
                ALUOp    = 2'b00;
                jal=1'b1;
            end
            //jalr
            7'b1100111: begin
                aluSrc   = 1'b1;
                regWrite = 1'b1;
                ALUOp    = 2'b00;
                jalr=1'b1;
            end
            
            // SYSTEM / ecall
            7'b1110011: begin
                if (inst[14:12] == 3'b000 && inst[31:20] == 12'b0) begin
                    // Standard ecall instruction
                    ecall = 1'b1;
                end else if (inst[14:12] == 3'b010 && inst[31:20] == 12'hC00 && inst[19:15] == 5'b0) begin
                    // rdcycle pseudo-instruction: csrrs rd, cycle, x0
                    rdcycle = 1'b1;
                    regWrite = 1'b1;
                end else begin
                    ecall = 1'b0;
                end
            end
            //Btype 
            7'b1100011: begin
                branch = 1'b1;
                ALUOp  = 2'b01;
            end
            default: begin
                branch   = 1'b0;
                aluSrc   = 1'b0;
                memRead  = 1'b0;
                memWrite = 1'b0;
                memToReg = 1'b0;
                regWrite = 1'b0;
                ALUOp    = 2'b00;
                jal=1'b0;
                jalr=1'b0;
                ecall=1'b0;
end


        endcase

end

endmodule
