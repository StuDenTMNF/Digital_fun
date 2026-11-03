`timescale 1ns / 1ps

module tb_decoder_10b_8b;

reg         clk;
reg         rst_n;
reg  [9:0]  data_10b_in;
reg         valid_in;
wire 			k;

wire [7:0]  data_8b_out;
wire        valid_out;
wire        code_err; 


decoder_10b8b_mntc DUT (
    .clk(clk),
    .rst_n(rst_n),
	 .k(k),
    .data_10b_in(data_10b_in),
    .valid_in(valid_in),
    .data_8b_out(data_8b_out),
    .valid_out(valid_out),
    .code_err(code_err)   
);


always #5 clk = ~clk;


task check_decode(input [9:0] in_10b, input [7:0] exp_8b, input exp_k);
        begin
            @(posedge clk);
            data_10b_in <= in_10b;
            valid_in    <= 1'b1;
            @(posedge clk);
            valid_in    <= 1'b0;
            @(posedge clk); 

            if (data_8b_out === exp_8b && k === exp_k && code_err === 1'b0) begin
                $display("[OK] 10b: %b -> output: %c.%02d.%0d (0x%02h)", 
                         in_10b, k ? "K" : "D", data_8b_out[4:0], data_8b_out[7:5], data_8b_out);
            end else begin
                $display("[FAIL] 10b: %b -> expected: %c (0x%02h), what we take: %c (0x%02h) | err=%b", 
                         in_10b, exp_k ? "K" : "D", exp_8b, k ? "K" : "D", data_8b_out, code_err);
            end
        end
    endtask

	 
	 task check_decode_error(input [9:0] in_10b);
        begin
            @(posedge clk);
            data_10b_in <= in_10b;
            valid_in    <= 1'b1;
            @(posedge clk);
            valid_in    <= 1'b0;
            @(posedge clk);

            if (code_err === 1'b1) begin
                $display("[OK] Error was correct find 10'b%b", in_10b);
            end else begin
                $display("[FAIL] Decoder cant mean error 10'b%b!", in_10b);
            end
        end
    endtask
	 

initial begin
    $display("==========================================================");
    $display("            Start testing DECODER 10b/8b");
    $display("==========================================================");
    clk = 0;
    rst_n = 0;
    data_10b_in = 10'b0;
    valid_in = 0;

    #20 rst_n = 1; 
    repeat(2) @(posedge clk);
    // =========================================================================
    // 1. Базовые коды данных D.x.y (Проверка прямой и инверсной полярности)
    // =========================================================================
    check_decode(10'b1001110100, 8'h00, 1'b0); // D.0.0 (из RD-)
    check_decode(10'b0110001011, 8'h00, 1'b0); // D.0.0 (из RD+)
    check_decode(10'b0111010100, 8'h01, 1'b0); // D.1.0 (из RD-)
    check_decode(10'b1011010100, 8'h02, 1'b0); // D.2.0 (из RD-)
    check_decode(10'b1100011011, 8'h03, 1'b0); // D.3.0 (из RD-)
    check_decode(10'b0010101011, 8'h04, 1'b0); // D.4.0 (из RD+)
    check_decode(10'b1010010100, 8'h05, 1'b0); // D.5.0 (из RD+)
    check_decode(10'b0110011011, 8'h06, 1'b0); // D.6.0 (из RD-)
    check_decode(10'b0001110100, 8'h07, 1'b0); // D.7.0 (из RD+)
    check_decode(10'b1110001011, 8'h07, 1'b0); // D.7.0 (из RD-)
    check_decode(10'b1110011011, 8'h08, 1'b0); // D.8.0 (из RD+)

    // =========================================================================
    // 2. Сложные исключения для D.x.7 (Primary P7 vs Alternate A7)
    // =========================================================================
    check_decode(10'b1100011110, 8'hE3, 1'b0); // D.3.7  (Primary P7)
    check_decode(10'b1000110001, 8'hF1, 1'b0); // D.17.7 (Primary P7)
    check_decode(10'b1000110111, 8'hF1, 1'b0); // D.17.7 (Alternate A7, из RD-)
    check_decode(10'b1101001000, 8'hEB, 1'b0); // D.11.7 (Alternate A7, из RD+)
    check_decode(10'b1101001110, 8'hEB, 1'b0); // D.11.7 (Primary P7)

    // =========================================================================
    // 3. Все 12 специальных K-кодов (С проверкой флага K=1)
    // =========================================================================
    check_decode(10'b0011110100, 8'h1C, 1'b1); // K.28.0 (из RD-)
    check_decode(10'b1100001011, 8'h1C, 1'b1); // K.28.0 (из RD+)
    check_decode(10'b0011111001, 8'h3C, 1'b1); // K.28.1 (из RD-)
    check_decode(10'b1100000110, 8'h3C, 1'b1); // K.28.1 (из RD+)
    check_decode(10'b1100000101, 8'hbc, 1'b1); // K.28.2 (из RD+)
    check_decode(10'b0011111010, 8'hbC, 1'b1); // K.28.2 (из RD-)
    check_decode(10'b0011110011, 8'h7C, 1'b1); // K.28.3 (из RD-)
    check_decode(10'b1100001101, 8'h9C, 1'b1); // K.28.4 (из RD+)
    check_decode(10'b0011111010, 8'hBC, 1'b1); // K.28.5 (Comma, из RD-)
    check_decode(10'b1100000101, 8'hBC, 1'b1); // K.28.5 (Comma, из RD+)
    check_decode(10'b0011110110, 8'hDC, 1'b1); // K.28.6 (из RD-)
    check_decode(10'b1100000111, 8'hFC, 1'b1); // K.28.7 (из RD+)

    // Группа K.x.7 (всегда используют Alternate A7)
    check_decode(10'b0001010111, 8'hF7, 1'b1); // K.23.7 (из RD+)
    check_decode(10'b1110101000, 8'hF7, 1'b1); // K.23.7 (из RD-)
    check_decode(10'b0010010111, 8'hFB, 1'b1); // K.27.7 (из RD+)
    check_decode(10'b0100010111, 8'hFD, 1'b1); // K.29.7 (из RD+)
    check_decode(10'b1000010111, 8'hFE, 1'b1); // K.30.7 (из RD+)

    // =========================================================================
    // 4. Проверка детекции аппаратных ошибок (code_err)
    // =========================================================================
    check_decode_error(10'b1111111111); // Несуществующий код (ошибка и в 6B, и в 4B)
    check_decode_error(10'b0000000000); // Строгие нули (Run Length > 5)
    check_decode_error(10'b0011111110); // K.28.7, но с Primary P7 (запрещено стандартом)

    $display("==========================================================");
    $display("             End testing DECODER 10b/8b");
    $display("==========================================================");        
    #50 $finish;
end    


initial begin
    $dumpfile("decoder.vcd");
    $dumpvars(0, tb_decoder_10b_8b);
end

endmodule