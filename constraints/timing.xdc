# system clock
create_clock -period 20.000 -name clk50 -waveform {0.000 10.000} [get_ports {clkin}]

# the 'clkin' is on the N pin of a PN pair, so it needs the next constraint to allow it to place the clock
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clkin_IBUF]

# gtx clock for GigE
create_clock -name gige_clk -period 8.000 [get_ports gtx_clk0]
# create_clock -name gt_drpclk_in -period 8.000 [get_ports gt*drpcl*]

# Separate asynchronous clock domains
set_clock_groups -name async_clk50_gige_clk -asynchronous\
 -group [get_clocks -include_generated_clocks clk50]\
 -group [get_clocks -include_generated_clocks gige_clk]\
 -group [get_clocks -include_generated_clocks ipb/eth/phy/U0/pcs_pma_block_i/transceiver_inst/gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK]

set_property ASYNC_REG TRUE [get_cells ipb/rst/sync_*]
# set_false_path -from [get_cells ipb/rst/rst_ipb_reg] -to [get_cells ipb/rst/sync_*]
set_false_path -from [get_cells ipb/rst/rst_delayed_reg] -to [get_cells ipb/rst/sync_*]

 # set_false_path -from [get_cells ipb/slaves/slave0/reg_reg[0][0] ] -to [all_registers]

# set_false_path -from [get_pins ipb/rst/rst_sr_reg[0]__0/C] -to [get_pins ipb/rst/rst_200_reg/D]

create_clock -period 4.000 -name DAQ_usrclk [get_pins */daq/i_UsrClk/o]
