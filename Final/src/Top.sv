module Top(
    input i_rst_n,
    input i_clk,
    input i_key_0, // Change Value
    input i_key_1, // Record/Play Loop
    input i_key_2, // Change Mode (Set <-> Play)
    input [17:0] i_sw, // [17:15]=Select Effect, [7:0]=Enable Effect

    // AudDSP and SRAM, 
    output [19:0] o_SRAM_ADDR,
    inout  [15:0] io_SRAM_DQ,
    output        o_SRAM_WE_N,
    output        o_SRAM_CE_N,
    output        o_SRAM_OE_N,
    output        o_SRAM_LB_N,
    output        o_SRAM_UB_N,

    // I2C
    input  i_clk_100k,
    output o_I2C_SCLK,
    inout  io_I2C_SDAT,
    
    // AudPlayer
    input  i_AUD_ADCDAT,
    inout  i_AUD_ADCLRCK,
    inout  i_AUD_BCLK,
    inout  i_AUD_DACLRCK,
    output o_AUD_DACDAT,

    // LED
    output logic [8:0]  o_ledg, // State Indicator
    output logic [17:0] o_ledr, // Effect Indicator

    // Display
    output [6:0] o_hex0         // Parameter Value
);

localparam S_I2C         = 4'd0;
localparam S_PLAY        = 4'd1;
localparam S_SET         = 4'd2;
localparam S_RECD_LOOP0  = 4'd3;
localparam S_PLAY_LOOP0  = 4'd4;
localparam S_RECD_LOOP1  = 4'd5;
localparam S_PLAY_LOOP1  = 4'd6;
localparam S_SET_LOOP0   = 4'd7;
localparam S_SET_LOOP1   = 4'd8;

// Effect mapping
localparam EFF_GATE   = 3'd0;
localparam EFF_COMP   = 3'd1;
localparam EFF_DIST   = 3'd2;
localparam EFF_EQ_B   = 3'd3;
localparam EFF_EQ_T   = 3'd4;
localparam EFF_TREM   = 3'd5;
localparam EFF_DEL    = 3'd6;
localparam EFF_LOOP   = 3'd7;

// loop state
localparam LOOP_UNENABLED = 2'd0;
localparam LOOP_RECORD = 2'd1; 
localparam LOOP_PLAY = 2'd2;

logic [3:0] state_w, state_r;
logic [1:0] state_mem_w, state_mem_r; // determines which module is in control of SRAM

localparam MEM_IDLE = 2'd0;
localparam MEM_DEL  = 2'd1;
localparam MEM_LOOP0 = 2'd2;
localparam MEM_LOOP1 = 2'd3;

wire [19:0] w_delay_addr;
wire [15:0] w_delay_wdata;
wire        w_delay_wen;

wire [19:0] w_loop0_addr;
wire [15:0] w_loop0_wdata;
wire        w_loop0_wen;

wire [19:0] w_loop1_addr;
wire [15:0] w_loop1_wdata;
wire        w_loop1_wen;

logic [15:0] sram_data_out_mux; // Data we WANT to write
logic sram_oe_mux;       // 1 = Output (Write), 0 = Input (Read)

assign io_SRAM_DQ = (sram_oe_mux) ? sram_data_out_mux : 16'dz;

wire signed [15:0] sram_read_data = io_SRAM_DQ; // read data when sram_oe_mux = 0

