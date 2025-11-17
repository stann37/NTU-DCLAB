module Rsa256Core (
    input          i_clk,
    input          i_rst,
    input          i_start,
    input  [255:0] i_a,
    input  [255:0] i_d,
    input  [255:0] i_n,
    output [255:0] o_a_pow_d,
    output         o_finished
);

typedef enum logic [2:0] {
    S_IDLE  = 3'd0,
    S_PREP  = 3'd1,
    S_CALC  = 3'd2,
    S_MONT  = 3'd3,
    S_DONE  = 3'd4
} STATE;

STATE state_r, state_w;

logic [255:0] d_r, d_w;
logic [259:0] n_r, n_w;
logic [259:0] m_r, m_w;
logic [259:0] t_r, t_w;
logic [8:0]   bit_counter_r, bit_counter_w;
logic [255:0] result_r, result_w;
logic         finished_r, finished_w;

logic         prep_start;
logic [259:0] prep_result;
logic         prep_done;

logic         mont_start;
logic [259:0] mont_a, mont_b;
logic [259:0] mont_result;
logic         mont_done;

logic         need_m_mult_r, need_m_mult_w;

RsaPrep prep_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(prep_start),
    .i_y(i_a),
    .i_n(n_r),
    .o_result(prep_result),
    .o_finished(prep_done)
);

RsaMont mont_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(mont_start),
    .i_a(mont_a),
    .i_b(mont_b),
    .i_n(n_r),
    .o_result(mont_result),
    .o_finished(mont_done)
);

assign o_a_pow_d = result_r;
assign o_finished = finished_r;

