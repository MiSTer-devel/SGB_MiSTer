module savestates
(
	input reset_n,
	input clk,

	input             save,
	input             save_sd,
	input             load,
	input       [1:0] slot,

	input       [3:0] ram_size,
	input       [7:0] rom_type,

	input             sysclkf_ce,
	input             sysclkr_ce,

	input             romsel_n,

	input      [15:0] rom_q,

	input      [23:0] ca,
	input             cpurd_n,
	input             cpuwr_n,

	input       [7:0] pa,
	input             pard_n,
	input             pawr_n,

	input       [7:0] di,
	output reg  [7:0] ss_do,

	output     [19:0] ext_addr,

	input       [7:0] spc_di,

	input      [63:0] ddr_di,
	output reg [63:0] ddr_do,
	input             ddr_ack,
	output     [21:3] ddr_addr,
	output reg        ddr_we,
	output reg  [7:0] ddr_be,
	output reg        ddr_req,

	output            aram_sel,
	output            dsp_regs_sel,
	output            smp_regs_sel,

	input       [7:0] ppu_di,

	output            bsram_sel,
	input       [7:0] bsram_di,

	output            ss_do_ovr,
	output reg        ss_busy,

	input       [7:0] gb_cart_ram_size,

	output     [63:0] gb_state_dout,
	output      [9:0] gb_state_adr,
	output            gb_state_wren,
	output            gb_state_load,
	input      [63:0] gb_state_din,

	output     [19:0] gb_ram_addr,
	output      [7:0] gb_ram_data,
	output      [4:0] gb_ram_wren,
	input       [7:0] gb_ram_din_wram,
	input       [7:0] gb_ram_din_vram,
	input       [7:0] gb_ram_din_oram,
	input       [7:0] gb_ram_din_zram,
	input       [7:0] gb_ram_din_cram
);

reg cpurd_n_old, cpuwr_n_old;
reg pawr_n_old, pard_n_old;
reg save_old, load_old;

always @(posedge clk or negedge reset_n) begin
	if (~reset_n) begin
		cpurd_n_old <= 1'b1;
		cpuwr_n_old <= 1'b1;
		pard_n_old <= 1'b1;
		pawr_n_old <= 1'b1;
		save_old <= 0;
		load_old <= 0;
	end else begin
		cpurd_n_old <= cpurd_n;
		cpuwr_n_old <= cpuwr_n;

		pawr_n_old <= pawr_n;
		pard_n_old <= pard_n;

		save_old <= save;
		load_old <= load;
	end
end

wire cpurd_ce   =  cpurd_n_old & ~cpurd_n;
wire cpurd_ce_n = ~cpurd_n_old &  cpurd_n;
wire cpuwr_ce   =  cpuwr_n_old & ~cpuwr_n;
wire cpuwr_ce_n = ~cpuwr_n_old &  cpuwr_n;

wire pard_ce   =  pard_n_old & ~pard_n;
wire pard_ce_n = ~pard_n_old &  pard_n;
wire pawr_ce   =  pawr_n_old & ~pawr_n;
wire pawr_ce_n = ~pawr_n_old &  pawr_n;

reg save_en;
reg load_en;
reg rd_rti;
reg snes_state_end;

