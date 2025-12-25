module AudRecorder (
    input i_rst_n,
    input i_clk,        // BCLK from WM8731
    input i_lrc,        // ADCLRCK (0=LEFT, 1=RIGHT)
    input i_start,      // Clear registers and start new recording
    input i_pause,      // Pause recording
    input i_resume,     // Resume from pause
    input i_stop,       // Stop recording
    input i_data,       // ADCDAT serial audio stream
    output [19:0] o_address,
    output [15:0] o_data,
    output o_finish,     // Asserted when memory full
    output [8:0] o_debug
);

parameter S_IDLE = 0;
parameter S_CLEAR = 1;
parameter S_RECORD = 2;
parameter S_RETRIEVED = 3;
parameter S_PAUSE = 4;

logic[2:0] state_r, state_w;
logic[15:0] data_r, data_w;         //temporary data, changed for 16 cycles
logic[19:0] address_r, address_w;
logic[9:0] count_r, count_w;
logic[15:0] output_r, output_w;     //output data, updated after new 16 bits is retreived
logic finish_r, finish_w;

logic [8:0] o_debug_w, o_debug_r;
assign o_debug = o_debug_r;

assign o_data = output_r;
assign o_address = address_r;
assign o_finish = finish_r;         //held high for 1 cycle after memory has been filled

localparam MAX_ADDR = 20'd1_023_999;

// FSM
always_comb begin
    state_w = state_r;
    o_debug_w = o_debug_r;
    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                state_w = S_CLEAR;
                o_debug_w = 9'b000000010;
            end
        end
        S_CLEAR: begin
            if (address_r == MAX_ADDR) begin
                state_w = S_RECORD;
                o_debug_w = 9'b000001000;
            end
        end
        S_RECORD: begin
            if (i_pause) begin
                state_w = S_PAUSE;
                o_debug_w = 9'b000000100;
            end
            else if (i_stop) begin
                state_w = S_IDLE;
                o_debug_w = 9'b000000001;
            end
            else if (count_r == 18) begin
                state_w = S_RETRIEVED;
                o_debug_w = 9'b000010000;
            end
        end
        S_RETRIEVED: begin
            if (i_pause) begin
                state_w = S_PAUSE;
                o_debug_w = 9'b000000100;
            end
            else if (i_stop) begin
                state_w = S_IDLE;
                o_debug_w = 9'b000000001;
            end
            else if (i_lrc) begin
                state_w = S_RECORD;
                o_debug_w = 9'b000001000;
            end
            else if (address_r == MAX_ADDR) begin
                state_w = S_IDLE;
                o_debug_w = 9'b000000001;
            end
        end
        S_PAUSE: begin
            if (i_resume) begin
                state_w = S_RECORD;
                o_debug_w = 9'b000001000;
            end
            else if (i_stop) begin
                state_w = S_IDLE;
                o_debug_w = 9'b000000001;
            end
        end
    endcase
end

// combinational
always_comb begin
    data_w = data_r;
    address_w = address_r;
    count_w = count_r;
    output_w = output_r;
    finish_w = 1'b0;
    
    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                address_w = 20'd0;
                output_w = 16'd0;
            end
        end
        S_CLEAR: begin
            output_w = 16'd0;
            address_w = address_r + 20'd1;
            if (address_r == MAX_ADDR) begin
                address_w = 20'd0;
                count_w = 10'd20;
            end
        end
        S_RECORD: begin
            if (i_lrc) begin
                count_w = 10'd0;
            end
            else begin
                count_w = count_r + 10'd1;
                if (count_r >= 1 && count_r <= 16) begin
                    data_w[16 - count_r] = i_data;
                end
                if (count_r == 17) begin
                    output_w = data_r;
                end
                if (count_r == 18) begin
                    address_w = address_r + 20'd1;
                end
            end
            if (address_r == MAX_ADDR) begin
                finish_w = 1'b1;
                address_w = 20'd0;
            end
        end
        S_RETRIEVED: begin
            if (address_r == MAX_ADDR) begin
                finish_w = 1'b1;
                address_w = 20'd0;
            end
        end
        S_PAUSE: begin
            if (i_resume) begin
                count_w = 10'd20;  // Skip first spurious data after resume
            end
        end
    endcase
end

// sequential
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        state_r <= S_IDLE;
        data_r <= 16'd0;
        address_r <= 20'd0;
        count_r <= 10'd0;
        output_r <= 16'd0;
        finish_r <= 1'b0;
        o_debug_r <= 9'd000000001;
    end
    else begin
        state_r <= state_w;
        data_r <= data_w;
        address_r <= address_w;
        count_r <= count_w;
        output_r <= output_w;
        finish_r <= finish_w;
        o_debug_r <= o_debug_w;
    end
end

endmodule