module Effect_Delay (
    input  logic         i_clk,
    input  logic         i_rst_n,
    input  logic         i_valid,
    input  logic         i_enable,
    input  [2:0]         i_level,
    input  signed [15:0] i_data,

    input  signed [15:0] i_sram_rdata, // Data read FROM SRAM
    output logic  [19:0] o_sram_addr,  // Address request
    output logic         o_sram_we_n,  // 0=Write, 1=Read
    output logic signed [15:0] o_sram_wdata, // Data to write

    output logic signed [15:0] o_data,
    output logic         o_valid
);
    // we need 1s of delay buffer: 32000 samples

    // work flow: write new sample, read old sample, process with current, output
    // for now, use constant delay of 9000 samples just to test the functionality

    logic [19:0] write_ptr;
    logic [19:0] read_ptr;

    logic [19:0] delay_samples_var;

    always_comb begin
        case (i_level)
            3'd0: delay_samples_var = 20'd4000;
            3'd1: delay_samples_var = 20'd8000;
            3'd2: delay_samples_var = 20'd12000;
            3'd3: delay_samples_var = 20'd16000;
            3'd4: delay_samples_var = 20'd20000;
            3'd5: delay_samples_var = 20'd24000;
            3'd6: delay_samples_var = 20'd28000;
            3'd7: delay_samples_var = 20'd31999;
        endcase
    end

    localparam MAX_BUFFER  = 20'd32000; 
    localparam DELAY_SAMPLES = 20'd9000;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            write_ptr <= 0;
        end else begin
            if (i_valid) begin
                if (write_ptr >= MAX_BUFFER - 1) 
                    write_ptr <= 0;
                else 
                    write_ptr <= write_ptr + 1;
            end
        end
    end

    assign read_ptr = (write_ptr >= delay_samples_var) ? (write_ptr - delay_samples_var) : (MAX_BUFFER + write_ptr - delay_samples_var);

    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_WRITE = 3'd1;
    localparam [2:0] S_READ_REQ = 3'd2;
    localparam [2:0] S_READ_LATCH = 3'd3;
    localparam [2:0] S_MIX = 3'd4;

    logic [2:0] state;

    logic signed [15:0] captured_input; // Store input stable
    logic signed [15:0] delayed_sample; // Store SRAM data
    logic signed [16:0] scaled_input, scaled_sample;
    logic signed [15:0] delayed_data;
    assign scaled_input = captured_input;
    assign scaled_sample = delayed_sample;
    assign delayed_data = (scaled_input + scaled_sample) >>> 1;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= S_IDLE;
            o_valid <= 0;
            o_data <= 0;
            captured_input <= 0;
            delayed_sample <= 0;
        end
        else begin
            o_valid <= 0; // default
            case (state)
                S_IDLE: begin
                    if (i_valid) begin
                        captured_input <= i_data; // Latch input audio
                        state <= S_WRITE;
                    end
                end
                S_WRITE: begin
                    // Wait 1 cycle for write to finish
                    state <= S_READ_REQ;
                end
                S_READ_REQ: begin
                    // Wait 1 cycle for address setup
                    state <= S_READ_LATCH;
                end
                S_READ_LATCH: begin
                    delayed_sample <= i_sram_rdata; 
                    state <= S_MIX;
                end
                S_MIX: begin
                    if (i_enable) begin
                        o_data <= delayed_data;
                    end else begin
                        o_data <= captured_input;
                    end
                    o_valid <= 1;
                    state <= S_IDLE;
                end
            endcase
        end  
    end

    always_comb begin
        o_sram_addr  = 20'd0;
        o_sram_we_n  = 1'b1; // read 
        o_sram_wdata = 16'd0;

        case (state)
            S_WRITE: begin
                o_sram_addr  = write_ptr;
                o_sram_wdata = captured_input;
                o_sram_we_n  = 1'b0; // Active Low WRITE
            end

            S_READ_REQ, S_READ_LATCH: begin
                o_sram_addr  = read_ptr;
                o_sram_we_n  = 1'b1; // READ
            end
            
            // S_IDLE, S_MIX: Do nothing (bus released by Top.sv anyway)
        endcase
    end
endmodule