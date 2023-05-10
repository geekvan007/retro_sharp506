//`define DEBUG_MODE

// 7-seg digital bitmap
//     AAAA         ; A = 8'h01;
//    F    B        ; B = 8'h02;
//    F    B        ; C = 8'h04;
//     GGGG         ; D = 8'h08;
//    E    C        ; E = 8'h10;
//    E    C        ; F = 8'h20;
//     DDDD P       ; G = 8'h40;
//                  ; P = 8'h80;

// symbols @ COM0-COM11
`define SYM7_0 8'h3F
`define SYM7_1 8'h06
`define SYM7_2 8'h5B
`define SYM7_3 8'h4F
`define SYM7_4 8'h66
`define SYM7_5 8'h6D
`define SYM7_6 8'h7D
`define SYM7_7 8'h07
`define SYM7_8 8'h7F
`define SYM7_9 8'h6F
`define SYM7_A 8'h77
`define SYM7_B 8'h7C
`define SYM7_C 8'h39
`define SYM7_D 8'h5E
`define SYM7_E 8'h79
`define SYM7_F 8'h71
`define SYM7_R 8'h50
`define SYM7_O 8'h5C

`define SYM7_MINUS 8'h40
`define SYM7_DOT   8'h80
`define SYM7_BLANK 8'h00

// State icon @ COM12
`define ICON_LRN  8'h01
`define ICON_STAT 8'h02
`define ICON_MEM  8'h04
`define ICON_ERR  8'h08
`define ICON_GRAD 8'h10
`define ICON_RAD  8'h20
`define ICON_DEG  8'h40

// COM bitmap
// S 888888 888888
// C 6789AB 012345
`define COM_DIG0   5
`define COM_DIG1   4
`define COM_DIG2   3
`define COM_DIG3   2
`define COM_DIG4   1
`define COM_DIG5   0
`define COM_DIG6  11
`define COM_DIG7  10
`define COM_DIG8  19
`define COM_DIG9   8
`define COM_DIG10  7
`define COM_DIG11  6
`define COM_ICON  12

module SHARP506_TOP (
	input        reset_n,
	output [3:0] adc_ch,
	output [2:0] dac_out,
	input  [1:0] adc_in,

	output       led_oe_n,
	output       led_clk,
	output       led_latch,
	output       led_data,

	output [2:0] debug_o
);

wire osc_clk; // on chip OSC
wire sys_clk;
wire adc_clk;
wire off_clk; // lcd off detection
wire busy_clk; // lcd busy detection
wire sys_reset;

wire sys_reset_n = reset_n;
//wire sys_reset_n = 1'b1;

assign sys_reset = ~sys_reset_n;

wire power_off;
wire calc_busy;

//------------------------------------------------------------------------------

// 250M / div
OSCZ osc_inst (
	.OSCOUT(osc_clk),
	.OSCEN(1'b1)
);
defparam osc_inst.FREQ_DIV = 100;
defparam osc_inst.S_RATE   = "SLOW";

//------------------------------------------------------------------------------

MCLK_DIVX sys_clk_div(
	.clk(osc_clk),
	.sys_reset_n(sys_reset_n),
	.clk_div2(),
	.clk_div4(), // 625k
	.clk_div8(sys_clk), // 312k
	.clk_div16(), // 156k
	.clk_div32(adc_clk), // 78k
	.clk_div64(off_clk) // 39k
);

assign busy_clk = off_clk;
//assign adc_clk = sys_clk;
//assign adc_clk = off_clk;

//------------------------------------------------------------------------------

OFF_DETECTOR u_off_det (
	.clk(off_clk),
	.sys_reset_n(sys_reset_n),
	.sample_i(adc_in),
	.power_off(power_off)
);

//------------------------------------------------------------------------------

wire       adc_sample;
wire       adc_write_en;
wire [6:0] adc_write_addr;
wire [1:0] adc_com_raw;
wire [2:0] adc_debug;

assign debug_o[0] = calc_busy;//adc_debug[2];
//assign debug_o[1] = adc_write_en;
//assign debug_o[2] = adc_sample;
assign debug_o[1] = adc_debug[0];
assign debug_o[2] = adc_debug[1];

// adc
ADC2_32CH u_adc2 (
	.clk(adc_clk),
	.sys_reset_n(sys_reset_n),
	.ch_sel_o(adc_ch),
	.dac_o(dac_out),
	.sample_i(adc_in),
	.write_en(adc_write_en),
	.write_addr(adc_write_addr),
	.sample_o(adc_sample),
	.com_raw_o(adc_com_raw),
	.debug_o(adc_debug)
);

//------------------------------------------------------------------------------

BUSY_DETECTOR u_busy_det (
	.clk(busy_clk),
	.sys_reset_n(sys_reset_n),
	.sample_i(adc_com_raw),
	.busy(calc_busy)
);

// 0: disp on
// 1: disp off
`ifdef DEBUG_MODE
assign led_oe_n = 1'b0;
`else
assign led_oe_n = power_off | calc_busy;
`endif

