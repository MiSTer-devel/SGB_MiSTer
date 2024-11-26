module SGBMap(

	input             clk,
	input             rst_n,

	input      [23:0] ca,
	input       [7:0] di,
	output      [7:0] sgb_do,
	input             cpurd_n,
	input             cpuwr_n,

	input             romsel_n,

	input             sysclkf_ce,
	input             sysclkr_ce,

	output     [23:0] rom_addr,
	input      [15:0] rom_q,
	output            rom_ce_n,
	output            rom_oe_n,

	output     [22:0] gb_rom_addr,
	output            gb_rom_rd,
	input       [7:0] gb_rom_di,

	output            gb_cram_wr,

	input             gb_bk_wr,
	input             gb_rtc_wr,
	input      [16:0] gb_bk_addr,
	input      [15:0] gb_bk_data,
	output     [15:0] gb_bk_q,
	input      [63:0] gb_bk_img_size,

	output      [7:0] gb_ram_mask,
	output            gb_has_save,

	input      [32:0] gb_rtc_time_in,
	output     [31:0] gb_rtc_timeout,
	output     [47:0] gb_rtc_savedtime,
	output            gb_rtc_inuse,

	input             gb_audio_no_pops,
	output     [15:0] gb_audio_l,
	output     [15:0] gb_audio_r,

	output            gb_sc_int_clock,
	input             gb_ser_clk_in,
	output            gb_ser_clk_out,
	input             gb_ser_data_in,
	output            gb_ser_data_out,

	input             gg_en,
	input             gg_reset,
	input     [128:0] gg_code,
	output            gg_available,

	input      [24:0] io_addr,
	input      [15:0] io_dat,
	input             io_wr,
	input             io_gb_cart,
	input             io_sgb_boot,

	input             pal,
	input       [1:0] sgb_speed,
	input       [2:0] gb_mapper,

	input             rom_mask,

	input             ss_busy,

	output      [7:0] cart_ram_size,

	input      [63:0] SaveStateBus_Din,
	input       [9:0] SaveStateBus_Adr,
	input             SaveStateBus_wren,
	input             SaveStateBus_load,
	output     [63:0] SaveStateBus_Dout,

	input      [19:0] Savestate_RAMAddr,
	input       [7:0] Savestate_RAMWriteData,
	input       [4:0] Savestate_RAMRWrEn,
	output      [7:0] Savestate_RAMReadData_WRAM,
	output      [7:0] Savestate_RAMReadData_VRAM,
	output      [7:0] Savestate_RAMReadData_ORAM,
	output      [7:0] Savestate_RAMReadData_ZRAM,
	output      [7:0] Savestate_RAMReadData_CRAM
);

reg rom_rd;
always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		rom_rd <= 0;
	end else begin
		rom_rd <= sysclkr_ce | sysclkf_ce;
	end
end


