

 
 `default_nettype none

module encoder_8b10b_mntc (
    input wire       clk,
    input wire       rst_n,    // Изменил с inout на input, так как это стандарт для сброса
    input wire       k,     // флаг о том, что пришел спец код
    input wire [7:0] data_in,  // младшие(x) 5 бит и старшие(y) 3 бита
    input wire       valid_in, // готовность загрузки данных

    output reg [9:0] data_10b_out,
    output reg       valid_out // данные готовы к отправке
);

    // Внутренние регистры для хранения состояния дисперсии
    reg rd_reg; // Running disparity

    // Промежуточные сигналы для комбинаторной логики
    reg [5:0] code_6b;
    reg [3:0] code_4b;
    reg       rd_after_6b;
    reg       rd_final;

	 
	 
	 
	 
   
    always @(*) begin
        // Значения по умолчанию
        code_6b     = 6'b000000;
        code_4b     = 4'b0000;
        rd_after_6b = rd_reg;
        rd_final    = rd_after_6b;

        // 1. Сначала вычисляем блок 6b (биты abcdei). Нейтральные коды.
        case(data_in[4:0])
            5'b00011: begin code_6b = 6'b110001; rd_after_6b = rd_reg; end // D.03 checking with rd.275.0440.pdf
            5'b00101: begin code_6b = 6'b101001; rd_after_6b = rd_reg; end // D.05 checking with rd.275.0440.pdf
            5'b00110: begin code_6b = 6'b011001; rd_after_6b = rd_reg; end // D.06 checking with rd.275.0440.pdf
            5'b01001: begin code_6b = 6'b100101; rd_after_6b = rd_reg; end // D.09 checking with rd.275.0440.pdf
            5'b01010: begin code_6b = 6'b010101; rd_after_6b = rd_reg; end // D.10 checking with rd.275.0440.pdf
            5'b01011: begin code_6b = 6'b110100; rd_after_6b = rd_reg; end // D.11 checking with rd.275.0440.pdf
            5'b01100: begin code_6b = 6'b001101; rd_after_6b = rd_reg; end // D.12 checking with rd.275.0440.pdf
            5'b01101: begin code_6b = 6'b101100; rd_after_6b = rd_reg; end // D.13 checking with rd.275.0440.pdf
            5'b01110: begin code_6b = 6'b011100; rd_after_6b = rd_reg; end // D.14 checking with rd.275.0440.pdf
            5'b10001: begin code_6b = 6'b100011; rd_after_6b = rd_reg; end // D.17 checking with rd.275.0440.pdf
            5'b10010: begin code_6b = 6'b010011; rd_after_6b = rd_reg; end // D.18 checking with rd.275.0440.pdf
            5'b10011: begin code_6b = 6'b110010; rd_after_6b = rd_reg; end // D.19 checking with rd.275.0440.pdf
            5'b10100: begin code_6b = 6'b001011; rd_after_6b = rd_reg; end // D.20 checking with rd.275.0440.pdf
            5'b10101: begin code_6b = 6'b101010; rd_after_6b = rd_reg; end // D.21 checking with rd.275.0440.pdf
            5'b10110: begin code_6b = 6'b011010; rd_after_6b = rd_reg; end // D.22 checking with rd.275.0440.pdf
            5'b11001: begin code_6b = 6'b100110; rd_after_6b = rd_reg; end // D.25 checking with rd.275.0440.pdf
            5'b11010: begin code_6b = 6'b010110; rd_after_6b = rd_reg; end // D.26 checking with rd.275.0440.pdf
				5'b00111: begin code_6b = rd_reg ? 6'b000111 : 6'b111000; rd_after_6b = rd_reg; end // D.07 checking with rd.275.0440.pdf
            
				5'b11100: if (k == 1'b1) begin code_6b = rd_reg ? 6'b110000 : 6'b001111; rd_after_6b = ~rd_reg; end  
							 else begin code_6b = 6'b001110; rd_after_6b = rd_reg; end // D.28 checking with rd.275.0440.pdf
            
            // Не нейтральные коды (RD меняется)
				5'b00000: begin code_6b = rd_reg ? 6'b011000 : 6'b100111; rd_after_6b = ~rd_reg; end // D.00 checking with rd.275.0440.pdf
				5'b00001: begin code_6b = rd_reg ? 6'b100010 : 6'b011101; rd_after_6b = ~rd_reg; end // D.01 checking with rd.275.0440.pdf
				5'b00010: begin code_6b = rd_reg ? 6'b010010 : 6'b101101; rd_after_6b = ~rd_reg; end // D.02 checking with rd.275.0440.pdf
				5'b00100: begin code_6b = rd_reg ? 6'b001010 : 6'b110101; rd_after_6b = ~rd_reg; end // D.04 checking with rd.275.0440.pdf
				5'b01000: begin code_6b = rd_reg ? 6'b000110 : 6'b111001; rd_after_6b = ~rd_reg; end // D.08 checking with rd.275.0440.pdf
				5'b01111: begin code_6b = rd_reg ? 6'b101000 : 6'b010111; rd_after_6b = ~rd_reg; end // D.15 checking with rd.275.0440.pdf 
				5'b10000: begin code_6b = rd_reg ? 6'b100100 : 6'b011011; rd_after_6b = ~rd_reg; end // D.16 checking with rd.275.0440.pdf. And this need validating
				5'b10111: begin code_6b = rd_reg ? 6'b000101 : 6'b111010; rd_after_6b = ~rd_reg; end // D.23 checking with rd.275.0440.pdf. And this need validating
				5'b11000: begin code_6b = rd_reg ? 6'b001100 : 6'b110011; rd_after_6b = ~rd_reg; end // D.24 checking with rd.275.0440.pdf
				5'b11011: begin code_6b = rd_reg ? 6'b001001 : 6'b110110; rd_after_6b = ~rd_reg; end // D.27 checking with rd.275.0440.pdf. And this need validating
				5'b11101: begin code_6b = rd_reg ? 6'b010001 : 6'b101110; rd_after_6b = ~rd_reg; end // D.29 checking with rd.275.0440.pdf. And this need validating
				5'b11110: begin code_6b = rd_reg ? 6'b100001 : 6'b011110; rd_after_6b = ~rd_reg; end // D.30 checking with rd.275.0440.pdf. And this need validating
				5'b11111: begin code_6b = rd_reg ? 6'b010100 : 6'b101011; rd_after_6b = ~rd_reg; end // D.31 checking with rd.275.0440.pdf. And this need validating
				default: begin code_6b = 6'b000000; rd_after_6b = ~rd_reg; end
				
				//If K code in input pin
				
				endcase

        // 2. Теперь вычисляем блок 4b (биты fghj), используя rd_after_6b
		  case (data_in[7:5])
            3'b000: begin // D/K.x.0 (D0 = +/-2, меняет RD)
                code_4b  = rd_after_6b ? 4'b0100 : 4'b1011;
                rd_final = ~rd_after_6b;
            end

            3'b001: begin // D.x.1 / K.28.1 (D0 = 0, RD не меняется)
                code_4b  = (k && !rd_after_6b) ? 4'b0110 : 4'b1001;
                rd_final = rd_after_6b;
            end

            3'b010: begin // D.x.2 / K.28.2 (D0 = 0, RD не меняется)
                code_4b  = (k && !rd_after_6b) ? 4'b1010 : 4'b0101;
                rd_final = rd_after_6b;
            end

            3'b011: begin // D/K.x.3 (D0 = 0, RD НЕ меняется, но маска зависит от rd_after_6b)
                code_4b  = rd_after_6b ? 4'b0011 : 4'b1100;
                rd_final = rd_after_6b; 
            end

            3'b100: begin // D/K.x.4 (D0 = +/-2, меняет RD)
                code_4b  = rd_after_6b ? 4'b0010 : 4'b1101;
                rd_final = ~rd_after_6b;
            end

            3'b101: begin // D.x.5 / K.28.5 (D0 = 0, RD не меняется)
                code_4b  = (k && !rd_after_6b) ? 4'b0101 : 4'b1010;
                rd_final = rd_after_6b;
            end

            3'b110: begin // D.x.6 / K.28.6 (D0 = 0, RD не меняется)
                code_4b  = (k && !rd_after_6b) ? 4'b1001 : 4'b0110;
                rd_final = rd_after_6b;
            end

            3'b111: begin // D.x.P7 / D/K.y.A7 (D0 = +/-2, меняет RD)
                // Условие выбора A7: K=1 ИЛИ (e=i=1 при RD6=-) ИЛИ (e=i=0 при RD6=+)
                if (k ||
                   (!rd_after_6b && (code_6b[1:0] == 2'b11)) ||
                   ( rd_after_6b && (code_6b[1:0] == 2'b00))) begin
                    // Alternate A7
                    code_4b = rd_after_6b ? 4'b1000 : 4'b0111;
                end else begin
                    // Primary P7
                    code_4b = rd_after_6b ? 4'b0001 : 4'b1110;
                end
                rd_final = ~rd_after_6b;
            end

            default: begin
                code_4b  = 4'b0000;
                rd_final = rd_after_6b;
            end
        endcase
    end

    // --- ПОСЛЕДОВАТЕЛЬНАЯ ЛОГИКА  ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_reg        <= 1'b0;
            data_10b_out  <= 10'b0;
            valid_out     <= 1'b0;
        end else if (valid_in) begin
            rd_reg        <= rd_final;
            data_10b_out  <= {code_6b, code_4b}; // Склеиваем 4 и 6 бит
            valid_out     <= 1'b1;
        end else begin
            valid_out     <= 1'b0;
				
				
        end
    end

endmodule

`default_nettype none
 