//------------------------------------------------------------------------------

// remap bits
wire        prom_clk;
wire [ 6:0] prom_addr;
wire [ 7:0] prom_dout;
wire [23:0] prom_dout_w;

assign prom_clk  = adc_clk;
assign prom_addr = adc_write_addr;

pROM prom_inst_0 (
	.DO({prom_dout_w[23:0], prom_dout[7:0]}),
	.CLK(prom_clk),
	.OCE(1'b1),
	.CE(1'b1),
	.RESET(sys_reset),
	.AD({4'd0, prom_addr[6:0], 3'd0})
);

defparam prom_inst_0.READ_MODE   = 1'b0;
defparam prom_inst_0.BIT_WIDTH   = 8;
defparam prom_inst_0.RESET_MODE  = "SYNC";
// remap LCD seg-com to LED
defparam prom_inst_0.INIT_RAM_00 = 256'h7F_7F_60_61_3D_38_45_40_2D_28_7F_7F_7F_7F_7F_7F__4D_48_55_50_00_05_58_5D_0D_08_15_10_1D_18_25_20;
defparam prom_inst_0.INIT_RAM_01 = 256'h7F_7F_64_62_3E_39_46_41_2E_29_7F_7F_7F_7F_7F_7F__4E_49_56_51_01_06_59_5E_0E_09_16_11_1E_19_26_21;
defparam prom_inst_0.INIT_RAM_02 = 256'h7F_7F_65_36_3C_3A_44_42_2C_2A_7F_7F_7F_7F_7F_7F__4C_4A_54_52_02_04_5A_5C_0C_0A_14_12_1C_1A_24_22;
defparam prom_inst_0.INIT_RAM_03 = 256'h7F_7F_66_63_3B_3F_43_47_2B_2F_7F_7F_7F_7F_7F_7F__4B_4F_53_57_07_03_5F_5B_0B_0F_13_17_1B_1F_23_27;

//------------------------------------------------------------------------------

wire       dbuf_w_clk;
wire [6:0] dbuf_w_addr;
wire       dbuf_w_data;
wire       dbuf_w_en;

wire       dbuf_r_clk;
wire [3:0] dbuf_r_addr;
wire [7:0] dbuf_r_data;

wire [23:0] sdpb_inst_0_dout_w; // unused

assign dbuf_w_clk  = adc_clk;
`ifdef DEBUG_MODE
assign dbuf_w_en   = 1'b0;
//assign dbuf_w_en   = adc_write_en;
`else
assign dbuf_w_en   = adc_write_en;
`endif
//assign dbuf_w_addr = adc_write_addr; // directly, for debug only
assign dbuf_w_addr = prom_dout[6:0]; // lookup
assign dbuf_w_data = adc_sample;

assign dbuf_r_clk  = sys_clk;

SDPB sdpb_inst_0 (
	.RESETA(sys_reset),
	.CEA(dbuf_w_en),
	.CLKA(dbuf_w_clk),
	.BLKSELA(3'b000),
	.ADA({7'd0, dbuf_w_addr[6:0]}),
	.DI({31'd0, dbuf_w_data}),

	.RESETB(sys_reset),
	.CEB(1'b1),
	.CLKB(dbuf_r_clk),
	.BLKSELB(3'b000),
	.ADB({7'd0, dbuf_r_addr[3:0], 3'b000}),
	.DO({sdpb_inst_0_dout_w[23:0], dbuf_r_data[7:0]}),

	.OCE(1'b1)
);

defparam sdpb_inst_0.READ_MODE   = 1'b0;
defparam sdpb_inst_0.BIT_WIDTH_0 = 1;
defparam sdpb_inst_0.BIT_WIDTH_1 = 8;
defparam sdpb_inst_0.BLK_SEL_0   = 3'b000;
defparam sdpb_inst_0.BLK_SEL_1   = 3'b000;
defparam sdpb_inst_0.RESET_MODE  = "SYNC";
`ifdef DEBUG_MODE
// display digitals at startup for test.
defparam sdpb_inst_0.INIT_RAM_00 = 256'h00000000_00000000_00000000_00000000_0000007F_6D664F5B_063F7C77_6F7F077D;
`endif

//------------------------------------------------------------------------------

wire [31:0] hc595_data;

HC595X3 u_595x3 (
	.clk(sys_clk),
	.sys_reset_n(sys_reset_n),
	.data_i(hc595_data),
	.shcp(led_clk),
	.stcp(led_latch),
	.data_o(led_data)
);

LED_CONTROLLER u_led_ctrl (
	.clk(sys_clk),
	.sys_reset_n(sys_reset_n),
	.char_clk(),
	.addr_o(dbuf_r_addr),
	.data_i(dbuf_r_data),
	.data_o(hc595_data)
);

endmodule

//==============================================================================

module MCLK_DIVX (
	input clk,
	input sys_reset_n,

	output clk_div2,
	output clk_div4,
	output clk_div8,
	output clk_div16,
	output clk_div32,
	output clk_div64
);

reg [5:0] clk_cnt = 0;

always@(posedge clk or negedge sys_reset_n) begin
	if (~sys_reset_n)
		clk_cnt <= 0;
	else
		clk_cnt <= clk_cnt + 6'b1;
end

assign clk_div2  = clk_cnt[0];
assign clk_div4  = clk_cnt[1];
assign clk_div8  = clk_cnt[2];
assign clk_div16 = clk_cnt[3];
assign clk_div32 = clk_cnt[4];
assign clk_div64 = clk_cnt[5];

endmodule

//==============================================================================

module HC595X3 (
	input         clk,
	input         sys_reset_n,
	input  [31:0] data_i,
	output        shcp,
	output        stcp,
	output        data_o
);

reg        stcp_r    = 0;
reg [ 4:0] bit_count = 0;
reg [31:0] data_buf  = 0;

assign stcp   = stcp_r;
assign data_o = data_buf[31];
assign shcp   = clk;

always@(negedge shcp or negedge sys_reset_n) begin
	if (~sys_reset_n) begin
		data_buf  <= 32'h0000;
		bit_count <= 0;
		stcp_r    <= 0;
	end else if (bit_count == 5'd31) begin
//	end else if (bit_count == 5'd20) begin
		// reload
		data_buf  <= data_i;
		bit_count <= 0;
		stcp_r    <= 1;
	end else  begin
		data_buf  <= { data_buf [30:0], 1'b0 };
		bit_count <= bit_count + 5'b1;
		stcp_r    <= 0;
	end
end

endmodule

//==============================================================================

module LED_CONTROLLER (
	input         clk,
	input         sys_reset_n,
	output        char_clk,
	output [ 3:0] addr_o,
	input  [ 7:0] data_i,
	output [31:0] data_o
);

MCLK_DIVX clk_divx (
	.clk(clk),
	.sys_reset_n(sys_reset_n),
	.clk_div2(),
	.clk_div4(),
	.clk_div8(),
	.clk_div16(),
	.clk_div32(char_clk),
	.clk_div64()
);

reg  [ 3:0] addr;
reg  [ 3:0] addr_pre;
reg  [12:0] bit_pos; // one hot

// for debug only
//wire [7:0] seg_map [12:0];
//assign seg_map[ 0] = `SYM7_7;
//assign seg_map[ 1] = `SYM7_8;
//assign seg_map[ 2] = `SYM7_9;
//assign seg_map[ 3] = `SYM7_0;
//assign seg_map[ 4] = `SYM7_A;
//assign seg_map[ 5] = `SYM7_B;
//assign seg_map[ 6] = `SYM7_C;
//assign seg_map[ 7] = `SYM7_D;
//assign seg_map[ 8] = `SYM7_E;
//assign seg_map[ 9] = `SYM7_F;
//assign seg_map[10] = `SYM7_5;
//assign seg_map[11] = `SYM7_6;
//assign seg_map[12] = 8'h7F;

assign addr_o = addr;
//assign data_o = {8'd0, 8'hFF, 3'd0, bit_pos};
//assign data_o = {8'd0, 8'hFF, 3'd0, 13'b0111111111111};
//assign data_o = {8'd0, 8'h00, 3'd0, 13'b1111111111110};
//assign data_o = {8'd0, 8'h00, 3'd0, 13'b1000000000001};
assign data_o = {8'd0, data_i, 3'd0, bit_pos};
//assign data_o = {8'd0, seg_map[addr], 3'd0, bit_pos};
//assign data_o = {8'd0, 8'hFF, 3'd0, 13'b0000000000000}; // all on
//assign data_o = {8'd0, 8'hFF, 3'd0, 13'b1111111111111}; // all off

always@(posedge char_clk or negedge sys_reset_n) begin
	if (~sys_reset_n) begin
		addr_pre <= 0;
	end else if (addr_pre == 4'd12) begin // 13 characters
		addr_pre <= 0;
	end else begin
		addr_pre <= addr_pre + 4'd1;
	end
end

always@(posedge char_clk or negedge sys_reset_n) begin
	if (~sys_reset_n) begin
		addr <= 4'd0;
		bit_pos <= 13'b1111111111110;
	end else if (addr_pre == 4'd0) begin
		addr <= 4'd0;
		bit_pos <= 13'b1111111111110;
	end else begin
		addr <= addr_pre;
		bit_pos <= {bit_pos[11:0], bit_pos[12]};
	end
end

endmodule

//==============================================================================

module ADC2_32CH (
	input         clk,
	input         sys_reset_n,
	output [ 3:0] ch_sel_o,
	output [ 2:0] dac_o,
	input  [ 1:0] sample_i,

	output        write_en,
	output [ 6:0] write_addr,
	output        sample_o,
	output [ 1:0] com_raw_o,
	output [ 2:0] debug_o
);

localparam ST_COM_START0 = 0;
localparam ST_COM_START1 = 1;
localparam ST_SEG_READ   = 2;

wire [4:0] ch_map [3:0];

assign ch_map[0] = 5'd20; // lcd_com_pin28
assign ch_map[1] = 5'd31; // lcd_com_pin1
assign ch_map[2] = 5'd30; // lcd_com_pin2
assign ch_map[3] = 5'd21; // lcd_com_pin27

reg [3:0] state;

// zz1 0.5v
// z1z 1.5v
// 1zz 2.5v
reg [2:0] dac;
reg       group_sel;
reg [3:0] ch_sel;
reg [2:0] ch_step;
reg [1:0] com_sel;
reg [1:0] com_raw;
reg [1:0] com_raw_prev;
reg [1:0] seg_raw;
reg       write_out;

reg [1:0] adc_raw0;
reg [1:0] adc_raw1;
reg [1:0] adc_raw2;
reg [1:0] adc_raw3;

wire       dac_i;
wire [1:0] next_com;

//assign dac_o    = 3'bzz1;
//assign dac_o    = 3'bz1z;
//assign dac_o    = 3'b1zz;
assign dac_o    = dac;

//assign ch_sel_o = 4'b1111;
assign ch_sel_o = ch_sel;
//assign ch_sel_o = 4'b0101;
//assign ch_sel_o = 4'b1010;

assign adc_i = group_sel ? sample_i[1] : sample_i[0];

assign next_com = com_sel + 2'd1;

assign write_en   = write_out;
assign write_addr = {com_sel, group_sel, ch_sel};
//assign write_addr = {group_sel, com_sel}; // debug

assign com_raw_o    = com_raw;
assign debug_o[1:0] = com_raw;
assign debug_o[2]   = com_sel[0];
//assign debug_o[2] = sample_o;

// dif = seg[1:0] - com[1:0]
// com1 com0 seg1 seg0 abs(dif) Q
//  0     0    0    0     00    0
//  0     0    0    1     01    0
//  0     0    1    0     10    1
//  0     0    1    1     11    1
//  1     1    0    0     11    1
//  1     1    0    1     10    1
//  1     1    1    0     01    0
//  1     1    1    1     00    0
LUT3 u_seg_com_dif (
	.I0(seg_raw[0]),
	.I1(seg_raw[1]),
	.I2(com_raw[0]),
	.F(sample_o)
);
defparam u_seg_com_dif.INIT=8'b00111100;

always@(posedge clk or negedge sys_reset_n) begin
	if (~sys_reset_n) begin
		state        <= ST_COM_START0;
		group_sel    <= ch_map[0][4];
		ch_sel       <= ch_map[0][3:0];
		ch_step      <= 0;
		dac          <= 3'bz1z; // 1.5V
		write_out    <= 0;

		adc_raw0     <= 0;
		adc_raw1     <= 0;
		adc_raw2     <= 0;
		adc_raw3     <= 0;

		com_sel      <= 0;
		com_raw      <= 2'b00;
		com_raw_prev <= 2'b00;
		seg_raw      <= 2'b00;
	end else begin
		case (state)
			ST_COM_START0: begin
				adc_raw0 <= adc_raw1;
				adc_raw1 <= adc_raw2;
				adc_raw2 <= adc_raw3;

				adc_raw3[1] <= adc_i;

				// 1: next 1zz 2.5V
				// 0: next zz1 0.5V
				dac <= {adc_i ? 1'b1 : 1'bz, 1'bz, adc_i ? 1'bz : 1'b1};
				state <= ST_COM_START1;
			end

			ST_COM_START1: begin
				dac <= 3'bz1z;
				adc_raw3[0] <= adc_i;

				if (adc_raw2 == {adc_raw3[1], adc_i} &&
					adc_raw1 == adc_raw2 &&
					adc_raw0 == adc_raw1
				) begin
					// stable signal
					com_raw <= adc_raw0;

//					if (com_raw[0] != com_raw[1] && adc_raw0[0] == adc_raw0[1]) begin // 10 -> 11 OR 01 -> 00
					if (com_raw != 2'b11 && adc_raw0 == 2'b11) begin // xx -> 11 only
						ch_sel  <= 0;
//						ch_sel  <= 6;
						ch_step <= 0;
						state   <= ST_SEG_READ;

						adc_raw0 <= 0;
						adc_raw1 <= 0;
						adc_raw2 <= 0;
						adc_raw3 <= 0;

//						state   <= ST_COM_START0;
					end else begin
						state   <= ST_COM_START0;
					end
				end else begin
					state <= ST_COM_START0;
				end
			end

			ST_SEG_READ: begin
				case (ch_step)
					// group 0: ch0-ch15
					3'd0: begin
						group_sel <= 1'b0; // for building write out only
//						group_sel <= 1'b1; // for building write out only
						// 1: next 1zz 2.5V
						// 0: next zz1 0.5V
						dac <= {sample_i[0] ? 1'b1 : 1'bz, 1'bz, sample_i[0] ? 1'bz : 1'b1};
//						dac <= {sample_i[1] ? 1'b1 : 1'bz, 1'bz, sample_i[1] ? 1'bz : 1'b1};
						seg_raw[1] <= sample_i[0];
//						seg_raw[1] <= sample_i[1];

						ch_step <= ch_step + 3'd1;
					end
					3'd1: begin
						dac <= 3'bz1z;
						seg_raw[0] <= sample_i[0];
//						seg_raw[0] <= sample_i[1];

						ch_step <= ch_step + 3'd1;
					end

					// write 1bit sample to ram
					3'd2: begin
						write_out <= 1'b1;

						ch_step <= ch_step + 3'd1;
					end

					// group 1: ch16-ch31
					3'd3: begin
						group_sel <= 1'b1; // for building write address only
						write_out <= 1'b0;

						// 1: next 1zz 2.5V
						// 0: next zz1 0.5V
						dac <= {sample_i[1] ? 1'b1 : 1'bz, 1'bz, sample_i[1] ? 1'bz : 1'b1};
						seg_raw[1] <= sample_i[1];

						ch_step <= ch_step + 3'd1;
					end

					3'd4: begin
						dac <= 3'bz1z;
						seg_raw[0] <= sample_i[1];

						ch_step <= ch_step + 3'd1;
					end

					3'd5: begin
						// write 1bit sample to ram
						write_out <= 1'b1;

						ch_step <= ch_step + 3'd1;
					end

					3'd6: begin
						write_out <= 1'b0;

						// next ch(segments pair)
						if (ch_sel == 4'd15) begin
							// last one
							com_sel   <= next_com;
							group_sel <= ch_map[next_com][4];
							ch_sel    <= ch_map[next_com][3:0];
//							group_sel <= ch_map[0][4];
//							ch_sel    <= ch_map[0][3:0];
							state     <= ST_COM_START0;
						end else begin
							ch_sel    <= ch_sel + 4'd1;
						end

						ch_step <= 0;
					end
				endcase
			end
		endcase
	end
end

endmodule

//==============================================================================

module OFF_DETECTOR (
	input         clk,
	input         sys_reset_n,

	input  [ 1:0] sample_i,

	output        power_off
);

reg        is_off = 1'b1;
reg [11:0] count;

assign power_off = is_off;

always@(posedge clk or negedge sys_reset_n) begin
	if (~sys_reset_n) begin
		count <= 0;
		is_off <= 1;
	end else if (sample_i == 2'b11) begin
		if (count == 12'd390) begin// 10ms
			count <= 0;
			is_off <= 1;
		end else begin
			count <= count + 12'd1;
		end
	end else if (is_off) begin
		// delayed trun on
		if (count == 12'd3900) begin// 100ms
			count <= 0;
			is_off <= 0;
		end else begin
			count <= count + 12'd1;
		end
	end else begin
		count <= 0;
		is_off <= 0;
	end
end

endmodule

//==============================================================================

// 100Hz square wave detector
//             __    __    __    __    __
// sample0: __|  |__|  |__|  |__|  |__|
//          __    __    __    __    __
// sample1:   |__|  |__|  |__|  |__|  |__

module BUSY_DETECTOR (
	input         clk,
	input         sys_reset_n,

	input  [ 1:0] sample_i,

	output        busy
);

reg [ 4:0] times;
reg [11:0] count_l;
reg [11:0] count_h;

reg       is_busy;
reg       prev_sample;

wire [1:0] sample_edge = {prev_sample, sample_i[1]};

assign busy = is_busy;

always@(posedge clk or negedge sys_reset_n) begin
	if (~sys_reset_n) begin
		prev_sample <= 0;
	end else begin
		prev_sample <= sample_i[1];
	end
end

always@(posedge clk or negedge sys_reset_n) begin
	if (~sys_reset_n) begin
		count_l <= 0;
		count_h <= 0;
		times <= 0;
		is_busy <= 0;
	end else if (sample_edge == 2'b01) begin // rising
		if (count_l < 120 || count_l > 240) begin
			times <= 0;
			is_busy <= 0;
		end else if (times >= 20) begin // 100ms
			times <= 0;
			is_busy <= 1;
		end else begin
			times <= times + 5'd1;
		end

		count_h <= 0;
	end else if (sample_edge == 2'b10) begin // falling
		if (count_h < 120 || count_h > 240) begin
			times <= 0;
			is_busy <= 0;
		end else if (times >= 20) begin // 100ms
			times <= 0;
			is_busy <= 1;
		end else begin
			times <= times + 5'd1;
		end

		count_l <= 0;
	end else if (sample_i[1]) begin
		if (count_h != 12'hFFF)
			count_h <= count_h + 12'd1;
	end else begin
		if (count_l != 12'hFFF)
			count_l <= count_l + 12'd1;
	end
end

endmodule

//==============================================================================
