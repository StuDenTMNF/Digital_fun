
module sprinkler_controller (
  // --- Интерфейс ---
  input clk,               // Системный тактовый сигнал
  input rst,             // Асинхронный сброс
  input start_button,      // Кнопка для запуска цикла
  output reg valve_A_open, // Выход на клапан А
  output reg valve_B_open  // Выход на клапан Б
);

  
  localparam IDLE         = 2'd0;
  localparam WATERING_A   = 2'd1;
  localparam PAUSE        = 2'd2;
  localparam WATERING_B   = 2'd3;

  // --- 2. Определяем время в тактах clk ---
  // Пусть 1 "условная секунда" = 1_000_000 тактов clk (для 1МГц клока)
  // Для симуляции можно поставить значения поменьше, например, 10 и 5.
  localparam DURATION_10_SEC = 32'd100; // 10 секунд
  localparam DURATION_5_SEC  = 32'd50;  // 5 секунд

  // --- 3. Регистры для состояний и таймера ---
  reg [1:0] state, next_state;    // Текущее и следующее состояние FSM
  reg [31:0] timer_cnt;           // 32-битный счётчик для отсчёта времени
  wire timer_done;                // Флаг, что таймер закончил считать

  // --- 4. Логика Таймера  ---
  // Этот блок отвечает за отсчёт времени.
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      timer_cnt <= 32'd0;
    // Таймер сбрасывается при любом переходе в новое состояние
    end else if (state != next_state) begin 
      timer_cnt <= 32'd0;
    // Таймер считает, только когда мы находимся в состояниях, требующих ожидания
    end else if (state == WATERING_A || state == PAUSE || state == WATERING_B) begin
      if (!timer_done) begin // Не даём счётчику переполняться
          timer_cnt <= timer_cnt + 1;
      end
    end else begin
      timer_cnt <= 32'd0;
    end
  end

  
  // Комбинационная логика для флага timer_done.
  // Флаг поднимается, когда счётчик достиг нужного значения.
  assign timer_done = 
         (state == WATERING_A && timer_cnt == DURATION_10_SEC) ||
         (state == PAUSE      && timer_cnt == DURATION_5_SEC)  ||
         (state == WATERING_B && timer_cnt == DURATION_10_SEC);

  // --- 5. Логика переходов состояний  ---
  always @(*) begin
    next_state = state; // По умолчанию остаёмся в том же состоянии
    case (state)
	 
      IDLE: begin
        if (start_button) begin
          next_state = WATERING_A;
        end
      end
		
      WATERING_A: begin
        if (timer_done) begin
          next_state = PAUSE;
        end
      end
		
      PAUSE: begin
        if (timer_done) begin
          next_state = WATERING_B;
        end
      end
		
      WATERING_B: begin
        if (timer_done) begin
          next_state = IDLE;
        end
      end
		
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // --- 6. Обновление состояния по тактовому сигналу  ---
 
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // --- 7. Логика выходов ( Автомат Мура) ---
  
  always @(*) begin
    // По умолчанию всё выключено
    valve_A_open = 1'b0;
    valve_B_open = 1'b0;
	 
    case (state)
	 
      WATERING_A: begin
        valve_A_open = 1'b1;
      end
		
      WATERING_B: begin
        valve_B_open = 1'b1;
      end
		
      // В состояниях IDLE и PAUSE клапаны закрыты по умолчанию
    endcase
  end

endmodule
