module top_display(
    input clk,          // 100MHz 主时钟
    input [31:0] value, // 要显示的运行周期计数（32-bit）
    output [7:0] p7_0,  // 位选 (控制哪一个管子亮)
    output [7:0] p7_1,  // 左组段选
    output [7:0] p7_2   // 右组段选
);

    // --- 分频/扫描选择 ---
    reg [19:0] cnt = 20'd0;
    always @(posedge clk) begin
        cnt <= cnt + 1'b1;
    end
    wire [1:0] scan_sel = cnt[19:18]; // 0..3

    // --- 位选 (pair scanning: 点亮左组和右组各一位) ---
    reg [7:0] bit_ctrl;
    always @(*) begin
        case(scan_sel)
            2'd0: bit_ctrl = 8'b10001000; // 点亮第1(左1) 和 第5(右1)
            2'd1: bit_ctrl = 8'b01000100; // 点亮第2 和 第6
            2'd2: bit_ctrl = 8'b00100010; // 点亮第3 和 第7
            2'd3: bit_ctrl = 8'b00010001; // 点亮第4 和 第8
            default: bit_ctrl = 8'h00;
        endcase
    end
    assign p7_0 = bit_ctrl;

    // --- 要显示的数字序列 (从输入的二进制数转换为 8 位 BCD) ---
    // Binary to BCD (double dabble) produces 8 decimal digits (0..9)
    function [31:0] bin2bcd; // returns 8 nibbles packed [31:0] = {d7,d6,...,d0}
        input [31:0] bin;
        integer i,j;
        reg [39:0] shift; // 40 bits: 8*4 + 8 extra for shifting
        begin
            shift = 40'd0;
            // shift in bits from MSB to LSB
            for (i = 31; i >= 0; i = i - 1) begin
                // add 3 to any nibble >=5
                for (j = 0; j < 8; j = j + 1) begin
                    if (shift[(j*4)+:4] >= 5)
                        shift[(j*4)+:4] = shift[(j*4)+:4] + 3;
                end
                // shift left by 1 and bring in next binary bit
                shift = {shift[38:0], bin[i]};
            end
            // pack nibbles into 32-bit return (d7..d0)
            bin2bcd = {shift[31:28], shift[27:24], shift[23:20], shift[19:16], shift[15:12], shift[11:8], shift[7:4], shift[3:0]};
        end
    endfunction

    // --- Common-cathode segment map (gfedcba in low bits, dp is MSB=0) ---
    function [7:0] digit_to_cc;
        input [3:0] d;
        begin
            case(d)
                4'd0: digit_to_cc = 8'h3F; // 0
                4'd1: digit_to_cc = 8'h06; // 1
                4'd2: digit_to_cc = 8'h5B; // 2
                4'd3: digit_to_cc = 8'h4F; // 3
                4'd4: digit_to_cc = 8'h66; // 4
                4'd5: digit_to_cc = 8'h6D; // 5
                4'd6: digit_to_cc = 8'h7D; // 6
                4'd7: digit_to_cc = 8'h07; // 7
                4'd8: digit_to_cc = 8'h7F; // 8
                4'd9: digit_to_cc = 8'h6F; // 9
                default: digit_to_cc = 8'h00;
            endcase
        end
    endfunction

    // --- bit reverse helper: convert LSB-first map to MSB-first wiring used on board ---
    function [7:0] rev8;
        input [7:0] x;
        begin
            rev8 = {x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7]};
        end
    endfunction

    // --- 两个段选输出，根据扫描从输入的 value 中提取对应的 BCD 数字 ---
    reg [31:0] bcd_packed; // packed d7..d0
    reg [3:0] digit_vals [7:0];
    integer k;
    always @(*) begin
        bcd_packed = bin2bcd(value);
        for (k = 0; k < 8; k = k + 1) begin
            digit_vals[k] = bcd_packed[ (7-k)*4 +: 4 ]; // d7 at MSB
        end
    end

    reg [7:0] seg_l, seg_r;
    always @(*) begin
        // 左组 digit index = scan_sel (0..3)
        seg_l = rev8(digit_to_cc(digit_vals[scan_sel]));
    end

    always @(*) begin
        // 右组 digit index = scan_sel + 4
        seg_r = rev8(digit_to_cc(digit_vals[scan_sel + 4]));
        // 末位显示小数点：总时间以十分之一秒显示，最后一个数码管为小数位
        if (scan_sel == 2'd2)
            seg_r = seg_r | 8'h01;
    end

    assign p7_1 = seg_l;
    assign p7_2 = seg_r;

endmodule 