// next state logic and SRAM port control
// note that the control of SRAM will be handed over one cycle later than the valid signal
always_comb begin
	state_mem_w = state_mem_r;
	o_SRAM_ADDR = 20'd0;
	o_SRAM_WE_N = 1'b1;  // Write Disable
	sram_oe_mux = 1'b0;         // Tristate (Input mode)
    sram_data_out_mux = 16'd0;  // Default value (doesn't matter when OE=0)

	case (state_mem_r)
		MEM_IDLE: begin
			if (w_trem_valid) state_mem_w = MEM_DEL; // Tremolo hands over to Delay
		end
		MEM_DEL: begin
            o_SRAM_ADDR = w_delay_addr;
            o_SRAM_WE_N = w_delay_wen;

			if (w_delay_wen == 1'b0) begin // Write Mode
                sram_oe_mux = 1'b1;           // Turn ON output driver
                sram_data_out_mux = w_delay_wdata; // Connect Delay Data to Pin
            end

            // ELSE: Read Mode. sram_oe_mux stays 0 (Default).
            // Delay will simply read 'sram_read_data' wire.

			if (w_delay_valid) begin
                state_mem_w = MEM_LOOP0; // Delay hands over to Loop
            end
        end
		MEM_LOOP0: begin
			o_SRAM_ADDR = w_loop0_addr;
			o_SRAM_WE_N = w_loop0_wen;

			if (w_loop0_wen == 1'b0) begin // Write Mode
				sram_oe_mux = 1'b1;          // Turn ON output driver
				sram_data_out_mux = w_loop0_wdata; // Connect Loop Data to Pin
			end

			// ELSE: Read Mode. sram_oe_mux stays 0 (Default).
			// Loop will simply read 'sram_read_data' wire.
			if (w_loop0_valid) begin
				state_mem_w = MEM_LOOP1; // Loop hands over to Idle
			end
		end
		MEM_LOOP1: begin
			o_SRAM_ADDR = w_loop1_addr;
			o_SRAM_WE_N = w_loop1_wen;

			if (w_loop1_wen == 1'b0) begin // Write Mode
				sram_oe_mux = 1'b1;          // Turn ON output driver
				sram_data_out_mux = w_loop1_wdata; // Connect Loop Data to Pin
			end

			// ELSE: Read Mode. sram_oe_mux stays 0 (Default).
			// Loop will simply read 'sram_read_data' wire.
			if (w_loop1_valid) begin
				state_mem_w = MEM_IDLE; // Loop hands over to Idle
			end
		end
		default: begin end
	endcase
end

always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_mem_r <= MEM_IDLE;
	end
	else begin
		state_mem_r <= state_mem_w;
	end
end

assign o_SRAM_CE_N = 1'b0;  // Chip Enable
assign o_SRAM_OE_N = 1'b0;  // Output Enable
assign o_SRAM_LB_N = 1'b0;  // Lower Byte Enable
assign o_SRAM_UB_N = 1'b0;  // Upper Byte Enable

// Parameters
logic [2:0] state_gate_r, state_gate_w;
logic [2:0] state_comp_r, state_comp_w;
logic [2:0] state_dist_r, state_dist_w;
logic [2:0] state_EQb_r, state_EQb_w;
logic [2:0] state_EQt_r, state_EQt_w;
logic [2:0] state_trem_r, state_trem_w;
logic [2:0] state_delay_r, state_delay_w;
logic [2:0] state_loop_r, state_loop_w;

wire [2:0] effect_sel = i_sw[17:15];
wire [7:0] effect_en  = i_sw[7:0];

logic daclrck_prev;
wire sample_valid;
wire left_channel_start;

// Detect rising edge of DACLRCK to signify start of new Left Channel sample
always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
    if (!i_rst_n) daclrck_prev <= 1'b0;
    else          daclrck_prev <= i_AUD_DACLRCK;
end

assign sample_valid = i_AUD_DACLRCK && ~daclrck_prev; // the first cycle that switches to right channel
assign left_channel_start = ~i_AUD_DACLRCK && daclrck_prev; // the first cycle that switches to left channel

// I2C
logic I2C_finish;
logic i2c_oen, i2c_sdat;
assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(1'b1),
	.o_finished(I2C_finish),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen)
);

// Audio Interface Modules
logic signed [15:0] adc_data; // Raw audio from Line In
logic signed [15:0] dac_data; // Final audio to Line Out

AudRecorder recorder0(
    .i_rst_n    (i_rst_n),
    .i_clk      (i_AUD_BCLK),
    .i_lrc      (i_AUD_ADCLRCK),
    .i_start    (1'b1),        // Always recording
    .i_pause    (1'b0),
    .i_resume   (1'b0),
    .i_stop     (1'b0),
    .i_data     (i_AUD_ADCDAT),
    .o_address  (),            // Not used for realtime
    .o_data     (adc_data),    // <--- THIS IS YOUR INPUT AUDIO
    .o_finish   (),
    .o_debug    ()
);

// Output: Convert 16-bit Parallel to Serial I2S
AudPlayer player0(
    .i_rst_n      (i_rst_n),
    .i_bclk       (i_AUD_BCLK),
    .i_daclrck    (i_AUD_DACLRCK),
    .i_en         (1'b1),        // Always playing
    .i_dac_data   (dac_data),    // <--- THIS IS YOUR OUTPUT AUDIO
    .o_aud_dacdat (o_AUD_DACDAT)
);

wire signed [15:0] w_gate_out;
wire signed [15:0] w_trem_out;
wire signed [15:0] w_dist_out;
wire signed [15:0] w_comp_out;
wire signed [15:0] w_eq_out;
wire signed [15:0] w_delay_out;
wire signed [15:0] w_loop0_out;
wire signed [15:0] w_loop1_out;
wire w_gate_valid;
wire w_trem_valid;
wire w_dist_valid;
wire w_comp_valid;
wire w_eq_valid;
wire w_delay_valid;
wire w_loop0_valid;
wire w_loop1_valid;
wire w_loop0_record_finish;
wire w_loop1_record_finish;

// loop state control
logic [1:0] loop0_state, loop1_state;
always_comb begin
	loop0_state = LOOP_UNENABLED;
	loop1_state = LOOP_UNENABLED;
	case (state_r)
		S_RECD_LOOP0: begin
			loop0_state = LOOP_RECORD;
		end
		S_PLAY_LOOP0: begin
			loop0_state = LOOP_PLAY;
		end
		S_SET_LOOP0: begin
			loop0_state = LOOP_PLAY;
		end
		S_RECD_LOOP1: begin
			loop0_state = LOOP_PLAY;
			loop1_state = LOOP_RECORD;
		end
		S_PLAY_LOOP1: begin
			loop0_state = LOOP_UNENABLED;
			loop1_state = LOOP_PLAY;
		end
		S_SET_LOOP1: begin
			loop0_state = LOOP_UNENABLED;
			loop1_state = LOOP_PLAY;
		end
	endcase
end

// stan branch

Effect_Gate gate0 (
    .i_clk      (i_AUD_BCLK),
    .i_rst_n    (i_rst_n),
    .i_valid    (sample_valid),
    .i_enable   (effect_en[EFF_GATE]),
    .i_level    (state_gate_r),
    .i_data     (adc_data),
    .o_data     (w_gate_out),
	.o_valid    (w_gate_valid)
);
// guitar lever to top, tone 1

Effect_Compressor compressor0 (
	.i_clk      (i_AUD_BCLK),
	.i_rst_n    (i_rst_n),
	.i_valid    (w_gate_valid),
	.i_enable   (effect_en[EFF_COMP]),
	.i_level    (state_comp_r),
	.i_data     (w_gate_out),
	.o_data     (w_comp_out),
	.o_valid    (w_comp_valid)
);
// note that compressor may induce makeup gain, be careful when chaining effects

Effect_Distortion distortion0 (
	.i_clk      (i_AUD_BCLK),
    .i_rst_n    (i_rst_n),
    .i_valid    (w_comp_valid),
    .i_enable   (effect_en[EFF_DIST]),
    .i_level    (state_dist_r),
    .i_data     (w_comp_out),
    .o_data     (w_dist_out),
	.o_valid    (w_dist_valid)
);

Effect_EQ eq0 (
	.i_clk      (i_AUD_BCLK),
	.i_rst_n    (i_rst_n),
	.i_valid    (w_dist_valid),
	.i_enable   (effect_en[EFF_EQ_B] || effect_en[EFF_EQ_T]),
	.i_level_bass     (state_EQb_r),
	.i_level_treble     (state_EQt_r),
	.i_data     (w_dist_out),
	.o_data     (w_eq_out),
	.o_valid    (w_eq_valid)
);

Effect_Tremolo tremolo0 (
	.i_clk      (i_AUD_BCLK),
    .i_rst_n    (i_rst_n),
	.i_clk_tri  (i_clk_100k),
    .i_valid    (w_eq_valid),
    .i_enable   (effect_en[EFF_TREM]),
    .i_freq     (state_trem_r),
    .i_data     (w_eq_out),
    .o_data     (w_trem_out),
	.o_valid    (w_trem_valid)
);


Effect_Delay delay0 (
	.i_clk      (i_AUD_BCLK),
	.i_rst_n    (i_rst_n),
	.i_valid    (w_trem_valid),
	.i_enable   (effect_en[EFF_DEL]),
	.i_level    (state_delay_r),
	.i_data     (w_trem_out),

	.i_sram_rdata(sram_read_data),
	.o_sram_addr(w_delay_addr),
	.o_sram_we_n(w_delay_wen),
	.o_sram_wdata(w_delay_wdata),

	.o_data     (w_delay_out),
	.o_valid    (w_delay_valid)
);

Effect_Loop0 loop0 (
	.i_clk      (i_AUD_BCLK),
	.i_rst_n    (i_rst_n),
	.i_valid    (w_delay_valid),
	.i_level    (state_loop_r),
	.i_data     (w_delay_out),
	.i_state    (loop0_state),
	.i_sram_rdata(sram_read_data),
	.o_sram_addr(w_loop0_addr),
	.o_sram_we_n(w_loop0_wen),
	.o_sram_wdata(w_loop0_wdata),
	.o_record_finish(w_loop0_record_finish),
	.o_data     (w_loop0_out),
	.o_valid    (w_loop0_valid)
);

Effect_Loop1 loop1 (
	.i_clk      (i_AUD_BCLK),
	.i_rst_n    (i_rst_n),
	.i_valid    (w_loop0_valid),
	.i_level    (state_loop_r),
	.i_data     (w_loop0_out),
	.i_state    (loop1_state),
	.i_sram_rdata(sram_read_data),
	.o_sram_addr(w_loop1_addr),
	.o_sram_we_n(w_loop1_wen),
	.o_sram_wdata(w_loop1_wdata),
	.o_record_finish(w_loop1_record_finish),
	.o_data     (w_loop1_out), // <--- FINAL OUTPUT
	.o_valid    (w_loop1_valid)
);

assign dac_data = w_loop1_out; // here

// FSM State Transition
always_comb begin
	state_w = state_r;
	case (state_r)
		S_I2C: begin
			if (I2C_finish) state_w = S_PLAY;
		end
		S_PLAY: begin
			if (i_key_2) state_w = S_SET;
			else if (i_key_1) state_w = S_RECD_LOOP0;
		end
		S_SET: begin
			if (i_key_2) state_w = S_PLAY;
		end
		S_RECD_LOOP0: begin
			if (i_key_1) state_w = S_PLAY_LOOP0;
			else if (w_loop0_record_finish) state_w = S_PLAY_LOOP0;
		end
		S_PLAY_LOOP0: begin
			if (i_key_0) state_w = S_PLAY;
			else if (i_key_1) state_w = S_RECD_LOOP1;
			else if (i_key_2) state_w = S_SET_LOOP0;
		end
		S_SET_LOOP0: begin
			if (i_key_2) state_w = S_PLAY_LOOP0;
		end
		S_RECD_LOOP1: begin
			if (i_key_1) state_w = S_PLAY_LOOP1;
			else if (w_loop1_record_finish) state_w = S_PLAY_LOOP1;
		end
		S_PLAY_LOOP1: begin
			if (i_key_0) state_w = S_PLAY_LOOP0;
			else if (i_key_2) state_w = S_SET_LOOP1;
		end
		S_SET_LOOP1: begin
			if (i_key_2) state_w = S_PLAY_LOOP1;
		end
	endcase
end

// Parameter Update Logic
always_comb begin
	// default: hold state
	state_gate_w = state_gate_r;
	state_comp_w = state_comp_r;
	state_dist_w = state_dist_r;
	state_EQb_w  = state_EQb_r;
	state_EQt_w  = state_EQt_r;
	state_trem_w = state_trem_r;
	state_loop_w = state_loop_r;
	state_delay_w = state_delay_r;

	if ((state_r == S_SET) || (state_r == S_SET_LOOP0) || (state_r == S_SET_LOOP1)) begin
		if (i_key_0) begin 
			case (effect_sel)
				EFF_GATE: state_gate_w  = state_gate_r + 1;
				EFF_COMP: state_comp_w  = state_comp_r + 1;
				EFF_DIST: state_dist_w  = state_dist_r + 1;
				EFF_EQ_B: state_EQb_w   = state_EQb_r + 1;
				EFF_EQ_T: state_EQt_w   = state_EQt_r + 1;
				EFF_TREM: state_trem_w  = state_trem_r + 1;
				EFF_LOOP: state_loop_w  = state_loop_r + 1;
				EFF_DEL:  state_delay_w = state_delay_r + 1;
			endcase
		end
	end
end

// LED Logic
always_comb begin
	// Green: FSM State
	case(state_r)
		S_I2C:        o_ledg = 9'b1_0000_0000;
		S_PLAY:       o_ledg = 9'b0_0000_0001;
		S_SET:        o_ledg = 9'b0_0000_0010;
		S_SET_LOOP0:  o_ledg = 9'b0_0000_0010;
		S_SET_LOOP1:  o_ledg = 9'b0_0000_0010;
		S_RECD_LOOP0: o_ledg = 9'b0_0000_0100;
		S_PLAY_LOOP0: o_ledg = 9'b0_0000_1000;
		S_RECD_LOOP1: o_ledg = 9'b0_0001_0000;
		S_PLAY_LOOP1: o_ledg = 9'b0_0010_0000;
		default:      o_ledg = 9'b0_0000_0000;
	endcase

	// Red: Effects
	o_ledr[17:8] = 10'b0; 
	if ((state_r == S_SET) || (state_r == S_SET_LOOP0) || (state_r == S_SET_LOOP1)) begin
		// In SET mode: Show a single cursor LED indicating which effect is selected
		o_ledr[7:0] = (8'b1 << effect_sel);
	end else begin
		// In PLAY mode: Show which effects are ENABLED via switches
		o_ledr[7:0] = effect_en;
	end
end

// HEX0: Show current value of selected effect when in SET mode
logic [2:0] current_val;
always_comb begin
	if ((state_r == S_SET) || (state_r == S_SET_LOOP0) || (state_r == S_SET_LOOP1)) begin
		case (effect_sel)
			EFF_GATE: current_val = state_gate_r;
			EFF_COMP: current_val = state_comp_r;
			EFF_DIST: current_val = state_dist_r;
			EFF_EQ_B: current_val = state_EQb_r;
			EFF_EQ_T: current_val = state_EQt_r;
			EFF_TREM: current_val = state_trem_r;
			EFF_LOOP: current_val = state_loop_r;
			EFF_DEL:  current_val = state_delay_r;
			default:  current_val = 3'd0;
		endcase
	end else begin
		current_val = 3'd0;
	end
end

SevenHexDecoder hex_val_inst (
	.i_hex({1'b0, current_val}), 
	.o_seven_ten(), 
	.o_seven_one(o_hex0)
);

// Sequential Logic
always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r <= S_I2C; 
		state_gate_r <= 3'd2;
		state_comp_r <= 0;
		state_dist_r <= 0;
		state_EQb_r  <= 3'd4;
		state_EQt_r  <= 3'd4;
		state_trem_r <= 0;
		state_loop_r <= 3'd3;
		state_delay_r <= 0;
	end
	else begin
		state_r <= state_w;
		state_gate_r <= state_gate_w;
		state_comp_r <= state_comp_w;
		state_dist_r <= state_dist_w;
		state_EQb_r  <= state_EQb_w; 
		state_EQt_r  <= state_EQt_w; 
		state_trem_r <= state_trem_w;
		state_loop_r <= state_loop_w;
		state_delay_r <= state_delay_w;
	end
end

endmodule