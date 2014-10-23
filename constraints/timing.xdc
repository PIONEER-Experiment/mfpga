# system clock
create_clock -period 20.000 -name clk50 -waveform {0.000 10.000} [get_ports {clkin}]

# gtx clock for GigE
create_clock -name gige_clk -period 8.000 [get_ports gtx_clk0]

# TTC clock
create_clock -period 25.000 -name ttc_clk [get_ports {ttc_clkp}]

# DAQ_Link_7S ReadMe said to include this line
create_clock -period 4.000 -name DAQ_usrclk [get_pins daq/i_UsrClk/O]

# Aurora USER_CLK Constraint : Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
create_clock -period 8.000 -name user_clk_chan0 [get_pins channels/chan0/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan1 [get_pins channels/chan1/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan2 [get_pins channels/chan2/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan3 [get_pins channels/chan3/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan4 [get_pins channels/chan4/clock_module/user_clk_buf_i/O]

# statements to deal with inter-clock timing problems
set_false_path -from [get_cells r/ipb_rst_stretch_reg[*]] -to [get_cells r/rst_clk50_sync_reg*]

# Separate asynchronous clock domains
set_clock_groups -name async_clks -asynchronous\
-group [get_clocks -include_generated_clocks clk50]\
-group [get_clocks -include_generated_clocks gige_clk]\
-group [get_clocks -include_generated_clocks ttc_clk]\
-group [get_clocks -include_generated_clocks DAQ_usrclk] \
-group [get_clocks -include_generated_clocks user_clk_chan0]\
-group [get_clocks -include_generated_clocks user_clk_chan1]\
-group [get_clocks -include_generated_clocks user_clk_chan2]\
-group [get_clocks -include_generated_clocks user_clk_chan3]\
-group [get_clocks -include_generated_clocks user_clk_chan4]\
-group [get_clocks -include_generated_clocks ipb/eth/phy/U0/pcs_pma_block_i/transceiver_inst/gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK]
