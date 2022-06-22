derive_pll_clocks

derive_clock_uncertainty

set_max_delay 23 -from [get_registers { emu|hps_io|* \
													 emu|main|* }] \
					  -to   [get_registers { emu|sdram|a[*] \
													 emu|sdram|ram_req* \
													 emu|sdram|we* \
													 emu|sdram|state[*] \
													 emu|sdram|old_* \
													 emu|sdram|SDRAM_nCAS \
													 emu|sdram|SDRAM_A[*] \
													 emu|sdram|SDRAM_BA[*] }] 

set_max_delay 23 -from [get_registers { emu|sdram|* }] \
					  -to   [get_registers { emu|main|* \
													 emu|wram|* \
													 emu|vram*|* }] 

set_false_path -to [get_registers { emu|sdram|ds emu|sdram|data[*]}]

set_false_path -from {emu|en216p}