assign rom_addr = { 5'd0, (ca[19] & rom_mask),ca[18:16], ca[14:0] };
assign rom_oe_n = ~rom_rd;
assign rom_ce_n = romsel_n;

reg [7:0] openbus;
always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		openbus <= 8'hFF;
	end else if (sysclkr_ce) begin
		openbus <= di;
	end
end

assign sgb_do = ~romsel_n ? rom_q[7:0] : icd2_oe ? icd_do : openbus;

wire        icd2_oe;

wire        lcd_clkena;
wire  [1:0] lcd_data;
wire        lcd_vsync;

wire  [1:0] joy_p54;
wire  [3:0] joy_do;

wire        gb_rst_n;
wire        gb_clk_en;
wire  [7:0] icd_do;

wire        gb_cpu_act;
wire        ss_gb_paused = ss_busy & ~gb_cpu_act;

ICD2 ICD2
(
	.clk(clk),
	.rst_n(rst_n),

	.ca(ca),
	.di(di),
	.icd_do(icd_do),
	.cpurd_n(cpurd_n),
	.cpuwr_n(cpuwr_n),

	.icd2_oe(icd2_oe),

	.joy_p54(joy_p54),
	.joy_do(joy_do),

	.lcd_ce(lcd_clkena),
	.lcd_data(lcd_data),
	.lcd_vs(lcd_vsync),

	.pal(pal),
	.sgb_speed(sgb_speed),

	.gb_rst_n(gb_rst_n),
	.gb_clk_en(gb_clk_en),

	.ss_gb_paused(ss_gb_paused)
);

localparam MCLK_NTSC = 21477270;
localparam MCLK_PAL  = 21281370;

wire ce_32k;
CEGen rtc_ce
(
	.CLK(clk),
	.RST_N(rst_n),
	.IN_CLK(pal ? MCLK_PAL : MCLK_NTSC),
	.OUT_CLK(32768),
	.CE(ce_32k)
);



GBTop GBTop
(
	.clk            (clk),
	.reset          ( ~(rst_n & gb_rst_n) ),

	.clk_en         (gb_clk_en),

	.cart_download  (io_gb_cart),
	.boot_download  (io_sgb_boot),
	.ioctl_wr       (io_wr),
	.ioctl_addr     (io_addr),
	.ioctl_dout     (io_dat),

	.rom_addr       (gb_rom_addr),
	.rom_rd         (gb_rom_rd),
	.rom_di         (gb_rom_di),

	.cram_wr        (gb_cram_wr),

	.cpu_act        (gb_cpu_act),

	.bk_wr          (gb_bk_wr),
	.bk_rtc_wr      (gb_rtc_wr),
	.bk_addr        (gb_bk_addr),
	.bk_data        (gb_bk_data),
	.bk_q           (gb_bk_q),
	.img_size       (gb_bk_img_size),

	.ram_mask_file  (gb_ram_mask),
	.cart_has_save  (gb_has_save),

	.mapper_sel     (gb_mapper),

	.lcd_clkena     (lcd_clkena),
	.lcd_data       (lcd_data),
	.lcd_vsync      (lcd_vsync),

	.joy_p54        (joy_p54),
	.joy_din        (joy_do),

	.audio_no_pops  (gb_audio_no_pops),
	.audio_l        (gb_audio_l),
	.audio_r        (gb_audio_r),

	.sc_int_clock   (gb_sc_int_clock),
	.ser_clk_in     (gb_ser_clk_in),
	.ser_data_in    (gb_ser_data_in),
	.ser_clk_out    (gb_ser_clk_out),
	.ser_data_out   (gb_ser_data_out),

	.gg_en          (gg_en),
	.gg_code        (gg_code),
	.gg_reset       (gg_reset),
	.gg_available   (gg_available),

	.ce_32k           (ce_32k),
	.RTC_time         (gb_rtc_time_in),
	.RTC_timestampOut (gb_rtc_timeout),
	.RTC_savedtimeOut (gb_rtc_savedtime),
	.RTC_inuse        (gb_rtc_inuse),

	// savestates
	.ss_gb_paused    (ss_gb_paused),
	.cart_ram_size   (cart_ram_size),

	.SaveStateBus_Din   (SaveStateBus_Din),
	.SaveStateBus_Adr   (SaveStateBus_Adr),
	.SaveStateBus_wren  (SaveStateBus_wren),
	.SaveStateBus_load  (SaveStateBus_load),
	.SaveStateBus_Dout  (SaveStateBus_Dout),

	.Savestate_RAMAddr          (Savestate_RAMAddr),
	.Savestate_RAMWriteData     (Savestate_RAMWriteData),
	.Savestate_RAMRWrEn         (Savestate_RAMRWrEn),
	.Savestate_RAMReadData_WRAM (Savestate_RAMReadData_WRAM),
	.Savestate_RAMReadData_VRAM (Savestate_RAMReadData_VRAM),
	.Savestate_RAMReadData_ORAM (Savestate_RAMReadData_ORAM),
	.Savestate_RAMReadData_ZRAM (Savestate_RAMReadData_ZRAM),
	.Savestate_RAMReadData_CRAM (Savestate_RAMReadData_CRAM)

);

endmodule