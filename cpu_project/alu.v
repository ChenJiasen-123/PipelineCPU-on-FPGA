module alu(
    input  [31:0] op1,
    input  [31:0] op2,
    input  [1:0]  alu_op,   // 来自主控制器的2位信号
    input  [2:0]  funct3,   // 来自指令 [14:12]
    input         funct7_5, // 来自指令 [30] 
    input         count_ones,  // 来自指令[29], 1=计算输入中1的个数
    output reg [31:0] res
);

    genvar gi;
    wire [1:0] step1 [15:0];
    wire [2:0] step2 [7:0];
    wire [3:0] step3 [3:0];
    wire [4:0] step4 [1:0];
    wire [5:0] popcnt;
    
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : g_step1
            assign step1[gi] = op1[gi*2] + op1[gi*2+1];
        end
        for (gi = 0; gi < 8; gi = gi + 1) begin : g_step2
            assign step2[gi] = step1[gi*2] + step1[gi*2+1];
        end
        for (gi = 0; gi < 4; gi = gi + 1) begin : g_step3
            assign step3[gi] = step2[gi*2] + step2[gi*2+1];
        end
        for (gi = 0; gi < 2; gi = gi + 1) begin : g_step4
            assign step4[gi] = step3[gi*2] + step3[gi*2+1];
        end
        assign popcnt = step4[0] + step4[1];
    endgenerate

    always @(*) begin
        res = 32'h0;
        case(alu_op)
            // 模式 00: 用于 Load/Store 计算内存地址
            2'b00: res = op1 + op2; 
            
            // 模式 01: 用于 Branch 指令进行比较
            2'b01: res = op1 - op2; 
            
            // 模式 10: R-type 或 I-type 运算
            2'b10: begin
                case(funct3)
                    3'b000: res = funct7_5 ? (op1 - op2) : (op1 + op2); // add, sub, addi
                    3'b001: res = op1 << op2[4:0];                      // sll, slli
                    3'b010: res = ($signed(op1) < $signed(op2)) ? 1 : 0; // slt, slti
                    3'b011: res = (op1 < op2) ? 1 : 0;                  // sltu, sltiu
                    3'b100: res = op1 ^ op2;                            // xor, xori
                    3'b101: begin
                        if (funct7_5)
                            res = $signed(op1) >>> op2[4:0];            // sra, srai 
                        else if (count_ones)
                            res = {26'b0, popcnt};
                        else
                            res = op1 >> op2[4:0];                      // srl, srli 
                    end
                    3'b110: res = op1 | op2;                            // or, ori
                    3'b111: res = op1 & op2;                            // and, andi
                    default: res = 32'h0;
                endcase
            end
            default: res = 32'h0;
        endcase
    end

endmodule
