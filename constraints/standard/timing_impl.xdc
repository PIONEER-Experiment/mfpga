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

# Statements to deal with intra-clock timing problems
set_false_path -from [get_cells {command_manager/chan_burst_count_type1_reg[*]}] -to [get_cells {command_manager/daq_data_reg[*]}]
set_false_path -from [get_cells {command_manager/chan_burst_count_type2_reg[*]}] -to [get_cells {command_manager/daq_data_reg[*]}]
set_false_path -from [get_cells {command_manager/chan_burst_count_type3_reg[*]}] -to [get_cells {command_manager/daq_data_reg[*]}]
set_false_path -from [get_cells {command_manager/chan_burst_count_type4_reg[*]}] -to [get_cells {command_manager/daq_data_reg[*]}]
set_false_path -from [get_cells {command_manager/chan_wfm_count_type1_reg[*]}] -to [get_cells {command_manager/daq_data_reg[*]}]
set_false_path -from [get_cells {command_manager/chan_wfm_count_type2_reg[*]}] -to [get_cells {command_manager/daq_data_reg[*]}]
set_false_path -from [get_cells {command_manager/chan_wfm_count_type3_reg[*]}] -to [get_cells {command_manager/daq_data_reg[*]}]


# -----------------------------------------------------------------------------
# GigE PCS/PMA: MMCM lock synchronizer output → mmcm_lock_count_reg[*]/R
# This path is fully inside clk200 but functionally async — the count register
# just stretches reset deassertion by N cycles.  At 200 MHz the path can fail
# setup when placement spreads source and dest far apart (net delay ~4.5 ns,
# logic only ~0.3 ns).  Allow 2 cycles for setup; keep hold at 1.
# -----------------------------------------------------------------------------
set_multicycle_path 2 -setup \
    -from [get_cells -hier -filter {NAME =~ *pcs_pma_block_i/*sync_mmcm_lock_reclocked/data_sync_reg*}] \
    -to   [get_cells -hier -filter {NAME =~ *pcs_pma_block_i/*resetfsm_i/mmcm_lock_count_reg*}]
set_multicycle_path 1 -hold \
    -from [get_cells -hier -filter {NAME =~ *pcs_pma_block_i/*sync_mmcm_lock_reclocked/data_sync_reg*}] \
    -to   [get_cells -hier -filter {NAME =~ *pcs_pma_block_i/*resetfsm_i/mmcm_lock_count_reg*}]


# GigE PHY: paths from synchronizer outputs inside *resetfsm_i to anything
# inside the same resetfsm are init/reset signals - tolerate 2 cycles
foreach fsm {gt0_txresetfsm_i gt0_rxresetfsm_i} {
    set_multicycle_path 2 -setup \
        -from [get_cells -hier -filter "NAME =~ *pcs_pma_block_i/*${fsm}/sync_*/data_sync_reg*"] \
        -to   [get_cells -hier -filter "NAME =~ *pcs_pma_block_i/*${fsm}/*"]
    set_multicycle_path 1 -hold \
        -from [get_cells -hier -filter "NAME =~ *pcs_pma_block_i/*${fsm}/sync_*/data_sync_reg*"] \
        -to   [get_cells -hier -filter "NAME =~ *pcs_pma_block_i/*${fsm}/*"]
}

