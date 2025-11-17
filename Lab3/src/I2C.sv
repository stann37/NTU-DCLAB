module I2cInitializer(
    input i_rst_n,
    input i_clk,
    input i_start,
    output o_finished,
    output o_sclk,
    output o_sdat,
    output o_oen
);

// parameter
localparam RESET = 24'b0011_0100_000_1111_0_0000_0000;
localparam LLI   = 24'b0011_0100_000_0000_0_1001_0111;
localparam RLI   = 24'b0011_0100_000_0001_0_1001_0111;
localparam LHO   = 24'b0011_0100_000_0010_0_0111_1001;
localparam RHO   = 24'b0011_0100_000_0011_0_0111_1001;
localparam AAPC  = 24'b0011_0100_000_0100_0_0001_0101;
localparam DAPC  = 24'b0011_0100_000_0101_0_0000_0000;
localparam PDC   = 24'b0011_0100_000_0110_0_0000_0000;
localparam DAIF  = 24'b0011_0100_000_0111_0_0100_0010;
localparam SC    = 24'b0011_0100_000_1000_0_0001_1001;
localparam AC    = 24'b0011_0100_000_1001_0_0000_0001;

// state
localparam S_IDLE = 1'b0;
localparam S_I2C = 1'b1;

// reg / wire
logic sclk_r, sclk_w;
logic sdat_r, sdat_w;
logic oen_r, oen_w;
logic state_r, state_w;
logic [4:0] data_count_r, data_count_w;
logic [3:0] inst_count_r, inst_count_w;
logic [23:0] inst_r, inst_w;

assign o_sclk = sclk_r;
assign o_sdat = sdat_r;
assign o_oen = oen_r;
assign o_finished = (inst_count_r == 4'd10) ? 1'b1 : 1'b0;

always @(*) begin
    state_w = state_r;
    case(state_r)
        S_IDLE: begin
            if((i_start && inst_count_r == 0) || (inst_count_r != 4'd11 && inst_count_r > 0)) state_w = S_I2C;
        end
        S_I2C: begin
            if(data_count_r == 28) state_w = S_IDLE;
        end
    endcase
end 

always @(*) begin
    sclk_w = sclk_r;
    sdat_w = sdat_r;
    oen_w = oen_r;
    data_count_w = data_count_r;
    inst_count_w = inst_count_r;
    inst_w = inst_r;
    case(state_r)
        S_IDLE: begin
            data_count_w = 0;
            if(i_start) sdat_w = 0;
            case(inst_count_r)
                4'd0: inst_w = LLI;
                4'd1: inst_w = RLI;
                4'd2: inst_w = LHO;
                4'd3: inst_w = RHO;
                4'd4: inst_w = AAPC;
                4'd5: inst_w = DAPC;
                4'd6: inst_w = PDC;
                4'd7: inst_w = DAIF;
                4'd8: inst_w = SC;
                4'd9: inst_w = AC;
                default: inst_w = 24'b0;
            endcase
            if(inst_count_r != 4'd10 && inst_count_r > 0) sdat_w = 0;
        end
        S_I2C: begin
            sclk_w = ~sclk_r;
            case(data_count_r)
                5'd8: oen_w = 0; // ACK
                5'd17: oen_w = 0;
                5'd26: oen_w = 0;
                5'd27: sdat_w = 0;
                5'd28: begin
                    sclk_w = 1;
                    sdat_w = 1;
                    inst_count_w = inst_count_r + 1;
                end
                default: begin
                    oen_w = 1;
                    if(sclk_r) begin
                        inst_w = inst_r << 1;
                        sdat_w = inst_r[23];
                    end
                end
            endcase
            if(!sclk_r) data_count_w = data_count_r + 1;
        end
    endcase
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        sclk_r <= 1'b1;
        sdat_r <= 1'b1;
        oen_r <= 1'b1;
        state_r <= S_IDLE;
        data_count_r <= 5'b0;
        inst_count_r <= 4'b0;
        inst_r <= 24'b0;
    end else begin
        sclk_r <= sclk_w;
        sdat_r <= sdat_w;
        oen_r <= oen_w;
        state_r <= state_w;
        data_count_r <= data_count_w;
        inst_count_r <= inst_count_w;
        inst_r <= inst_w;
    end
end

endmodule