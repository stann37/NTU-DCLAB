module Effect_EQ (
    input  logic       i_clk,
    input  logic       i_rst_n,
    input  logic       i_valid,
    input  logic       i_enable,
    input  logic [2:0] i_level_treble,
    input  logic [2:0] i_level_bass,
    input  logic signed [15:0] i_data,
    output logic signed [15:0] o_data,
    output logic       o_valid
);

    // Q4.28
    logic signed [31:0] bass_a0, bass_a1, bass_a2, bass_b1, bass_b2;
    logic signed [31:0] treb_a0, treb_a1, treb_a2, treb_b1, treb_b2;

    // -12 dB to +9 dB
    // level 4 is flat
    always_comb begin
        // Bass LUT
        case (i_level_bass)
            3'd0: begin bass_a0 = 32'd259330623; bass_a1 = -32'd500665367; bass_a2 = 32'd241938545; bass_b1 = -32'd499765381; bass_b2 = 32'd233733699; end
            3'd1: begin bass_a0 = 32'd262189954; bass_a1 = -32'd506185610; bass_a2 = 32'd244606114; bass_b1 = -32'd505630587; bass_b2 = 32'd238915635; end
            3'd2: begin bass_a0 = 32'd264621522; bass_a1 = -32'd510880011; bass_a2 = 32'd246874608; bass_b1 = -32'd510573411; bass_b2 = 32'd243367275; end
            3'd3: begin bass_a0 = 32'd266685703; bass_a1 = -32'd514865133; bass_a2 = 32'd248800355; bass_b1 = -32'd514737055; bass_b2 = 32'd247178680; end
            3'd4: begin bass_a0 = 32'd268435456; bass_a1 = -32'd518243217; bass_a2 = 32'd250432760; bass_b1 = -32'd518243217; bass_b2 = 32'd250432760; end
            3'd5: begin bass_a0 = 32'd270196689; bass_a1 = -32'd518114299; bass_a2 = 32'd248800445; bass_b1 = -32'd518243217; bass_b2 = 32'd250432760; end
            3'd6: begin bass_a0 = 32'd272304360; bass_a1 = -32'd517932197; bass_a2 = 32'd246874876; bass_b1 = -32'd518243217; bass_b2 = 32'd250432760; end
            3'd7: begin bass_a0 = 32'd274829729; bass_a1 = -32'd517674972; bass_a2 = 32'd244606731; bass_b1 = -32'd518243217; bass_b2 = 32'd250432760; end
        endcase

        // Treble LUT
        case (i_level_treble)
            3'd0: begin treb_a0 = 32'd80067259;  treb_a1 = -32'd105919965; treb_a2 = 32'd40034125;  treb_b1 = -32'd442812889; treb_b2 = 32'd188558853; end
            3'd1: begin treb_a0 = 32'd109432643; treb_a1 = -32'd144767059; treb_a2 = 32'd54716999;  treb_b1 = -32'd425631487; treb_b2 = 32'd176578614; end
            3'd2: begin treb_a0 = 32'd148675449; treb_a1 = -32'd196680872; treb_a2 = 32'd74338645;  treb_b1 = -32'd405534163; treb_b2 = 32'd163431930; end
            3'd3: begin treb_a0 = 32'd200585074; treb_a1 = -32'd265351459; treb_a2 = 32'd100293779; treb_b1 = -32'd382147090; treb_b2 = 32'd149239028; end
            3'd4: begin treb_a0 = 32'd268435456; treb_a1 = -32'd355109871; treb_a2 = 32'd134219390; treb_b1 = -32'd355109871; treb_b2 = 32'd134219390; end
            3'd5: begin treb_a0 = 32'd359237069; treb_a1 = -32'd511413069; treb_a2 = 32'd199720975; treb_b1 = -32'd355109871; treb_b2 = 32'd134219390; end
            3'd6: begin treb_a0 = 32'd484663706; treb_a1 = -32'd732197204; treb_a2 = 32'd295078474; treb_b1 = -32'd355109871; treb_b2 = 32'd134219390; end
            3'd7: begin treb_a0 = 32'd658465265; treb_a1 = -32'd1044063085; treb_a2 = 32'd433142795; treb_b1 = -32'd355109871; treb_b2 = 32'd134219390; end
        endcase
    end

    logic signed [15:0] w_bass_out_data;
    logic w_bass_out_valid;

    logic signed [15:0] w_treb_out_data;
    logic w_treb_out_valid;

    Biquad_Filter u_bass (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_valid(i_valid),
        .i_data(i_data),
        
        .i_a0(bass_a0), .i_a1(bass_a1), .i_a2(bass_a2),
        .i_b1(bass_b1), .i_b2(bass_b2),
        
        .o_data(w_bass_out_data),
        .o_valid(w_bass_out_valid)
    );

    Biquad_Filter u_treble (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_valid(w_bass_out_valid),
        .i_data(w_bass_out_data),
        
        .i_a0(treb_a0), .i_a1(treb_a1), .i_a2(treb_a2),
        .i_b1(treb_b1), .i_b2(treb_b2),
        
        .o_data(w_treb_out_data),
        .o_valid(w_treb_out_valid)
    );


    always_comb begin
        if (i_enable) begin
            o_data  = w_treb_out_data;
            o_valid = w_treb_out_valid;
        end else begin
            o_data  = i_data;
            o_valid = i_valid;
        end
    end

endmodule


module Biquad_Filter (
    input  logic i_clk,
    input  logic i_rst_n,
    input  logic i_valid,
    input  logic signed [15:0] i_data,

    input  logic signed [31:0] i_a0,
    input  logic signed [31:0] i_a1,
    input  logic signed [31:0] i_a2,
    input  logic signed [31:0] i_b1,
    input  logic signed [31:0] i_b2,

    output logic signed [15:0] o_data,
    output logic o_valid
);

    logic signed [15:0] x_d1, x_d2;
    logic signed [15:0] y_d1, y_d2;
    
    logic signed [47:0] mul_a0, mul_a1, mul_a2;
    logic signed [47:0] mul_b1, mul_b2;
    logic signed [63:0] acc;
    logic signed [15:0] next_out;

    always_comb begin
        mul_a0 = i_data * i_a0;
        mul_a1 = x_d1   * i_a1;
        mul_a2 = x_d2   * i_a2;
        mul_b1 = y_d1   * i_b1;
        mul_b2 = y_d2   * i_b2;

        acc = (mul_a0 + mul_a1 + mul_a2) - (mul_b1 + mul_b2);

        if ((acc >>> 28) > 32767)       next_out = 32767;
        else if ((acc >>> 28) < -32768) next_out = -32768;
        else                            next_out = acc[43:28];
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            x_d1 <= 0;
            x_d2 <= 0;
            y_d1 <= 0;
            y_d2 <= 0;
            o_data <= 0;
            o_valid <= 0;
        end else begin
            o_valid <= i_valid;

            if (i_valid) begin
                x_d2 <= x_d1;
                x_d1 <= i_data;
                y_d2 <= y_d1;
                y_d1 <= next_out; // Use the result we just calculated
                
                o_data <= next_out;
            end
        end
    end

endmodule