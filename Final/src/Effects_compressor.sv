module Effect_Compressor (
    input  logic             i_clk,
    input  logic             i_rst_n,
    input  logic             i_valid,   // Sync pulse from previous stage
    input  logic             i_enable,  // Switch to enable/bypass
    input  logic [2:0]       i_level,   // 0 (Light) to 7 (Heavy)
    input  signed [15:0]     i_data,    // Input Audio
    output logic signed [15:0] o_data,  // Output Audio
    output logic             o_valid    // Sync pulse to next stage
);

    logic signed [15:0] abs_data;
    assign abs_data = (i_data[15]) ? -i_data : i_data;

    logic signed [15:0] threshold;
    logic [3:0]         makeup_shift;

    always_comb begin
        case (i_level)
            3'd0: begin threshold = 16'd30000;              makeup_shift = 4'd0; end
            3'd1: begin threshold = 16'd27000;              makeup_shift = 4'd0; end
            3'd2: begin threshold = 16'd24000;              makeup_shift = 4'd0; end
            3'd3: begin threshold = 16'd21000;              makeup_shift = 4'd0; end
            3'd4: begin threshold = 16'd18000;              makeup_shift = 4'd0; end
            3'd5: begin threshold = 16'd15000;               makeup_shift = 4'd0; end
            3'd6: begin threshold = 16'd12000;               makeup_shift = 4'd1; end // ~2.0x
            3'd7: begin threshold = 16'd9000;               makeup_shift = 4'd1; end // ~2.0x
        endcase
    end

    logic signed [15:0] compressed_abs;
    logic signed [15:0] diff;
    logic signed [15:0] gain_adjusted;

    always_comb begin
        diff = abs_data - threshold;
        if (abs_data > threshold) begin
            compressed_abs = threshold + (diff >>> 2); 
        end else begin
            compressed_abs = abs_data;
        end
    end

    assign gain_adjusted = compressed_abs <<< makeup_shift;
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_data  <= 16'd0;
            o_valid <= 1'b0;
        end else begin
            o_valid <= i_valid;

            if (i_valid) begin
                if (i_enable) begin
                    if (i_data[15]) // Was originally negative
                        o_data <= -gain_adjusted;
                    else            // Was originally positive
                        o_data <= gain_adjusted;
                        
                end else begin
                    o_data <= i_data;
                end
            end
        end
    end

endmodule