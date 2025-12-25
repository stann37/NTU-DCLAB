module Effect_Gate (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,              // Trigger IN
    input  i_enable,
    input  [2:0] i_level,
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output logic o_valid         // Trigger OUT
);

    logic signed [15:0] data_out_r;
    assign o_data = data_out_r;

    logic valid_r;
    assign o_valid = valid_r;

    logic signed [15:0] abs_data;
    assign abs_data = (i_data[15]) ? -i_data : i_data; 

    logic signed [15:0] threshold;
    always_comb begin
        case (i_level)
            3'd0: threshold = 16'd0;
            3'd1: threshold = 16'd25;
            3'd2: threshold = 16'd50;
            3'd3: threshold = 16'd75;
            3'd4: threshold = 16'd100;
            3'd5: threshold = 16'd125;
            3'd6: threshold = 16'd150;
            3'd7: threshold = 16'd175;
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            data_out_r <= 16'd0;
            valid_r    <= 1'b0;
        end else begin
            valid_r <= i_valid;
            
            if (i_valid) begin
                if (i_enable) begin
                    // GATE LOGIC
                    if (abs_data < threshold) 
                        data_out_r <= 16'd0; // Mute
                    else 
                        data_out_r <= i_data; // Pass through
                end else begin
                    // BYPASS
                    data_out_r <= i_data;
                end
            end
        end
    end

endmodule
