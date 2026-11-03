

module sipo_10bit_mntc(
    input           clk,
    input           rst_n,
    input           ser_in,
    input           en_in,
    output reg [9:0] par_out,
    output reg      valid_sipo_out
);
    reg [9:0] shift_reg;
    reg [3:0] bit_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 10'b0;
            par_out   <= 10'b0; 
            valid_sipo_out <= 1'b0;
            bit_cnt   <= 4'd0;
        end else begin
            valid_sipo_out <= 1'b0; // По умолчанию сбрасываем флаг
            if (en_in) begin
                shift_reg <= {ser_in, shift_reg[9:1]};
                if (bit_cnt == 4'd9) begin
                    par_out <= {ser_in, shift_reg[9:1]};
                    valid_sipo_out <= 1'b1; // Поднимаем флаг готовности на 1 такт
                    bit_cnt <= 4'd0;
                end else begin
                    bit_cnt <= bit_cnt + 4'd1;
                end
            end else begin
                bit_cnt <= 4'd0; // Если передача прервалась, сбрасываем счетчик
            end
        end
    end
endmodule