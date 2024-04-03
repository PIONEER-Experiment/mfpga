# Separate asynchronous clock domains
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks ipb/eth/phy/inst/pcs_pma_block_i/transceiver_inst/gtwizard_inst/inst/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {clk_6p25M_slow_i2c_clock adcclk_dclk_slow_i2c_clock}]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks channels/chan0/aurora/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i/TXOUTCLK]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks channels/chan1/aurora/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i/TXOUTCLK]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks channels/chan2/aurora/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i/TXOUTCLK]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks channels/chan3/aurora/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i/TXOUTCLK]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks channels/chan4/aurora/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i/TXOUTCLK]

# recommended by clock wizard
#set_clock_groups -asynchronous -group [get_clocks clkin] -group [get_clocks clk_6p25M_slow_i2c_clock]
#set_false_path -from [get_clocks clk_125] -to [get_clocks clk_6p25M_slow_i2c_clock]

