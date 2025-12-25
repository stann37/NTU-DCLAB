module Effect_Tremolo (
    input                i_clk,
    input                i_rst_n,
    input                i_clk_tri,
    input                i_valid,
    input                i_enable,
    input         [2:0]  i_freq,
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output               o_valid
);

    logic [1:0] freq_r, freq_w;
    logic       valid_r;
    logic signed [31:0] tri_data_w;
    logic signed [15:0] tremolo_data_r, tremolo_data_w;
    logic signed [47:0] temp_data_w;

    assign o_data = tremolo_data_r;
    assign o_valid = valid_r;

    Triangle_generator tri_gen(
        .i_clk(i_clk_tri),
        .i_rst_n(i_rst_n),
        .i_start(i_enable),
        .i_freq(i_freq),
        .o_tri(tri_data_w)
    );

    always_comb begin
        temp_data_w = tri_data_w * i_data;
        tremolo_data_w = (((temp_data_w) >>> 31) > 32767) ? 32767 : ((((temp_data_w) >>> 31) < -32768) ? -32768 : (temp_data_w) >>> 31);
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            freq_r <= 0;
            tremolo_data_r <= 0;
            valid_r <= 0;
        end
        else begin
            if (i_enable) begin
                tremolo_data_r <= tremolo_data_w;
            end
            else begin
                tremolo_data_r <= i_data;
            end
            valid_r <= i_valid;
        end
    end

    
endmodule