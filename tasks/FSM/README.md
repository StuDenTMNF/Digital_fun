# Finite State Machine

### Содержание
1. [Теория](#теория)
2. [Решение задач на тему конечных автоматов](#решение-задач)
3. [Тестирование](#тестирование)
4. [Получение нетлиста в Cadence Genus](#получение-нетлиста)

---

## Теория

В цифровой схемотехнике под **конечным автоматом (FSM)** понимают устройство с памятью, которое в любой момент времени находится ровно в одном из ранее известных состояний, и переключается между ними только по строгим правилам в зависимости от входных сигналов.

### Свойства КА:

1. **Конечность (Finiteness)**
> Это свойство означает, что мы всегда знаем, сколько всего ситуаций может возникнуть.

2. **Четкость состояний (Mutually exclusive state)**
> Это свойство означает, что КА всегда находится ровно в одном состоянии в конкретный момент времени.

3. **Предсказуемость (Determinism)**
> Мы всегда можем предсказать, что будет с КА в следующем такте.

4. **Строгость (Rigid Transition Logic)**
> КА всегда строго следует графу переходов.

Возможно, сейчас пока не понятна красота FSM, но на самом деле тут все просто. Это упрощает работу в общем смысле на каждом этапе производства.

### Виды конечных автоматов

В реализации встречаются только два вида конечных автоматов:

> **А. Автомат Мура.**
> Его выходные сигналы зависят *только от текущего состояния*.

> **Б. Автомат Мили.**
> Его выходные сигналы зависят *не только от текущего состояния, но и от входящих сигналов*.

При этом, "next state logic" и "output logic" строятся как комбинационные блоки.

---

## Решение задач

Для того, чтобы полнее понять смысл двух реализаций, рассмотрим несколько типовых задач. Я буду решать их для автоматов Мура и Милли в программе **Quartus Prime 21.1**.

### Первая задача
**Задание:** Реализуйте модуль для детектирования 6-ти битной последовательности `110011`, используя конечный автомат.

#### Реализация через автомат Мура

Мы объявляем модуль:

<details>
<summary><b>Показать объявление модуля</b></summary>

```systemverilog
module detect_6_bit_sequence_using_fsm
(
    input clk,
    input rst,
    input a,
    output detected
);
```
</details>

Далее объявляем состояния.

**Enum (enumeration)** — это способ создать свой собственный тип данных. Он нужен для визуализации в симуляторе (Vivado, ModelSim), чтобы упростить чтение языка.

В состоянии `IDLE` наш модуль находится в ожидании последовательности (а именно, в ожидании нужного первого бита последовательности). Последующие состояния — это состояния нашего модуля на каждом из этапов получения числовой последовательности.

<details>
<summary><b>Показать объявление состояний (Enum)</b></summary>

```systemverilog
enum logic[2:0]
{
    IDLE = 3'b000,
    F1   = 3'b001,
    F0   = 3'b010,
    S1   = 3'b011,
    S0   = 3'b100,
    G1   = 3'b101,
    G0   = 3'b110
} state, new_state;

```
</details>
**Enum (enumeration)** — это способ создать свой собственный тип данных. Он нужен для визуализации в симуляторе (Vivado, ModelSim), чтобы упростить чтение языка.

В состоянии `IDLE` наш модуль находится в ожидании последовательности (а именно, в ожидании нужного первого бита последовательности). Последующие состояния — это состояния нашего модуля на каждом из этапов получения числовой последовательности.


Перейдем к описанию **Next State Logic**:

<details>
<summary><b>Показать код (Always Comb)</b></summary>

```systemverilog
always_comb begin
    new_state = state;

    case (state)
        IDLE: if (a)  new_state = F1;
        F1:   if (a)  new_state = F0;
        F0:   if (~a) new_state = S1;
              else    new_state = F1;
        S1:   if (~a) new_state = S0;
              else    new_state = F1;
        S0:   if (a)  new_state = G1;
              else    new_state = IDLE;
        G1:   if (a)  new_state = G0;
              else    new_state = G1;
        G0:   if (a)  new_state = IDLE;
              else    new_state = G0;
    endcase
end
```
</details>
Немножко остановимся на логике состояний подробнее.

Может возникнуть вопрос: Почему когда мы не получаем нужный бит последовательности в состоянии S1 — мы возвращаемся в F1, а если мы в состоянии G1 получаем не нужный бит последовательности — мы отправляемся в IDLE?
**Ответ простой:**
Нам нужна последовательность `110011`. Если в состоянии `F0` (когда мы получили две единицы) мы получаем не ноль, а единицу — это не означает, что следующим битом может прийти не ноль. То есть: в следующем такте уже может прийти ноль.

Для того, чтобы описать все состояния и их переходы, используется диаграмма состояний. К ней также прилагается таблица состояний и переходов.

 #Тут картинка
 
Выглядит она следующим образом:

| Начальное состояние | Конечное состояние | Условие |
| :---: | :---: | :---: |
| F0 | S1 | `~a` |
| F0 | F1 | `a` |
| F1 | F0 | `a` |
| F1 | F1 | `~a` |
| G0 | IDLE | `a` |
| G0 | G0 | `~a` |
| G1 | G1 | `~a` |
| G1 | G0 | `a` |
| IDLE | IDLE | `~a` |
| IDLE | F1 | `a` |
| S0 | IDLE | `~a` |
| S0 | G1 | `a` |
| S1 | S0 | `~a` |
| S1 | F1 | `a` |

Опишем **output logic**:

<details>
<summary><b>Показать код </b></summary>

```systemverilog
assign detected = (state == G0);
```
</details>

Последним этапом будет описание логики обновления состояний:
<details>
  
<summary><b>Показать код </b></summary>
  
  ```systemverilog
  
always_ff @ (posedge clk) begin
    if (rst)
        state <= IDLE;
    else
        state <= new_state;
end

```
</details>

Тогда полный код будет выглядеть следующим образом:
<details>
  
<summary>Конечный автомат FSM </summary>
  
```systemverilog

module detect_6_bit_sequence_using_fsm
(
  input  clk,
  input  rst,
  input  a,
  output detected
);
//объявление состояний
enum logic[2:0]
  {
     IDLE = 3'b000,
     F1   = 3'b001,
     F0   = 3'b010,
     S1   = 3'b011,
     S0   = 3'b100,
	  G1   = 3'b101,
	  G0   = 3'b110
  }
  state, new_state;

//логка переходов
always_comb
  begin
    new_state = state;

    case (state)
      IDLE: if (  a) new_state = F1;
      F1:   if (  a) new_state = F0;
      F0:   if (~ a) new_state = S1;
            else     new_state = F1;
      S1:   if (~ a) new_state = S0;
            else     new_state = F1;
      S0:   if (  a) new_state = G1;
            else     new_state = IDLE;
      G1:   if (  a) new_state = G0;
		      else     new_state = G1;
	    G0:   if (  a) new_state = IDLE;
		      else     new_state = G0;
    endcase
end

	 assign detected = (state == G0);
	 
//обновление состояний 
always_ff @(posedge clk or posedge rst) begin
   if (rst)
	   state <= IDLE;
	else
	   state <= new_state;
end


endmodule

```
</details>
И реализация такого же по функционалу модуля для автомата Милли 

<details>

<summary>Конечный автомат Милли</summary>

```systemverilog

module detect_6_bit_sequence_mealy
(
  input  logic clk,
  input  logic rst,
  input  logic a,
  output logic detected
);


  enum logic [2:0] {
     IDLE     = 3'd0, 
     GOT_1    = 3'd1, 
     GOT_11   = 3'd2, 
     GOT_110  = 3'd3, 
     GOT_1100 = 3'd4, 
     GOT_11001= 3'd5  
  } state, next_state;

  // 1. Логика переходов и выхода (Mealy)
  // Выход зависит от State И от Input 'a' прямо здесь
  always_comb begin
    next_state = state;
    detected   = 1'b0; // По умолчанию ничего не нашли

    case (state)
      IDLE: begin
        if (a) next_state = GOT_1;
        else   next_state = IDLE;
      end

      GOT_1: begin
        if (a) next_state = GOT_11;
        else   next_state = IDLE; 
      end

      GOT_11: begin
        if (~a) next_state = GOT_110; 
        else    next_state = GOT_11; 
      end

      GOT_110: begin
        if (~a) next_state = GOT_1100;
        else    next_state = GOT_1;  
		end

      GOT_1100: begin
        if (a) next_state = GOT_11001;
        else   next_state = IDLE; 
      end

      GOT_11001: begin
        // Логика Мили
        if (a) begin 
            // Пришла 1! Мы собрали 11001 + 1 = 110011!
            detected = 1'b1; 
            
            
            // Мы получили ...110011. Конец "11" может быть началом новой
            next_state = GOT_11; 
        end else begin
            // Пришел 0. ...110010. Сброс.
            next_state = IDLE; 
        end
      end
      
      default: next_state = IDLE;
    endcase
  end

  // 2. Обновление состояния 
  always_ff @(posedge clk or posedge rst) begin
    if (rst) state <= IDLE;
    else     state <= next_state;
  end

endmodule

```
  
</details>



| Текущее состояние | Конечное состояние | Условие |
| :---: | :---: | :---: |
| GOT_1 | GOT_11 | `a` |
| GOT_1 | IDLE | `~a` |
| GOT_11 | GOT_11 | `a` |
| GOT_11 | GOT_110 | `~a` |
| GOT_110 | GOT_1 | |
| GOT_1100 | GOT_11001 | `a` |
| GOT_1100 | IDLE | `~a` |
| GOT_11001 | GOT_11 | `a` |
| GOT_11001 | IDLE | `~a` |
| IDLE | GOT_1 | `a` |
| IDLE | IDLE | `~a` |

Автомат Мили реагирует быстрее (асинхронно внутри такта) и часто требует меньше регистров, но его выход может "глитчить" (дребезжать), если входной сигнал нестабилен, так как между входом и выходом нет регистра.
