`timescale 1ns / 1ps

module tb_encoder_8b_10b;   

reg         clk;
reg         rst_n;
reg  [7:0]  data_in;
reg         k;
reg         valid_in;
    
wire [9:0]  data_10b_out;
wire        valid_out;

encoder_8b10b_mntc DUT (
    .clk(clk),
    .rst_n(rst_n),
    .k(k),
    .data_in(data_in),
    .valid_in(valid_in),
    .data_10b_out(data_10b_out),
    .valid_out(valid_out)
);

always #5 clk = ~clk;


task check_encode;
    input [7:0] t_data;
    input       t_k;
    input [9:0] expected_10b;
begin 
    data_in = t_data;
    k = t_k;
    valid_in = 1; 
    @(posedge clk); 
	 
    #1;
    valid_in = 0; 
    if (valid_out === 1'b1 && data_10b_out === expected_10b) begin
    $display(" Success! Input: %h (k=%b) Output: %b (expected: %b) | rd_reg=%b rd_after=%b rd_final=%b", 
             t_data, t_k, data_10b_out, expected_10b, 
             DUT.rd_reg, DUT.rd_after_6b, DUT.rd_final);
end else begin
    $display(" FAIL! Input: %h (k=%b). Output: %b (expected: %b) | rd_reg=%b rd_after=%b rd_final=%b | Valid=%b",
             t_data, t_k, data_10b_out, expected_10b, 
             DUT.rd_reg, DUT.rd_after_6b, DUT.rd_final, valid_out);
end
    @(posedge clk);
end
endtask


initial begin
    $display("==========================================================");
    $display("            Start testing encoder 8b/10b");
    $display("==========================================================");
    clk = 0;
    rst_n = 0;
    data_in = 8'h00;
    k = 0;
    valid_in = 0;
    #20 rst_n = 1;          // исправлено rest_n -> rst_n_n
    @(posedge clk);
    
	 // =========================================================================
    // 1. Базовые коды данных D.x.0 (Проверка переключений RD)
    // Стартовое состояние: предполагаем rd_reg = 0 (RD-)
    // =========================================================================
    check_encode(8'h00, 1'b0, 10'b1001110100); // D.0.0 (RD-): 6b=100111(+), 4b=0100(-). rd_out = -
    check_encode(8'h01, 1'b0, 10'b0111010100); // D.1.0 (RD-): 6b=011101(+), 4b=0100(-). rd_out = -
    check_encode(8'h02, 1'b0, 10'b1011010100); // D.2.0 (RD-): 6b=101101(+), 4b=0100(-). rd_out = -
    check_encode(8'h03, 1'b0, 10'b1100011011); // D.3.0 (RD-): 6b=110001(0), 4b=1011(+). rd_out = +

    // --- Теперь текущая RD = +1 ---
    check_encode(8'h04, 1'b0, 10'b0010101011); // D.4.0 (RD+): 6b=001010(-), 4b=1011(+). rd_out = +
    check_encode(8'h05, 1'b0, 10'b1010010100); // D.5.0 (RD+): 6b=101001(0), 4b=0100(-). rd_out = -

    // --- Теперь текущая RD = -1 ---
    check_encode(8'h06, 1'b0, 10'b0110011011); // D.6.0 (RD-): 6b=011001(0), 4b=1011(+). rd_out = +
    
    // --- Теперь текущая RD = +1 ---
    check_encode(8'h07, 1'b0, 10'b0001110100); // D.7.0 (RD+): 6b=000111(0), 4b=0100(-). rd_out = -
    
    // --- Теперь текущая RD = -1 ---
    check_encode(8'h07, 1'b0, 10'b1110001011); // D.7.0 (RD-): 6b=111000(0), 4b=1011(+). rd_out = +
    
    // --- Теперь текущая RD = +1 ---
    check_encode(8'h08, 1'b0, 10'b0001101011); // D.8.0 (RD+): 6b=111001(-), 4b=1011(+). rd_out = +
    check_encode(8'h05, 1'b0, 10'b1010010100); // D.5.0 (RD+): Используем для сброса RD в минус. rd_out = -

    // =========================================================================
    // 2. Сложные исключения для D.x.7 (Primary P7 vs Alternate A7)
    // Текущая RD = -1
    // =========================================================================
    check_encode(8'hE3, 1'b0, 10'b1100011110); // D.3.7  (RD-): 6b=110001 (ei=01), Primary 1110(+). rd_out = +
    check_encode(8'hF1, 1'b0, 10'b1000110001); // D.17.7 (RD+): 6b=100011 (ei=11), Primary 0001(-). rd_out = -
    check_encode(8'hF1, 1'b0, 10'b1000110111); // D.17.7 (RD-): 6b=100011 (ei=11), Alternate A7 0111(+). rd_out = +
    check_encode(8'hEB, 1'b0, 10'b1101001000); // D.11.7 (RD+): 6b=110100 (ei=00), Alternate A7 1000(-). rd_out = -
    check_encode(8'hEB, 1'b0, 10'b1101001110); // D.11.7 (RD-): 6b=110100 (ei=00), Primary 1110(+). rd_out = +
    
    // Сбрасываем RD обратно в минус
    check_encode(8'h05, 1'b0, 10'b1010010100); // D.5.0 (RD+): rd_out = -

    // =========================================================================
    // 3. Все 12 специальных K-кодов
    // Текущая RD = -1
    // =========================================================================
    check_encode(8'h1C, 1'b1, 10'b0011110100); // K.28.0 (RD-): 6b=001111(+), 4b=0100(-). rd_out = -
    check_encode(8'h3C, 1'b1, 10'b0011111001); // K.28.1 (RD-): 6b=001111(+), 4b=1001(0). rd_out = +
    check_encode(8'h5C, 1'b1, 10'b1100001010); // K.28.2 (RD+): 6b=110000(-), 4b=0101(0). rd_out = -
    check_encode(8'h7C, 1'b1, 10'b0011110011); // K.28.3 (RD-): 6b=001111(+), 4b=0011(0). rd_out = +
    check_encode(8'h9C, 1'b1, 10'b1100001101); // K.28.4 (RD+): 6b=110000(-), 4b=1101(+). rd_out = +
    check_encode(8'hBC, 1'b1, 10'b1100000101); // K.28.5 (RD+): 6b=110000(-), 4b=0101(0). rd_out = -
    check_encode(8'hDC, 1'b1, 10'b0011110110); // K.28.6 (RD-): 6b=001111(+), 4b=0110(0). rd_out = +
    check_encode(8'hFC, 1'b1, 10'b1100000111); // K.28.7 (RD+): 6b=110000(-), 4b=0111(+). rd_out = +

    // Группа K.x.7 (всегда используют Alternate A7)
    // Текущая RD = +1
    check_encode(8'hF7, 1'b1, 10'b0001010111); // K.23.7 (RD+): 6b=000101(-), A7=0111(+). rd_out = +
    check_encode(8'hFB, 1'b1, 10'b0010010111); // K.27.7 (RD+): 6b=001001(-), A7=0111(+). rd_out = +
    check_encode(8'hFD, 1'b1, 10'b0100010111); // K.29.7 (RD+): 6b=010001(-), A7=0111(+). rd_out = +
    check_encode(8'hFE, 1'b1, 10'b1000010111); // K.30.7 (RD+): 6b=100001(-), A7=0111(+). rd_out = +

    // =========================================================================
    // 4. Проверка инверсной полярности для Comma-кодов
    // Текущая RD = +1
    // =========================================================================
    check_encode(8'h05, 1'b0, 10'b1010010100); // D.5.0 (RD+): Сбрасываем RD обратно в минус. rd_out = -
    check_encode(8'hBC, 1'b1, 10'b0011111010); // K.28.5 (RD-): 6b=001111(+), 4b=1010(0). rd_out = +
    check_encode(8'h3C, 1'b1, 10'b1100000110); // K.28.1 (RD+): 6b=110000(-), 4b=0110(0). rd_out = -

    $display("==========================================================");
    $display("             End testing encoder 8b/10b");
    $display("==========================================================");        
    #20 $finish;
end    


initial begin
    $dumpfile("encoder.vcd");
    $dumpvars(0, tb_encoder_8b_10b);
end

endmodule