wire nmi_vect = ({ca[23:1],1'b0} == 24'h00FFEA) || ({ca[23:1],1'b0} == 24'h00FFFA);
wire nmi_vect_l = nmi_vect & ~ca[0];
wire nmi_vect_h = nmi_vect &  ca[0];

wire irq_vect = ({ca[23:1],1'b0} == 24'h00FFEE) || ({ca[23:1],1'b0} == 24'h00FFFE);
wire irq_vect_l = irq_vect & ~ca[0];
wire irq_vect_h = irq_vect &  ca[0];

wire ss_reg_sel = (ca[23:16] == 8'hC0);

reg [19:0] ss_data_addr;
reg [19:0] ss_data_size;
reg [19:0] ss_ddr_addr;
reg [1:0] ss_slot;
reg ss_data_addr_inc;
wire ss_data_sel = ss_reg_sel & (ca[15:0] == 16'h6000);
wire ss_addr_sel = ss_reg_sel & (ca[15:0] == 16'h6001);
wire ss_ext_addr_sel = ss_reg_sel & (ca[15:0] == 16'h6002);
wire ss_ramsize_sel = ss_reg_sel & (ca[15:0] == 16'h6003);
wire ss_romtype_sel = ss_reg_sel & (ca[15:0] == 16'h6004);
wire ss_end_sel = ss_reg_sel & (ca[15:0] == 16'h600E);
wire ss_status_sel = ss_reg_sel & (ca[15:0] == 16'h600F);

wire ppu_sel = (ca[23:16] == 8'hC1) & (ca[15:8] == 8'h21);

wire rti_sel = (ca[23:0] == 24'h008008);

reg [19:0] ss_ext_addr;
reg ss_ext_addr_inc;

wire spc_sel = (aram_sel | dsp_regs_sel | smp_regs_sel);
wire spc_read = spc_sel & ~pard_n;

wire bsram_read = bsram_sel & ~pard_n;

reg [3:0] ddr_state;
reg [7:0] ddr_data;
reg load_ready;

wire ddr_busy = (ddr_state != DDR_IDLE);

localparam DDR_IDLE = 4'd0, LOAD_DATA = 4'd1, WRITE_DATA = 4'd2,
			WRITE_CNTSIZE = 4'd3, READ_HEAD = 4'd4,	READ_HEAD_END = 4'd5,
			DDR_END = 4'd6;

reg [31:0] ss_count = 0;

wire gb_ddr_req, gb_ddr_wren;
wire gb_ss_busy, gb_ss_done;
wire [63:0] gb_ddr_do;
reg gb_ss_start, gb_ddr_busy, gb_ddr_ack;

// Detect if NMI is being used. Some games do not use NMI during game play.
reg [15:0] nmi_cycle_cnt, nmi_read_sr;
wire ss_use_nmi = |nmi_read_sr;
always @(posedge clk) begin
	if (~reset_n) begin
		nmi_cycle_cnt <= 0;
		nmi_read_sr   <= 0;
	end else if (sysclkf_ce) begin
		nmi_cycle_cnt <= nmi_cycle_cnt + 1'b1;
		if (&nmi_cycle_cnt | (~cpurd_n & nmi_vect_l)) begin
			nmi_read_sr <= { nmi_read_sr[14:0], nmi_vect_l };
			nmi_cycle_cnt <= 0;
		end
	end
end


always @(posedge clk) begin
	if (~reset_n) begin
		ss_busy <= 0;
		save_en <= 0;
		load_en <= 0;
		snes_state_end <= 0;
		load_ready <= 0;
		rd_rti <= 0;
		ss_data_addr <= 0;
		ss_data_addr_inc <= 0;
		ss_ext_addr <= 0;
		ss_ext_addr_inc <= 0;
		ddr_state <= DDR_IDLE;
		gb_ddr_busy <= 0;
		gb_ddr_ack <= 0;
		gb_ss_start <= 0;
	end else begin
		if (~(load_en | save_en)) begin
			if (~save_old & save) begin
				save_en <= 1;
				ss_slot <= slot;
			end else if (~load_old & load) begin
				load_en <= 1;
				ss_slot <= slot;
				ddr_state <= READ_HEAD; // Check header in RAM
				load_ready <= 0;
			end
		end

		if (cpurd_ce) begin
			if (nmi_vect_l | (~ss_use_nmi & irq_vect_l)) begin // Prefer to use NMI
				if (~ss_busy & (save_en | (load_en & load_ready))) begin
					ss_busy <= 1; // Override NMI/IRQ vector
					if (save_en) begin
						ss_count <= ss_count + 1'b1;
					end
				end
			end

			if (ss_busy & rti_sel) begin
				rd_rti <= 1;
			end
		end

		if (cpurd_ce_n) begin
			if (rd_rti) begin
				ss_busy <= 0;
				rd_rti <= 0;
				load_en <= 0;
				save_en <= 0;
				snes_state_end <= 0;
			end
		end

		if (cpuwr_ce & ss_busy) begin
			if (ss_addr_sel) begin // Reset save state address
				ss_data_addr <= 20'd8;
				if (load_en) begin
					// Request new data when address is reset
					ddr_state <= LOAD_DATA;
				end
			end

			if (ss_ext_addr_sel) begin
				ss_ext_addr <= 0;
			end

			if (ss_end_sel) begin // SNES state finished
				snes_state_end <= 1;
				if (save_en & (ss_data_addr[2:0] != 3'd0)) begin
					// Write remaining data first
					ddr_state <= WRITE_DATA;
				end
			end
		end



		if (cpuwr_ce | cpurd_ce) begin
			if (ss_data_sel & ss_busy) begin
				ss_data_addr_inc <= 1;
			end
		end

		if (cpuwr_ce_n | cpurd_ce_n) begin
			if (ss_data_addr_inc) begin
				ss_data_addr <= ss_data_addr + 1'b1;
				ss_data_addr_inc <= 0;
				if (cpurd_ce_n & (ss_data_addr[2:0] == 3'd7)) begin
					// Request next 8 bytes
					ddr_state <= LOAD_DATA;
				end
			end
		end

		if (pawr_ce | pard_ce) begin
			if (spc_sel | bsram_sel) begin
				ss_ext_addr_inc <= 1;
			end
		end

		if (pawr_ce_n | pard_ce_n) begin
			if (ss_ext_addr_inc) begin
				ss_ext_addr <= ss_ext_addr + 1'b1;
				ss_ext_addr_inc <= 0;
			end
		end

		if (~cpuwr_n & sysclkf_ce & ss_busy & ss_data_sel) begin // Data write
			if (ss_data_addr[2:0] == 3'd0) begin
				ddr_do[63:8] <= 0; // Clear for possible partial last write
			end

			ddr_do[ss_data_addr[2:0]*8 +:8] <= ddr_data;

			if (ss_data_addr[2:0] == 3'd7) begin // 8 bytes written
				ddr_state <= WRITE_DATA;
			end
		end

		gb_ss_start <= 0;
		if (snes_state_end) begin
			if (gb_ss_done) begin
				snes_state_end <= 0;
				if (save_en) begin
					ss_data_size <= ss_data_addr;
					ddr_state <= WRITE_CNTSIZE;
				end
			end else if (~gb_ss_busy & ~ddr_busy) begin
				gb_ss_start <= 1;
				if (ss_data_addr[2:0] != 3'd0) begin // Align to next 8 bytes
					ss_data_addr <= { ss_data_addr[19:3]+1'b1, 3'd0 };
				end
			end
		end

		if ((gb_ddr_req != gb_ddr_ack) & ~gb_ddr_busy) begin
			gb_ddr_busy <= 1;
			ddr_state <= gb_ddr_wren ? WRITE_DATA : LOAD_DATA;
			ddr_do <= gb_ddr_do;
		end
		
		if (gb_ddr_busy & ~ddr_busy) begin
			gb_ddr_busy <= 0;
			gb_ddr_ack <= gb_ddr_req;
			ss_data_addr <= ss_data_addr + 20'd8;
		end

		ddr_we <= 0;
		ddr_be <= 8'hFF;

		if (ddr_req == ddr_ack) begin
			case(ddr_state)
				LOAD_DATA: begin
					ss_ddr_addr <= ss_data_addr;
					ddr_req <= ~ddr_req;
					ddr_state <= DDR_END;
				end
				WRITE_DATA: begin
					ss_ddr_addr <= ss_data_addr;
					ddr_req <= ~ddr_req;
					ddr_we <= 1;
					ddr_state <= DDR_END;
				end
				WRITE_CNTSIZE: begin
					ddr_do <= {14'd0, ss_data_size[19:2], ss_count[31:0]};
					ss_ddr_addr <= 20'd0;
					ddr_we <= 1;
					ddr_req <= ~ddr_req;
					if (~save_sd) begin
						ddr_be <= 8'hF0; // Skip count write
					end
					ddr_state <= DDR_END;
				end
				READ_HEAD: begin
					ss_ddr_addr <= 20'd8;
					ddr_req <= ~ddr_req;
					ddr_state <= READ_HEAD_END;
				end
				READ_HEAD_END: begin
					ddr_state <= DDR_END;
					if (ddr_di[31:0] == 32'h4247_4E53) begin // "SNGB"
						load_ready <= 1; // State found
					end else begin
						load_en <= 0;
					end
				end

				DDR_END: begin
					ddr_state <= DDR_IDLE;
				end
			endcase

		end
	end
end

savestates_gb ss_gb
(
	.reset_n         (reset_n),
	.clk             (clk),

	.ss_start        (gb_ss_start),
	.ss_busy         (gb_ss_busy),
	.ss_done         (gb_ss_done),
	

	.save_en         (save_en),

	.ddr_di          (ddr_di),
	.ddr_do          (gb_ddr_do),
	.ddr_wren        (gb_ddr_wren),
	.ddr_req         (gb_ddr_req),
	.ddr_ack         (gb_ddr_ack),

	.cart_ram_size   (gb_cart_ram_size),

	.gb_state_dout   (gb_state_dout),
	.gb_state_adr    (gb_state_adr),
	.gb_state_wren   (gb_state_wren),
	.gb_state_load   (gb_state_load),
	.gb_state_din    (gb_state_din),

	.gb_ram_addr     (gb_ram_addr),
	.gb_ram_data     (gb_ram_data),
	.gb_ram_wren     (gb_ram_wren),
	.gb_ram_din_wram (gb_ram_din_wram),
	.gb_ram_din_vram (gb_ram_din_vram),
	.gb_ram_din_oram (gb_ram_din_oram),
	.gb_ram_din_zram (gb_ram_din_zram),
	.gb_ram_din_cram (gb_ram_din_cram)
);

wire [15:0] nmi_vect_addr = save_en ? 16'h8000 : 16'h8004;

wire [7:0] ssr_do;
wire ssr_oe;
savestates_regs ss_regs
(
	.reset_n(reset_n),
	.clk(clk),

	.ss_busy(ss_busy),
	.save_en(save_en),

	.ss_reg_sel(ss_reg_sel),

	.sysclkf_ce(sysclkf_ce),
	.sysclkr_ce(sysclkr_ce),

	.romsel_n(romsel_n),

	.ca(ca),
	.cpurd_ce(cpurd_ce),
	.cpurd_ce_n(cpurd_ce_n),
	.cpuwr_ce(cpuwr_ce),

	.pa(pa),

	.pard_ce(pard_ce),
	.pawr_ce(pawr_ce),

	.di(di),
	.ssr_do(ssr_do),
	.ssr_oe(ssr_oe)
);

wire [7:0] ssrom_q;
spram #(12,8, "src/savestates.mif") ssrom (
	.clock   (clk  ),
	.address (ca[11:0]),
	.wren    (0),
	.data    (  ),
	.q       (ssrom_q)
);

always @(posedge clk) begin
	ss_do <= ssrom_q;
	if (ss_data_sel) ss_do <= ddr_di[ss_data_addr[2:0]*8 +:8];
	if (ss_status_sel) ss_do <= { 5'd0, snes_state_end, ddr_busy, save_en };
	if (nmi_vect_l | irq_vect_l) ss_do <= nmi_vect_addr[7:0];
	if (nmi_vect_h | irq_vect_h) ss_do <= nmi_vect_addr[15:8];
	if (ss_ramsize_sel) ss_do <= { 4'd0, ram_size };
	if (ss_romtype_sel) ss_do <= rom_type;
	if (ssr_oe) ss_do <= ssr_do;
	if (ppu_sel) ss_do <= ppu_di;
end

// Data to DDRAM
always @(*) begin
	ddr_data = di;
	if (spc_read) ddr_data = spc_di;
	if (bsram_read) ddr_data = bsram_di;
end

assign ss_do_ovr = ss_busy & ~romsel_n;

assign aram_sel = ss_busy & (pa == 8'h84);
assign dsp_regs_sel = ss_busy & (pa == 8'h85);
assign smp_regs_sel = ss_busy & (pa == 8'h86);
assign bsram_sel = 0;
assign ext_addr = ss_ext_addr;

assign ddr_addr = { ss_slot[1:0], ss_ddr_addr[19:3] };

endmodule