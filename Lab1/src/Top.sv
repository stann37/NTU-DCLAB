module Top (
	input        i_clk,
	input        i_rst_n,
	input        i_start,
	input		 i_key2,
	input 		 i_key3,
	output reg [3:0] o_random_out,
	output 		 o_sel_led
);
	// reg   [3:0] o_random_out;
	parameter F = 128;	// F = 128 for demo, 1 for TB
	
	parameter MAX = 16384 * F;
	parameter STOP = 262144  * F;
	parameter INCRE = 16384  * F;

	parameter MAX_D = MAX / 2;
	parameter STOP_D = STOP / 2;
	parameter INCRE_D = INCRE / 2;

	parameter S_IDLE = 2'd0;
	parameter S_RUN = 2'd1;
	parameter S_STOP = 2'd2;

	logic [31:0] counter_r, counter_w;
	logic [31:0] max_r, max_w;
	logic [1:0] state_r, state_w;
	logic state_pause_r, state_pause_w;
	logic state_speed;	// 0: normal, 1: half the cycles
	
	logic sel;
	assign o_sel_led = sel;

	logic [3:0] LFSR_out;
	

	always_comb begin
		counter_w = counter_r;
		state_w = state_r;
		max_w = max_r;

		if (i_key2 && (state_r == S_RUN)) begin
			state_pause_w = ~state_pause_r;
		end
		else begin
			state_pause_w = state_pause_r;
		end

		case(state_r)
			S_IDLE: begin
				
			end
			S_RUN: begin
				if (!state_pause_r) begin
					if (max_r == (sel ? STOP_D : STOP)) begin
						state_w = S_STOP;
					end
					else if (counter_r == max_r) begin
						counter_w = 0;
						max_w = max_r + (sel ? INCRE_D : INCRE);
					end
					else begin
						counter_w = counter_r + 1;
					end
				end
			end
			S_STOP: begin
				
			end
		endcase
	end

	always_ff @(posedge i_clk or negedge i_rst_n) begin
		if (!i_rst_n) begin
			counter_r <= 0;
			max_r <= MAX;
			state_r <= S_IDLE;
			o_random_out <= 0;
			state_pause_r <= 0;
			state_speed <= 0;
			sel <= 0;
		end
		else if (i_start) begin
			counter_r <= 0;
			max_r <= state_speed ? MAX_D : MAX;
			state_r <= S_RUN;
			o_random_out <= LFSR_out;
			state_pause_r <= 0;
			state_speed <= state_speed;
			sel <= state_speed;
		end
		else begin
			counter_r <= counter_w;
			max_r <= max_w;
			state_r <= state_w;
			o_random_out <= ((state_r == S_RUN) && !state_pause_r && (counter_r == 0)) ? LFSR_out : o_random_out;
			state_pause_r <= state_pause_w;
			state_speed <= state_speed ^ i_key3;
			sel <= sel;
		end
	end

	LFSR LFSR(.clk(i_clk), .rst_n(i_rst_n), .pause(state_pause_r), .out(LFSR_out));

endmodule

module LFSR(
	input			clk,
	input			rst_n,
	input			pause,
	output reg [3:0] 	out
);
	parameter SEED = 42069;

	//reg [3:0] out;
	logic [15:0] state_r, state_w;

	always_comb begin
		out = state_r[3:0];	// 4-bit output

		if (pause) begin
			state_w = state_r;  // Hold current state
		end
		else begin
			state_w = {state_r[0] ^ state_r[2] ^ state_r[3] ^ state_r[5], state_r[15:1]};	// tapping config
		end
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			state_r <= SEED;
		end
		else begin
			state_r <= state_w;
		end
	end

endmodule