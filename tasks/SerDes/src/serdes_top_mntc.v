`default_nettype none

module serdes_top_mntc (
    input  wire       clk,
    input  wire       rst_n,

    // Входной интерфейс передатчика (TX)
    input  wire       valid_in,
    input  wire       k_in,
    input  wire [7:0] data_in,
    output wire       tx_busy,      // Опционально: статус занятости PISO

    // Выходной интерфейс приемника (RX)
    output wire       valid_out,
    output wire       k_out,
    output wire [7:0] data_out,
    output wire       code_err
);

    // Внутренние соединения
    wire [9:0] enc_data_10b;
    wire       enc_valid;
    wire       serial_line;
    wire       piso_busy;
    wire [9:0] sipo_data_10b;
    wire       sipo_valid;

    assign tx_busy = piso_busy;

    // 1. Энкодер 8B/10B
    encoder_8b10b_mntc u_encoder (
        .clk          (clk),
        .rst_n        (rst_n),
        .k            (k_in),
        .data_in      (data_in),
        .valid_in     (valid_in),
        .data_10b_out (enc_data_10b),
        .valid_out    (enc_valid)
    );

    // 2. Сериализатор (PISO)
    piso_10bit_mntc u_piso (
        .clk          (clk),
        .rst_n        (rst_n),
        .par_in       (enc_data_10b),
        .load_en      (enc_valid),
        .ser_out      (serial_line),
        .busy         (piso_busy)
    );

    // 3. Десериализатор (SIPO)
    sipo_10bit_mntc u_sipo (
        .clk            (clk),
        .rst_n          (rst_n),
        .ser_in         (serial_line),
        .en_in          (piso_busy),
        .par_out        (sipo_data_10b),
        .valid_sipo_out (sipo_valid)
    );

    // 4. Декодер 10B/8B
    decoder_10b8b_mntc u_decoder (
        .clk          (clk),
        .rst_n        (rst_n),
        .data_10b_in  (sipo_data_10b),
        .valid_in     (sipo_valid),
        .k            (k_out),
        .data_8b_out  (data_out),
        .valid_out    (valid_out),
        .code_err     (code_err)
    );

endmodule

`default_nettype wire