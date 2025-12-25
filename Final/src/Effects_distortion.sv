module Effect_Distortion (
    input  logic         i_clk,
    input  logic         i_rst_n,
    input  logic         i_valid,
    input  logic         i_enable,
    input  [2:0]         i_level,
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output logic         o_valid
);

    integer i;
    logic [2:0] level;
    logic signed [15:0] max_abs;
    assign level = (i_level == 3'b0) ? 3'b111 : i_level;
    assign max_abs = {2'b0, level, 11'b0};

    // p1
    logic p1_valid_r, p1_enable_r;
    logic signed [15:0] p1_data_r;
    logic signed [15:0] p1_dist_r[0:11];
    logic signed [15:0] dist_w[0:11];

    assign dist_w[0] = max_abs;
    assign dist_w[1] = max_abs - (max_abs >>> 4);
    assign dist_w[2] = max_abs - (max_abs >>> 3);
    assign dist_w[3] = max_abs - (max_abs >>> 3) - (max_abs >>> 4);
    assign dist_w[4] = max_abs - (max_abs >>> 2);
    assign dist_w[5] = max_abs - (max_abs >>> 2) - (max_abs >>> 4);
    assign dist_w[6] = (max_abs >>> 1) + (max_abs >>> 3);
    assign dist_w[7] = (max_abs >>> 1) + (max_abs >>> 4);
    assign dist_w[8] = (max_abs >>> 1);
    assign dist_w[9] = (max_abs >>> 1) - (max_abs >>> 4);
    assign dist_w[10] = (max_abs >>> 1) - (max_abs >>> 3);
    assign dist_w[11] = (max_abs >>> 2) + (max_abs >>> 4);

    // p2
    logic signed [15:0] p2_data_r, p2_data_w; 
    logic p2_valid_r, p2_valid_w;
    logic [15:0] abs_data;
    assign abs_data = p1_data_r[15] ? -p1_data_r : p1_data_r;

    
    assign p2_valid_w = p1_valid_r;
    logic signed [15:0] result_abs;

    always_comb begin
        if (abs_data >= p1_dist_r[6]) begin
            if (abs_data >= p1_dist_r[3]) begin
                if (abs_data >= p1_dist_r[1]) begin
                    if (abs_data >= p1_dist_r[0])
                        result_abs = p1_dist_r[0];
                    else
                        result_abs = p1_dist_r[1];
                end else begin
                    if (abs_data >= p1_dist_r[2])
                        result_abs = p1_dist_r[2];
                    else
                        result_abs = p1_dist_r[3];
                end                
            end else begin
                if (abs_data >= p1_dist_r[5]) begin
                    if (abs_data >= p1_dist_r[4])
                        result_abs = p1_dist_r[4];
                    else
                        result_abs = p1_dist_r[5];
                end else begin
                    result_abs = p1_dist_r[6];
                end
            end
            
        end else begin
            if (abs_data >= p1_dist_r[9]) begin
                if (abs_data >= p1_dist_r[8]) begin
                    if (abs_data >= p1_dist_r[7])
                        result_abs = p1_dist_r[7];
                    else
                        result_abs = p1_dist_r[8];
                end else begin
                    result_abs = p1_dist_r[9];
                end
            end else begin
                if (abs_data >= p1_dist_r[10])
                    result_abs = p1_dist_r[10];
                else if (abs_data >= p1_dist_r[11])
                    result_abs = p1_dist_r[11];
                else
                    result_abs = abs_data;
            end
        end
        p2_data_w = p1_data_r[15] ? -result_abs : result_abs;
    end
    // always_comb begin
    //     if (abs_data >= p1_dist_r[0]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[0] : p1_dist_r[0]);
    //     else if (abs_data >= p1_dist_r[1] && abs_data < p1_dist_r[0]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[1] : p1_dist_r[1]);
    //     else if (abs_data >= p1_dist_r[2] && abs_data < p1_dist_r[1]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[2] : p1_dist_r[2]);
    //     else if (abs_data >= p1_dist_r[3] && abs_data < p1_dist_r[2]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[3] : p1_dist_r[3]);
    //     else if (abs_data >= p1_dist_r[4] && abs_data < p1_dist_r[3]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[4] : p1_dist_r[4]);
    //     else if (abs_data >= p1_dist_r[5] && abs_data < p1_dist_r[4]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[5] : p1_dist_r[5]);
    //     else if (abs_data >= p1_dist_r[6] && abs_data < p1_dist_r[5]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[6] : p1_dist_r[6]);
    //     else if (abs_data >= p1_dist_r[7] && abs_data < p1_dist_r[6]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[7] : p1_dist_r[7]);
    //     else if (abs_data >= p1_dist_r[8] && abs_data < p1_dist_r[7]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[8] : p1_dist_r[8]);
    //     else if (abs_data >= p1_dist_r[9] && abs_data < p1_dist_r[8]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[9] : p1_dist_r[9]);
    //     else if (abs_data >= p1_dist_r[10] && abs_data < p1_dist_r[9]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[10] : p1_dist_r[10]);
    //     else if (abs_data >= p1_dist_r[11] && abs_data < p1_dist_r[10]) p2_data_w = (p1_data_r[15] ? -p1_dist_r[11] : p1_dist_r[11]);
    //     else p2_data_w = p1_data_r;
    // end
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            p1_data_r <= 16'b0;
            p1_valid_r <= 1'b0;
            p1_enable_r <= 1'b0;
            for (i = 0; i < 12; i = i + 1) begin
                p1_dist_r[i] <= 16'b0;
            end
            p2_data_r <= 16'b0;
            p2_valid_r <= 1'b0;
        end else begin
            p1_data_r <= (i_data == 16'h8000) ? 16'h8001 : i_data;
            p1_valid_r <= i_valid;
            p1_enable_r <= i_enable;
            for (i = 0; i < 12; i = i + 1) begin
                p1_dist_r[i] <= dist_w[i];
            end
            p2_valid_r <= p2_valid_w;
            if(p1_enable_r) p2_data_r <= p2_data_w;
            else p2_data_r <= p1_data_r;
        end
    end

    assign o_data = p2_data_r;
    assign o_valid = p2_valid_r;

endmodule