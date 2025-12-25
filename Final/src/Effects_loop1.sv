module Effect_Loop1 (
    input                      i_clk,
    input                      i_rst_n,
    input                      i_valid,
    // input i_enable,
    input  signed [2:0]        i_level,
    input  signed [15:0]       i_data,
    input  [1:0]               i_state, // 0: unenabled, 1: record 2: play 
    input  [15:0]              i_sram_rdata,
    output logic [19:0]        o_sram_addr,
    output logic               o_sram_we_n,
    output logic signed [15:0] o_sram_wdata,
    output                     o_record_finish,

    output signed [15:0]       o_data,
    output logic               o_valid
);

    localparam PERIOD_MAX = 320000; // 10 sec
    localparam START_ADDR = 352000;
    localparam MAX_ADDR = 671999;

    // FSM state in Top
    // localparam TOP_RECD_LOOP = 3'd3;
    // localparam TOP_PLAY_LOOP = 3'd4;
    localparam UNENABLED = 2'd0;
    localparam RECORD = 2'd1; 
    localparam PLAY = 2'd2;

    // FSM
    localparam S_IDLE = 3'd0;
    localparam S_WRITE = 3'd1;
    localparam S_READ_REQ = 3'd2;
    localparam S_READ_LATCH = 3'd3;
    localparam S_MIX = 3'd4;

    logic [2:0] state_r, state_w;

    logic [19:0] waddr_r, waddr_w, raddr_r, raddr_w;
    logic [19:0] period_r, period_w;
    logic valid_r, valid_w;

    logic finish_r, finish_w;

    logic signed [15:0] captured_input_r, captured_input_w, looped_sample_r, looped_sample_w;
    logic signed [4:0] sample_weight, input_weight;
    logic signed [19:0] scaled_input, scaled_sample;
    logic signed [15:0] looped_data, output_data_r, output_data_w;

    // two inputs
    always_comb begin
        captured_input_w = captured_input_r;
        looped_sample_w = looped_sample_r;
        case (state_r) 
            S_IDLE: begin
                if (i_valid) begin
                    captured_input_w = i_data;
                end
            end
            S_READ_LATCH: begin
                looped_sample_w = i_sram_rdata;
            end
        endcase
    end

    // mix data
    assign sample_weight = i_level + 5'd1;
    assign input_weight = 5'd7 - i_level;
    assign scaled_input = captured_input_r * input_weight;
    assign scaled_sample = looped_sample_r * sample_weight;
    assign looped_data = (scaled_input + scaled_sample) >>> 3;

    // output
    assign output_data_w = (i_state == PLAY) ? looped_data : captured_input_r;
    assign o_data = output_data_r;
    assign valid_w = (state_r == S_MIX) ? 1 : 0;
    assign o_valid = valid_r;
    assign o_record_finish = finish_r;

    // period waddr raddr finish
    always_comb begin
        period_w = period_r;
        waddr_w = waddr_r;
        raddr_w = raddr_r;
        finish_w = 0;
        case (i_state)
            RECORD: begin
                if (i_valid) begin 
                    period_w = (period_r < MAX_ADDR) ? period_r + 1 : MAX_ADDR;
                    waddr_w = (waddr_r < MAX_ADDR) ? waddr_r + 1 : MAX_ADDR;
                end
                else begin
                    period_w = period_r;
                    waddr_w = waddr_r;
                end
                if (period_r >= MAX_ADDR) finish_w = 1;
            end 
            PLAY: begin
                period_w = period_r;
                if (i_valid) begin
                    raddr_w = (raddr_r < period_r - 1) ? raddr_r + 1 : START_ADDR;
                end
            end
            default: begin
                period_w = START_ADDR;
                waddr_w = START_ADDR;
                raddr_w = START_ADDR;
            end
        endcase
    end

    // FSM
    always_comb begin
        state_w = state_r;
        case (state_r)
            S_IDLE: if (i_valid) state_w = S_WRITE;
            S_WRITE: state_w = S_READ_REQ;
            S_READ_REQ: state_w = S_READ_LATCH;
            S_READ_LATCH: state_w = S_MIX;
            S_MIX: state_w = S_IDLE;
        endcase
    end 

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state_r <= S_IDLE;
            period_r <= START_ADDR;
            waddr_r <= START_ADDR;
            raddr_r <= START_ADDR;
            captured_input_r <= 0;
            looped_sample_r <= 0;
            output_data_r <= 0;
            valid_r <= 0;
            finish_r <= 0;
        end
        else begin
            state_r <= state_w;
            period_r <= period_w;
            waddr_r <= waddr_w;
            raddr_r <= raddr_w;
            captured_input_r <= captured_input_w;
            looped_sample_r <= looped_sample_w;
            output_data_r <= output_data_w;
            valid_r <= valid_w;
            finish_r <= finish_w;
        end
    end

    // SRAM control
    always_comb begin
        o_sram_addr  = 20'd0;
        o_sram_we_n  = 1'b1;
        o_sram_wdata = 16'd0;
        case (state_r)
            S_WRITE: begin
                o_sram_addr  = waddr_r;
                if (i_state == RECORD) begin
                    o_sram_wdata = captured_input_r;
                    o_sram_we_n  = 1'b0;
                end
            end
            S_READ_REQ, S_READ_LATCH: begin
                o_sram_addr  = raddr_r;
            end
        endcase
    end

endmodule