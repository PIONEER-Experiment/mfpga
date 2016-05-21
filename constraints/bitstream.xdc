set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE [current_design]
set_property BITSTREAM.CONFIG.NEXT_CONFIG_REBOOT DISABLE [current_design]
set_property BITSTREAM.CONFIG.NEXT_CONFIG_ADDR 0x670000 [current_design]
set_property BITSTREAM.CONFIG.TIMER_CFG 0x00800000 [current_design]

# compress the output bitstream file
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
