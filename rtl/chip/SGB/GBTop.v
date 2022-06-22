module GBTop(
	input         clk,
	input         reset,

	input         clk_en,

	input         cart_download,
	input         ioctl_wr,
	input  [24:0] ioctl_addr,
	input  [15:0] ioctl_dout,

	output [22:0] rom_addr,
	output        rom_rd,
	input   [7:0] rom_di,

	output        cram_wr,

	output        lcd_clkena,
	output  [1:0] lcd_data,
	output  [1:0] lcd_mode,
	output        lcd_on,
	output        lcd_vsync,

	output  [1:0] joy_p54,
	input   [3:0] joy_din,

	input         bk_wr,
	input         bk_rtc_wr,
	input  [16:0] bk_addr,
	input  [15:0] bk_data,
	output [15:0] bk_q,
	input  [63:0] img_size,

	output  [7:0] ram_mask_file,
	output        cart_has_save,

	output [15:0] audio_l,
	output [15:0] audio_r,

	output        sc_int_clock,
	input         ser_clk_in,
	output        ser_clk_out,
	input         ser_data_in,
	output        ser_data_out,

	input         gg_en,
	input         gg_reset,
	input [128:0] gg_code,
	output        gg_available,

	input  [32:0] RTC_time,
	output [31:0] RTC_timestampOut,
	output [47:0] RTC_savedtimeOut,
	output        RTC_inuse
);

wire [14:0] cart_addr;
wire [22:0] mbc_addr;
wire cart_a15;
wire cart_rd;
wire cart_wr;
wire cart_oe;
wire [7:0] cart_di, cart_do;
wire nCS; // WRAM or Cart RAM CS
wire cram_rd;

wire [7:0] cart_ram_size;

wire SaveStateBus_rst;

assign rom_addr = mbc_addr;
assign rom_rd = (cart_rd & ~cart_a15);


cart_top cart (
	.reset	     ( reset      ),

	.clk_sys     ( clk    ),
	.ce_cpu      ( clk_en    ),
	.ce_cpu2x    ( 0  ),
	.speed       ( 0     ),

	.cart_addr   ( cart_addr  ),
	.cart_a15    ( cart_a15   ),
	.cart_rd     ( cart_rd    ),
	.cart_wr     ( cart_wr    ),
	.cart_do     ( cart_do    ),
	.cart_di     ( cart_di    ),
	.cart_oe     ( cart_oe    ),

	.nCS         ( nCS        ),

	.mbc_addr    ( mbc_addr   ),

	.dn_write    (     ),
	.cart_ready  (     ),

	.cram_rd     ( cram_rd     ),
	.cram_wr     ( cram_wr     ),

	.cart_download ( cart_download ),

	.ram_mask_file ( ram_mask_file ),
	.ram_size      ( cart_ram_size ),
	.has_save      ( cart_has_save ),

	.isGBC_game    (    ),
	.isSGB_game    (    ),

	.ioctl_download ( 0 ),
	.ioctl_wr       ( ioctl_wr       ),
	.ioctl_addr     ( ioctl_addr     ),
	.ioctl_dout     ( ioctl_dout     ),
	.ioctl_wait     (      ),

	.bk_wr          ( bk_wr         ),
	.bk_rtc_wr      ( bk_rtc_wr     ),
	.bk_addr        ( bk_addr        ),
	.bk_data        ( bk_data        ),
	.bk_q           ( bk_q          ),
	.img_size       ( img_size       ),

	.rom_di         ( rom_di       ),

	.joystick_analog_0 ( 0 ),

	.RTC_time         ( RTC_time         ),
	.RTC_timestampOut ( RTC_timestampOut ),
	.RTC_savedtimeOut ( RTC_savedtimeOut ),
	.RTC_inuse        ( RTC_inuse        ),

	.SaveStateExt_Din ( 0  ),
	.SaveStateExt_Adr ( 0  ),
	.SaveStateExt_wren( 0 ),
	.SaveStateExt_rst ( SaveStateBus_rst  ),
	.SaveStateExt_Dout(  ),
	.savestate_load   ( 0   ),
	.sleep_savestate  ( 0   ),

	.Savestate_CRAMAddr     ( 0  ),
	.Savestate_CRAMRWrEn    ( 0  ),
	.Savestate_CRAMWriteData( 0  ),
	.Savestate_CRAMReadData (    )
);

// the gameboy itself
gb gb (
	.reset	    ( reset      ),

	.clk_sys     ( clk    ),
	.ce          ( clk_en    ),   // the whole gameboy runs on 4mhnz
	.ce_2x       ( 0  ),   // ~8MHz in dualspeed mode (GBC)

	.fast_boot   ( 0  ),

	.isGBC       ( 0  ),
	.isGBC_game  ( 0 ),
	.isSGB       ( 1'b1 ),

	.joy_p54     ( joy_p54     ),
	.joy_din     ( joy_din      ),

	// interface to the "external" game cartridge
	.ext_bus_addr( cart_addr  ),
	.ext_bus_a15 ( cart_a15   ),
	.cart_rd     ( cart_rd    ),
	.cart_wr     ( cart_wr    ),
	.cart_do     ( cart_do    ),
	.cart_di     ( cart_di    ),
	.cart_oe     ( cart_oe    ),

	.nCS         ( nCS     ),

	// audio
	.audio_l 	 ( audio_l ),
	.audio_r 	 ( audio_r ),

	// interface to the lcd
	.lcd_clkena  ( lcd_clkena ),
	.lcd_data    (            ),
	.lcd_data_gb ( lcd_data   ),
	.lcd_mode    ( lcd_mode   ),
	.lcd_on      ( lcd_on     ),
	.lcd_vsync   ( lcd_vsync  ),

	.speed       (     ),
	.DMA_on      (     ),

	// serial port
	.sc_int_clock2  (sc_int_clock),
	.serial_clk_in  (ser_clk_in),
	.serial_data_in (ser_data_in),
	.serial_clk_out (ser_clk_out),
	.serial_data_out(ser_data_out),

	.gg_reset     (gg_reset),
	.gg_en        (gg_en),
	.gg_code      (gg_code),
	.gg_available (gg_available),

	// savestates
	.increaseSSHeaderCount (1'b0),
	.cart_ram_size   (cart_ram_size),
	.save_state      (1'b0),
	.load_state      (1'b0),
	.savestate_number(2'b00),
	.sleep_savestate (),

	.SaveStateExt_Din (),
	.SaveStateExt_Adr (),
	.SaveStateExt_wren(),
	.SaveStateExt_rst (SaveStateBus_rst),
	.SaveStateExt_Dout(0),
	.SaveStateExt_load(),

	.Savestate_CRAMAddr     (),
	.Savestate_CRAMRWrEn    (),
	.Savestate_CRAMWriteData(),
	.Savestate_CRAMReadData (0),

	.SAVE_out_Din(),            // data read from savestate
	.SAVE_out_Dout(0),          // data written to savestate
	.SAVE_out_Adr(),           // all addresses are DWORD addresses!
	.SAVE_out_rnw(),            // read = 1, write = 0
	.SAVE_out_ena(),            // one cycle high for each action
	.SAVE_out_be(),            
	.SAVE_out_done(1'b1),            // should be one cycle high when write is done or read value is valid

	.rewind_on(1'b0),
	.rewind_active(1'b0)
);


endmodule