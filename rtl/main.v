module main (
	input             RESET_N,

	input             MCLK,
	input             ACLK,

	input      [23:0] ROM_MASK,

	output reg [23:0] ROM_ADDR,
	output reg [15:0] ROM_D,
	input      [15:0] ROM_Q,
	output reg        ROM_CE_N,
	output reg        ROM_OE_N,
	output reg        ROM_WE_N,
	output reg        ROM_WORD,

	output     [16:0] WRAM_ADDR,
	output      [7:0] WRAM_D,
	input       [7:0] WRAM_Q,
	output            WRAM_CE_N,
	output            WRAM_OE_N,
	output            WRAM_WE_N,

	output     [15:0] VRAM1_ADDR,
	input       [7:0] VRAM1_DI,
	output      [7:0] VRAM1_DO,
	output            VRAM1_WE_N,
	output     [15:0] VRAM2_ADDR,
	input       [7:0] VRAM2_DI,
	output      [7:0] VRAM2_DO,
	output            VRAM2_WE_N,
	output            VRAM_OE_N,

	output reg [15:0] ARAM_ADDR,
	output reg  [7:0] ARAM_D,
	input       [7:0] ARAM_Q,
	output reg        ARAM_CE_N,
	output reg        ARAM_OE_N,
	output reg        ARAM_WE_N,

	input             BLEND,
	input             PAL,
	output            HIGH_RES,
	output            FIELD,
	output            INTERLACE,
	output            DOTCLK,
	output      [7:0] R,
	output      [7:0] G,
	output      [7:0] B,
	output            HBLANKn,
	output            VBLANKn,
	output            HSYNC,
	output            VSYNC,

	input       [1:0] JOY1_DI,
	input       [1:0] JOY2_DI,
	output            JOY_STRB,
	output            JOY1_CLK,
	output            JOY2_CLK,
	output            JOY1_P6,
	output            JOY2_P6,
	input             JOY2_P6_in,

	input             GG_EN,
	input     [128:0] GG_CODE,
	input             GG_RESET,
	output            GG_AVAILABLE,

	input             SPC_MODE,

	input      [24:0] IO_ADDR,
	input      [15:0] IO_DAT,
	input             IO_WR,
	input             IO_GB_CART,
	input             IO_SGB_BOOT,

	input       [4:0] DBG_BG_EN,
	input             DBG_CPU_EN,

	input             TURBO,

	output     [22:0] GB_ROM_ADDR,
	output            GB_ROM_RD,
	input       [7:0] GB_ROM_DI,

	output            GB_CRAM_WR,

	input             GB_BK_WR,
	input             GB_RTC_WR,
	input      [16:0] GB_BK_ADDR,
	input      [15:0] GB_BK_DATA,
	output     [15:0] GB_BK_Q,
	input      [63:0] GB_BK_IMG_SIZE,

	output      [7:0] GB_RAM_MASK,
	output            GB_HAS_SAVE,

	input  [32:0]     GB_RTC_TIME_IN,
	output [31:0]     GB_RTC_TIMEOUT,
	output [47:0]     GB_RTC_SAVEDTIME,
	output            GB_RTC_INUSE,

	input       [2:0] GB_MAPPER,
	input       [1:0] SGB_SPEED,

	input             GB_AUDIO_NO_POPS,
	output     [15:0] GB_AUDIO_L,
	output     [15:0] GB_AUDIO_R,

	output            GB_SC_INT_CLOCK,
	input             GB_SER_CLK_IN,
	output            GB_SER_CLK_OUT,
	input             GB_SER_DATA_IN,
	output            GB_SER_DATA_OUT,

	output     [15:0] MSU_TRACK_NUM,
	output            MSU_TRACK_REQUEST,
	input             MSU_TRACK_MOUNTING,
	input             MSU_TRACK_MISSING,
	output      [7:0] MSU_VOLUME,
	input             MSU_AUDIO_STOP,
	output            MSU_AUDIO_REPEAT,
	output            MSU_AUDIO_PLAYING,
	output     [31:0] MSU_DATA_ADDR,
	input       [7:0] MSU_DATA,
	input             MSU_DATA_ACK,
	output            MSU_DATA_SEEK,
	output            MSU_DATA_REQ,
	input             MSU_ENABLE,

	input             SS_SAVE,
	input             SS_TOSD,
	input             SS_LOAD,
	input       [1:0] SS_SLOT,
	output            SS_AVAIL,

	input      [63:0] SS_DDR_DI,
	input             SS_DDR_ACK,
	output     [63:0] SS_DDR_DO,
	output     [21:3] SS_DDR_ADDR,
	output            SS_DDR_WE,
	output      [7:0] SS_DDR_BE,
	output            SS_DDR_REQ,

	input       [7:0] CH_EN,
	output            AUDIO_MUTE,
	output     [15:0] AUDIO_L,
	output     [15:0] AUDIO_R
);

