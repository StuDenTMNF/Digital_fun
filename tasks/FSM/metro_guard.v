/*Тебе необходимо создать модуль на Verilog, 
реализующий конечный автомат для управления турникетом.
 Система должна обрабатывать оплату, разблокировать 
 проход и автоматически
 блокироваться по прошествии времени или 
 после прохода человека.*/
 
 module metro_guard(
input valid_pay,
input entire_flag,
input rst,
input clk,
output reg unblock
);

localparam IDLE = 1'd0;
localparam unlock = 1'd1;
localparam duration_10_sec = 32'd100;

reg  state, next_state;
reg [31:0] timer_cnt;
wire timer_done;


always @(posedge clk or posedge rst) begin
 if (rst) begin
    timer_cnt <= 32'd0;
	 end else if (state != next_state) begin
	 timer_cnt <= 32'd0;
	 end else if( state == unlock) begin
	 timer_cnt <= timer_cnt +1;
	 
	 end else begin
	 timer_cnt <= 32'd0;
	 end
end
	 
	 
assign timer_done = (state == unlock && timer_cnt   ==  duration_10_sec);
                    
	



//как работаем
always @(*) begin 
  
  next_state = state;;
  
  case(state)
  
       IDLE: begin if ( valid_pay) begin next_state = unlock;
		 
		end
		 
	end
	
	
       unlock: begin if ( timer_done || entire_flag) begin next_state = IDLE;
		 
		end
	  end
	  
	
       default: begin  next_state = IDLE;
		 
		end
	  
	  
	endcase
	
end

//сердце
always @(posedge clk or posedge rst)begin
      if(rst) begin
		    state <= IDLE;
			 end else begin
		state <= next_state;
		end
end


 //комб логика
always @(*) begin

unblock = 1'd0;


    case (state) 
	 
	 unlock : begin unblock = 1'b1;
	 end
	 
	 IDLE   : begin unblock = 1'b0;
end
endcase
end

endmodule 	 
			
  

