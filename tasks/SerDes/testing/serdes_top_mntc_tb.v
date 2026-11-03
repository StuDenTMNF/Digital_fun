`timescale 1ns / 1ps
`default_nettype none

module tb_serdes_top_mntc;

    // -------------------------------------------------------------------------
    // 1. Сигналы подключения к Top-модулю (только внешние пины!)
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg        valid_in;
    reg        k_in;
    reg  [7:0] data_in;
    wire       tx_busy;

    wire       valid_out;
    wire       k_out;
    wire [7:0] data_out;
    wire       code_err;

    
    serdes_top_mntc dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .k_in      (k_in),
        .data_in   (data_in),
        .tx_busy   (tx_busy),
        .valid_out (valid_out),
        .k_out     (k_out),
        .data_out  (data_out),
        .code_err  (code_err)
    );

    // Генерация тактового сигнала: 100 МГц (период 10 нс)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // 2. Очередь (Scoreboard FIFO) для наглядного сравнения ВХОДА и ВЫХОДА
    // -------------------------------------------------------------------------
    reg [8:0] fifo_mem [0:1023]; // Хранит {k_in, data_in[7:0]}
    integer   wr_ptr = 0;
    integer   rd_ptr = 0;
    integer   tx_count = 0;
    integer   rx_count = 0;
    integer   err_count = 0;

    // Специальные сигналы для окна Waveform (выравнивают отправленный байт с принятым!)
    reg [7:0] exp_data_out;
    reg       exp_k_out;
    reg       match_ok;

    // Запись в очередь в момент отправки в Top-модуль
    always @(posedge clk) begin
        if (rst_n && valid_in) begin
            fifo_mem[wr_ptr] <= {k_in, data_in};
            wr_ptr           <= (wr_ptr + 1) % 1024;
            tx_count         <= tx_count + 1;
        end
    end

    // Чтение из очереди и автоматическая проверка в момент появления valid_out
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_data_out <= 8'h00;
            exp_k_out    <= 1'b0;
            match_ok     <= 1'b1;
        end else if (valid_out) begin
            {exp_k_out, exp_data_out} = fifo_mem[rd_ptr];
            rd_ptr                    = (rd_ptr + 1) % 1024;
            rx_count                  = rx_count + 1;

            if (data_out === exp_data_out && k_out === exp_k_out && code_err === 1'b0) begin
                match_ok <= 1'b1;
                $display("[%0t ns] #%0d | input: %s.%02d.%0d (k=%b, 0x%02h) ---> output: %s.%02d.%0d (k=%b, 0x%02h) | err=%b | [OK]",
                         $time, rx_count,
                         exp_k_out ? "K" : "D", exp_data_out[4:0], exp_data_out[7:5], exp_k_out, exp_data_out,
                         k_out     ? "K" : "D", data_out[4:0],     data_out[7:5],     k_out,     data_out,
                         code_err);
            end else begin
                match_ok <= 1'b0;
                err_count = err_count + 1;
                $display("[%0t ns] #%0d | error! input: %s.%02d.%0d (k=%b, 0x%02h) ---> output: %s.%02d.%0d (k=%b, 0x%02h) | err=%b | [FAIL]",
                         $time, rx_count,
                         exp_k_out ? "K" : "D", exp_data_out[4:0], exp_data_out[7:5], exp_k_out, exp_data_out,
                         k_out     ? "K" : "D", data_out[4:0],     data_out[7:5],     k_out,     data_out,
                         code_err);
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. Базовые задачи (Tasks) для генерации трафика
    // -------------------------------------------------------------------------
    // Функция упаковки нотации D/K.x.y в 8-битный байт {y[2:0], x[4:0]}
    function [7:0] sym(input [4:0] x, input [2:0] y);
        sym = {y, x};
    endfunction

    // Задача отправки одного байта через вход топового модуля
    task send_symbol(input is_k, input [7:0] payload);
        begin
            @(posedge clk);
            valid_in <= 1'b1;
            k_in     <= is_k;
            data_in  <= payload;
            @(posedge clk);
            valid_in <= 1'b0;
            k_in     <= 1'b0;
            data_in  <= 8'h00;

            // Ждем окончания сериализации 10 бит (11 тактов между подачами)
            repeat (11) @(posedge clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // 4. Генераторы тестовых паттернов
    // -------------------------------------------------------------------------
    // Паттерн 1: Все 12 специальных K-символов стандарта 8B/10B
    task run_k_codes_pattern;
        begin
            $display("\n================ pattern 1: all K-codes ================");
            send_symbol(1'b1, sym(5'd28, 3'd0)); // K.28.0
            send_symbol(1'b1, sym(5'd28, 3'd1)); // K.28.1 (Comma)
            send_symbol(1'b1, sym(5'd28, 3'd2)); // K.28.2
            send_symbol(1'b1, sym(5'd28, 3'd3)); // K.28.3
            send_symbol(1'b1, sym(5'd28, 3'd4)); // K.28.4
            send_symbol(1'b1, sym(5'd28, 3'd5)); // K.28.5 (Main Comma)
            send_symbol(1'b1, sym(5'd28, 3'd6)); // K.28.6
            send_symbol(1'b1, sym(5'd28, 3'd7)); // K.28.7 (Comma)
            send_symbol(1'b1, sym(5'd23, 3'd7)); // K.23.7
            send_symbol(1'b1, sym(5'd27, 3'd7)); // K.27.7
            send_symbol(1'b1, sym(5'd29, 3'd7)); // K.29.7
            send_symbol(1'b1, sym(5'd30, 3'd7)); // K.30.7
        end
    endtask

    // Паттерн 2: Специальные стресс-паттерны (Idle меандр, бегущая 1, бегущий 0)
    task run_bit_patterns;
        integer b;
        begin
            $display("\n================ pattern 2: byte pattern (IDLE / WALKING 1 & 0) ================");
            // D.21.5 (1010101010) и D.10.2 (0101010101) — максимальная частота переключений
            send_symbol(1'b0, sym(5'd21, 3'd5));
            send_symbol(1'b0, sym(5'd10, 3'd2));
            send_symbol(1'b0, 8'h00); // Все нули (D.00.0)
            send_symbol(1'b0, 8'hFF); // Все единицы (D.31.7)
            send_symbol(1'b0, 8'h55); // Шахматный код 01010101
            send_symbol(1'b0, 8'hAA); // Шахматный код 10101010

            // Бегущая единица (Walking 1) и бегущий ноль (Walking 0)
            for (b = 0; b < 8; b = b + 1) begin
                send_symbol(1'b0, (8'h01 << b));
                send_symbol(1'b0, ~(8'h01 << b));
            end
        end
    endtask

    // Паттерн 3: Имитация реального кадра передачи данных (Frame Packet)
    task run_packet_pattern(input integer payload_len);
        integer p;
        begin
            $display("\n================ pattern 3: data of real packets (IDLE -> SOP -> PAYLOAD -> EOP) ================");
            // 1. Синхронизация (2 символа Comma K.28.5)
            send_symbol(1'b1, sym(5'd28, 3'd5));
            send_symbol(1'b1, sym(5'd28, 3'd5));
            // 2. Маркер начала пакета (SOP = K.28.1)
            send_symbol(1'b1, sym(5'd28, 3'd1));
            // 3. Полезная нагрузка (Payload)
            for (p = 1; p <= payload_len; p = p + 1) begin
                send_symbol(1'b0, (p * 8'h11) ^ 8'hA5);
            end
            // 4. Маркер конца пакета (EOP = K.29.7) и возврат в IDLE (K.28.5)
            send_symbol(1'b1, sym(5'd29, 3'd7));
            send_symbol(1'b1, sym(5'd28, 3'd5));
        end
    endtask

    // Паттерн 4: Полный перебор всех 256 байт данных (дважды для проверки обеих RD)
    task run_full_data_sweep;
        integer val;
        begin
            $display("\n================ pattern 4: A COMPLETE CHECK OF ALL 256 BYTES OF DATA (0x00..0xFF) ================");
            for (val = 0; val < 256; val = val + 1) begin
                send_symbol(1'b0, val[7:0]);
            end
        end
    endtask

    // Паттерн 5: Псевдослучайная последовательность (PRBS / Random Data + Random Valid K)
    task run_random_prbs_pattern(input integer num_transactions);
        integer n;
        reg [7:0] rand_byte;
        reg [3:0] k_idx;
        begin
            $display("\n================ pattern 5: pseudorandom flow (%0d transactions) ================", num_transactions);
            for (n = 0; n < num_transactions; n = n + 1) begin
                if (($urandom % 5) == 0) begin
                    // С вероятностью 20% отправляем случайный валидный K-код
                    k_idx = $urandom % 11; // Исключаем два K.28.7 подряд по правилу стандарта
                    case (k_idx)
                        4'd0:  send_symbol(1'b1, sym(5'd28, 3'd0));
                        4'd1:  send_symbol(1'b1, sym(5'd28, 3'd1));
                        4'd2:  send_symbol(1'b1, sym(5'd28, 3'd2));
                        4'd3:  send_symbol(1'b1, sym(5'd28, 3'd3));
                        4'd4:  send_symbol(1'b1, sym(5'd28, 3'd4));
                        4'd5:  send_symbol(1'b1, sym(5'd28, 3'd5));
                        4'd6:  send_symbol(1'b1, sym(5'd28, 3'd6));
                        4'd7:  send_symbol(1'b1, sym(5'd23, 3'd7));
                        4'd8:  send_symbol(1'b1, sym(5'd27, 3'd7));
                        4'd9:  send_symbol(1'b1, sym(5'd29, 3'd7));
                        default: send_symbol(1'b1, sym(5'd30, 3'd7));
                    endcase
                end else begin
                    // С вероятностью 80% отправляем случайный байт данных
                    rand_byte = $urandom;
                    send_symbol(1'b0, rand_byte);
                end
            end
        end
    endtask

    
    initial begin
        
        rst_n    = 1'b0;
        valid_in = 1'b0;
        k_in     = 1'b0;
        data_in  = 8'h00;

        
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        
        run_k_codes_pattern();
        run_bit_patterns();
        run_packet_pattern(8);
        run_full_data_sweep();
        run_random_prbs_pattern(50);

        
        repeat (25) @(posedge clk);

        
        $display("\n================================================================================");
        $display(" test results SERDES TOP:");
        $display("   words send : %0d", tx_count);
        $display("   words accept    : %0d", rx_count);
        $display("   mismatch: %0d", err_count);
        if (err_count == 0 && tx_count == rx_count && tx_count > 0)
            $display("   status          : *** test success !!!! ***");
        else
            $display("   status          : !!!  TEST FAILED)!!!");
        $display("================================================================================\n");

        $finish;
    end

	 initial begin
    $dumpfile("serdes_top.vcd");
    $dumpvars(0, tb_serdes_top_mntc);
end
	 
endmodule

`default_nettype wire