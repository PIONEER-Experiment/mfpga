# let vivado know about uncorrelated clocks
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks clk50] -group [get_clocks -include_generated_clocks gige_clk] -group [get_clocks -include_generated_clocks ttc_clk] -group [get_clocks -include_generated_clocks DAQ_txoutclk] -group [get_clocks -include_generated_clocks ipb/eth/phy/inst/pcs_pma_block_i/transceiver_inst/gtwizard_inst/inst/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK] -group [get_clocks -include_generated_clocks ipb/eth/phy/inst/pcs_pma_block_i/transceiver_inst/gtwizard_inst/inst/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/RXOUTCLK]


