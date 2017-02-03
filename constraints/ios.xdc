# ############
# io standards
# ############

set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports gige_rx]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports gige_rx_N]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports gige_tx]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports gige_tx_N]

set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports daq_rx]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports daq_rx_N]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports daq_tx]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports daq_tx_N]

set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports gtx_clk0]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports gtx_clk0_N]

set_property IOSTANDARD LVCMOS33 [get_ports bbus_scl]
set_property IOSTANDARD LVCMOS33 [get_ports bbus_sda]

set_property IOSTANDARD LVCMOS33 [get_ports master_led0]
set_property IOSTANDARD LVCMOS33 [get_ports master_led1]

set_property IOSTANDARD LVCMOS33 [get_ports clksynth_led0]
set_property IOSTANDARD LVCMOS33 [get_ports clksynth_led1]

set_property IOSTANDARD LVCMOS33 [get_ports ext_clk_sel0]
set_property IOSTANDARD LVCMOS33 [get_ports ext_clk_sel1]

set_property IOSTANDARD LVCMOS33 [get_ports daq_clk_sel]
set_property IOSTANDARD LVCMOS33 [get_ports daq_clk_en]

set_property IOSTANDARD LVDS [get_ports ttc_clkp]
set_property IOSTANDARD LVDS [get_ports ttc_clkn]
set_property IOSTANDARD LVDS [get_ports ttc_rxp]
set_property IOSTANDARD LVDS [get_ports ttc_rxn]
set_property IOSTANDARD LVDS [get_ports ttc_txp]
set_property IOSTANDARD LVDS [get_ports ttc_txn]

set_property IOSTANDARD LVCMOS33 [get_ports clkin]

set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi_ss]

set_property IOSTANDARD LVCMOS33 [get_ports fp_sw_master]

# ################
# extra properties
# ################

set_property PULLUP TRUE [get_ports bbus_scl]
set_property PULLUP TRUE [get_ports bbus_sda]

# ###############
# pin assignments
# ###############

set_property PACKAGE_PIN P1 [get_ports gige_tx_N]
set_property PACKAGE_PIN M1 [get_ports daq_tx_N]

set_property PACKAGE_PIN H6 [get_ports gtx_clk0]
set_property PACKAGE_PIN H5 [get_ports gtx_clk0_N]

set_property PACKAGE_PIN B14 [get_ports bbus_scl]
set_property PACKAGE_PIN A14 [get_ports bbus_sda]

set_property PACKAGE_PIN V26 [get_ports master_led0]
set_property PACKAGE_PIN U26 [get_ports master_led1]

set_property PACKAGE_PIN AC21 [get_ports clksynth_led0]
set_property PACKAGE_PIN AB21 [get_ports clksynth_led1]

set_property PACKAGE_PIN P26 [get_ports ext_clk_sel0]
set_property PACKAGE_PIN M26 [get_ports ext_clk_sel1]

set_property PACKAGE_PIN K23 [get_ports daq_clk_sel]
set_property PACKAGE_PIN K26 [get_ports daq_clk_en]

set_property PACKAGE_PIN AB4 [get_ports ttc_clkn]
set_property PACKAGE_PIN V1  [get_ports ttc_rxn]
set_property PACKAGE_PIN Y2  [get_ports ttc_txn]

set_property PACKAGE_PIN C12 [get_ports clkin]

set_property PACKAGE_PIN A25 [get_ports spi_miso]
set_property PACKAGE_PIN B24 [get_ports spi_mosi]
set_property PACKAGE_PIN C23 [get_ports spi_ss]

set_property PACKAGE_PIN J21 [get_ports fp_sw_master]
