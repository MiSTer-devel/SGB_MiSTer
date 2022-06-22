module ICD2(
	input             clk,
	input             rst_n,

	input      [23:0] ca,
	input       [7:0] di,
	output reg  [7:0] icd_do,
	input             cpurd_n,
	input             cpuwr_n,

	output            icd2_oe,

	input       [1:0] joy_p54,
	output      [3:0] joy_do,

	input             lcd_ce,
	input       [1:0] lcd_data,
	input             lcd_vs,

	input             pal,
	input       [1:0] sgb_speed,
	output reg        gb_rst_n,
	output            gb_clk_en
);

reg  [7:0] packet_data[0:15];
reg  [7:0] data;
reg  [3:0] byte_cnt;
reg  [2:0] cnt;
reg        old_p15, old_p14;
reg        new_packet, byte_done, packet_end;

reg  [1:0] num_controllers;
reg  [1:0] gb_cpu_speed;
reg  [7:0] buttons1, buttons2, buttons3, buttons4;
reg  [1:0] joypad_id;

reg  [3:0] gb_clk_cnt;

reg  [7:0] pix_x, pix_y;
reg  [7:0] trn_temp_h, trn_temp_l, trn_data_q;
reg  [8:0] trn_read_index;
reg  [7:0] trn_write_index;
reg  [1:0] trn_read_buffer, trn_write_buffer, trn_write_buf_l;
reg        trn_write;
reg        old_lcd_vs;

reg        cpurd_n_old, cpuwr_n_old;

reg [31:0] gb_out_clk;
reg        gb1_ce, gb2_ce;

