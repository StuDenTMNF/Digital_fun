

module piso_10bit_mntc(
    input           clk,
    input           rst_n,
    input [9:0]     par_in,
    input           load_en,
    output          ser_out, 
    output reg      busy
);
    reg [9:0] shift_reg;
    reg [3:0] bit_cnt;

    // Комбинационный выход: младший бит всегда смотрит наружу
    assign ser_out = shift_reg[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 10'b0;
            bit_cnt   <= 4'd0;
            busy      <= 1'b0;
        end else if (load_en) begin
            shift_reg <= par_in;
            busy      <= 1'b1;
            bit_cnt   <= 4'd0;
        end else if (busy) begin
            if (bit_cnt == 4'd9) begin
                busy    <= 1'b0; // Передача окончена
                // На 10-м такте мы уже ничего не сдвигаем
            end else begin
                shift_reg <= {1'b0, shift_reg[9:1]};
                bit_cnt   <= bit_cnt + 4'd1;
            end
        end
    end
endmodule