always_comb begin
    state_w = state_r;
    d_w = d_r;
    n_w = n_r;
    m_w = m_r;
    t_w = t_r;
    bit_counter_w = bit_counter_r;
    result_w = result_r;
    finished_w = 1'b0;
    need_m_mult_w = need_m_mult_r;
    
    prep_start = 1'b0;
    mont_start = 1'b0;
    mont_a = 260'd0;
    mont_b = 260'd0;
    
    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                d_w = i_d;
                n_w = {4'd0, i_n};
                m_w = 260'd1;
                bit_counter_w = 9'd0;
                prep_start = 1'b1;
                state_w = S_PREP;
            end
        end
        
        S_PREP: begin
            if (prep_done) begin
                t_w = prep_result;
                state_w = S_CALC;
            end
        end
        
        S_CALC: begin
            if (bit_counter_r < 9'd256) begin
                if (d_r[bit_counter_r] == 1'b1) begin
                    need_m_mult_w = 1'b1;
                    mont_a = m_r;
                    mont_b = t_r;
                end
                else begin
                    need_m_mult_w = 1'b0;
                    mont_a = t_r;
                    mont_b = t_r;
                end
                
                mont_start = 1'b1;
                state_w = S_MONT;
            end
            else begin
                result_w = m_r[255:0];
                state_w = S_DONE;
            end
        end
        
        S_MONT: begin
            if (mont_done) begin
                if (need_m_mult_r) begin
                    m_w = mont_result;
                    mont_a = t_r;
                    mont_b = t_r;
                    mont_start = 1'b1;
                    need_m_mult_w = 1'b0;
                end
                else begin
                    t_w = mont_result;
                    bit_counter_w = bit_counter_r + 9'd1;
                    state_w = S_CALC;
                end
            end
        end
        
        S_DONE: begin
            finished_w = 1'b1;
            state_w = S_IDLE;
        end
        
        default: begin
            state_w = S_IDLE;
        end
    endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        state_r       <= S_IDLE;
        d_r           <= 256'd0;
        n_r           <= 260'd0;
        m_r           <= 260'd1;
        t_r           <= 260'd0;
        bit_counter_r <= 9'd0;
        result_r      <= 256'd0;
        finished_r    <= 1'b0;
        need_m_mult_r <= 1'b0;
    end
    else begin
        state_r       <= state_w;
        d_r           <= d_w;
        n_r           <= n_w;
        m_r           <= m_w;
        t_r           <= t_w;
        bit_counter_r <= bit_counter_w;
        result_r      <= result_w;
        finished_r    <= finished_w;
        need_m_mult_r <= need_m_mult_w;
    end
end

endmodule

module RsaMont (
    input i_clk,
    input i_rst,
    input i_start,
    input [259:0] i_a,
    input [259:0] i_b,
    input [259:0] i_n,
    output [259:0] o_result,
    output o_finished
);

typedef enum logic [1:0] {
    S_IDLE   = 2'd0,
    S_CALC   = 2'd1,
    S_REDUCE = 2'd2,
    S_DONE   = 2'd3
} STATE;

STATE state_r, state_w;
logic [259:0] m_r, m_w;
logic [259:0] a_r, a_w;
logic [259:0] b_r, b_w;
logic [259:0] n_r, n_w;
logic [8:0]   counter_r, counter_w;
logic         finished_r, finished_w;

assign o_result = m_r;
assign o_finished = finished_r;

always_comb begin
    state_w = state_r;
    m_w = m_r;
    a_w = a_r;
    b_w = b_r;
    n_w = n_r;
    counter_w = counter_r;
    finished_w = 1'b0;

    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                m_w = 260'd0;
                a_w = i_a;
                b_w = i_b;
                n_w = i_n;
                counter_w = 9'd0;
                state_w = S_CALC;
            end
        end
        
        S_CALC: begin
            if (counter_r < 9'd256) begin
                if (a_r[counter_r] == 1'b1) begin
                    if (m_r[0] ^ b_r[0])
                        m_w = (m_r + b_r + n_r) >> 1;
                    else 
                        m_w = (m_r + b_r) >> 1;
                end
                else begin
                    if (m_r[0] == 1'b1) 
                        m_w = (m_r + n_r) >> 1;
                    else 
                        m_w = m_r >> 1;
                end
                counter_w = counter_r + 9'd1;
            end
            else begin
                state_w = S_REDUCE;
            end
        end
        
        S_REDUCE: begin
            if (m_r >= n_r) begin
                m_w = m_r - n_r;
            end
            state_w = S_DONE;
        end
        
        S_DONE: begin
            finished_w = 1'b1;
            state_w = S_IDLE;
        end
        
        default: begin
            state_w = S_IDLE;
        end
    endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        state_r    <= S_IDLE;
        m_r        <= 260'd0;
        a_r        <= 260'd0;
        b_r        <= 260'd0;
        n_r        <= 260'd0;
        counter_r  <= 9'd0;
        finished_r <= 1'b0;
    end
    else begin
        state_r    <= state_w;
        m_r        <= m_w;
        a_r        <= a_w;
        b_r        <= b_w;
        n_r        <= n_w;
        counter_r  <= counter_w;
        finished_r <= finished_w;
    end
end

endmodule

// Calculate y*2^256 mod N
module RsaPrep (
    input i_clk,
    input i_rst,
    input i_start,
    input [255:0] i_y,
    input [259:0] i_n,
    output [259:0] o_result,
    output o_finished
);

typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_REDUCE = 3'd1,
    S_DOUBLE = 3'd2,
    S_FINAL  = 3'd3,
    S_DONE   = 3'd4
} STATE;

STATE state_r, state_w;
logic [259:0] x_r, x_w;
logic [259:0] t_r, t_w;
logic [8:0]   counter_r, counter_w;
logic         finished_r, finished_w;

assign o_result = t_r;
assign o_finished = finished_r;

always_comb begin
    state_w = state_r;
    x_w = x_r;
    t_w = t_r;
    counter_w = counter_r;
    finished_w = finished_r;

    case (state_r)
        S_IDLE: begin
            finished_w = 1'b0;
            if (i_start) begin
                x_w = {4'd0, i_y};
                t_w = 260'd0;
                counter_w = 9'd0;
                state_w = S_REDUCE;
            end
        end
        
        S_REDUCE: begin
            if (x_r >= i_n) begin
                x_w = x_r - i_n;
                // Stay in S_REDUCE
            end
            else if (counter_r == 9'd256) begin
                state_w = S_FINAL;
            end
            else begin
                state_w = S_DOUBLE;
            end
        end
        
        S_DOUBLE: begin
            if (x_r + x_r >= i_n)
                x_w = x_r + x_r - i_n;
            else
                x_w = x_r + x_r;
            
            counter_w = counter_r + 9'd1;
            state_w = S_REDUCE;
        end
        
        S_FINAL: begin
            if (x_r >= i_n)
                t_w = x_r - i_n;
            else
                t_w = x_r;
            
            state_w = S_DONE;
        end
        
        S_DONE: begin
            finished_w = 1'b1;
            state_w = S_IDLE;
        end
        
        default: begin
            state_w = S_IDLE;
        end
    endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        state_r    <= S_IDLE;
        x_r        <= 260'd0;
        t_r        <= 260'd0;
        counter_r  <= 9'd0;
        finished_r <= 1'b0;
    end
    else begin
        state_r    <= state_w;
        x_r        <= x_w;
        t_r        <= t_w;
        counter_r  <= counter_w;
        finished_r <= finished_w;
    end
end

endmodule