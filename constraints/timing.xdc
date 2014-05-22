# system clock
create_clock -period 20.000 -name clk50 -waveform {0.000 10.000} [get_ports {clkin}]

# the 'clkin' is on the N pin of a PN pair, so it needs the next constraint to allow it to place the clock
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets xlnx_opt__10]

# gtx clock for GigE
create_clock -name gige_clk -period 8.000 [get_ports gtx_clk0]
# create_clock -name gt_drpclk_in -period 8.000 [get_ports gt*drpcl*]

set_property ASYNC_REG TRUE [get_cells ipb/rst/sync_*]
# set_false_path -from [get_cells ipb/rst/rst_ipb_reg] -to [get_cells ipb/rst/sync_*]
set_false_path -from [get_cells ipb/rst/rst_delayed_reg] -to [get_cells ipb/rst/sync_*]
set_property ASYNC_REG TRUE [get_cells r/rst_clk50_sync[*]]
set_false_path -from [get_cells r/ipb_rst_stretch_reg[*]] -to [get_cells r/rst_clk50_sync_reg*]

create_clock -period 4.000 -name DAQ_usrclk [get_pins daq/i_DAQLINK_7S_init/GT0_TXOUTCLK_OUT]

# virtual clock to constrain trigger outputs
create_clock -period 1.250 -name chan_clk
set_output_delay -clock chan_clk 0.0 [get_ports acq_trigs[*]]
set_output_delay -clock chan_clk 0.0 [get_ports debug[*]]

# Separate asynchronous clock domains
set_clock_groups -name async_clk50_gige_clk -asynchronous\
 -group [get_clocks -include_generated_clocks clk50]\
 -group [get_clocks -include_generated_clocks gige_clk]\
 -group [get_clocks -include_generated_clocks ipb/eth/phy/U0/pcs_pma_block_i/transceiver_inst/gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK]\
 -group [get_clocks -include_generated_clocks DAQ_usrclk]\
 -group [get_clocks -include_generated_clocks chan_clk]

create_clock -name chan0_tx_out_clk -period 8.0 [get_pins channels/chan0/aurora/inst/tx_out_clk]

set_max_delay -from [get_clocks clk50] -to [get_clocks chan0_tx_out_clk] -datapath_only 8.0	 
set_false_path -from [get_clocks chan0_tx_out_clk] -to [get_clocks clk125]