parameter USE_MSU = 1'b1;

wire [23:0] CA;
wire        CPURD_N;
wire        CPUWR_N;
reg   [7:0] DI;
wire  [7:0] DO;
wire        RAMSEL_N;
wire        ROMSEL_N;
reg         IRQ_N;
wire  [7:0] PA;
wire        PARD_N;
wire        PAWR_N;
wire        SYSCLKF_CE;
wire        SYSCLKR_CE;
wire        REFRESH;

wire  [15:0] SNES_ARAM_ADDR;
wire   [7:0] SNES_ARAM_D;
wire         SNES_ARAM_CE_N;
wire         SNES_ARAM_OE_N;
wire         SNES_ARAM_WE_N;

wire  [5:0] MAP_ACTIVE;

SNES SNES
(
	.mclk(MCLK),
	.dspclk(ACLK),

	.rst_n(RESET_N),
	.enable(1),

	.ca(CA),
	.cpurd_n(CPURD_N),
	.cpuwr_n(CPUWR_N),

	.pa(PA),
	.pard_n(PARD_N),
	.pawr_n(PAWR_N),
	.di(DI),
	.do(DO),

	.ramsel_n(RAMSEL_N),
	.romsel_n(ROMSEL_N),

	.sysclkf_ce(SYSCLKF_CE),
	.sysclkr_ce(SYSCLKR_CE),

	.refresh(REFRESH),

	.irq_n(IRQ_N),

	.wsram_addr(WRAM_ADDR),
	.wsram_d(WRAM_D),
	.wsram_q(WRAM_Q),
	.wsram_ce_n(WRAM_CE_N),
	.wsram_oe_n(WRAM_OE_N),
	.wsram_we_n(WRAM_WE_N),

	.vram_addra(VRAM1_ADDR),
	.vram_addrb(VRAM2_ADDR),
	.vram_dai(VRAM1_DI),
	.vram_dbi(VRAM2_DI),
	.vram_dao(VRAM1_DO),
	.vram_dbo(VRAM2_DO),
	.vram_rd_n(VRAM_OE_N),
	.vram_wra_n(VRAM1_WE_N),
	.vram_wrb_n(VRAM2_WE_N),

	.aram_addr(SNES_ARAM_ADDR),
	.aram_d(SNES_ARAM_D),
	.aram_q(ARAM_Q),
	.aram_ce_n(SNES_ARAM_CE_N),
	.aram_oe_n(SNES_ARAM_OE_N),
	.aram_we_n(SNES_ARAM_WE_N),

	.joy1_di(JOY1_DI),
	.joy2_di(JOY2_DI),
	.joy_strb(JOY_STRB),
	.joy1_clk(JOY1_CLK),
	.joy2_clk(JOY2_CLK),
	.joy1_p6(JOY1_P6),
	.joy2_p6(JOY2_P6),
	.joy2_p6_in(JOY2_P6_in),

	.blend(BLEND),
	.pal(PAL),
	.high_res(HIGH_RES),
	.field_out(FIELD),
	.interlace(INTERLACE),
	.dotclk(DOTCLK),

	.rgb_out({B,G,R}),
	.hde(HBLANKn),
	.vde(VBLANKn),
	.hsync(HSYNC),
	.vsync(VSYNC),

	.gg_en(0),
	.gg_code(0),
	.gg_reset(0),
	.gg_available(),

	.spc_mode(SPC_MODE),

	.io_addr(0),
	.io_dat(0),
	.io_wr(0),

	.ss_addr(SS_EXT_ADDR[8:0]),
	.ss_regs_sel(SS_DSP_REGS_SEL),
	.ss_smp_sel(SS_SMP_SEL),
	.ss_busy(SS_BUSY),
	.ss_wr(~PAWR_N),
	.ss_di(SS_DO),
	.ss_spc_do(SS_SPC_DI),
	.ss_ppu_do(SS_PPU_DI),

	.DBG_BG_EN(DBG_BG_EN),
	.DBG_CPU_EN(DBG_CPU_EN),

	.turbo(TURBO),

	.CH_EN(CH_EN),
	.audio_mute(AUDIO_MUTE),
	.audio_l(AUDIO_L),
	.audio_r(AUDIO_R)
);

wire  [7:0] MSU_DO;
wire        MSU_SEL;

