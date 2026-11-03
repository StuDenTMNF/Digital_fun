# 8b/10b Serializer deserializer (SerDes)

### Содержание
1. [Теория](#теория)
   - [Задачи SerDes](#задачи-serdes)
   - [Устройство 8b/10b SerDes](#устройство-8b10b-serdes)
   - [8b/10b Encoder](#8b10b-encoder)
   - [3b/4b Encoder](#3b4b-encoder)
   - [Тестирование encoder 8b/10b](#тестирование-encoder-8b10b)
2. [10b/8b Decoder](#10b8b-decoder)
   - [Декодирование 6b/5b](#декодирование-6b5b)
   - [Декодирование 4b/3b](#декодирование-4b3b)
   - [Тестирование decoder 10b/8b](#тестирование-decoder-10b8b)
3. [Тестирование SerDes Top](#тестирование-serdes-top)

---

## Теория

Сериализатор десериализатор - это цифро-аналоговый блок системы передачи данных. Такое определение вы встретите в инженерной среде. Такое определение я дал ему при написании курсовой работы на тему физического проектирования цифрового блока системы передачи данных. В реальности у этого блока есть несколько важных свойства и задач, которые он должен выполнять. Мы будем рассматривать общую концепцию блока и его цифровую часть.



### задачи SerDes:

1. **Кодирование и декодирование**
> Устройство должно кодировать данный на входе и декодировать на выходе.

2. **Передавать данные на высокой скорости без потери качества данных**
> Об этом чуть чуть далее, так как  данная задача и определяет существование данного блока таким, каким он есть.

Чтобы данные задачи стали предельно понятными, разберемся с устройством цифровой части SerDes блока.

### Устройство 8b/10b SerDes

Сериализатор десериализатор можно представить так:


<img src=".\media\SerDes.svg" alt="SerDes" width="1300">


Вход состоит из 8и битного кода и указателя на определенный особенный код(K код), о нем будет рассказано в блоке энкодера. Внутри энкодера код переводится из базиса 8и битного кода в базис 10и битного кода. 

Далее 10 битный код параллельно отправляется в PISO(Parallel input Serial Output) блок, где формируется последовательный код, отправляемый в SIPO(Serial Input Parallel Output) блок.

SIPO формирует паралаллельный 10b код, который подается в Decoder 10b/8b и декодируется в 8и битный код, причем на выходе так же существует флаг, отвечающий за указание того, получен ли К код или нет.

**Потеря качества данных** - это самый важный аспект при работе данного блока. Для выполнения этого условия в блоке могут быть реализованы:

- Clock and Data Recovery(CDR). Аналоговый блок, отвечающий за подстраивание частоты принимающего(SIPO) блока под частоту принимаемых данных от передающего блока(PISO). 

- RX Amplifier (VGA) & Equalizer(CTLE / DFE). Входной усилитель с регулируемым коэффициентом, а также эквалайзеры для усиления затухших частот.

-  Особый тип кодирования. Определенные последовательности битов, по типу 1111111111 (0000000000) При передачи по serial data тракту заряжают конденсаторы на принимающей стороне, из-за чего принимающая сторона менее восприимчива к остальной части кода. Данная проблема приводит к особой теории кодирования, которая и будет реализована нами в рамках работы  энкодером и декодером.

**8b/10b encoder**

Принципиальная рабочая схема:

<img src=".\media\encoder.svg" alt="Encoder" width="700">



 Для того, чтобы передаваемый код корректно обрабатывался принимающим блоком сумма нулей и единиц должна быть одинакова. Как это сделать?

Реализуется 8b/10b кодирование - стандартный подход в данном случае. Принцип работы:

1. Вводится переменная running disparity (RD) - данная переменная отвечает за разницу в количестве единиц и нулей в передаваемом коде. $RD \in [-1 : +1]$

2. Вводится понятие о D.x.y и K.x.y кодах. Где x - это data_6b(так же их называют abcdei), а н - это data_4b (так же называют fghj) на схеме соответственно.

Disparity (D) - Код с текущей разницей по количеству единиц и нулей. 
Например:

```
1110000111 - Disparity = +2
0001100101 - Disparity = -2
```
#### Принцип работы идеи о RD

| текущий RD | Disparity текущего слова | какую Disparity  выбираем| следующий RD |
|:-----------:|:----------------------:|:----------------:|:-------:|
| −1          | 0                      | 0                | −1      |
| −1          | ±2                     | +2               | +1      |
| +1          | 0                      | 0                | +1      |
| +1          | ±2                     | −2               | −1      |

При кодировании RD всегда:

* Меняется на противположное

* Остается неизменным 
Это означает, что описать работу данного сигнала можно двубитным сигналом, что и делаем в модуле encoder_8b_10b

```verilog
reg rd_reg;
```

Если ```rd_reg = 1'b0```, то $RD=-1$. 

Если же ```rd_reg = 1'b1``` то $RD=+1$

Аналогичным образом устроены rd_after_6b и  rd_final.

RD меняется два раза в модуле энкодера.

Как выбирается код на основании информации о RD? У каждого кода есть его противоположность, так у последовательности ```111001 (D.08)``` Существует противоположность в виде ```000110 (D.08)```, но оба кода в 6и битном кодировании определяют один 5и битный код ```01000```.

Рассмотрим таблицу

#### 5b/6b code (EDCBA) to abcdei

| Input<br>Code | Input<br>EDCBA | RD = −1<br>abcdei | RD = +1<br>abcdei | Input<br>Code | Input<br>EDCBA | RD = −1<br>abcdei | RD = +1<br>abcdei |
|:-------------:|:--------------:|:-----------------:|:-----------------:|:-------------:|:--------------:|:-----------------:|:-----------------:|
| D.00          | 00000          | 100111            | 011000            | D.16          | 10000          | 011011            | 100100            |
| D.01          | 00001          | 011101            | 100010            | D.17          | 10001          | 100011            |                   |
| D.02          | 00010          | 101101            | 010010            | D.18          | 10010          | 010011            |                   |
| D.03          | 00011          | 110001            |                   | D.19          | 10011          | 110010            |                   |
| D.04          | 00100          | 110101            | 001010            | D.20          | 10100          | 001011            |                   |
| D.05          | 00101          | 101001            |                   | D.21          | 10101          | 101010            |                   |
| D.06          | 00110          | 011001            |                   | D.22          | 10110          | 011010            |                   |
| D.07          | 00111          | 111000            | 000111            | D.23 †        | 10111          | 111010            | 000101            |
| D.08          | 01000          | 111001            | 000110            | D.24          | 11000          | 110011            | 001100            |
| D.09          | 01001          | 100101            |                   | D.25          | 11001          | 100110            |                   |
| D.10          | 01010          | 010101            |                   | D.26          | 11010          | 010110            |                   |
| D.11          | 01011          | 110100            |                   | D.27 †        | 11011          | 110110            | 001001            |
| D.12          | 01100          | 001101            |                   | D.28          | 11100          | 001110            |                   |
| D.13          | 01101          | 101100            |                   | D.29 †        | 11101          | 101110            | 010001            |
| D.14          | 01110          | 011100            |                   | D.30 †        | 11110          | 011110            | 100001            |
| D.15          | 01111          | 010111            | 101000            | D.31          | 11111          | 101011            | 010100            |
| not used      |                | 111100            | 000011            | K.28 ‡        | 11100          | 001111            | 110000            |

† Also used for the K.23.7 (D.23), K.27.7 (D.27), K.29.7 (D.29) and K.30.7 (D.30) symbols.  
‡ K.28.7 symbol.

В таблице присутствуют:

1. Нейтральные коды(D.14, D.13 и т.д). Они Не меняют RD и кодируются единственным образом. Так: ```00011``` переводится в D.03 единственным образом как ```110001```, при этом видно, что количество единиц и нулей в коде одинаковое, по этому код нейтральный, а значит RD не поменяло своего значения.

2. Коды с изменяемой диспаритентностью(D.15, D.31, D.08 и т.д). Они имеют разное количество нулей и единиц, по этому меняют текущее для них RD на противоположное. Так: ```10111``` переводится в D.23 при $RD=+1$ в ```000101```, а при $RD=-1$ в ```111010```. При этом у текущего кода будет противоположное количество единиц и нулей, поэтому ```rd_after_6b = ~rd_reg```

3. Особые коды(Все K коды). К коды выбираются, если ```is_k = 1'b1```. Также они могут иметь разное количество единиц и нулей. В 6и битном кодировании для K кода зарезервирован только D.28, выбор можно описать следующим образом:

```verilog
5'b11100: if (k == 1'b1) begin code_6b = rd_reg ? 6'b110000 : 6'b001111; rd_after_6b = ~rd_reg; end  
							 else begin code_6b = 6'b001110; rd_after_6b = rd_reg; end
```

В итоге реализованное описание для D.x кодов будет выглядеть следующим образом:

```verilog

always @(*) begin
        // Значения по умолчанию
        code_6b     = 6'b000000;
        code_4b     = 4'b0000;
        rd_after_6b = rd_reg;
        rd_final    = rd_after_6b;

        // 1. Сначала вычисляем блок 6b (биты abcdei). Нейтральные коды.
        // EDCBA 5b -> abcdei (6b)
        case(data_in[4:0])
            5'b00011: begin code_6b = 6'b110001; rd_after_6b = rd_reg; end // D.03  
            5'b00101: begin code_6b = 6'b101001; rd_after_6b = rd_reg; end // D.05  
            5'b00110: begin code_6b = 6'b011001; rd_after_6b = rd_reg; end // D.06  
            5'b01001: begin code_6b = 6'b100101; rd_after_6b = rd_reg; end // D.09  
            5'b01010: begin code_6b = 6'b010101; rd_after_6b = rd_reg; end // D.10  
            5'b01011: begin code_6b = 6'b110100; rd_after_6b = rd_reg; end // D.11  
            5'b01100: begin code_6b = 6'b001101; rd_after_6b = rd_reg; end // D.12  
            5'b01101: begin code_6b = 6'b101100; rd_after_6b = rd_reg; end // D.13  
            5'b01110: begin code_6b = 6'b011100; rd_after_6b = rd_reg; end // D.14  
            5'b10001: begin code_6b = 6'b100011; rd_after_6b = rd_reg; end // D.17  
            5'b10010: begin code_6b = 6'b010011; rd_after_6b = rd_reg; end // D.18  
            5'b10011: begin code_6b = 6'b110010; rd_after_6b = rd_reg; end // D.19  
            5'b10100: begin code_6b = 6'b001011; rd_after_6b = rd_reg; end // D.20  
            5'b10101: begin code_6b = 6'b101010; rd_after_6b = rd_reg; end // D.21  
            5'b10110: begin code_6b = 6'b011010; rd_after_6b = rd_reg; end // D.22  
            5'b11001: begin code_6b = 6'b100110; rd_after_6b = rd_reg; end // D.25  
            5'b11010: begin code_6b = 6'b010110; rd_after_6b = rd_reg; end // D.26  
			5'b00111: begin code_6b = rd_reg ? 6'b000111 : 6'b111000; rd_after_6b = rd_reg; end // D.07  


            // Не нейтральные коды (RD меняется)
            5'b00000: begin code_6b = rd_reg ? 6'b011000 : 6'b100111; rd_after_6b = ~rd_reg; end // D.00  
            5'b00001: begin code_6b = rd_reg ? 6'b100010 : 6'b011101; rd_after_6b = ~rd_reg; end // D.01  
            5'b00010: begin code_6b = rd_reg ? 6'b010010 : 6'b101101; rd_after_6b = ~rd_reg; end // D.02  
            5'b00100: begin code_6b = rd_reg ? 6'b001010 : 6'b110101; rd_after_6b = ~rd_reg; end // D.04  
            5'b01000: begin code_6b = rd_reg ? 6'b000110 : 6'b111001; rd_after_6b = ~rd_reg; end // D.08  
            5'b01111: begin code_6b = rd_reg ? 6'b101000 : 6'b010111; rd_after_6b = ~rd_reg; end // D.15   
            5'b10000: begin code_6b = rd_reg ? 6'b100100 : 6'b011011; rd_after_6b = ~rd_reg; end // D.16  
            5'b10111: begin code_6b = rd_reg ? 6'b000101 : 6'b111010; rd_after_6b = ~rd_reg; end // D.23  
            5'b11000: begin code_6b = rd_reg ? 6'b001100 : 6'b110011; rd_after_6b = ~rd_reg; end // D.24  
            5'b11011: begin code_6b = rd_reg ? 6'b001001 : 6'b110110; rd_after_6b = ~rd_reg; end // D.27  
            5'b11101: begin code_6b = rd_reg ? 6'b010001 : 6'b101110; rd_after_6b = ~rd_reg; end // D.29  
            5'b11110: begin code_6b = rd_reg ? 6'b100001 : 6'b011110; rd_after_6b = ~rd_reg; end // D.30  
            5'b11111: begin code_6b = rd_reg ? 6'b010100 : 6'b101011; rd_after_6b = ~rd_reg; end // D.31  
            default: begin code_6b = 6'b000000; rd_after_6b = ~rd_reg; end
				
```

Рассмотрим так же 3b/4b кодирование 

### 3b/4b code (fghj) to HGF

Кодирование этой части слова происходит практически аналогично 5b/6b кодированию.

| Input<br>Code | Input<br>HGF | RD = −1<br>fghj | RD = +1<br>fghj | Input<br>Code | Input<br>HGF | RD = −1<br>fghj | RD = +1<br>fghj |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| D.x.0 | 000 | 1011 | 0100 | K.x.0 | 000 | 1011 | 0100 |
| D.x.1 | 001 | 1001 |  | K.x.1 ‡ | 001 | 0110 | 1001 |
| D.x.2 | 010 | 0101 |  | K.x.2 | 010 | 1010 | 0101 |
| D.x.3 | 011 | 1100 | 0011 | K.x.3 | 011 | 1100 | 0011 |
| D.x.4 | 100 | 1101 | 0010 | K.x.4 | 100 | 1101 | 0010 |
| D.x.5 | 101 | 1010 |  | K.x.5 ‡ | 101 | 0101 | 1010 |
| D.x.6 | 110 | 0110 |  | K.x.6 | 110 | 1001 | 0110 |
| D.x.P7 † | 111 | 1110 | 0001 | K.x.7 ‡ | 111 | 0111 | 1000 |
| D.x.A7 † | (111) | 0111 | 1000 | — | — | — | — |

† D.x.P7 и D.x.A7 используют один и тот же вход HGF = 111, но разные коды fghj (A7 — альтернативный вариант; в исходной таблице HGF у A7 не повторён, т.к. совпадает с P7).  
‡ Управляющие символы (control / special).  


В таблице предсталены
1. Нейтральные коды.
2. Коды с изменяемой диспаритентностью.
3. K коды. Все они имеют изменяемую диспаритентность.
4. Primary коды


Пустая ячейка в колонке RD = +1 означает, что для RD = +1 используется тот же код, что и для RD = −1 (disparity = 0).

Так же важно отметить, что теперь используется ```rd_after_6b```, т.е именно так, как показано выше на принципиальной схеме. При этом сама логика выбора кода не изменилась.

```verilog
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
```


Как видим, ```rd_after_6b``` перешел в ```rd_final```, осталось только реализовать триггер в нашей схеме. 

```verilog
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
```

На этом не закончено. Проверим работу нашего экодера.

#### Тестирование encoder 8b/10b

Для тестирования будем использовать среду Modelsim и тест бенч. Ранее я уже показывал как [запустить test bench через modelsim](https://github.com/StuDenTMNF/FullAdder32.git)


Test Bench
```verilog
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
```

Лог тестирования

```tcl
# ==========================================================
#             Start testing encoder 8b/10b
# ==========================================================
#  Success! Input: 00 (k=0) Output: 1001110100 (expected: 1001110100) | rd_reg=0 rd_after=1 rd_final=0
#  Success! Input: 01 (k=0) Output: 0111010100 (expected: 0111010100) | rd_reg=0 rd_after=1 rd_final=0
#  Success! Input: 02 (k=0) Output: 1011010100 (expected: 1011010100) | rd_reg=0 rd_after=1 rd_final=0
#  Success! Input: 03 (k=0) Output: 1100011011 (expected: 1100011011) | rd_reg=1 rd_after=1 rd_final=0
#  Success! Input: 04 (k=0) Output: 0010101011 (expected: 0010101011) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: 05 (k=0) Output: 1010010100 (expected: 1010010100) | rd_reg=0 rd_after=0 rd_final=1
#  Success! Input: 06 (k=0) Output: 0110011011 (expected: 0110011011) | rd_reg=1 rd_after=1 rd_final=0
#  Success! Input: 07 (k=0) Output: 0001110100 (expected: 0001110100) | rd_reg=0 rd_after=0 rd_final=1
#  Success! Input: 07 (k=0) Output: 1110001011 (expected: 1110001011) | rd_reg=1 rd_after=1 rd_final=0
#  Success! Input: 08 (k=0) Output: 0001101011 (expected: 0001101011) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: 05 (k=0) Output: 1010010100 (expected: 1010010100) | rd_reg=0 rd_after=0 rd_final=1
#  Success! Input: e3 (k=0) Output: 1100011110 (expected: 1100011110) | rd_reg=1 rd_after=1 rd_final=0
#  Success! Input: f1 (k=0) Output: 1000110001 (expected: 1000110001) | rd_reg=0 rd_after=0 rd_final=1
#  Success! Input: f1 (k=0) Output: 1000110111 (expected: 1000110111) | rd_reg=1 rd_after=1 rd_final=0
#  Success! Input: eb (k=0) Output: 1101001000 (expected: 1101001000) | rd_reg=0 rd_after=0 rd_final=1
#  Success! Input: eb (k=0) Output: 1101001110 (expected: 1101001110) | rd_reg=1 rd_after=1 rd_final=0
#  Success! Input: 05 (k=0) Output: 1010010100 (expected: 1010010100) | rd_reg=0 rd_after=0 rd_final=1
#  Success! Input: 1c (k=1) Output: 0011110100 (expected: 0011110100) | rd_reg=0 rd_after=1 rd_final=0
#  Success! Input: 3c (k=1) Output: 0011111001 (expected: 0011111001) | rd_reg=1 rd_after=0 rd_final=0
#  Success! Input: 5c (k=1) Output: 1100001010 (expected: 1100001010) | rd_reg=0 rd_after=1 rd_final=1
#  Success! Input: 7c (k=1) Output: 0011110011 (expected: 0011110011) | rd_reg=1 rd_after=0 rd_final=0
#  Success! Input: 9c (k=1) Output: 1100001101 (expected: 1100001101) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: bc (k=1) Output: 1100000101 (expected: 1100000101) | rd_reg=0 rd_after=1 rd_final=1
#  Success! Input: dc (k=1) Output: 0011110110 (expected: 0011110110) | rd_reg=1 rd_after=0 rd_final=0
#  Success! Input: fc (k=1) Output: 1100000111 (expected: 1100000111) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: f7 (k=1) Output: 0001010111 (expected: 0001010111) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: fb (k=1) Output: 0010010111 (expected: 0010010111) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: fd (k=1) Output: 0100010111 (expected: 0100010111) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: fe (k=1) Output: 1000010111 (expected: 1000010111) | rd_reg=1 rd_after=0 rd_final=1
#  Success! Input: 05 (k=0) Output: 1010010100 (expected: 1010010100) | rd_reg=0 rd_after=0 rd_final=1
#  Success! Input: bc (k=1) Output: 0011111010 (expected: 0011111010) | rd_reg=1 rd_after=0 rd_final=0
#  Success! Input: 3c (k=1) Output: 1100000110 (expected: 1100000110) | rd_reg=0 rd_after=1 rd_final=1
# ==========================================================
#              End testing encoder 8b/10b
# ==========================================================
```

wave формы

<img src=".\media\encoder_tb.png" alt="Encoder" width="3000">

Теперь приступим к работе над Decoder 10b/8b
## 10b/8b Decoder

Реализация декодера немногим легче реализации энкодера, т.к вы уже понимаете, какой код присваивается на определенных этапах.

Принципиальная работающая схема энкодера выглядит так:


<img src=".\media\decoder.svg" alt="Encoder" width="700">

Я решил реализовать decoder почти так же, как и encoder. В блоке case для data_in[5:0] реализовано декодирование. Момент декодирования 4ех битного слова требует понимания k код ли это уже на моменте декодирования 6и битного слова. По этому сначала декодируются старшие биты, а потом уже младшие.

### 6b/5b abcdei to code (EDCBA)
Декодирование кодов происходит с мыслями:
1. Декодировать нужно D.x коды.
2. Так как от декодирования EDCBA зависит декодирование HGF, то следует ввести переменные, отвечающие за информацию о получении k кодов. 

D.x коды, которые не имеют аналогов в K кодах декодируются просто

Декодирование D.x кодов:

```verilog
case (code_6b)
            // Нейтральные коды (по одной комбинации)
            6'b110001: dec_5b = 5'b00011; // D.03
            6'b101001: dec_5b = 5'b00101; // D.05
            6'b011001: dec_5b = 5'b00110; // D.06
            6'b100101: dec_5b = 5'b01001; // D.09
            6'b010101: dec_5b = 5'b01010; // D.10
            6'b110100: dec_5b = 5'b01011; // D.11
            6'b001101: dec_5b = 5'b01100; // D.12
            6'b101100: dec_5b = 5'b01101; // D.13
            6'b011100: dec_5b = 5'b01110; // D.14
            6'b100011: dec_5b = 5'b10001; // D.17
            6'b010011: dec_5b = 5'b10010; // D.18
            6'b110010: dec_5b = 5'b10011; // D.19
            6'b001011: dec_5b = 5'b10100; // D.20
            6'b101010: dec_5b = 5'b10101; // D.21
            6'b011010: dec_5b = 5'b10110; // D.22
            6'b100110: dec_5b = 5'b11001; // D.25
            6'b010110: dec_5b = 5'b11010; // D.26
            6'b001110: dec_5b = 5'b11100; // D.28 (только данные)

            // Парные коды (зависящие от RD)
            6'b011000, 6'b100111: dec_5b = 5'b00000; // D.00
            6'b100010, 6'b011101: dec_5b = 5'b00001; // D.01
            6'b010010, 6'b101101: dec_5b = 5'b00010; // D.02
            6'b001010, 6'b110101: dec_5b = 5'b00100; // D.04
            6'b000111, 6'b111000: dec_5b = 5'b00111; // D.07
            6'b000110, 6'b111001: dec_5b = 5'b01000; // D.08
            6'b101000, 6'b010111: dec_5b = 5'b01111; // D.15
            6'b100100, 6'b011011: dec_5b = 5'b10000; // D.16
            6'b001100, 6'b110011: dec_5b = 5'b11000; // D.24
            6'b010100, 6'b101011: dec_5b = 5'b11111; // D.31

        default: begin
            dec_5b = 5'b00000;
            err_6b = 1'b1;
        end
    endcase
end
```

Теперь переходим к реализации получения K кодов. Из таблицы четко видно, что всего несколько кодов причастны к получению как K кодов, так и D кодов (K.23, K.27, K.29,K.30). При этом получение K.28 кодов единственно и D.28 не существует. По этому мы и вводим ```is_k_y``` и ```is_k28```, чтобы сразу перевести на другие рельсы кодирование.

```verilog
// Коды D/K.23, D/K.27, D/K.29, D/K.30 (могут быть и D, и K.y.7)
            6'b111010, 6'b000101: begin dec_5b = 5'b10111; is_k_y = 1'b1; end // D/K.23
            6'b110110, 6'b001001: begin dec_5b = 5'b11011; is_k_y = 1'b1; end // D/K.27
            6'b101110, 6'b010001: begin dec_5b = 5'b11101; is_k_y = 1'b1; end // D/K.29
            6'b011110, 6'b100001: begin dec_5b = 5'b11110; is_k_y = 1'b1; end // D/K.30

            // Специальный код K.28 (в данных никогда не встречается)
            6'b001111, 6'b110000: begin dec_5b = 5'b11100; is_k28 = 1'b1; end // K.28
```

На этом описание кодирования 6b/5b окончено, переходим к 5b/4b кодированию

### 4b/3b HGF to code fghj

```verilog
// =========================================================================
    // 2. Декодируем 4-битный блок обратно в 3 бита (старшая часть HGF) и флаг K
    // =========================================================================
    always @(*) begin
        dec_3b   = 3'b000;
        err_4b   = 1'b0;
        err_comb = 1'b0;
        k_comb   = 1'b0;

        case (code_4b)
            4'b1011, 4'b0100: dec_3b = 3'b000; // D/K.x.0

            // Для .1, .2, .5, .6 учитываем инверсию при code_6b == 6'b110000 (K.28 с RD+)
            4'b1001: dec_3b = (code_6b == 6'b110000) ? 3'b110 : 3'b001; // K.28.6 (при 110000) иначе D/K.x.1
            4'b0110: dec_3b = (code_6b == 6'b110000) ? 3'b001 : 3'b110; // K.28.1 (при 110000) иначе D/K.x.6
            4'b0101: dec_3b = (code_6b == 6'b110000) ? 3'b101 : 3'b010; // K.28.5 (при 110000) иначе D/K.x.2
            4'b1010: dec_3b = (code_6b == 6'b110000) ? 3'b010 : 3'b101; // K.28.2 (при 110000) иначе D/K.x.5

            4'b1100, 4'b0011: dec_3b = 3'b011; // D/K.x.3
            4'b1101, 4'b0010: dec_3b = 3'b100; // D/K.x.4

            // Primary P7 (1110 и 0001) — используется ТОЛЬКО для данных D.x.7 (нельзя с K.28)
            4'b1110, 4'b0001: begin
                dec_3b = 3'b111;
                if (is_k28) err_comb = 1'b1; // K.28.7 не может кодироваться через P7
            end

            // Alternate A7 (1000 и 0111) — используется для K.x.7 и для D.11/13/14/17/18/20.7
            // Alternate A7 (1000 и 0111) — используется для K.x.7 и для D.11/13/14/17/18/20.7
            4'b1000: begin
                dec_3b = 3'b111;
                // 1000 (при RD6=+) валиден после K.28(001111), K.23/27/29/30(с ei=10) или D.11/13/14(с ei=00)
                if (!(code_6b == 6'b001111 ||
                     (is_k_y && code_6b[1:0] == 2'b10) ||
                     (code_6b[1:0] == 2'b00 && (dec_5b == 5'd11 || dec_5b == 5'd13 || dec_5b == 5'd14)))) begin
                    err_comb = 1'b1;
                end
            end

            4'b0111: begin
                dec_3b = 3'b111;
                // 0111 (при RD6=-) валиден после K.28(110000), K.23/27/29/30(с ei=01) или D.17/18/20(с ei=11)
                if (!(code_6b == 6'b110000 ||
                     (is_k_y && code_6b[1:0] == 2'b01) ||
                     (code_6b[1:0] == 2'b11 && (dec_5b == 5'd17 || dec_5b == 5'd18 || dec_5b == 5'd20)))) begin
                    err_comb = 1'b1;
                end
            end

            default: begin
                dec_3b = 3'b000;
                err_4b = 1'b1;
            end
        endcase
```

#### Тестирование decoder 10b/8b

Для тестирования так же будем использовать среду Modelsim

TB для decoder
```verilog

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

```

Полученный лог

```tcl
# ==========================================================
#             Start testing DECODER 10b/8b
# ==========================================================
# [OK] 10b: 1001110100 -> output: D. 0.0 (0x00)
# [OK] 10b: 0110001011 -> output: D. 0.0 (0x00)
# [OK] 10b: 0111010100 -> output: D. 1.0 (0x01)
# [OK] 10b: 1011010100 -> output: D. 2.0 (0x02)
# [OK] 10b: 1100011011 -> output: D. 3.0 (0x03)
# [OK] 10b: 0010101011 -> output: D. 4.0 (0x04)
# [OK] 10b: 1010010100 -> output: D. 5.0 (0x05)
# [OK] 10b: 0110011011 -> output: D. 6.0 (0x06)
# [OK] 10b: 0001110100 -> output: D. 7.0 (0x07)
# [OK] 10b: 1110001011 -> output: D. 7.0 (0x07)
# [OK] 10b: 1110011011 -> output: D. 8.0 (0x08)
# [OK] 10b: 1100011110 -> output: D. 3.7 (0xe3)
# [OK] 10b: 1000110001 -> output: D.17.7 (0xf1)
# [OK] 10b: 1000110111 -> output: D.17.7 (0xf1)
# [OK] 10b: 1101001000 -> output: D.11.7 (0xeb)
# [OK] 10b: 1101001110 -> output: D.11.7 (0xeb)
# [OK] 10b: 0011110100 -> output: K.28.0 (0x1c)
# [OK] 10b: 1100001011 -> output: K.28.0 (0x1c)
# [OK] 10b: 0011111001 -> output: K.28.1 (0x3c)
# [OK] 10b: 1100000110 -> output: K.28.1 (0x3c)
# [OK] 10b: 1100000101 -> output: K.28.5 (0xbc)
# [OK] 10b: 0011111010 -> output: K.28.5 (0xbc)
# [OK] 10b: 0011110011 -> output: K.28.3 (0x7c)
# [OK] 10b: 1100001101 -> output: K.28.4 (0x9c)
# [OK] 10b: 0011111010 -> output: K.28.5 (0xbc)
# [OK] 10b: 1100000101 -> output: K.28.5 (0xbc)
# [OK] 10b: 0011110110 -> output: K.28.6 (0xdc)
# [OK] 10b: 1100000111 -> output: K.28.7 (0xfc)
# [OK] 10b: 0001010111 -> output: K.23.7 (0xf7)
# [OK] 10b: 1110101000 -> output: K.23.7 (0xf7)
# [OK] 10b: 0010010111 -> output: K.27.7 (0xfb)
# [OK] 10b: 0100010111 -> output: K.29.7 (0xfd)
# [OK] 10b: 1000010111 -> output: K.30.7 (0xfe)
# [OK] Error was correct find 10'b1111111111
# [OK] Error was correct find 10'b0000000000
# [OK] Error was correct find 10'b0011111110
# ==========================================================
#              End testing DECODER 10b/8b
# ==========================================================
```

Wave формы

<img src=".\media\decoder_tb.png" alt="Encoder" width="3000">

Пусть вас не пугает такое количество тестовых паттернов. Мы переходим к тестированию Top модуля Serdes

### Тестирование SerDes Top

Для тестирования топового модуля будет использовать тестбенч с симуляцией работы топового модуля в разных режимах(Псевдослучайная последовательность,Полный перебор всех 256 байт данных,Frame packet, Стресс паттерны,Все 12 K символов).

```verilog
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

endmodule

`default_nettype wire

```

Тестирование прошло успешно:

```tcl
# [45045000 ns] #346 | input: D.13.1 (k=0, 0x2d) ---> output: D.13.1 (k=0, 0x2d) | err=0 | [OK]
# [45175000 ns] #347 | input: D.26.0 (k=0, 0x1a) ---> output: D.26.0 (k=0, 0x1a) | err=0 | [OK]
# [45305000 ns] #348 | input: D.26.2 (k=0, 0x5a) ---> output: D.26.2 (k=0, 0x5a) | err=0 | [OK]
# [45435000 ns] #349 | input: D. 1.3 (k=0, 0x61) ---> output: D. 1.3 (k=0, 0x61) | err=0 | [OK]
# [45565000 ns] #350 | input: D. 3.4 (k=0, 0x83) ---> output: D. 3.4 (k=0, 0x83) | err=0 | [OK]
# [45695000 ns] #351 | input: D.16.5 (k=0, 0xb0) ---> output: D.16.5 (k=0, 0xb0) | err=0 | [OK]
# [45825000 ns] #352 | input: D.18.0 (k=0, 0x12) ---> output: D.18.0 (k=0, 0x12) | err=0 | [OK]
# [45955000 ns] #353 | input: D.31.5 (k=0, 0xbf) ---> output: D.31.5 (k=0, 0xbf) | err=0 | [OK]
# 
# ================================================================================
#  test results SERDES TOP:
#    words send : 353
#    words accept    : 353
#    mismatch: 0
#    status          : *** test success !!!! ***
# ================================================================================
```

Wave формы

<img src=".\media\SerDes_tb.png" alt="Encoder" width="3000">

На этом мы заканчиваем работу с описанием работы SerDes на verilog.