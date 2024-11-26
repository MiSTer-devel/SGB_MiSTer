module savestates_gb
(
	input             reset_n,
	input             clk,

	input             ss_start,
	output reg        ss_done,
	output            ss_busy,
	
	input             save_en,

	input       [7:0] cart_ram_size,
	
	input      [63:0] ddr_di,
	output reg [63:0] ddr_do,
	output reg        ddr_req,
	output reg        ddr_wren,
	input             ddr_ack,

	output reg [63:0] gb_state_dout,
	output reg  [9:0] gb_state_adr,
	output reg        gb_state_wren,
	output            gb_state_load,
	input      [63:0] gb_state_din,

	output reg [19:0] gb_ram_addr,
	output reg  [7:0] gb_ram_data,
	output reg  [4:0] gb_ram_wren,
	input       [7:0] gb_ram_din_wram,
	input       [7:0] gb_ram_din_vram,
	input       [7:0] gb_ram_din_oram,
	input       [7:0] gb_ram_din_zram,
	input       [7:0] gb_ram_din_cram
);


reg [3:0] state;
reg [2:0] byte_count;
localparam STATE_COUNT = 64;

reg [2:0] ram_index;
reg [19:0] ram_size;
reg [7:0] gb_ram_din;
always @(*) begin
	case (ram_index)
		0,1: ram_size = 'd8192; // WRAM/VRAM
		2: ram_size = 'd160; // OAM
		3: ram_size = 'd128; // ZeroPage
		4: case (cart_ram_size)
				0: ram_size = 'd512; // for MBC2
				1: ram_size = 'd2048; // 2 KByte
				2: ram_size = 'd8192; // 8 KByte
				3: ram_size = 'd32768; // 32 KByte
				default: ram_size = 'd131072; // 128 KByte
			endcase
		default: ram_size = 'd128;
	endcase

	case (ram_index)
		0: gb_ram_din = gb_ram_din_wram;
		1: gb_ram_din = gb_ram_din_vram;
		2: gb_ram_din = gb_ram_din_oram;
		3: gb_ram_din = gb_ram_din_zram;
		default: gb_ram_din = gb_ram_din_cram;
	endcase
end

localparam STATE_IDLE = 4'd0, STATE_INIT = 4'd1, SAVE_STATE = 4'd2,
			SAVE_RAM = 4'd3, READ_STATE = 4'd4,	READ_RAM = 4'd5,
			STATE_END = 4'd6;

assign ss_busy = (state != STATE_IDLE);

wire ddr_busy = (ddr_req != ddr_ack);
always @(posedge clk) begin
	if (~reset_n) begin
		state <= STATE_IDLE;
		ddr_req <= 0;
		ddr_wren <= 0;
		ss_done <= 0;
		gb_state_wren <= 0;
		gb_ram_wren <= 5'd0;
		gb_state_load <= 0;
	end else begin

		ss_done <= 0;
		gb_state_load <= 0;
		
		if (ss_start & ~ss_busy) begin
			state <= STATE_INIT;
		end

		case(state)
			STATE_INIT: begin
				gb_state_adr <= 10'd0;
				state <= save_en ? SAVE_STATE : READ_STATE;
				ddr_wren <= save_en;
				gb_ram_addr <= 20'd0;
				ram_index <= 3'd0;
				byte_count <= 3'd0;
				if (~save_en) begin
					// Load first data
					ddr_req <= ~ddr_req;
				end
			end
			SAVE_STATE: begin
				if (~ddr_busy) begin
					ddr_do <= gb_state_din;
					ddr_req <= ~ddr_req;
					gb_state_adr <= gb_state_adr + 1'b1;
					if (gb_state_adr == STATE_COUNT-1) begin
						state <= SAVE_RAM;
						
					end
				end
			end
			SAVE_RAM: begin
				if (~ddr_busy) begin
					ddr_do[byte_count*8 +:8] <= gb_ram_din;
					byte_count <= gb_ram_addr[2:0];
					
					if (byte_count == 3'd7) begin
						ddr_req <= ~ddr_req;
					end else begin
						gb_ram_addr <= gb_ram_addr + 1'b1;
					end

					if (gb_ram_addr == ram_size) begin
						gb_ram_addr <= 20'd0;
						byte_count <= 3'd0;
						ram_index <= ram_index + 1'b1;
						if (ram_index == 3'd4) begin
							state <= STATE_END;
						end
					end

				end
			end
			READ_STATE: begin
				if (~ddr_busy) begin
					gb_state_wren <= ~gb_state_wren;
					if (~gb_state_wren) begin
						gb_state_dout <= ddr_di;
					end else begin
						ddr_req <= ~ddr_req;
						gb_state_adr <= gb_state_adr + 1'b1;
						if (gb_state_adr == STATE_COUNT-1) begin
							state <= READ_RAM;
						end
					end
				end
			end
			READ_RAM: begin
				if (~ddr_busy) begin
					gb_ram_wren[ram_index] <= ~gb_ram_wren[ram_index];
					if (~gb_ram_wren[ram_index]) begin
						gb_ram_data <= ddr_di[gb_ram_addr[2:0]*8 +:8];
					end else begin
						if (gb_ram_addr == ram_size-1'b1) begin
							gb_ram_addr <= 20'd0;
							ram_index <= ram_index + 1'b1;
							if (ram_index == 3'd4) begin
								state <= STATE_END;
							end else begin
								ddr_req <= ~ddr_req;
							end
						end else begin
							gb_ram_addr <= gb_ram_addr + 1'b1;
							if (gb_ram_addr[2:0] == 3'd7) begin
								ddr_req <= ~ddr_req;
							end
						end
					end


					

				end
			end
			STATE_END: begin
				if (~ddr_busy) begin
					state <= STATE_IDLE;
					ss_done <= 1;
					if (~save_en) gb_state_load <= 1;
				end
			end
		endcase
		
	end
end


endmodule