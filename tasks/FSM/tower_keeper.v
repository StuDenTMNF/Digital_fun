/*Представь себе частную двухэтажную библиотеку. 
Чтобы перемещаться между этажами, её эксцентричный владелец 
установил небольшой лифт. 
Твоя задача — спроектировать "мозг" этого лифта. 
Система должна быть достаточно 
умной, чтобы не просто двигаться вверх-вниз, 
а реагировать на вызовы с этажей и безопасно доставлять своего 
единственного пассажира.*/

module tower_keeper_moore(
input clk,
input rst,
input request_F1,
input request_F2,
input sensor_F1,
input sensor_F2,
output reg motor_up,
output reg motor_down,
output reg door_open
);

localparam IDLE_F1     = 2'd0;
localparam moving_up   = 2'd1;
localparam IDLE_F2     = 2'd2;
localparam moving_down = 2'd3;

reg [1:0] state, next_state;

always @(*) begin
      next_state = state;
		
       case(state) 
	 
	          IDLE_F1 : begin if (request_F2) begin next_state = moving_up;
	 
	     end
	 end
	 
	  
	 
	           moving_up: begin if (sensor_F2) begin next_state = IDLE_F2;
	 
	     end
	 end
	 
	 
	           IDLE_F2: begin if (request_F1) begin next_state = moving_down;
	 
	     end
	 end
	 
	 
	           moving_down: begin if (sensor_F1) begin next_state = IDLE_F1;
	 
	     end
	 end
	 
	 
	           default: begin next_state = IDLE_F1;
	 
	     end
	 endcase
end


always @(posedge clk or posedge rst) begin

      if (rst) begin
		
		state <= IDLE_F1;
		
		end else begin
		
		state <= next_state;
	end
end

	always @(*) begin
	motor_up = 1'b0;
	motor_down = 1'b0;
	door_open = 1'b0;
	
		  case (state) 
		  
					 moving_up : begin  motor_up = 1'b1;
		 
			  end
		 
		 
		 
					 IDLE_F2 : begin  door_open = 1'b1;
		 
			  end
		 
		  
		  
					 moving_down : begin  motor_down = 1'b1;
		 
			  end
		 
		  
		  
					 IDLE_F1 : begin  door_open = 1'b1;
		 
			  end
		 
		
		 
		 
	  endcase
	end

endmodule
	 
	     
module tower_keeper_mealy(
input clk,
input rst,
input request_F1,
input request_F2,
input sensor_F1,
input sensor_F2,
output reg motor_up,
output reg motor_down,
output reg door_open
);		 

localparam IDLE_F1     = 2'd0;
localparam moving_up   = 2'd1;
localparam IDLE_F2     = 2'd2;
localparam moving_down = 2'd3;

reg [1:0] state, next_state;

always @(*) begin
      next_state = state;
		
       case(state) 
	 
	          IDLE_F1 : begin if (request_F2) begin next_state = moving_up;
	 
	     end
	 end
	 
	  
	 
	           moving_up: begin if (sensor_F2) begin next_state = IDLE_F2;
	 
	     end
	 end
	 
	 
	           IDLE_F2: begin if (request_F1) begin next_state = moving_down;
	 
	     end
	 end
	 
	 
	           moving_down: begin if (sensor_F1) begin next_state = IDLE_F1;
	 
	     end
	 end
	 
	 
	           default: begin next_state = IDLE_F1;
	 
	     end
	 endcase
end


always @(posedge clk or posedge rst) begin

      if (rst) begin
		
		state <= IDLE_F1;
		
		end else begin
		
		state <= next_state;
	end
end


//логика выходов
	always @(*) begin
	motor_up = 1'b0;
	motor_down = 1'b0;
	door_open = 1'b0;
	
		  case (state) 
		  
					 moving_up : begin  motor_up = 1'b1;
					 
					 
					 if (sensor_F2) begin
					 door_open = 1'b1;
					end
		 
			  end
		 
		 
		 
					 IDLE_F2 : begin  door_open = 1'b1;
		 
			  end
		 
		  
		  
					 moving_down : begin  motor_down = 1'b1;
					 
					 if (sensor_F1) begin
					 door_open = 1'b1;
					end
		 
			  end
		 
		  
		  
					 IDLE_F1 : begin  door_open = 1'b1;
		 
			  end
		 
		
		 
		 
	  endcase
	end

endmodule	 