generate
if (USE_MSU == 1'b1) begin
MSU MSU
(
	.CLK(MCLK),
	.RST_N(RESET_N),
	.ENABLE(MSU_ENABLE),

	.RD_N(CPURD_N),
	.WR_N(CPUWR_N),
	.SYSCLKF_CE(SYSCLKF_CE),

	.ADDR(CA),
	.DIN(DO),
	.DOUT(MSU_DO),
	.MSU_SEL(MSU_SEL),

	.data_addr(MSU_DATA_ADDR),
	.data(MSU_DATA),
	.data_ack(MSU_DATA_ACK),
	.data_seek(MSU_DATA_SEEK),
	.data_req(MSU_DATA_REQ),

	.track_num(MSU_TRACK_NUM),
	.track_request(MSU_TRACK_REQUEST),
	.track_mounting(MSU_TRACK_MOUNTING),

	.status_track_missing(MSU_TRACK_MISSING),
	.status_audio_repeat(MSU_AUDIO_REPEAT),
	.status_audio_playing(MSU_AUDIO_PLAYING),
	.audio_stop(MSU_AUDIO_STOP),

	.volume(MSU_VOLUME)
);
end else begin
	assign MSU_DO  = 0;
	assign MSU_SEL = 0;
	assign MSU_TRACK_NUM = 0;
	assign MSU_TRACK_REQUEST = 0;
	assign MSU_VOLUME = 0;
	assign MSU_AUDIO_REPEAT = 0;
	assign MSU_AUDIO_PLAYING = 0;
end
endgenerate

wire  [7:0] SGB_DO;
wire [23:0] SGB_ROM_ADDR;
wire        SGB_ROM_CE_N;
wire        SGB_ROM_OE_N;

//GB save states
wire [63:0] gb_state_din;
wire  [9:0] gb_state_adr;
wire        gb_state_wren;
wire        gb_state_load;
wire [63:0] gb_state_dout;

wire [19:0] gb_ram_addr;
wire  [7:0] gb_ram_data;
wire  [4:0] gb_ram_wren;
wire  [7:0] gb_ram_din_wram;
wire  [7:0] gb_ram_din_vram;
wire  [7:0] gb_ram_din_oram;
wire  [7:0] gb_ram_din_zram;
wire  [7:0] gb_ram_din_cram;

wire  [7:0] gb_cart_ram_size;

SGBMap SGBMap
(
	.clk(MCLK),
	.rst_n(RESET_N),

	.ca(CA),
	.di(DO),
	.sgb_do(SGB_DO),
	.cpurd_n(CPURD_N),
	.cpuwr_n(CPUWR_N),
	
	.romsel_n(ROMSEL_N),

	.sysclkf_ce(SYSCLKF_CE),
	.sysclkr_ce(SYSCLKR_CE),

	.rom_addr(SGB_ROM_ADDR),
	.rom_q(ROM_Q),
	.rom_ce_n(SGB_ROM_CE_N),
	.rom_oe_n(SGB_ROM_OE_N),

	.gb_rom_addr(GB_ROM_ADDR),
	.gb_rom_rd(GB_ROM_RD),
	.gb_rom_di(GB_ROM_DI),

	.gb_cram_wr(GB_CRAM_WR),

	.gb_bk_wr(GB_BK_WR),
	.gb_rtc_wr(GB_RTC_WR),
	.gb_bk_addr(GB_BK_ADDR),
	.gb_bk_data(GB_BK_DATA),
	.gb_bk_q(GB_BK_Q),
	.gb_bk_img_size(GB_BK_IMG_SIZE),

	.gb_ram_mask(GB_RAM_MASK),
	.gb_has_save(GB_HAS_SAVE),

	.gb_rtc_time_in(GB_RTC_TIME_IN),
	.gb_rtc_timeout(GB_RTC_TIMEOUT),
	.gb_rtc_savedtime(GB_RTC_SAVEDTIME),
	.gb_rtc_inuse(GB_RTC_INUSE),

	.gb_audio_no_pops(GB_AUDIO_NO_POPS),
	.gb_audio_l(GB_AUDIO_L),
	.gb_audio_r(GB_AUDIO_R),

	.gb_sc_int_clock(GB_SC_INT_CLOCK),
	.gb_ser_clk_in(GB_SER_CLK_IN),
	.gb_ser_data_in(GB_SER_DATA_IN),
	.gb_ser_clk_out(GB_SER_CLK_OUT),
	.gb_ser_data_out(GB_SER_DATA_OUT),

	.gg_en(GG_EN),
	.gg_code(GG_CODE),
	.gg_reset(GG_RESET),
	.gg_available(GG_AVAILABLE),

	.io_addr(IO_ADDR),
	.io_dat(IO_DAT),
	.io_wr(IO_WR),
	.io_gb_cart(IO_GB_CART),
	.io_sgb_boot(IO_SGB_BOOT),

	.pal(PAL),
	.sgb_speed(SGB_SPEED),
	.gb_mapper(GB_MAPPER),

	.rom_mask(ROM_MASK[18]),

	.ss_busy(SS_BUSY),

	.cart_ram_size(gb_cart_ram_size),

	.SaveStateBus_Din   (gb_state_dout),
	.SaveStateBus_Adr   (gb_state_adr),
	.SaveStateBus_wren  (gb_state_wren),
	.SaveStateBus_load  (gb_state_load),
	.SaveStateBus_Dout  (gb_state_din),

	.Savestate_RAMAddr          (gb_ram_addr),
	.Savestate_RAMWriteData     (gb_ram_data),
	.Savestate_RAMRWrEn         (gb_ram_wren),
	.Savestate_RAMReadData_WRAM (gb_ram_din_wram),
	.Savestate_RAMReadData_VRAM (gb_ram_din_vram),
	.Savestate_RAMReadData_ORAM (gb_ram_din_oram),
	.Savestate_RAMReadData_ZRAM (gb_ram_din_zram),
	.Savestate_RAMReadData_CRAM (gb_ram_din_cram)
);

wire        SS_BUSY;
wire  [7:0] SS_DO;
wire [19:0] SS_EXT_ADDR;
wire  [7:0] SS_SPC_DI;
wire  [7:0] SS_PPU_DI;
wire        SS_DO_OVR;
wire        SS_ARAM_SEL, SS_DSP_REGS_SEL, SS_SMP_SEL;

savestates ss
(
	.reset_n(RESET_N),
	.clk(MCLK),

	.save(SS_SAVE),
	.save_sd(SS_TOSD),
	.load(SS_LOAD),
	.slot(SS_SLOT),

	.ram_size(4'h0),
	.rom_type(8'h00),

	.sysclkf_ce(SYSCLKF_CE),
	.sysclkr_ce(SYSCLKR_CE),

	.romsel_n(ROMSEL_N),
	.rom_q(ROM_Q),

	.ca(CA),
	.cpurd_n(CPURD_N),
	.cpuwr_n(CPUWR_N),

	.pa(PA),
	.pard_n(PARD_N),
	.pawr_n(PAWR_N),

	.di(DO),
	.ss_do(SS_DO),

	.ddr_di(SS_DDR_DI),
	.ddr_ack(SS_DDR_ACK),
	.ddr_do(SS_DDR_DO),
	.ddr_addr(SS_DDR_ADDR),
	.ddr_we(SS_DDR_WE),
	.ddr_be(SS_DDR_BE),
	.ddr_req(SS_DDR_REQ),

	.ext_addr(SS_EXT_ADDR),

	.spc_di(SS_SPC_DI),
	.aram_sel(SS_ARAM_SEL),
	.dsp_regs_sel(SS_DSP_REGS_SEL),
	.smp_regs_sel(SS_SMP_SEL),

	.ppu_di(SS_PPU_DI),

	.ss_do_ovr(SS_DO_OVR),
	.ss_busy(SS_BUSY),

	// GB save states
	.gb_cart_ram_size(gb_cart_ram_size),

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

assign SS_AVAIL = 1;

always @(*) begin
	begin
		DI         = SGB_DO;
		IRQ_N      = 1;
		ROM_ADDR   = SGB_ROM_ADDR;
		ROM_D      = 7'h00;
		ROM_CE_N   = SGB_ROM_CE_N;
		ROM_OE_N   = SGB_ROM_OE_N;
		ROM_WE_N   = 1;
		ROM_WORD   = 0;
	end
	if(MSU_SEL) DI = MSU_DO;

	if (SS_ARAM_SEL) begin
		ARAM_ADDR = SS_EXT_ADDR[15:0];
		ARAM_D    = SS_DO;
		ARAM_CE_N = 0;
		ARAM_OE_N = PARD_N;
		ARAM_WE_N = PAWR_N;
	end else begin
		ARAM_ADDR = SNES_ARAM_ADDR;
		ARAM_D    = SNES_ARAM_D;
		ARAM_CE_N = SNES_ARAM_CE_N;
		ARAM_OE_N = SNES_ARAM_OE_N;
		ARAM_WE_N = SNES_ARAM_WE_N;
	end

	if (SS_DO_OVR) begin
		DI         = SS_DO;
	end

end

endmodule