// The ICD chip only has A22,A15-A11 and A3-A0 connected
wire icd2_sel = ~ca[22] & (ca[15:13] == 3'b011); // 00-3F,80-BF:6xxN/7xxN

wire r600x = icd2_sel & (ca[12:11] == 2'b00);
wire r6000 = r600x    & (ca[ 3: 0] == 4'h0);
wire r6002 = r600x    & (ca[ 3: 0] == 4'h2);
wire r600F = r600x    & (ca[ 3: 0] == 4'hF);
wire r700x = icd2_sel & (ca[12:11] == 2'b10);
wire r7000 = r700x    & (ca[ 3: 0] == 4'h0);
wire r780x = icd2_sel & (ca[12:11] == 2'b11);

wire p14 = joy_p54[0];
wire p15 = joy_p54[1];

always @(*) begin
	icd_do = 8'h00;
	if (r6000) icd_do = { pix_y[7:3], 1'b0, trn_write_buffer };      // $6000 LCD Row, Write buffer
	if (r6002) icd_do = { 7'd0, new_packet };                        // $6002 Packet available
	if (r600F) icd_do = 8'h21;                                       // $600F Chip version
	if (r700x) icd_do = packet_data[ ca[3:0] ];                      // $7000-7000F 16-Byte packet
	if (r780x) icd_do = (trn_read_index < 320) ? trn_data_q : 8'hFF; // $7800 Tile data Mirror: $7801-780F
end

assign icd2_oe = r6000 | r6002 | r600F | r700x | r780x;


always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		cpurd_n_old <= 1'b1;
		cpuwr_n_old <= 1'b1;
	end else begin
		cpurd_n_old <= cpurd_n;
		cpuwr_n_old <= cpuwr_n;
	end
end


// Simple clock divider for SGB1 speed.
wire [3:0] gb_clk_div =
		(gb_cpu_speed == 2'd0) ? 4'd3 :
		(gb_cpu_speed == 2'd1) ? 4'd4 :
		(gb_cpu_speed == 2'd2) ? 4'd6 :
		                         4'd8;

always @(posedge clk) begin
	if (~rst_n) begin
		gb1_ce  <= 0;
		gb_clk_cnt <= 0;
	end else begin
		gb_clk_cnt <= gb_clk_cnt + 1'b1;

		gb1_ce <= 0;
		if (gb_clk_cnt == gb_clk_div) begin
			gb_clk_cnt <= 0;
			gb1_ce  <= 1'b1;
		end
	end
end

localparam MCLK_NTSC = 21477270;
localparam MCLK_PAL  = 21281370;
localparam MCLK_SGB2 = 20971520;
localparam MCLK_SNES = 21101890; // Closest to 60.09Hz refresh rate to avoid stutter

// CEGen for async clock dividers (SGB2 & SNES speed)
always @(posedge clk) begin
	case ({ (sgb_speed == 2'd2), gb_cpu_speed })
		{1'b0, 2'd0}: gb_out_clk <= MCLK_SGB2/4;
		{1'b0, 2'd1}: gb_out_clk <= MCLK_SGB2/5;
		{1'b0, 2'd2}: gb_out_clk <= MCLK_SGB2/7;
		{1'b0, 2'd3}: gb_out_clk <= MCLK_SGB2/9;

		{1'b1, 2'd0}: gb_out_clk <= MCLK_SNES/4;
		{1'b1, 2'd1}: gb_out_clk <= MCLK_SNES/5;
		{1'b1, 2'd2}: gb_out_clk <= MCLK_SNES/7;
		{1'b1, 2'd3}: gb_out_clk <= MCLK_SNES/9;
	endcase
end

CEGen gb_ce
(
	.CLK(clk),
	.RST_N(rst_n),
	.IN_CLK(pal ? MCLK_PAL : MCLK_NTSC),
	.OUT_CLK(gb_out_clk),
	.CE(gb2_ce)
);

assign gb_clk_en = (sgb_speed == 2'd0) ? gb1_ce : gb2_ce;

// SGB command packets
always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		cnt <= 0;
		byte_cnt <= 0;
		byte_done <= 0;
		packet_end <= 1'b1;
	end else begin

		if (gb_clk_en) begin
			old_p15 <= p15;
			old_p14 <= p14;

			// Reset pulse
			if (~p15 & ~p14) begin
				{cnt, byte_cnt, packet_end} <= 0;
			end

			if ( old_p15 & old_p14 & (p15 ^ p14) ) begin
				if (~packet_end) begin
					data <= {~p15,data[7:1]};
					cnt <= cnt + 1'b1;
					if (&cnt) byte_done <= 1'b1;
				end
			end

			// Corrupt packet. p15 and p14 should both go high after one is low.
			if ( (old_p15 ^ p15) & (old_p15 ^ old_p14) & (p15 ^ p14) ) begin
				packet_end <= 1'b1;
			end

			if (byte_done) begin
				byte_done <= 0;
				byte_cnt <= byte_cnt + 1'b1;

				packet_data[byte_cnt] <= data;

				// End of packet
				if (&byte_cnt) begin
					packet_end <= 1'b1;
					new_packet <= 1'b1;
				end
			end
		end

		if (~cpurd_n_old & cpurd_n & r7000) begin
			new_packet <= 0;
		end
	end

end

always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		trn_read_buffer <= 0;
		gb_rst_n <= 0;
		num_controllers <= 0;
		gb_cpu_speed <= 2'd1;
	end else begin
		if (cpuwr_n_old & ~cpuwr_n & r600x) begin
			case (ca[3:0])
				4'h1: begin // $6001 Select read buffer
					trn_read_index <= 0;
					trn_read_buffer <= di[1:0];
				end
				4'h3: begin // $6003 Reset/Multiplayer/Speed control
					gb_rst_n <= di[7];
					num_controllers <= di[5:4];
					gb_cpu_speed <= di[1:0];
				end
				4'h4: buttons1 <= di;
				4'h5: buttons2 <= di;
				4'h6: buttons3 <= di;
				4'h7: buttons4 <= di;
				default: ;
			endcase
		end

		if (~cpurd_n_old & cpurd_n & r780x) begin
			trn_read_index <= trn_read_index + 1'b1;
		end
	end
end

/*
  Lower 4 bits of FF00
  0Fh  Joypad 1
  0Eh  Joypad 2
  0Dh  Joypad 3
  0Ch  Joypad 4

  Setting P15 from low to high will decrement the joypad id if multiplayer
  is enabled with MLT_REQ.

  2 player: 0F,0E. 4 player: 0F,0E,0D,0C
  Normal Gameboy or Super Gameboy with multiplayer disabled will always return 0F.
*/
always @(posedge clk or negedge rst_n) begin
	 if (~rst_n) begin
		joypad_id <= 0;
	end else if (gb_clk_en) begin
		if (~old_p15 & p15) begin
			joypad_id <= (joypad_id + 1'b1) & num_controllers;
		end
	end
end

wire [3:0] joy_dir     = { joystick[3], joystick[2], joystick[1], joystick[0] } | {4{p14}};
wire [3:0] joy_buttons = { joystick[7], joystick[6], joystick[5], joystick[4] } | {4{p15}};
wire [3:0] joy_data = joy_dir & joy_buttons;

wire [7:0] joystick =
				(~num_controllers[0]) ? buttons1 :
				(joypad_id == 2'd0) ? buttons1 :
				(joypad_id == 2'd1) ? buttons2 :
				(joypad_id == 2'd2) ? buttons3 :
				                      buttons4;

assign joy_do = (p15 & p14) ? ~{2'b00,joypad_id} : joy_data;

// Convert 2bpp pixel data back to 16 bit tile data
always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		trn_write_index <= 0;
		trn_write_buf_l <= 0;
		trn_write_buffer <= 0;
		trn_write <= 0;
	end else begin
		old_lcd_vs <= lcd_vs;
		if(~old_lcd_vs & lcd_vs) begin
			pix_x <= 0;
			pix_y <= 0;
		end

		trn_write <= 0;
		if(lcd_ce & gb_clk_en) begin
			pix_x <= pix_x + 1'b1;
			if (pix_x == 8'd159) begin
				pix_x <= 0;
				pix_y <= pix_y + 1'b1;
				if(&pix_y[2:0]) begin
					trn_write_buffer <= trn_write_buffer + 1'b1;
				end
			end

			if (&pix_x[2:0]) begin
				trn_write <= 1'b1;
				trn_write_index <= {pix_x[7:3], pix_y[2:0]};
				trn_write_buf_l <= trn_write_buffer;
			end

			// HLHLHLHLHLHLHLHL -> HHHHHHHH LLLLLLLL
			trn_temp_h <= {trn_temp_h[6:0],lcd_data[1]};
			trn_temp_l <= {trn_temp_l[6:0],lcd_data[0]};
		end

	end
end

// 4x 320 byte tile data buffers
dpram_dif #(11,8,10,16) trn_data (
	.clock (clk),

	.address_a ( {trn_read_buffer, trn_read_index[8:0]} ),
	.wren_a (0),
	.data_a ( ),
	.q_a (trn_data_q),

	.address_b ( {trn_write_buf_l, trn_write_index[7:0]} ),
	.wren_b (trn_write),
	.data_b ( {trn_temp_h, trn_temp_l} ),
	.q_b ()
);

endmodule