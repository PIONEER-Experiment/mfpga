// Top-level module for Muon g-2 WFD5 Master FPGA
//
// As a useful reference, here's the syntax to mark signals for debug:
// (* mark_debug = "true" *) 

module wfd_top (
    input  wire clkin,                // 50 MHz clock
    input  wire gtx_clk0, gtx_clk0_N, // Bank 115 125 MHz GTX Transceiver refclk
    output wire gige_tx,  gige_tx_N,  // Gigabit Ethernet TX
    input  wire gige_rx,  gige_rx_N,  // Gigabit Ethernet RX
    input  wire daq_rx,   daq_rx_N,   // AMC13 Link RX
    output wire daq_tx,   daq_tx_N,   // AMC13 Link TX
    output wire master_led0,          // front panel LEDs for master status, led0 is green
    output wire master_led1,          // front panel LEDs for master status, led1 is red
    output wire clksynth_led0,        // front panel LEDs for clk synth status, led0 is green
    output wire clksynth_led1,        // front panel LEDs for clk synth status, led1 is red
    inout  wire bbus_scl,             // I2C bus clock, connected to EEPROM Chip, Atmel Chip, Channel FPGAs
    inout  wire bbus_sda,             // I2C bus data,  connected to EEPROM Chip, Atmel Chip, Channel FPGAs
    output wire ext_clk_sel0,         //
    output wire ext_clk_sel1,         //
    output wire daq_clk_sel,          //
    output wire daq_clk_en,           //
    input  wire ttc_clkp, ttc_clkn,   // TTC diff clock
    input  wire ttc_rxp,  ttc_rxn,    // data from TTC
    output wire ttc_txp,  ttc_txn,    // data to TTC
    input  wire spi_miso,             // serial data from SPI flash memory
    output wire spi_mosi,             // serial data (commands) to SPI flash memory
    output wire spi_ss,               // SPI flash memory chip select
    input  wire fp_sw_master          // front panel switch
);

    // ======== clock signals ========
    wire clk50;
    wire clk_125, clk125;
    wire clk200;
    wire clkfb;
    wire gtrefclk0;
    wire spi_clk;

    assign clk50 = clkin; // just to make the frequency explicit

    wire ipb_clk50_reset, clk50_reset;

    // ======== startup reset signals ========
    wire master_init_rst1_clk50, master_init_rst1_clk125;

    // synchronous reset logic for master
    startup_reset master_startup_reset1 (
        .clk50(clk50),                          // 50 MHz buffered clock 
        .reset_clk50(master_init_rst1_clk50),   // active-high reset output, goes low after startup
        .clk125(clk125),                        // buffered clock, 125 MHz
        .reset_clk125(master_init_rst1_clk125), // active-high reset output, goes low after startup
        .hold(ipb_clk50_reset)                  // reset signal from reset
    );

    assign clk50_reset = ipb_clk50_reset | master_init_rst1_clk50;

    // ======== TTC signals ========
    wire ttc_ready;
    wire ttc_freq_rst;

    // ======== front panel LED for master ========
    assign master_led0 = 1'b0;
    assign master_led1 = 1'b0;

    // ======== front panel LED for clk synth ========
    assign clksynth_led0 = 1'b0;
    assign clksynth_led1 = 1'b0;

    // front panel clock   : sel0 = 1'b0, sel1 = 1'b1
    // uTCA backplane clock: sel0 = 1'b1, sel1 = 1'b0
    // both                : sel0 = 1'b1, sel1 = 1'b1
    assign ext_clk_sel0 = 1'b0;
    assign ext_clk_sel1 = 1'b1;

    // uTCA backplane clock: daq_clk_sel = 1'b0
    // front panel clock:    daq_clk_sel = 1'b1
    assign daq_clk_sel = 1'b0;
    assign daq_clk_en  = 1'b1;

    // Required statement to support differential ttc_txp / ttc_txn pair
    OBUFDS ttc_tx_buf (.I(1'b0), .O(ttc_txp), .OB(ttc_txn));

    // Generate clocks from the 50 MHz input clock
    // Most of the design is run from the 125 MHz clock (don't confuse it with the 125 MHz GTREFCLK)
    // clk200 acts as the independent clock required by the Gigabit Ethernet IP
    PLLE2_BASE #(
        .CLKFBOUT_MULT(20.0),
        .CLKIN1_PERIOD(20), // in ns, so 20 -> 50 MHz
        .CLKOUT0_DIVIDE(5),
        .CLKOUT1_DIVIDE(8)
    ) clk (
        .CLKIN1(clkin),
        .CLKOUT0(clk200),
        .CLKOUT1(clk_125),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(),
        .RST(0),
        .PWRDWN(0),
        .CLKFBOUT(clkfb),
        .CLKFBIN(clkfb)
    );

    // Added BUFG object to deal with a warning message that caused implementation to fail
    // "Clock net clk125 is not driven by a Clock Buffer and has more than 2000 loads."
    BUFG BUFG_clk125 (.I(clk_125), .O(clk125));


    // ======== reset signals ========
    wire rst_from_ipb; // active-high reset from IPbus; synchronous to IPbus clock

    // Synchronize reset from IPbus clock domain to other domains
    wire ipb_rst_stretch;
    signal_stretch reset_stretch (
        .signal_in(rst_from_ipb),
        .clk(clk125),
        .n_extra_cycles(8'h13),      // more than enough cycles for synchronization into 50-MHz, 40-MHz domains
        .signal_out(ipb_rst_stretch) // 160-ns wide
    );

    sync_2stage clk50_reset_sync (
        .clk(clk50),
        .in(ipb_rst_stretch),
        .out(ipb_clk50_reset)
    );


	// connect a module that will read from the I2C temperature/memory chip.
	// since the MAC and IP address are used with IPbus, run the block with 'clk125'
	wire [47:0] i2c_mac_adr; // MAC address read from I2C EEPROM
	wire [31:0] i2c_ip_adr;  // IP address read from I2C EEPROM
    wire [11:0] i2c_temp;    // temperature reading from I2C EEPROM
    wire i2c_startup_done;
    wire i2c_temp_polling_dis;

    wire bbus_scl_oen;
    wire bbus_sda_oen;

	i2c_top i2c_top (
		// inputs
		.clk(clk125),
        .reset(ip_addr_rst),                         // IPbus reset for reloading addresses from EEPROM
        .i2c_temp_polling_dis(i2c_temp_polling_dis), // disable temperature polling
        // outputs
        .i2c_startup_done(i2c_startup_done),         // MAC and IP will be valid when this is asserted
		.i2c_mac_adr(i2c_mac_adr[47:0]),	         // MAC address read from I2C EEPROM
		.i2c_ip_adr(i2c_ip_adr[31:0]),	             // IP address read from I2C EEPROM
        .i2c_temp(i2c_temp[11:0]),                   // temperature reading from I2C EEPROM
		// I2C signals
		.scl_pad_i(bbus_scl),				         // input from external pin
		.scl_pad_o(bbus_scl_o),			             // output to tri-state driver
		.scl_padoen_o(bbus_scl_oen),		         // enable signal for tri-state driver
		.sda_pad_i(bbus_sda),                        // input from external pin
		.sda_pad_o(bbus_sda_o),				         // output to tri-state driver
		.sda_padoen_o(bbus_sda_oen)			         // enable signal for tri-state driver
	);

    assign bbus_scl = bbus_scl_oen ? 1'bz : bbus_scl_o;
    assign bbus_sda = bbus_sda_oen ? 1'bz : bbus_sda_o;


    // ======== communicate with FPGA XADC ========

    wire [15:0] xadc_temp;
    wire [15:0] xadc_vccint;
    wire [15:0] xadc_vccaux;
    wire [15:0] xadc_vccbram;

    wire xadc_reset;
    wire xadc_over_temp;
    wire [3:0] xadc_alarms;
    wire xadc_alarm_temp;
    wire xadc_alarm_vccint;
    wire xadc_alarm_vccaux;
    wire xadc_alarm_vccbram;
    wire xadc_eoc;
    wire xadc_eos;

    assign xadc_reset = master_init_rst1_clk125 | rst_from_ipb;
    assign xadc_alarms = {xadc_alarm_temp, xadc_alarm_vccint, xadc_alarm_vccaux, xadc_alarm_vccbram};

    // XADC interface
    xadc_interface xadc_interface (
        .dclk(clk125),
        .reset(xadc_reset),
        .measured_temp(xadc_temp[15:0]),
        .measured_vccint(xadc_vccint[15:0]),
        .measured_vccaux(xadc_vccaux[15:0]),
        .measured_vccbram(xadc_vccbram[15:0]),
        .over_temp(xadc_over_temp),
        .alarm_temp(xadc_alarm_temp),
        .alarm_vccint(xadc_alarm_vccint),
        .alarm_vccaux(xadc_alarm_vccaux),
        .alarm_vccbram(xadc_alarm_vccbram),
        .eoc(xadc_eoc),
        .eos(xadc_eos)
    );

    
    // ======== communicate with SPI flash memory ========

    // The startup block will give us access to the SPI clock pin (which is otherwise reserved for use during FPGA configuration)
    // STARTUPE2: STARTUP Block
    //            7  Series
    // Xilinx HDL Libraries Guide, version 13.3
    STARTUPE2 #(
        .PROG_USR("FALSE"), // Activate program event security feature. Requires encrypted bitstreams.
        .SIM_CCLK_FREQ(0.0) // Set the Configuration Clock Frequency(ns) for simulation.
    ) STARTUPE2_inst (
        .CFGCLK(),          // 1-bit output: Configuration main clock output
        .CFGMCLK(),         // 1-bit output: Configuration internal oscillator clock output
        .EOS(),             // 1-bit output: Active high output signal indicating the End Of Startup.
        .PREQ(),            // 1-bit output: PROGRAM request to fabric output
        .CLK(0),            // 1-bit  input: User start-up clock input
        .GSR(0),            // 1-bit  input: Global Set/Reset input (GSR cannot be used for the port name)
        .GTS(0),            // 1-bit  input: Global 3-state input (GTS cannot be used for the port name)
        .KEYCLEARB(0),      // 1-bit  input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
        .PACK(0),           // 1-bit  input: PROGRAM acknowledge input
        .USRCCLKO(spi_clk), // 1-bit  input: User CCLK input
        .USRCCLKTS(0),      // 1-bit  input: User CCLK 3-state enable input
        .USRDONEO(0),       // 1-bit  input: User DONE pin output control
        .USRDONETS(0)       // 1-bit  input: User DONE 3-state enable output
    );


    wire [ 8:0] ipbus_to_flash_wr_nBytes;
    wire [ 8:0] ipbus_to_flash_rd_nBytes;
    wire ipbus_to_flash_cmd_strobe;
    wire flash_to_ipbus_cmd_ack;
    wire ipbus_to_flash_rbuf_en;
    wire [ 6:0] ipbus_to_flash_rbuf_addr;
    wire [31:0] flash_rbuf_to_ipbus_data;
    wire ipbus_to_flash_wbuf_en;
    wire [ 6:0] ipbus_to_flash_wbuf_addr;
    wire [31:0] ipbus_to_flash_wbuf_data;

    spi_flash_intf spi_flash_intf (
        .clk(clk50),
        .ipb_clk(clk125),
        .reset(clk50_reset),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_ss(spi_ss),
        .prog_chan_in_progress(1'b0),
        .read_bitstream(1'b0),
        .end_bitstream(),
        .ipb_flash_wr_nBytes(ipbus_to_flash_wr_nBytes),
        .ipb_flash_rd_nBytes(ipbus_to_flash_rd_nBytes),
        .ipb_flash_cmd_strobe(ipbus_to_flash_cmd_strobe),
        .ipb_rbuf_rd_en(ipbus_to_flash_rbuf_en),
        .ipb_rbuf_rd_addr(ipbus_to_flash_rbuf_addr),
        .ipb_rbuf_data_out(flash_rbuf_to_ipbus_data),
        .ipb_wbuf_wr_en(ipbus_to_flash_wbuf_en),
        .ipb_wbuf_wr_addr(ipbus_to_flash_wbuf_addr),
        .ipb_wbuf_data_in(ipbus_to_flash_wbuf_data),
        .pc_wbuf_wr_en(1'b0),
        .pc_wbuf_wr_addr(7'd0),
        .pc_wbuf_data_in(32'b0),
        .send_write_command(1'b0),
        .end_write_command(),
        .pc_flash_wr_nBits(12'b0)
    );


    // ======== module to reprogram FPGA from flash ========

    wire [1:0] reprog_trigger_from_ipbus; // in 125 MHz clock domain
    wire [1:0] reprog_trigger;            // in 50 MHz clock domain
                                          // don't have to worry about missing the faster signal
                                          // (stays high until you use ipbus to set it low again)
    wire [1:0] reprog_trigger_delayed;    // after passing through 32-bit shift register
                                          // (to allow time for IPbus ack before reprogramming FPGA)

    sync_2stage #(
        .WIDTH(2)
    ) reprog_trigger_sync (
        .clk(clk50),
        .in(reprog_trigger_from_ipbus),
        .out(reprog_trigger)
    );

    // Delay signal by passing through 32-bit shift register (to allow time for IPbus ack)

    // SRLC32E: 32-bit variable length cascadable shift register LUT (Mapped to a SliceM LUT6)
    //          with clock enable
    //          7 Series
    // Xilinx HDL Libraries Guide, version 14.2
    SRLC32E #(
        .INIT(32'h00000000) // Initial value of shift register
    ) SRLC32E_inst0 (
        .Q(reprog_trigger_delayed[0]), // SRL data output
        .Q31(),                        // SRL cascade output pin
        .A(5'b11111),                  // 5-bit shift depth select input (5'b11111 = 32-bit shift)
        .CE(1'b1),                     // Clock enable input
        .CLK(clk50),                   // Clock input
        .D(reprog_trigger[0])          // SRL data input
    );

    SRLC32E #(
        .INIT(32'h00000000) // Initial value of shift register
    ) SRLC32E_inst1 (
        .Q(reprog_trigger_delayed[1]), // SRL data output
        .Q31(),                        // SRL cascade output pin
        .A(5'b11111),                  // 5-bit shift depth select input (5'b11111 = 32-bit shift)
        .CE(1'b1),                     // Clock enable input
        .CLK(clk50),                   // Clock input
        .D(reprog_trigger[1])          // SRL data input
    );

    // reprog_trigger_mux[0] for golden image
    // reprog_trigger_mux[1] for master image
    wire [1:0] reprog_trigger_mux; // combine IPbus and front panel switch
    assign reprog_trigger_mux = (fp_sw_master) ? reprog_trigger_delayed : 2'b01;

    reprog reprog (
        .clk(clk50),
        .reset(clk50_reset),
        .trigger(reprog_trigger_mux)
    );


    // ======== communication with the AMC13 DAQ link ========
    wire daq_almost_full;
    
    // ======== status register signals ========
    wire [31:0] status_reg00, status_reg01, status_reg02, status_reg03, status_reg04, 
                status_reg05, status_reg06, status_reg07, status_reg08, status_reg09,
                status_reg10, status_reg11, status_reg12, status_reg13, status_reg14,
                status_reg15, status_reg16, status_reg17, status_reg18, status_reg19,
                status_reg20, status_reg21, status_reg22, status_reg23, status_reg24,
                status_reg25, status_reg26, status_reg27, status_reg28;

    
    // ======== module instantiations ========

    // TTC decoder module
    TTC_decoder ttc (
        .TTC_CLK_p(ttc_clkp),   // in  STD_LOGIC
        .TTC_CLK_n(ttc_clkn),   // in  STD_LOGIC
        .TTC_rst(ttc_freq_rst), // in  STD_LOGIC -- asynchronous reset after TTC_CLK_p/TTC_CLK_n frequency changed
        .TTC_data_p(ttc_rxp),   // in  STD_LOGIC
        .TTC_data_n(ttc_rxn),   // in  STD_LOGIC
        .TTC_CLK_out(),
        .TTCready(ttc_ready),   // out STD_LOGIC
        .L1Accept(),
        .BCntRes(),
        .EvCntRes(),
        .SinErrStr(),
        .DbErrStr(),
        .BrcstStr(),
        .Brcst()
    );


    // IPbus top module
    ipbus_top ipb (
        .gt_clkp(gtx_clk0), .gt_clkn(gtx_clk0_N),
        .gt_txp(gige_tx),   .gt_txn(gige_tx_N),
        .gt_rxp(gige_rx),   .gt_rxn(gige_rx_N),
        .rst_out(rst_from_ipb),

        // clocks
        .clk_200(clk200),
        .clk_125(),
        .ipb_clk(clk125),
        .gtrefclk_out(gtrefclk0),
        
        // MAC and IP address from I2C EEPROM
        .ip_addr_rst_out(ip_addr_rst),       // IP/MAC address from EEPROM reset
        .i2c_mac_adr(i2c_mac_adr[47:0]),     // MAC address read from I2C EEPROM
        .i2c_ip_adr(i2c_ip_adr[31:0]),       // IP address read from I2C EEPROM
        .i2c_startup_done(i2c_startup_done), // MAC and IP will be valid when this is asserted

        // channel user space interface
        // pass out the raw IPbus signals; they're handled in the Aurora block
        .user_ipb_clk(),
        .user_ipb_strobe(),
        .user_ipb_addr(),
        .user_ipb_write(),
        .user_ipb_wdata(),
        .user_ipb_rdata(32'd0),
        .user_ipb_ack(1'b0),
        .user_ipb_err(1'b0),

        // data interface to channel serial link
        // connections from IPbus to command manager
        .axi_stream_out_tvalid(),
        .axi_stream_out_tdata(),
        .axi_stream_out_tlast(),
        .axi_stream_out_tdest(),
        .axi_stream_out_tready(1'b0),
        .axi_stream_out_tstrb(),
        .axi_stream_out_tkeep(),
        .axi_stream_out_tid(),

        // connections from command manager to IPbus
        .axi_stream_in_tvalid(1'b0),
        .axi_stream_in_tdata(32'd0),
        .axi_stream_in_tready(),
        .axi_stream_in_tstrb(4'h0),
        .axi_stream_in_tkeep(4'h0),
        .axi_stream_in_tlast(1'b0),
        .axi_stream_in_tid(4'h0),
        .axi_stream_in_tdest(4'h0),

        // control signals
        .async_mode_in(1'b0),
        .async_mode_out(),
        .accept_pulse_trig_out(),
        .async_trig_type_out(),
        .chan_en_out(),
        .prog_chan_out(),
        .reprog_trigger_out(reprog_trigger_from_ipbus),  // signal to issue IPROG command to re-program FPGA from flash
        .trig_delay_out(),
        .endianness_out(),
        .trig_settings_out(),
        .ttc_loopback_out(),
        .ext_trig_pulse_en_out(),
        .ttc_freq_rst_out(ttc_freq_rst),                 // dedicated reset to TTC decoder for frequency changes
        .i2c_temp_polling_dis_out(i2c_temp_polling_dis), // disable EEPROM temperature polling

        // threshold registers
        .thres_data_corrupt(),
        .thres_unknown_ttc(),
        .thres_ddr3_overflow(),

        // status registers
        .status_reg00(status_reg00),
        .status_reg01(status_reg01),
        .status_reg02(status_reg02),
        .status_reg03(status_reg03),
        .status_reg04(status_reg04),
        .status_reg05(status_reg05),
        .status_reg06(status_reg06),
        .status_reg07(status_reg07),
        .status_reg08(status_reg08),
        .status_reg09(status_reg09),
        .status_reg10(status_reg10),
        .status_reg11(status_reg11),
        .status_reg12(status_reg12),
        .status_reg13(status_reg13),
        .status_reg14(status_reg14),
        .status_reg15(status_reg15),
        .status_reg16(status_reg16),
        .status_reg17(status_reg17),
        .status_reg18(status_reg18),
        .status_reg19(status_reg19),
        .status_reg20(status_reg20),
        .status_reg21(status_reg21),
        .status_reg22(status_reg22),
        .status_reg23(status_reg23),
        .status_reg24(status_reg24),
        .status_reg25(status_reg25),
        .status_reg26(status_reg26),
        .status_reg27(status_reg27),
        .status_reg28(status_reg28),

        // flash interface ports
        .flash_wr_nBytes(ipbus_to_flash_wr_nBytes),
        .flash_rd_nBytes(ipbus_to_flash_rd_nBytes),
        .flash_cmd_strobe(ipbus_to_flash_cmd_strobe),
        .flash_rbuf_en(ipbus_to_flash_rbuf_en),
        .flash_rbuf_addr(ipbus_to_flash_rbuf_addr),
        .flash_rbuf_data(flash_rbuf_to_ipbus_data),
        .flash_wbuf_en(ipbus_to_flash_wbuf_en),
        .flash_wbuf_addr(ipbus_to_flash_wbuf_addr),
        .flash_wbuf_data(ipbus_to_flash_wbuf_data)
    );


    // synchronize ttc_ready
    wire ttc_ready_clk125;
    sync_2stage ttc_ready_sync (
        .clk(clk125),
        .in(ttc_ready),
        .out(ttc_ready_clk125)
    );

    // status register assembly
    status_reg_block status_reg_block (
        // user interface clock and reset
        .clk(clk125),
        .reset(rst_from_ipb),

        // FPGA status
        .prog_chan_done(1'b0),
        .async_mode(1'b0),
        .is_golden(1'b1),

        // soft error thresholds
        .thres_data_corrupt(32'd0),
        .thres_unknown_ttc(32'd0),
        .thres_ddr3_overflow(32'd0),

        // soft error counts
        .unknown_cmd_count(32'd0),
        .ddr3_overflow_count(32'd0),
        .cs_mismatch_count(32'd0),

        // hard errors
        .error_data_corrupt(1'b0),
        .error_trig_num_from_tt(1'b0),
        .error_trig_type_from_tt(1'b0),
        .error_trig_num_from_cm(1'b0),
        .error_trig_type_from_cm(1'b0),
        .error_pll_unlock(1'b0),
        .error_trig_rate(1'b0),
        .error_unknown_ttc(1'b0),

        // warnings
        .ddr3_almost_full(1'b0),

        // other error signals
        .chan_error_sn(5'd0),
        .chan_error_rc(5'd0),

        // external clock
        .daq_clk_sel(daq_clk_sel),
        .daq_clk_en(daq_clk_en),

        // clock synthesizer
        .adcclk_clkin0_stat(1'b0),
        .adcclk_clkin1_stat(1'b0),
        .adcclk_stat_ld(1'b0),
        .adcclk_stat(1'b0),

        // DAQ link
        .daq_almost_full(daq_almost_full),
        .daq_ready(daq_ready),

        // TTC/TTS
        .tts_state(4'b1100),
        .ttc_chan_b_info(6'd0),
        .ttc_ready(ttc_ready_clk125),

        // FSM state
        .cm_state(34'd0),
        .ttr_state(4'd0),
        .ptr_state(4'd0),
        .cac_state(4'd0),
        .caca_state(4'd0),
        .tp_state(7'd0),

        // acquisition
        .acq_readout_pause(5'b0),
        .fill_type(5'd0),
        .chan_en(5'd0),
        .endianness_sel(1'b0),
        .acq_dones(5'd0),

        // trigger
        .trig_fifo_full(1'b0),
        .acq_fifo_full(1'b0),
        .trig_delay(32'd0),
        .trig_settings(3'd0),
        .trig_num(24'd0),
        .trig_timestamp(44'd0),
        .pulse_trig_num(24'd0),

        // slow control
        .i2c_temp(i2c_temp),
        .xadc_temp(xadc_temp),
        .xadc_vccint(xadc_vccint),
        .xadc_vccaux(xadc_vccaux),
        .xadc_vccbram(xadc_vccbram),

        .xadc_over_temp(xadc_over_temp),
        .xadc_alarm_temp(xadc_alarm_temp),
        .xadc_alarm_vccint(xadc_alarm_vccint),
        .xadc_alarm_vccaux(xadc_alarm_vccaux),
        .xadc_alarm_vccbram(xadc_alarm_vccbram),

        // DDR3
        .stored_bursts_chan0(23'd0),
        .stored_bursts_chan1(23'd0),
        .stored_bursts_chan2(23'd0),
        .stored_bursts_chan3(23'd0),
        .stored_bursts_chan4(23'd0),

        // status register outputs
        .status_reg00(status_reg00),
        .status_reg01(status_reg01),
        .status_reg02(status_reg02),
        .status_reg03(status_reg03),
        .status_reg04(status_reg04),
        .status_reg05(status_reg05),
        .status_reg06(status_reg06),
        .status_reg07(status_reg07),
        .status_reg08(status_reg08),
        .status_reg09(status_reg09),
        .status_reg10(status_reg10),
        .status_reg11(status_reg11),
        .status_reg12(status_reg12),
        .status_reg13(status_reg13),
        .status_reg14(status_reg14),
        .status_reg15(status_reg15),
        .status_reg16(status_reg16),
        .status_reg17(status_reg17),
        .status_reg18(status_reg18),
        .status_reg19(status_reg19),
        .status_reg20(status_reg20),
        .status_reg21(status_reg21),
        .status_reg22(status_reg22),
        .status_reg23(status_reg23),
        .status_reg24(status_reg24),
        .status_reg25(status_reg25),
        .status_reg26(status_reg26),
        .status_reg27(status_reg27),
        .status_reg28(status_reg28)
    );

    // DAQ Link to AMC13, version 0x10
    DAQ_LINK_Kintex #(
        .F_REFCLK(125),
        .SYSCLK_IN_period(8),
        .USE_TRIGGER_PORT(1'b0)
    ) daq (
        .reset(rst_from_ipb),

        .GTX_REFCLK(gtrefclk0),
        .GTX_RXN(daq_rx_N),
        .GTX_RXP(daq_rx),
        .GTX_TXN(daq_tx_N),
        .GTX_TXP(daq_tx),
        .SYSCLK_IN(clk125),

        .TTCclk(clk125),
        .BcntRes(rst_from_ipb),
        .trig(8'd0),

        .TTSclk(clk125),
        .TTS(4'b1100),

	    .ReSyncAndEmpty(1'b0),
        .EventDataClk(clk125),
        .EventData_valid(1'b0),
        .EventData_header(1'b0),
        .EventData_trailer(1'b0),
        .EventData(64'd0),
        .AlmostFull(daq_almost_full),
        .Ready(daq_ready)
    );

endmodule
