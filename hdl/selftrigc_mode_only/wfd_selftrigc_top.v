// Top-level module for Muon g-2 WFD5 Master FPGA
//
// As a useful reference, here's the syntax to mark signals for debug:
// 

module wfd_selftrigc_top (
    input  wire clkin,                // 50 MHz clock
    input  wire gtx_clk0, gtx_clk0_N, // Bank 115 125 MHz GTX Transceiver refclk
    //input  wire gtx_clk1, gtx_clk1_N, // Bank 116 125 MHz GTX Transceiver refclk
    output wire gige_tx,  gige_tx_N,  // Gigabit Ethernet TX
    input  wire gige_rx,  gige_rx_N,  // Gigabit Ethernet RX
    input  wire daq_rx,   daq_rx_N,   // AMC13 Link RX
    output wire daq_tx,   daq_tx_N,   // AMC13 Link TX
    input  wire c0_rx, c0_rx_N,       // Serial link to Channel 0 RX
    output wire c0_tx, c0_tx_N,       // Serial link to Channel 0 TX
    input  wire c1_rx, c1_rx_N,       // Serial link to Channel 1 RX
    output wire c1_tx, c1_tx_N,       // Serial link to Channel 1 TX
    input  wire c2_rx, c2_rx_N,       // Serial link to Channel 2 RX
    output wire c2_tx, c2_tx_N,       // Serial link to Channel 2 TX
    input  wire c3_rx, c3_rx_N,       // Serial link to Channel 3 RX
    output wire c3_tx, c3_tx_N,       // Serial link to Channel 3 TX
    input  wire c4_rx, c4_rx_N,       // Serial link to Channel 4 RX
    output wire c4_tx, c4_tx_N,       // Serial link to Channel 4 TX
    output wire [7:0] debug,          // debug header
    input  wire [4:0] acq_trigs,      // the channels' trigger lines: unused since 6.8.0 (the channels hold them low)
    input  wire [4:0] acq_dones,      // done signals from channel FPGAs
    output wire master_led0,          // front panel LEDs for master status, led0 is green
    output wire master_led1,          // front panel LEDs for master status, led1 is red
    output wire clksynth_led0,        // front panel LEDs for clk synth status, led0 is green
    output wire clksynth_led1,        // front panel LEDs for clk synth status, led1 is red
    inout  wire bbus_scl,             // I2C bus clock, connected to EEPROM Chip, Atmel Chip, Channel FPGAs
    inout  wire bbus_sda,             // I2C bus data,  connected to EEPROM Chip, Atmel Chip, Channel FPGAs
    input  wire ext_trig,             // front panel trigger
    input  wire [3:0] mmc_io,         // controls from the Atmel
    output wire [3:0] c0_io,          // utility signals to Channel 0
    output wire [3:0] c1_io,          // utility signals to Channel 1
    output wire [3:0] c2_io,          // utility signals to Channel 2
    output wire [3:0] c3_io,          // utility signals to Channel 3
    output wire [3:0] c4_io,          // utility signals to Channel 4
    output wire afe_dac_sclk,         // MB[0] on schematic, for AFE's DAC clock
    output wire afe_dac_sdi,          // MB[1] on schematic, for AFE's DAC data input
    output wire afe_dac_sync_n,       // MB[2] on schematic, for AFE's DAC \sync signal
    input  wire [5:3] mezzb,          // MB[5:3] on schematic, unused
    input  wire mmc_reset_m,          // reset line 
    input  wire adcclk_stat_ld,       // clock synth status, PLL lock detect
    input  wire adcclk_stat,          // clock synth status
    input  wire adcclk_clkin0_stat,   // clock synth status
    input  wire adcclk_clkin1_stat,   // clock synth status, uWire Readback
    output wire adcclk_sync,          //
    output wire adcclk_dlen,          //
    output wire adcclk_ddat,          //
    output wire adcclk_dclk,          //
    output wire ext_clk_sel0,         //
    output wire ext_clk_sel1,         //
    output wire daq_clk_sel,          //
    output wire daq_clk_en,           //
    input  wire ttc_clkp, ttc_clkn,   // TTC diff clock
    input  wire ttc_rxp,  ttc_rxn,    // data from TTC
    output wire ttc_txp,  ttc_txn,    // data to TTC
    input  wire [1:0] wfdps,          //
    output wire c_progb,              // to all channels for FPGA configuration
    output wire c_clk,                // to all channels for FPGA configuration
    output wire c_din,                // to all channels for FPGA configuration
    input  wire [4:0] initb,          // from each channel for FPGA configuration
    input  wire [4:0] prog_done,      // from each channel for FPGA configuration
    //input  wire test_point6,          // TP6 on schematic, unused
    input  wire spi_miso,             // serial data from SPI flash memory
    output wire spi_mosi,             // serial data (commands) to SPI flash memory
    output wire spi_ss,               // SPI flash memory chip select
    input  wire fp_sw_master          // front panel switch
);

    // ======== clock signals ========
    wire clk_10, clk10;   // 10 MHz clock for AFE DAC interface
    wire clk_50, clk_50b, clk50, clk50b;
    wire clk_125, clk125;
    wire clk200;          // 200 MHz, globally buffered
    wire clk_200;         // 200 MHz straight from the PLL (BUFG input only)
    wire clkfb;
    wire gtrefclk0;
    wire ttc_clk;         // 40 MHz output from TTC decoder module
    wire spi_clk;
    wire ttc_clk_x5;      // 200 MHz clock derived from ttc_clk
    wire ttc_clk_lock_200M;

    // now generate the clk and clk-bar using the PLL to avoid creating a LUT in the clock tree in reprog
    //    assign clk50 = clkin; // just to make the frequency explicit

    wire ipb_clk50_reset, clk50_reset, clk125_reset;
    wire prog_chan_done; // channels have been programmed signal

    // ======== operation mode signals ========
    wire async_mode_from_ipbus; // asynchronous mode select
    wire async_channels;
    wire async_mode_ttc_clk;
    wire async_mode_clk50;
    wire async_mode_clk125;
    // cbuf
    wire cbuf_mode_from_ipbus; // cbuf mode select
    wire cbuf_acquire;         // stream data from adc to circular buffer
    wire cbuf_channels;
    wire cbuf_mode_ttc_clk;
    wire cbuf_mode_clk50;
    wire cbuf_mode_clk125;
    wire cbuf_acquire_ttc_clk;
    wire selftrig_acquire;
    // self trigger (strg)
//    wire strg_mode_fixed; // self-triggering mode always selected for this image
    assign strg_mode_fixed = 1'b1;
    wire strg_channels;
    wire strg_mode_ttc_clk;
    wire strg_mode_clk50;
    wire strg_mode_clk125;

    wire [3:0] fp_trig_width_from_ipbus;
    wire [3:0] fp_trig_width;

    // IPbus overrides
    wire ipb_accept_self_triggers;
    wire ipb_async_trig_type;
    wire i2c_temp_polling_dis;
    wire i2c_temp_update;

    // ======== startup reset signals ========
    wire master_init_rst1_clk50, master_init_rst1_clk125;
    wire master_init_rst2_clk50, master_init_rst2_clk125;

    // synchronous reset logic for master
    startup_reset master_startup_reset1 (
        .clk50(clk50),                          // 50 MHz buffered clock
        .reset_clk50(master_init_rst1_clk50),   // active-high reset output, goes low after startup
        .clk125(clk125),                        // buffered clock, 125 MHz
        .reset_clk125(master_init_rst1_clk125), // active-high reset output, goes low after startup
        .hold(ipb_clk50_reset)                  // reset signal from reset
    );

    // starts the channel programming logic
    startup_reset master_startup_reset2 (
        .clk50(clk50),                          // 50 MHz buffered clock
        .reset_clk50(master_init_rst2_clk50),   // active-high reset output, goes low after startup
        .clk125(clk125),                        // buffered clock, 125 MHz
        .reset_clk125(master_init_rst2_clk125), // active-high reset output, goes low after startup
        .hold(clk50_reset)                      // reset signal from reset
    );

    // ======== error signals ========
    // thresholds
    wire [31:0] thres_data_corrupt;  // data corruption
    wire [31:0] thres_unknown_ttc;   // unknown TTC broadcast command
    wire [31:0] thres_ddr3_overflow; // DDR3 overflow

    // soft error counts
    wire [31:0] unknown_cmd_count;
    wire [31:0] cs_mismatch_count;

    // hard errors
    wire error_data_corrupt;
    wire error_trig_num_from_tt;
    wire error_trig_type_from_tt;
    wire error_trig_num_from_cm;
    wire error_trig_type_from_cm;
    wire error_pll_unlock;
    wire error_trig_rate;
    wire [7:0] triggers_downgraded;   // ttc_trigger_receiver: readout triggers answered with an empty event, TTC domain, status only
    wire [7:0] trig_num_error_count;  // command_manager: trigger-number mismatches (no longer terminal), status only
    // error capture (6.6.10)
    wire [15:0] err_loss_pulse;  wire [7:0] err_fault_pulse;  wire [5:0] err_warn_pulse;
    wire        cm_peeking;      // command manager in its header-first phase (6.7.0, status)
    wire [ 6:0] chan_err_word;   wire chan_err_valid;
    wire [31:0] last_rsn_word, last_rc_word, last_info1_word, last_info4_word;
    wire [ 8:0] cm_retry_status;
    wire        empty_midrun, cac_wait_gave_up;      // ttc_clk pulses
    wire        data_loss, hw_fault, err_warning;    // sticky
    wire [ 2:0] err_summary;
    wire        clear_errors;                        // control register bit 29
    wire [31:0] status_reg35, status_reg36, status_reg37, status_reg38, status_reg39, status_reg40, status_reg41, status_reg42, status_reg43, status_reg44, status_reg45, status_reg46, status_reg47, status_reg48, status_reg49;
    wire error_unknown_ttc;

    // warnings
    wire ddr3_almost_full;

    // throw error if either PLL is unlocked or if there is a loss-of-signal
    assign error_pll_unlock = ~adcclk_stat_ld | ~adcclk_stat | adcclk_clkin0_stat;

    wire [4:0] chan_error_sn; // master and channel serial number mismatch, one bit for each channel
    wire [4:0] chan_error_rc; // master received an error response code, one bit for each channel


    // ======== I/O lines to channel ========
    wire [4:0] acq_enable;
    wire [4:0] acq_enable_encoded;
    wire new_fill_pause_triggers;
    wire [4:0] acq_readout_pause;

    assign c0_io[0] = acq_readout_pause[0];
    assign c1_io[0] = acq_readout_pause[1];
    assign c2_io[0] = acq_readout_pause[2];
    assign c3_io[0] = acq_readout_pause[3];
    assign c4_io[0] = acq_readout_pause[4];

    assign c0_io[1] = acq_enable_encoded[0];
    assign c1_io[1] = acq_enable_encoded[1];
    assign c2_io[1] = acq_enable_encoded[2];
    assign c3_io[1] = acq_enable_encoded[3];
    assign c4_io[1] = acq_enable_encoded[4];

    assign c0_io[3] = new_fill_pause_triggers;
    assign c1_io[3] = new_fill_pause_triggers;
    assign c2_io[3] = new_fill_pause_triggers;
    assign c3_io[3] = new_fill_pause_triggers;
    assign c4_io[3] = new_fill_pause_triggers;

    // enable signals to channels
    wire [4:0] chan_en;


    // ++++++++ for self triggering, encode "enable triggering" and "enable acquisition" separately on the c?_io[1] lines +++++++++
    // OR of the five channel enables, registered in the TTC domain before it crosses into the
    // clk125 synchroniser inside acq_encode2: a combinational OR feeding a synchroniser can glitch
    // through it (report_cdc CDC-10)
    reg acq_enable_reduce = 1'b0;
    always @(posedge ttc_clk) acq_enable_reduce <= |acq_enable;
    wire event_readout_pending, readout_trigger_stretch;   // from selftriggerc_top, for the end-of-run readout
    wire self_triggering_enabled;
    wire channel_acq_enabled;
    wire clear_trigger_counts;
    reg  accept_self_triggers = 1'b0;   // registered in the TTC domain, see below
    wire [14:0] acq_encode2_state;
    acq_encode2 acq_encode2(
      // inputs
      .clk(clk125),
      .reset(clk125_reset),

      .chan_en(chan_en),

      .accept_self_triggers(accept_self_triggers),
      .channels_active(acq_enable_reduce),
      .event_readout_pending(event_readout_pending),
      .readout_trigger_seen(readout_trigger_stretch),

      .acq_enable_encoded(acq_enable_encoded),
      .self_triggering_enabled(self_triggering_enabled),
      .channel_acq_enabled(channel_acq_enabled),
      .clear_trigger_counts(clear_trigger_counts),
      .state_out(acq_encode2_state)
    );

    // Record what was driven on the five io[1] enable lines, for comparison with the channels'
    // own account of what they saw (channel registers 0x30 / 0x31): rising and falling edge
    // counts per line since the last reset (status registers 19 and 20).
    reg  [4:0] acq_enable_encoded_d = 5'd0;
    reg  [3:0] io1_rise_cnt [0:4];
    reg  [2:0] io1_fall_cnt [0:4];
    integer k;
    always @(posedge clk125) begin
        acq_enable_encoded_d <= acq_enable_encoded;
        for (k = 0; k < 5; k = k + 1) begin
            if (clk125_reset) begin
                io1_rise_cnt[k] <= 4'd0;
                io1_fall_cnt[k] <= 3'd0;
            end
            else begin
                if ( acq_enable_encoded[k] && !acq_enable_encoded_d[k]) io1_rise_cnt[k] <= io1_rise_cnt[k] + 1;
                if (!acq_enable_encoded[k] &&  acq_enable_encoded_d[k]) io1_fall_cnt[k] <= io1_fall_cnt[k] + 1;
            end
        end
    end
    wire [31:0] io1_status_a, io1_status_b;
    assign io1_status_a = {acq_enable_encoded[4:0], 7'd0,
                           io1_rise_cnt[4], io1_rise_cnt[3], io1_rise_cnt[2], io1_rise_cnt[1], io1_rise_cnt[0]};
    assign io1_status_b = {2'd0, acq_encode2_state[14:0],
                           io1_fall_cnt[4], io1_fall_cnt[3], io1_fall_cnt[2], io1_fall_cnt[1], io1_fall_cnt[0]};
    wire channel_acq_enabled_ttc;
    sync_2stage cae_ttc (
      .clk(ttc_clk),
      .in(channel_acq_enabled),
      .out(channel_acq_enabled_ttc)
    );
    // (6.7.x synchronised clear_trigger_counts into the 40 MHz domain for the trigger-line counters; it
    // now clears hdr_monitor_selftrigc, in the clk125 domain)



    // ======== pulse trigger FIFO ========
    wire pulse_fifo_tready;
    wire pulse_fifo_tvalid;
    wire [127:0] pulse_fifo_tdata;
    //wire [31:0] ext_pulse_delta_t;    // latched time between triggers in pulse_trigger_receiver
    //wire [31:0] ext_trig_delta_t;     // lated time between triggers seen in the raw trigger counting

    // ======== TTC signals ========
    wire ttc_ready;
    wire ttc_loopback;
    wire ttc_freq_rst;

    wire BCntRes;
    wire SinErrStr;
    wire DbErrStr;

    // ======== TTS signals ========
    wire [3:0] tts_state;


    // ======== front panel LED for master ========
    led_master_status led_master_status (
        //.clk(clk50),
        .red_led(master_led1),
        .green_led(master_led0),
        // status input signals
        .tts_state(tts_state)
    );

    // ======== front panel LED for clk synth ========
    led_clksynth_status led_clksynth_status (
        //.clk(clk50),
        .red_led(clksynth_led1),
        .green_led(clksynth_led0),
        // status input signals
        .adcclk_ld(adcclk_stat_ld),
        .adcclk_stat(adcclk_stat),
        .adcclk_clkin0_stat(adcclk_clkin0_stat)
    );

    // ======== derived clock =======
    clk_wiz_200M clk_wiz_trig_200M(
        .clk_in1(ttc_clk),
        .clk_out1(ttc_clk_x5),
        .locked(ttc_clk_lock_200M)
    );


    // ======== finite state machine states ========
    wire [ 3:0] ttr_state;
    wire [ 5:0] cac_state;
    wire [ 6:0] tp_state;
    wire [34:0] cm_state;

    // ======== TTC Channel B information signals ========
    wire [5:0] ttc_chan_b_info;
    wire ttc_evt_reset;
    wire ttc_chan_b_valid;
    wire rst_trigger_num;
    wire rst_trigger_timestamp;
    wire [4:0] ttc_fill_type;
    reg  [4:0] fill_type = 5'd0;        // registered in the TTC domain, see below
    wire ttc_accept_self_triggers;

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
        .CLKOUT1_DIVIDE(8),
        .CLKOUT2_DIVIDE(100),
        .CLKOUT3_DIVIDE(20),
        .CLKOUT4_DIVIDE(20),
        .CLKOUT4_PHASE(180)
    ) clk (
        .CLKIN1(clkin),
        .CLKOUT0(clk_200),
        .CLKOUT1(clk_125),
        .CLKOUT2(clk_10),
        .CLKOUT3(clk_50),
        .CLKOUT4(clk_50b),
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
    BUFG BUFG_clk10  (.I(clk_10 ), .O(clk10 ));
    BUFG BUFG_clk50  (.I(clk_50 ), .O(clk50 ));
    BUFG BUFG_clk50b (.I(clk_50b), .O(clk50b));
    // clk200 feeds the Gigabit Ethernet IP's 'independent_clock_bufg' input, which (as the name says)
    // must be a globally buffered clock.  Without this BUFG the PLL output was distributed to its ~300
    // loads over general routing: 2 ns of clock insertion delay with poor skew, which made the IP's
    // 200 MHz reset / synchroniser logic fail setup at the first routing pass on every build.
    BUFG BUFG_clk200 (.I(clk_200), .O(clk200));


    // ======== reset signals ========
    wire rst_from_ipb, rst_from_ipb_n;  // active-high reset from IPbus; synchronous to IPbus clock
    assign clk50_reset  = ipb_clk50_reset | master_init_rst1_clk50;
    assign clk125_reset = rst_from_ipb    | master_init_rst2_clk125;
    assign rst_from_ipb_n = ~rst_from_ipb;


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

    wire reset40;
    sync_2stage reset40_sync (
        .clk(ttc_clk),
        .in(ipb_rst_stretch),
        .out(reset40)
    );

    wire reset40_n;
    assign reset40_n = ~reset40;


     // Bring ipb_accept intp ttc clock domain. Assumption that signals are on / off for long periods
     wire ipb_accept_self_triggers_ttc;
     reg [1:0] sync_reg;
     (* ASYNC_REG = "TRUE" *) reg [1:0] sync_reg_slow;   // the actual clk125 -> ttc_clk synchroniser

     always @(posedge clk125 or posedge rst_from_ipb) begin
         if (rst_from_ipb) begin
             sync_reg <= 2'b0;
         end else begin
             sync_reg <= {sync_reg[0], ipb_accept_self_triggers};
         end
     end

    always @(posedge ttc_clk or posedge reset40) begin
        if (reset40) begin
            sync_reg_slow <= 2'b0;
        end else begin
            sync_reg_slow <= {sync_reg_slow[0], sync_reg[1]};   // two flops in series, not two parallel copies
        end
    end
    assign ipb_accept_self_triggers_ttc = sync_reg_slow[1];

    // ensure fill_type is in ttc clock domain.  It is configured and stable before running starts,
    // so we can simply sync it into this domain
    wire ipb_async_trig_type_sync;
    sync_2stage async_type_sync (
       .clk(ttc_clk),
       .in(ipb_async_trig_type),
       .out(ipb_async_trig_type_sync)
    );

    // Both are registered here so that the logic combining them sits behind a flop in the TTC
    // domain rather than directly in front of the clk125 synchronisers that sample them
    // (fill_type_sync, acq_encode2.sync_ast); one TTC clock of latency is immaterial.
    always @(posedge ttc_clk) begin
        fill_type[4:0]       <= (ipb_async_trig_type_sync) ? 5'b00100 : ttc_fill_type[4:0];
        accept_self_triggers <= ttc_accept_self_triggers | ipb_accept_self_triggers_ttc;
    end



    wire rst_trigger_num_stretch;
    signal_stretch event_reset_stretch (
        .signal_in(rst_trigger_num),
        .clk(ttc_clk),
        .n_extra_cycles(8'h02),
        .signal_out(rst_trigger_num_stretch) // 120 ns wide
    );

    // active-high reset signal to channels
    assign c0_io[2] = (ipb_rst_stretch | rst_trigger_num_stretch);
    assign c1_io[2] = (ipb_rst_stretch | rst_trigger_num_stretch);
    assign c2_io[2] = (ipb_rst_stretch | rst_trigger_num_stretch);
    assign c3_io[2] = (ipb_rst_stretch | rst_trigger_num_stretch);
    assign c4_io[2] = (ipb_rst_stretch | rst_trigger_num_stretch);


//  // for debugging
//  wire rst_trigger_num_125;
//  sync_2stage rtn_125_sync (
//     .clk(clk125),
//     .in(rst_trigger_num),
//     .out(rst_trigger_num_125)
//  );

    // connect a module that will read from the I2C temperature/memory chip.
    // since the MAC and IP address are used with IPbus, run the block with 'clk125'
    wire [47:0] i2c_mac_adr; // MAC address read from I2C EEPROM
    wire [31:0] i2c_ip_adr;  // IP address read from I2C EEPROM
    wire [11:0] i2c_temp;    // temperature reading from I2C EEPROM
    wire i2c_startup_done;

    wire bbus_scl_oen;
    wire bbus_sda_oen;

    i2c_top i2c_top (
      // inputs
      .clk(clk125),
      .reset(ip_addr_rst),                         // IPbus reset for reloading addresses from EEPROM
      .i2c_temp_polling_dis(i2c_temp_polling_dis), // disable temperature polling
      .i2c_temp_update(i2c_temp_update),           // update temperature value
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
      .sda_padoen_o(bbus_sda_oen)                   // enable signal for tri-state driver
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


    // ======== debug signals ========
//    assign debug[0] = test_point6;
//    assign debug[1] = bbus_sda;
    assign debug[2] = wfdps[1] & wfdps[0];
    assign debug[3] = mmc_io[3] & mmc_io[2] & mmc_io[1] & mmc_io[0];
//    assign debug[4] = spi_ss & spi_clk & spi_mosi & spi_miso;
//    assign debug[5] = initb[4] & initb[3] & initb[2] & initb[1] & initb[0];
    assign debug[6] = mmc_reset_m & mezzb[5] & mezzb[4] & mezzb[3];
//    assign debug[7] = prog_done[4] & prog_done[3] & prog_done[2] & prog_done[1] & prog_done[0];
      assign debug[0] = cs_mismatch_found;
      assign debug[1] = cs_mismatch_found;
//      assign debug[2] = cs_mismatch_found;
//      assign debug[3] = cs_mismatch_found;
      assign debug[4] = cs_mismatch_found;
      assign debug[5] = cs_mismatch_found;
//      assign debug[6] = cs_mismatch_found;
      assign debug[7] = cs_mismatch_found;

    
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


    wire [31:0] spi_data;
    wire send_write_command;
    wire read_bitstream;
    wire end_bitstream;
    wire end_write_command;
    wire prog_chan_in_progress;

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

    wire pc_to_flash_wbuf_en;
    wire [ 6:0] pc_to_flash_wbuf_addr;
    wire [31:0] pc_to_flash_wbuf_data;
    wire [11:0] pc_to_flash_wr_nBits;

    spi_flash_intf spi_flash_intf (
        .clk(clk50),
        .ipb_clk(clk125),
        .reset(clk50_reset),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_ss(spi_ss),
        .prog_chan_in_progress(prog_chan_in_progress),    // signal from prog_channels
        .read_bitstream(read_bitstream),                  // start signal from prog_channels
        .end_bitstream(end_bitstream),                    // done signal to prog_channels
        .ipb_flash_wr_nBytes(ipbus_to_flash_wr_nBytes),
        .ipb_flash_rd_nBytes(ipbus_to_flash_rd_nBytes),
        .ipb_flash_cmd_strobe(ipbus_to_flash_cmd_strobe),
        .ipb_rbuf_rd_en(ipbus_to_flash_rbuf_en),
        .ipb_rbuf_rd_addr(ipbus_to_flash_rbuf_addr),
        .ipb_rbuf_data_out(flash_rbuf_to_ipbus_data),
        .ipb_wbuf_wr_en(ipbus_to_flash_wbuf_en),
        .ipb_wbuf_wr_addr(ipbus_to_flash_wbuf_addr),
        .ipb_wbuf_data_in(ipbus_to_flash_wbuf_data),
        .pc_wbuf_wr_en(pc_to_flash_wbuf_en),              // from prog_channels
        .pc_wbuf_wr_addr(pc_to_flash_wbuf_addr[6:0]),     // from prog_channels
        .pc_wbuf_data_in(pc_to_flash_wbuf_data[31:0]),    // from prog_channels
        .send_write_command(send_write_command),          // start signal from prog_channels
        .end_write_command(end_write_command),            // done signal to prog_channels
        .pc_flash_wr_nBits(pc_to_flash_wr_nBits[11:0])    // from prog_channels
    );


    // ======== program channel FPGAs using bitstream stored on SPI flash memory ========

    wire prog_chan_start_from_ipbus; // in 125 MHz clock domain
    wire ipb_prog_chan_start;        // in 50 MHz clock domain 
                                     // don't have to worry about missing the faster signal -- stays high 
                                     // until you use IPbus to set it low again

    wire ipb_prog_chan_start_on;
    wire ipb_prog_chan_start_off;

    wire async_mode_on;
    wire async_mode_off;

    wire cbuf_mode_on;
    wire cbuf_mode_off;

    wire strg_mode_on;
    wire strg_mode_off;

    sync_2stage prog_chan_start_sync (
        .clk(clk50),
        .in(prog_chan_start_from_ipbus),
        .out(ipb_prog_chan_start)
    );

    edge_detect prog_chan_start_edge_detect (
        .clk(clk50),                      // clock
        .in(ipb_prog_chan_start),         // input signal
        .rising(ipb_prog_chan_start_on),  // rising edge detect
        .falling(ipb_prog_chan_start_off) // falling edge detect
    );

    // active-high, single-pulse signals for when asychronous mode changes
    edge_detect async_mode_edge_detect (
        .clk(clk50),             // clock
        .in(async_mode_clk50),   // input signal
        .rising(async_mode_on),  // rising edge detect
        .falling(async_mode_off) // falling edge detect
    );

    // active-high, single-pulse signals for when cbuf mode changes
    edge_detect cbuf_mode_edge_detect (
        .clk(clk50),             // clock
        .in(cbuf_mode_clk50),   // input signal
        .rising(cbuf_mode_on),  // rising edge detect
        .falling(cbuf_mode_off) // falling edge detect
    );

    // active-high, single-pulse signals for when self trigger mode changes
    edge_detect strg_mode_edge_detect (
        .clk(clk50),             // clock
        .in(strg_mode_clk50),   // input signal
        .rising(strg_mode_on),  // rising edge detect
        .falling(strg_mode_off) // falling edge detect
    );


    // combine IPbus and startup triggers
    // reprogram channels when: Master FPGA startup, IPbus configuration, asynchronous mode change
    wire prog_chan_start;
    assign prog_chan_start = master_init_rst2_clk50 | ipb_prog_chan_start_on | async_mode_on | async_mode_off | cbuf_mode_on | cbuf_mode_off;

    prog_channels prog_channels (
        .clk(clk50),
        .reset(clk50_reset),
        .async_mode(1'b0),                             // asynchronous mode enable -- not available in self triggering master
        .cbuf_mode(1'b0),                              // circular buffer mode enable -- not available in self triggering master
        .strg_mode(strg_mode_clk50),                   // self triggering  mode enable
        .prog_chan_start(prog_chan_start),             // start signal from IPbus
        .c_progb(c_progb),                             // configuration signal to all five channels
        .c_clk(c_clk),                                 // configuration clock to all five channels
        .c_din(c_din),                                 // configuration bitstream to all five channels
        .initb(initb),                                 // configuration signals from each channel
        .prog_done(prog_done),                         // configuration signals from each channel
        .bitstream(spi_miso),                          // bitstream from flash memory
        .prog_chan_in_progress(prog_chan_in_progress), // signal to spi_flash_intf
        .store_flash_command(pc_to_flash_wbuf_en),     // signal to spi_flash_intf
        .wbuf_address(pc_to_flash_wbuf_addr[6:0]),     // signal to spi_flash_intf
        .flash_command(pc_to_flash_wbuf_data[31:0]),   // signal to spi_flash_intf
        .flash_wr_nBits(pc_to_flash_wr_nBits[11:0]),   // signal to spi_flash_intf
        .send_write_command(send_write_command),       // start signal to spi_flash_intf
        .read_bitstream(read_bitstream),               // start signal to spi_flash_intf
        .end_write_command(end_write_command),         // done signal from spi_flash_intf
        .end_bitstream(end_bitstream),                 // done signal from spi_flash_intf
        .prog_chan_done(prog_chan_done),               // done programming the channels
        .async_channels(async_channels),               // flag for if the channels are sync or async
        .cbuf_channels(cbuf_channels),                  // flag for circular buffer or patterns in sync mode
        .strg_channels(strg_channels)                  // flag for self triggering mode
    );


    // ======== module to reprogram FPGA from flash ========

    wire [2:0] reprog_trigger_from_ipbus; // in 125 MHz clock domain
    wire [2:0] reprog_trigger;            // in 50 MHz clock domain
                                          // don't have to worry about missing the faster signal
                                          // (stays high until you use ipbus to set it low again)
    wire [2:0] reprog_trigger_delayed;    // after passing through 32-bit shift register
                                          // (to allow time for IPbus ack before reprogramming FPGA)
                                          // 01 -> 001 = GOLDEN
                                          // 10 -> 010 = MASTER (standard)
                                          // 01 -> 100 = Self Trigger Master

    sync_2stage #(
        .WIDTH(3)
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

    SRLC32E #(
        .INIT(32'h00000000) // Initial value of shift register
    ) SRLC32E_inst2 (
        .Q(reprog_trigger_delayed[2]), // SRL data output
        .Q31(),                        // SRL cascade output pin
        .A(5'b11111),                  // 5-bit shift depth select input (5'b11111 = 32-bit shift)
        .CE(1'b1),                     // Clock enable input
        .CLK(clk50),                   // Clock input
        .D(reprog_trigger[2])          // SRL data input
    );

    // image selection: the IPbus request (delayed above) and the raw front panel switch both go to
    // 'reprog', which synchronises and debounces the switch, holds off after configuration and
    // qualifies every request before issuing the IPROG

    wire reprog_done;
    reprog reprog (
        .clk(clk50),
        .clkb(clk50b),
        .reset(clk50_reset),
        .ipbus_trigger(reprog_trigger_delayed),
        .fp_sw_master(fp_sw_master),
        .reprog_done(reprog_done)
    );
   

    // ======== operation modes ========

    // for the self triggering mode, there is only one operational mode -- self triggering
    // for use in prog_channels
    sync_2stage async_mode_clk50_module (
        .clk(clk50),
        .in(async_mode_from_ipbus),
        .out(async_mode_clk50)
    );
    sync_2stage cbuf_mode_clk50_module (
        .clk(clk50),
        .in(cbuf_mode_from_ipbus),
        .out(cbuf_mode_clk50)
    );
    sync_2stage strg_mode_clk50_module (
        .clk(clk50),
        .in(strg_mode_fixed),
        .out(strg_mode_clk50)
    );


//    // for use in trigger_top
//    sync_2stage async_mode_ttc_clk_module (
//        .clk(ttc_clk),
//        .in(async_channels),
//        .out(async_mode_ttc_clk)
//    );
//    sync_2stage cbuf_mode_ttc_clk_module (
//        .clk(ttc_clk),
//        .in(cbuf_channels),
//        .out(cbuf_mode_ttc_clk)
//    );
//    sync_2stage cbuf_acquire_ttc_clk_module (
//        .clk(ttc_clk),
//        .in(cbuf_acquire),
//        .out(cbuf_acquire_ttc_clk)
//    );


    // for use in ipbus_top, status_reg_block, and command_manager
    // -- asyncMods: in ipbus, forces mode type.  Needs review for what happens for front panel vs ttc ring buffering
    //                 in status_reg_block, flags asynch mode.  Also needs review: flags front panel trigs or type of channel image?
    //                 in Command Manage: i) affects burst counting for readout -- needs to refer explicitly to front panel triggering!
    //                                   ii) in a related action, affects the async_readout_done flag, presumably
    //                                       associated with the TTC readout trigger of front panel triggers.
    sync_2stage async_mode_clk125_module (
        .clk(clk125),
        .in(async_channels),
        .out(async_mode_clk125)
    );
    sync_2stage cbuf_mode_clk125_module (
        .clk(clk125),
        .in(cbuf_channels),
        .out(cbuf_mode_clk125)
    );
    sync_2stage strg_mode_clk125_module (
        .clk(clk125),
        .in(strg_channels),
        .out(strg_mode_clk125)
    );

//    // for use in trigger_top
//    sync_2stage #(
//        .WIDTH(4)
//    ) fp_trig_width_ttc_clk_module (
//        .clk(ttc_clk),
//        .in(fp_trig_width_from_ipbus),
//        .out(fp_trig_width)
//    );


    // ======== triggers and data transfer ========

    // TTC trigger in 40 MHz TTC clock domain
    wire trigger_from_ttc;
    wire trigger_from_decoder;

    // tie decoder trigger with ready signal
    // meant to prevent spurious triggers due to clock changes
    assign trigger_from_ttc = trigger_from_decoder & ttc_ready;

    // put other trigger signals into 40 MHz TTC clock domain
    wire ext_trig_stretch;
    wire ext_trig_sync;
    wire ext_trig_pulse_en;

    signal_stretch ext_trig_stretch_module (
        .signal_in(ext_trig),
        .clk(clk125),
        .n_extra_cycles(8'h04),
        .signal_out(ext_trig_stretch)
    );
    
    sync_2stage ext_trig_sync_module (
        .clk(ttc_clk),
        .in(ext_trig_stretch),
        .out(ext_trig_sync)
    );

    // rgw

    (* ASYNC_REG = "TRUE" *) reg ext_trig_pulse_sync1, ext_trig_pulse_sync2, ext_trig_pulse_sync3;
    reg ext_trig_pulse;

    // level-to-pulse converter
    always @(posedge ttc_clk) begin
        ext_trig_pulse_sync1 <= ext_trig;
        ext_trig_pulse_sync2 <= ext_trig_pulse_sync1;
        ext_trig_pulse_sync3 <= ext_trig_pulse_sync2;

        // make single period pulse
        ext_trig_pulse <= ext_trig_pulse_sync2 & ~ext_trig_pulse_sync3;
    end

    wire ext_trig_to_trigger_top;
    assign ext_trig_to_trigger_top = (ext_trig_pulse_en) ? ext_trig_pulse : ext_trig_sync;


    // select bit for the endianness of ADC data
    //   0 = big-endian (default)
    //   1 = little-endian
    wire endianness_sel;

    // delay between receiving the trigger and passing it onto the channels                                                                                                                                                   
    wire [31:0] trig_delay;


    // ======== wires for interface to channel serial link ========

    // user IPbus interface. Used by the Aurora block.
    wire [31:0] user_ipb_addr, user_ipb_wdata, user_ipb_rdata;
    wire user_ipb_clk, user_ipb_strobe, user_ipb_write, user_ipb_ack;


    ///////////////////////////////////////////////////////////////////////////
    // AXI4-Stream interface for communicating with serial link to channel FPGA
    // Channel 0
    wire c0_axi_stream_to_cm_tvalid, c0_axi_stream_to_cm_tlast, c0_axi_stream_to_cm_tready;
    wire [0:31] c0_axi_stream_to_cm_tdata;

    wire c0_axi_stream_to_channel_tvalid, c0_axi_stream_to_channel_tlast, c0_axi_stream_to_channel_tready;
    wire [0:31] c0_axi_stream_to_channel_tdata;
    wire [0: 3] c0_axi_stream_to_channel_tdest;

    // Channel 1
    wire c1_axi_stream_to_cm_tvalid, c1_axi_stream_to_cm_tlast, c1_axi_stream_to_cm_tready;
    wire [0:31] c1_axi_stream_to_cm_tdata;

    wire c1_axi_stream_to_channel_tvalid, c1_axi_stream_to_channel_tlast, c1_axi_stream_to_channel_tready;
    wire [0:31] c1_axi_stream_to_channel_tdata;
    wire [0: 3] c1_axi_stream_to_channel_tdest;

    // Channel 2
    wire c2_axi_stream_to_cm_tvalid, c2_axi_stream_to_cm_tlast, c2_axi_stream_to_cm_tready;
    wire [0:31] c2_axi_stream_to_cm_tdata;

    wire c2_axi_stream_to_channel_tvalid, c2_axi_stream_to_channel_tlast, c2_axi_stream_to_channel_tready;
    wire [0:31] c2_axi_stream_to_channel_tdata;
    wire [0: 3] c2_axi_stream_to_channel_tdest;

    // Channel 3
    wire c3_axi_stream_to_cm_tvalid, c3_axi_stream_to_cm_tlast, c3_axi_stream_to_cm_tready;
    wire [0:31] c3_axi_stream_to_cm_tdata;

    wire c3_axi_stream_to_channel_tvalid, c3_axi_stream_to_channel_tlast, c3_axi_stream_to_channel_tready;
    wire [0:31] c3_axi_stream_to_channel_tdata;
    wire [0: 3] c3_axi_stream_to_channel_tdest;

    // Channel 4
    wire c4_axi_stream_to_cm_tvalid, c4_axi_stream_to_cm_tlast, c4_axi_stream_to_cm_tready;
    wire [0:31] c4_axi_stream_to_cm_tdata;

    wire c4_axi_stream_to_channel_tvalid, c4_axi_stream_to_channel_tlast, c4_axi_stream_to_channel_tready;
    wire [0:31] c4_axi_stream_to_channel_tdata;
    wire [0: 3] c4_axi_stream_to_channel_tdest;


    ////////////////////////////////////////////////////////////////
    // packaged up channel connections for the AXIS TX Switch output
    wire [  4:0] c_axi_stream_to_channel_tvalid, c_axi_stream_to_channel_tlast, c_axi_stream_to_channel_tready;
    wire [ 19:0] c_axi_stream_to_channel_tdest;
    wire [159:0] c_axi_stream_to_channel_tdata;

    assign c0_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[0];
    assign c1_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[1];
    assign c2_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[2];
    assign c3_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[3];
    assign c4_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[4];

    assign c0_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[0];
    assign c1_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[1];
    assign c2_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[2];
    assign c3_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[3];
    assign c4_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[4];

    assign c_axi_stream_to_channel_tready[0] = c0_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[1] = c1_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[2] = c2_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[3] = c3_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[4] = c4_axi_stream_to_channel_tready;

    assign c0_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[ 31:  0];
    assign c1_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[ 63: 32];
    assign c2_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[ 95: 64];
    assign c3_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[127: 96];
    assign c4_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[159:128];

    assign c0_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[ 3: 0];
    assign c1_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[ 7: 4];
    assign c2_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[11: 8];
    assign c3_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[15:12];
    assign c4_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[19:16];

    // connections from command manager to AXIS TX Switch
    wire axi_stream_to_channel_from_cm_tvalid, axi_stream_to_channel_from_cm_tlast, axi_stream_to_channel_from_cm_tready;
    wire [0:31] axi_stream_to_channel_from_cm_tdata;
    wire [0: 3] axi_stream_to_channel_from_cm_tdest;


    ///////////////////////////////////////////////////////////////
    // packaged up channel connections for the AXIS RX Switch input
    wire [  4:0] c_axi_stream_to_cm_tvalid, c_axi_stream_to_cm_tlast, c_axi_stream_to_cm_tready;
    wire [159:0] c_axi_stream_to_cm_tdata;

    assign c_axi_stream_to_cm_tvalid[0] = c0_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[1] = c1_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[2] = c2_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[3] = c3_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[4] = c4_axi_stream_to_cm_tvalid;

    assign c_axi_stream_to_cm_tlast[0] = c0_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[1] = c1_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[2] = c2_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[3] = c3_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[4] = c4_axi_stream_to_cm_tlast;

    assign c0_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[0];
    assign c1_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[1];
    assign c2_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[2];
    assign c3_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[3];
    assign c4_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[4];

    assign c_axi_stream_to_cm_tdata[ 31:  0] = c0_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[ 63: 32] = c1_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[ 95: 64] = c2_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[127: 96] = c3_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[159:128] = c4_axi_stream_to_cm_tdata;

    // connections from AXIS RX Switch to command manager
    wire axi_stream_to_cm_from_channel_tvalid, axi_stream_to_cm_from_channel_tlast, axi_stream_to_cm_from_channel_tready;
    wire [0:31] axi_stream_to_cm_from_channel_tdata;


    //////////////////////////////////////////////////
    // IPbus and command manager interface connections
    // connections from command manager to IPbus
    wire axi_stream_to_ipbus_from_cm_tvalid, axi_stream_to_ipbus_from_cm_tlast, axi_stream_to_ipbus_from_cm_tready;
    wire [0:31] axi_stream_to_ipbus_from_cm_tdata;

    // connections from IPbus to command manager
    wire axi_stream_to_cm_from_ipbus_tvalid, axi_stream_to_cm_from_ipbus_tlast, axi_stream_to_cm_from_ipbus_tready;
    wire [0:31] axi_stream_to_cm_from_ipbus_tdata;
    wire [0: 3] axi_stream_to_cm_from_ipbus_tdest;


    ////////////////////////////////////////////////////////
    // trigger top and command manager interface connections
    wire readout_ready, readout_done;
    wire send_empty_event;
    wire skip_payload;
    wire initiate_readout;

    wire [22:0] burst_count_chan0, burst_count_chan1, burst_count_chan2, burst_count_chan3, burst_count_chan4;
    wire [11:0] wfm_count_chan0, wfm_count_chan1, wfm_count_chan2, wfm_count_chan3, wfm_count_chan4;
    wire [22:0] readout_size_chan0, readout_size_chan1, readout_size_chan2, readout_size_chan3, readout_size_chan4;


    // ======== communication with the AMC13 DAQ link ========
    wire daq_header, daq_trailer;
    wire daq_valid, daq_ready;
    wire daq_almost_full;
    wire [63:0] daq_data;
    
    // ======== status register signals ========
    wire [31:0] status_reg00, status_reg01, status_reg02, status_reg03, status_reg04, 
                status_reg05, status_reg06, status_reg07, status_reg08, status_reg09,
                status_reg10, status_reg11, status_reg12, status_reg13, status_reg14,
                status_reg15, status_reg16, status_reg17, status_reg18, status_reg19,
                status_reg20, status_reg21, status_reg22, status_reg23, status_reg24,
                status_reg25, status_reg26, status_reg27, status_reg28, status_reg29,
                status_reg30, status_reg31, status_reg32, status_reg33, status_reg34;

    // ======== trigger information signals ========
    wire [ 2:0] trig_settings;
    wire [23:0] ttc_event_num;
    wire [23:0] ttc_trig_num;
    wire [ 4:0] ttc_trig_type;
    wire [43:0] ttc_trig_timestamp;
    wire [ 3:0] ttc_xadc_alarms;
    wire [23:0] trig_num;
    wire [43:0] trig_timestamp;
//    wire [23:0] pulse_trig_num;
//    wire [23:0] pulse_trigs_last_readout;
//    wire [31:0] raw_ext_trigger_count;
//    wire [31:0] accepted_ext_trigger_count;

    // ======== FIFO signals ========
    wire trig_fifo_full;
    wire pulse_fifo_full;
    wire acq_fifo_full;

    
    // ======== module instantiations ========

    wire [4:0] ttc_data_delay;
    wire       ttc_ddelay_rdy;
    // TTC decoder module
    TTC_decoder_ddelay ttc (
        .TTC_CLK_p(ttc_clkp),            // in  STD_LOGIC
        .TTC_CLK_n(ttc_clkn),            // in  STD_LOGIC
        .TTC_rst(ttc_freq_rst),          // in  STD_LOGIC -- asynchronous reset after TTC_CLK_p/TTC_CLK_n frequency changed
        .TTC_data_p(ttc_rxp),            // in  STD_LOGIC
        .TTC_data_n(ttc_rxn),            // in  STD_LOGIC
        .TTC_CLK_out(ttc_clk),           // out STD_LOGIC
        .TTCready(ttc_ready),            // out STD_LOGIC
        .L1Accept(trigger_from_decoder), // out STD_LOGIC
        .BCntRes(BCntRes),               // out STD_LOGIC
        .EvCntRes(ttc_evt_reset),        // out STD_LOGIC
        .SinErrStr(SinErrStr),           // out STD_LOGIC
        .DbErrStr(DbErrStr),             // out STD_LOGIC
        .BrcstStr(ttc_chan_b_valid),     // out STD_LOGIC
        .Brcst(ttc_chan_b_info),         // out STD_LOGIC_VECTOR(7 DOWNTO 2)
        .TTC_CLK_ddelay(ttc_clk_x5),     // in  clock for IDELAYE2 for data
        .delay_count(ttc_data_delay),    // out amount that ttc data gets delayed
        .delay_rdy(ttc_ddelay_rdy)       // out delay unit ready for data delay
    );


    // TTC Channel B information receiver
    ttc_broadcast_receiver chanb (
        .clk(ttc_clk),
        .reset(reset40),

        // TTC Channel B information
        .chan_b_info(ttc_chan_b_info),
        .accept_pulse_triggers(ttc_accept_self_triggers),
        .evt_count_reset(ttc_evt_reset),
        .chan_b_valid(ttc_chan_b_valid),
        .ttc_loopback(ttc_loopback),

        // outputs to trigger logic
        .fill_type(ttc_fill_type[4:0]),
        .reset_trig_num(rst_trigger_num),
        .reset_trig_timestamp(rst_trigger_timestamp),

        // status information
        .thres_unknown_ttc(thres_unknown_ttc), // threshold for unknown TTC broadcast command instances
        .unknown_cmd_count(unknown_cmd_count), // number of unknown TTC broadcast commands
        .error_unknown_ttc(error_unknown_ttc)  // hard error flag for unknown TTC broadcast commands
    );


    // 6.7.3: 1 = build in the Ethernet / IPbus debug VIO (read over JTAG when the board goes deaf);
    // needs the vio_eth IP and constraints/debug/debug_vio.xdc in the project (scripts/add_debug_vio.tcl).
    // Set to 0 for a release build (and remove those two files from the project).
    localparam DEBUG_ETH_VIO = 1;

    // IPbus top module
    ipbus_top #(.DEBUG_VIO(DEBUG_ETH_VIO)) ipb (
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
        .user_ipb_clk(user_ipb_clk),           // programming clock
        .user_ipb_strobe(user_ipb_strobe),     // this ipb space is selected for an I/O operation
        .user_ipb_addr(user_ipb_addr[31:0]),   // slave address, memory or register
        .user_ipb_write(user_ipb_write),       // this is a write operation
        .user_ipb_wdata(user_ipb_wdata[31:0]), // data to write for write operations
        .user_ipb_rdata(user_ipb_rdata[31:0]), // data returned for read operations
        .user_ipb_ack(user_ipb_ack),           // 'write' data has been stored, 'read' data is ready
        .user_ipb_err(1'b0),                   // '1' if error, '0' if OK? We never generate an error!

        // data interface to channel serial link
        // connections from IPbus to command manager
        .axi_stream_out_tvalid(axi_stream_to_cm_from_ipbus_tvalid),
        .axi_stream_out_tdata(axi_stream_to_cm_from_ipbus_tdata[0:31]),
        .axi_stream_out_tlast(axi_stream_to_cm_from_ipbus_tlast),
        .axi_stream_out_tdest(axi_stream_to_cm_from_ipbus_tdest),
        .axi_stream_out_tready(axi_stream_to_cm_from_ipbus_tready),
        .axi_stream_out_tstrb(),
        .axi_stream_out_tkeep(),
        .axi_stream_out_tid(),

        // connections from command manager to IPbus
        .axi_stream_in_tvalid(axi_stream_to_ipbus_from_cm_tvalid),
        .axi_stream_in_tdata(axi_stream_to_ipbus_from_cm_tdata),
        .axi_stream_in_tready(axi_stream_to_ipbus_from_cm_tready),
        .axi_stream_in_tstrb(4'h0),
        .axi_stream_in_tkeep(4'h0),
        .axi_stream_in_tlast(1'b0),
        .axi_stream_in_tid(4'h0),
        .axi_stream_in_tdest(4'h0),

        // control signals
        .async_mode_in(async_mode_clk125),                 // set asychronous mode in channels
        .async_mode_out(async_mode_from_ipbus),            // asynchronous mode select
        .accept_pulse_trig_out(ipb_accept_self_triggers),  // allow front panel triggers (for testing)
        .async_trig_type_out(ipb_async_trig_type),         // fix TTC trigger type to be asynchronous readout (for testing)
        .cbuf_mode_in(cbuf_mode_clk125),                   // circular buffer mode is set in channels
        .cbuf_mode_out(cbuf_mode_from_ipbus),              // circular buffer mode select
        .cbuf_acquire(cbuf_acquire),                       // stream adc data to circular buffer
        .selftrig_acquire(selftrig_acquire),               // stream self-triggered adc data to circular buffer
        .strg_mode_in(strg_mode_clk125),                   // self triggering mode is set in channels
        .chan_en_out(chan_en),                             // channel enable to command manager
        .prog_chan_out(prog_chan_start_from_ipbus),        // signal to start programming sequence for channel FPGAs
        .reprog_trigger_out(reprog_trigger_from_ipbus),    // signal to issue IPROG command to re-program FPGA from flash
        .trig_delay_out(trig_delay[31:0]),                 // set trigger delay in the trigger manager
        .endianness_out(endianness_sel),                   // select signal for the ADC data's endianness
        .trig_settings_out(trig_settings),                 // select which trigger types are enabled
        .ttc_loopback_out(ttc_loopback),                   // select whether TTC/TTS is in loopback mode (for testing)
        .ext_trig_pulse_en_out(ext_trig_pulse_en),         // convert front panel triggers to single pulse triggers (for testing)
        .ttc_freq_rst_out(ttc_freq_rst),                   // dedicated reset to TTC decoder for frequency changes
        .i2c_temp_polling_dis_out(i2c_temp_polling_dis),   // disable EEPROM temperature polling
        .i2c_temp_update_out(i2c_temp_update),             // read and update EEPROM temperature value
        .clear_errors_out(clear_errors),                   // clear the error capture (6.6.10)
        .fp_trig_width_out(fp_trig_width_from_ipbus[3:0]), // width to separate short from long front panel triggers

        // threshold registers
        .thres_data_corrupt(thres_data_corrupt),   // data corruption
        .thres_unknown_ttc(thres_unknown_ttc),     // unknown TTC broadcast command
        .thres_ddr3_overflow(thres_ddr3_overflow), // DDR3 overflow

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
        .status_reg29(status_reg29),
        .status_reg30(status_reg30),
        .status_reg31(status_reg31),
        .status_reg32(status_reg32),
        .status_reg33(status_reg33),
        .status_reg34(status_reg34),
        .status_reg35(status_reg35),
        .status_reg36(status_reg36),
        .status_reg37(status_reg37),
        .status_reg38(status_reg38),
        .status_reg39(status_reg39),
        .status_reg40(status_reg40),
        .status_reg41(status_reg41),
        .status_reg42(status_reg42),
        .status_reg43(status_reg43),
        .status_reg44(status_reg44),
        .status_reg45(status_reg45),
        .status_reg46(status_reg46),
        .status_reg47(status_reg47),
        .status_reg48(status_reg48),
        .status_reg49(status_reg49),

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

 
    // Serial links to channel FPGAs
    all_channels channels (
        .clk50(clk50),
        .clk50_reset(clk50_reset),
        .axis_clk(clk125),
        .axis_clk_resetN(rst_from_ipb_n),
        .gt_refclk(gtrefclk0),
        .clk10(clk10),

        // IPbus inputs
        .ipb_clk(user_ipb_clk),            // programming clock
        .ipb_reset(rst_from_ipb),
        .ipb_clk50_reset(ipb_clk50_reset),
        .ipb_strobe(user_ipb_strobe),      // this ipb space is selected for an I/O operation
        .ipb_addr(user_ipb_addr[23:0]),    // slave address(), memory or register
        .ipb_write(user_ipb_write),        // this is a write operation
        .ipb_wdata(user_ipb_wdata[31:0]),  // data to write for write operations
        // IPbus outputs
        .ipb_rdata(user_ipb_rdata[31:0]),  // data returned for read operations
        .ipb_ack(user_ipb_ack),            // 'write' data has been stored(), 'read' data is ready

        // channel 0 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c0_s_axi_tx_tdata(c0_axi_stream_to_channel_tdata),   // note index order
        .c0_s_axi_tx_tkeep(4'b0000),                          // note index order
        .c0_s_axi_tx_tvalid(c0_axi_stream_to_channel_tvalid),
        .c0_s_axi_tx_tlast(c0_axi_stream_to_channel_tlast),
        .c0_s_axi_tx_tready(c0_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c0_m_axi_rx_tdata(c0_axi_stream_to_cm_tdata),        // note index order
        .c0_m_axi_rx_tkeep(),                                 // note index order
        .c0_m_axi_rx_tvalid(c0_axi_stream_to_cm_tvalid),
        .c0_m_axi_rx_tlast(c0_axi_stream_to_cm_tlast),
        .c0_m_axi_rx_tready(c0_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                     // receive from channel 0 FPGA
        .c0_txp(c0_tx), .c0_txn(c0_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c0_readout_pause(acq_readout_pause[0]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // channel 1 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c1_s_axi_tx_tdata(c1_axi_stream_to_channel_tdata),   // note index order
        .c1_s_axi_tx_tkeep(4'b0000),                          // note index order
        .c1_s_axi_tx_tvalid(c1_axi_stream_to_channel_tvalid),
        .c1_s_axi_tx_tlast(c1_axi_stream_to_channel_tlast),
        .c1_s_axi_tx_tready(c1_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c1_m_axi_rx_tdata(c1_axi_stream_to_cm_tdata),        // note index order
        .c1_m_axi_rx_tkeep(),                                 // note index order
        .c1_m_axi_rx_tvalid(c1_axi_stream_to_cm_tvalid),
        .c1_m_axi_rx_tlast(c1_axi_stream_to_cm_tlast),
        .c1_m_axi_rx_tready(c1_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c1_rxp(c1_rx), .c1_rxn(c1_rx_N),                     // receive from channel 0 FPGA
        .c1_txp(c1_tx), .c1_txn(c1_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c1_readout_pause(acq_readout_pause[1]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // channel 2 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c2_s_axi_tx_tdata(c2_axi_stream_to_channel_tdata),   // note index order
        .c2_s_axi_tx_tkeep(4'b0000),                          // note index order
        .c2_s_axi_tx_tvalid(c2_axi_stream_to_channel_tvalid),
        .c2_s_axi_tx_tlast(c2_axi_stream_to_channel_tlast),
        .c2_s_axi_tx_tready(c2_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c2_m_axi_rx_tdata(c2_axi_stream_to_cm_tdata),        // note index order
        .c2_m_axi_rx_tkeep(),                                 // note index order
        .c2_m_axi_rx_tvalid(c2_axi_stream_to_cm_tvalid),
        .c2_m_axi_rx_tlast(c2_axi_stream_to_cm_tlast),
        .c2_m_axi_rx_tready(c2_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c2_rxp(c2_rx), .c2_rxn(c2_rx_N),                     // receive from channel 0 FPGA
        .c2_txp(c2_tx), .c2_txn(c2_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c2_readout_pause(acq_readout_pause[2]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // channel 3 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c3_s_axi_tx_tdata(c3_axi_stream_to_channel_tdata),   // note index order
        .c3_s_axi_tx_tkeep(4'b0000),                          // note index order
        .c3_s_axi_tx_tvalid(c3_axi_stream_to_channel_tvalid),
        .c3_s_axi_tx_tlast(c3_axi_stream_to_channel_tlast),
        .c3_s_axi_tx_tready(c3_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c3_m_axi_rx_tdata(c3_axi_stream_to_cm_tdata),        // note index order
        .c3_m_axi_rx_tkeep(),                                 // note index order
        .c3_m_axi_rx_tvalid(c3_axi_stream_to_cm_tvalid),
        .c3_m_axi_rx_tlast(c3_axi_stream_to_cm_tlast),
        .c3_m_axi_rx_tready(c3_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c3_rxp(c3_rx), .c3_rxn(c3_rx_N),                     // receive from channel 0 FPGA
        .c3_txp(c3_tx), .c3_txn(c3_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c3_readout_pause(acq_readout_pause[3]),              // readout pause signal asserted when the Aurora RX FIFO is almost full
 
        // channel 4 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c4_s_axi_tx_tdata(c4_axi_stream_to_channel_tdata),   // note index order
        .c4_s_axi_tx_tkeep(4'b0000),                          // note index order
        .c4_s_axi_tx_tvalid(c4_axi_stream_to_channel_tvalid),
        .c4_s_axi_tx_tlast(c4_axi_stream_to_channel_tlast),
        .c4_s_axi_tx_tready(c4_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c4_m_axi_rx_tdata(c4_axi_stream_to_cm_tdata),        // note index order
        .c4_m_axi_rx_tkeep(),                                 // note index order
        .c4_m_axi_rx_tvalid(c4_axi_stream_to_cm_tvalid),
        .c4_m_axi_rx_tlast(c4_axi_stream_to_cm_tlast),
        .c4_m_axi_rx_tready(c4_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c4_rxp(c4_rx), .c4_rxn(c4_rx_N),                     // receive from channel 0 FPGA
        .c4_txp(c4_tx), .c4_txn(c4_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c4_readout_pause(acq_readout_pause[4]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // clock synthesizer connections
        .adcclk_dclk(adcclk_dclk),
        .adcclk_ddat(adcclk_ddat),
        .adcclk_dlen(adcclk_dlen),
        .adcclk_sync(adcclk_sync),
        .adcclk_rdbk(adcclk_clkin1_stat),

        // analog front-end DAC connections
        .afe_dac_sclk(afe_dac_sclk),
        .afe_dac_sdi(afe_dac_sdi),
        .afe_dac_sync_n(afe_dac_sync_n),

        // debug outputs
        .debug()
    );

    // =====================================================================================
    // synchronize signals into 125 MHz clock domain for use in status register block module 
    // =====================================================================================

    // synchronize ttc_ready
    wire ttc_ready_clk125;
    sync_2stage ttc_ready_sync (
        .clk(clk125),
        .in(ttc_ready),
        .out(ttc_ready_clk125)
    );

    // synchronize ttc_chan_b_info
    wire [5:0] ttc_chan_b_info_clk125;
    sync_2stage #(
        .WIDTH(6)
    ) ttc_chan_b_info_sync (
        .clk(clk125),
        .in(ttc_chan_b_info),
        .out(ttc_chan_b_info_clk125)
    );

    // synchronize ttr_state
    wire [3:0] ttr_state_clk125;
    sync_2stage #(
        .WIDTH(4)
    ) ttr_state_sync (
        .clk(clk125),
        .in(ttr_state),
        .out(ttr_state_clk125)
    );

    // the channel trigger receivers' states (status register 7) read 0 since 6.8.0: no receivers
    wire [1:0] ctr_state_chan0_clk125 = 2'd0, ctr_state_chan1_clk125 = 2'd0, ctr_state_chan2_clk125 = 2'd0,
               ctr_state_chan3_clk125 = 2'd0, ctr_state_chan4_clk125 = 2'd0;

    // synchronize cac_state
    wire [5:0] cac_state_clk125;
    sync_2stage #(
        .WIDTH(6)
    ) cac_state_sync (
        .clk(clk125),
        .in(cac_state),
        .out(cac_state_clk125)
    );

    // The multi-bit synchronisers below (fill_type, trig_num, trig_timestamp, and the cac / ctr
    // state and stored_bursts vectors) carry status-register values only: each bit is synchronised
    // on its own, so a value read while it is changing can be a mix of old and new bits.  Nothing
    // that makes a decision uses them; the command manager's event number comes through the
    // acquisition-event FIFO instead.
    // synchronize fill_type
    wire [4:0] fill_type_clk125;
    sync_2stage #(
        .WIDTH(5)
    ) fill_type_sync (
        .clk(clk125),
        .in(fill_type),
        .out(fill_type_clk125)
    );

    // synchronize trig_num
    wire [23:0] trig_num_clk125;
    sync_2stage #(
        .WIDTH(24)
    ) trig_num_sync (
        .clk(clk125),
        .in(trig_num),
        .out(trig_num_clk125)
    );

    // synchronize trig_timestamp
    wire [43:0] trig_timestamp_clk125;
    sync_2stage #(
        .WIDTH(44)
    ) trig_timestamp_sync (
        .clk(clk125),
        .in(trig_timestamp),
        .out(trig_timestamp_clk125)
    );

//    // synchronize pulse_trig_num
//    wire [23:0] pulse_trig_num_clk125;
//    sync_2stage #(
//        .WIDTH(24)
//    ) pulse_trig_num_sync (
//        .clk(clk125),
//        .in(pulse_trig_num),
//        .out(pulse_trig_num_clk125)
//    );

    // synchronize acq_dones
    wire [4:0] acq_dones_clk125;
    sync_2stage #(
        .WIDTH(5)
    ) acq_dones_sync (
        .clk(clk125),
        .in(acq_dones),
        .out(acq_dones_clk125)
    );

    wire [23:0] chan_trig_num_0, chan_trig_num_1, chan_trig_num_2, chan_trig_num_3, chan_trig_num_4;
    // from hdr_monitor_selftrigc (below, after the command manager): per-channel counts from the fill headers
    wire        hdr_peek_strobe, hdr_read_strobe;
    wire [ 2:0] hdr_chan;
    wire [22:0] hdr_wfms;
    wire [119:0] hdr_wfms_read;
    wire [114:0] hdr_fill_bursts;
    wire [22:0] stored_bursts_chan0_clk125, stored_bursts_chan1_clk125, stored_bursts_chan2_clk125,
                stored_bursts_chan3_clk125, stored_bursts_chan4_clk125;

    // status register assembly
    // ======== trigger-block reset sequencer ========
    // The trigger processor is reset by rst_from_ipb on clk125 and is running again a few cycles
    // later, while the trigger receiver, acquisition controller and the trigger / acquisition
    // FIFOs are reset by reset40, the same reset stretched and resynchronised into the 40 MHz domain,
    // some 100-200 ns later, and the FIFOs are then busy for a while longer.  A trigger arriving in
    // that window, or a record left in a FIFO, was seen by a half-reset block: a stale acquisition
    // record paired with a new trigger (ERROR_TRIG_NUM), or a trigger with its count record missing
    // (the CHECK_SELFTRIG_FIFO time-out).  Both happened on frontend restarts, where the master is
    // reset with the FC7 still able to send its end-of-run trigger.
    // So: from any reset, hold the trigger receiver, acquisition controller and trigger processor in
    // reset until reset40 has come and gone, every FIFO reports its reset finished, and a hold-off
    // of 2^17 clk125 cycles (~1 ms) has elapsed.  Triggers arriving meanwhile are ignored (the
    // receiver is in reset).  The command manager is not held, so IPbus register access works
    // throughout; it only reads out on the trigger processor's request.
    wire trig_fifo_rst_busy, trig_fifo_rst_busy_125, reset40_125;
    sync_2stage trig_fifo_busy_sync (.clk(clk125), .in(trig_fifo_rst_busy), .out(trig_fifo_rst_busy_125));   // (6.7.x: and the five count FIFOs)
    sync_2stage reset40_sync_125   (.clk(clk125), .in(reset40),                                    .out(reset40_125));
    reg [17:0] trig_hold_cntr = 18'd0;
    reg        trig_hold_reset = 1'b1;
    always @(posedge clk125) begin
        if (rst_from_ipb || reset40_125 || trig_fifo_rst_busy_125) begin
            trig_hold_cntr  <= 18'd0;
            trig_hold_reset <= 1'b1;
        end
        else if (!trig_hold_cntr[17]) begin
            trig_hold_cntr  <= trig_hold_cntr + 1;
            trig_hold_reset <= 1'b1;
        end
        else begin
            trig_hold_reset <= 1'b0;
        end
    end
    wire trig_hold_reset40;
    sync_2stage trig_hold_reset_sync40 (.clk(ttc_clk), .in(trig_hold_reset), .out(trig_hold_reset40));

    status_reg_block_selftrigc status_reg_block (
        // user interface clock and reset
        //.clk(clk125),
        //.reset(rst_from_ipb),

        // FPGA status
        .prog_chan_done(prog_chan_done),
        .async_mode(1'b0),
        .cbuf_mode(1'b0),
        .strg_mode(1'b1),
        .is_golden(1'b0),
        .reprog_done(reprog_done),

        // soft error thresholds
        .thres_data_corrupt(thres_data_corrupt),
        .thres_unknown_ttc(thres_unknown_ttc),
        //.thres_ddr3_overflow(thres_ddr3_overflow),

        // soft error counts
        .unknown_cmd_count(unknown_cmd_count),
        .cs_mismatch_count(cs_mismatch_count),
        .io1_status_a(io1_status_a),
        .io1_status_b(io1_status_b),

        // hard errors
        .error_data_corrupt(error_data_corrupt),
        .error_trig_num_from_tt(error_trig_num_from_tt),
        .error_trig_type_from_tt(error_trig_type_from_tt),
        .error_trig_num_from_cm(error_trig_num_from_cm),
        .error_trig_type_from_cm(error_trig_type_from_cm),
        .error_pll_unlock(error_pll_unlock),
        .error_trig_rate(error_trig_rate),
        .error_unknown_ttc(error_unknown_ttc),

        // warnings
        .ddr3_almost_full(ddr3_almost_full),

        // other error signals
        .chan_error_sn(chan_error_sn),
        .chan_error_rc(chan_error_rc),

        // external clock
        .daq_clk_sel(daq_clk_sel),
        .daq_clk_en(daq_clk_en),

        // clock synthesizer
        .adcclk_clkin0_stat(adcclk_clkin0_stat),
        .adcclk_clkin1_stat(adcclk_clkin1_stat),
        .adcclk_stat_ld(adcclk_stat_ld),
        .adcclk_stat(adcclk_stat),

        // DAQ link
        .daq_almost_full(daq_almost_full),
        .daq_ready(daq_ready),

        // TTC/TTS
        .tts_state(tts_state),
        .ttc_chan_b_info(ttc_chan_b_info_clk125),
        .ttc_ready(ttc_ready_clk125),

        // FSM state
        .cm_state(cm_state),
        .ttr_state(ttr_state_clk125),
        .ctr_state_chan0(ctr_state_chan0_clk125),
        .ctr_state_chan1(ctr_state_chan1_clk125),
        .ctr_state_chan2(ctr_state_chan2_clk125),
        .ctr_state_chan3(ctr_state_chan3_clk125),
        .ctr_state_chan4(ctr_state_chan4_clk125),
        .cac_state(cac_state_clk125),
        .tp_state(tp_state),

        // acquisition
        .acq_readout_pause(acq_readout_pause),
        .cm_tx_dest(axi_stream_to_channel_from_cm_tdest),     // command path diagnostics, status register 14
        .cm_tx_ready(c_axi_stream_to_channel_tready),
        .cm_rx_valid(c_axi_stream_to_cm_tvalid),
        .cm_tx_valid(axi_stream_to_channel_from_cm_tvalid),
        .cm_rx_ready(axi_stream_to_cm_from_channel_tready),
        .trig_hold_reset(trig_hold_reset),
        .triggers_downgraded(triggers_downgraded),
        .cm_peeking(cm_peeking),                 // header-first phase (6.7.0)
        .trig_num_error_count(trig_num_error_count),
        .fill_type(fill_type_clk125),
        .chan_en(chan_en),
        .endianness_sel(endianness_sel),
        .acq_dones(acq_dones_clk125),
        .accept_self_triggers(accept_self_triggers),
        .ttc_accept_self_triggers(ttc_accept_self_triggers),
        .ipb_accept_self_triggers(ipb_accept_self_triggers),

        // trigger
        .trig_fifo_full(trig_fifo_full),
        .pulse_fifo_full(1'b0),
        .acq_fifo_full(acq_fifo_full),
        .trig_delay(trig_delay),
        .trig_settings(trig_settings),
        .trig_num(trig_num_clk125),
        .trig_timestamp(trig_timestamp_clk125),
        .chan_trig_num_0(chan_trig_num_0),
        .chan_trig_num_1(chan_trig_num_1),
        .chan_trig_num_2(chan_trig_num_2),
        .chan_trig_num_3(chan_trig_num_3),
        .chan_trig_num_4(chan_trig_num_4),

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
        .stored_bursts_chan0(stored_bursts_chan0_clk125),
        .stored_bursts_chan1(stored_bursts_chan1_clk125),
        .stored_bursts_chan2(stored_bursts_chan2_clk125),
        .stored_bursts_chan3(stored_bursts_chan3_clk125),
        .stored_bursts_chan4(stored_bursts_chan4_clk125),

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
        .status_reg28(status_reg28),
        .status_reg29(status_reg29),
        .status_reg30(status_reg30),
        .status_reg31(status_reg31),
        .status_reg32(status_reg32),
        .status_reg33(status_reg33),
        .status_reg34(status_reg34)
    );


    // trigger top module
    wire [22:0] burst_count_selftrig;
    selftriggerc_top selftriggerc_top (
        // clocks
        .ttc_clk(ttc_clk), //  40 MHz
        .clk125(clk125),   // 125 MHz

        // resets
        .reset40(reset40),           // in  40 MHz clock domain
        .reset40_n(reset40_n),       // in  40 MHz clock domain
        .rst_from_ipb(rst_from_ipb), // in 125 MHz clock domain
        .trig_hold_reset(trig_hold_reset),       // hold-off after any reset, clk125
        .trig_hold_reset40(trig_hold_reset40),   // the same in the 40 MHz domain
        .trig_fifo_rst_busy(trig_fifo_rst_busy), // the trigger / acquisition FIFOs are still resetting
        .readout_trigger_stretch(readout_trigger_stretch), // a readout trigger has been accepted (ttc_clk, stretched)
        .event_readout_pending(event_readout_pending),     // a trigger is queued or being read out

        .rst_trigger_num(rst_trigger_num),             // from TTC Channel B
        .rst_trigger_timestamp(rst_trigger_timestamp), // from TTC Channel B

        // trigger interface
        .ttc_trigger(trigger_from_ttc),                    // TTC trigger signal
        .accept_self_triggers(accept_self_triggers),       // accept self panel triggers in enabled channels
        .trig_type(fill_type[4:0]),                        // trigger type (muon fill, laser, pedestal, async)
        //.trig_settings({28'd0, trig_settings[2:0], 1'b0}), // trigger settings
        .chan_en(chan_en),                                 // enabled channels
        .channel_acq_enabled(channel_acq_enabled_ttc),

        // channel interface
        .chan_dones(acq_dones),
        .chan_enable(acq_enable),

        // command manager interface
        .readout_ready(readout_ready),           // command manager is idle
        .readout_done(readout_done),             // initiated readout has finished
        .new_fill_pause_triggers(new_fill_pause_triggers),                     // the DDR3 readout buffer has changed
        .send_empty_event(send_empty_event),     // request an empty event
        .skip_payload(skip_payload),             // request to skip channel payloads
        .initiate_readout(initiate_readout),     // request for the channels to be read out

        .ttc_event_num(ttc_event_num),           // channel's trigger number (n'th ttc trigger sent to channel)
        .ttc_trig_num(ttc_trig_num),             // global trigger number (nth ttc trigger, including "ignored" ttc trigger types
        .ttc_trig_type(ttc_trig_type),           // trigger type
        .ttc_trig_timestamp(ttc_trig_timestamp), // trigger timestamp
        .ttc_xadc_alarms(ttc_xadc_alarms),       // XADC alarms

        // status connections
        .xadc_alarms(xadc_alarms[3:0]),    // XADC alarm signals
        .ttr_state(ttr_state),             // TTC trigger receiver state
        .cac_state(cac_state),             // channel acquisition controller state
        .tp_state(tp_state),               // trigger processor state
        .trig_num(trig_num),               // global trigger number
        .trig_timestamp(trig_timestamp),   // timestamp for latest trigger received
        .trig_fifo_full(trig_fifo_full),   // TTC trigger FIFO is almost full
        .acq_fifo_full(acq_fifo_full),     // acquisition event FIFO is almost full
        
        // error connections
        .error_trig_rate(error_trig_rate),           // trigger rate error
        .triggers_downgraded(triggers_downgraded),   // triggers turned into empty events (status)
        .empty_midrun(empty_midrun),                 // ... while the run was active (error capture, ttc_clk)
        .cac_wait_gave_up(cac_wait_gave_up),         // controller stopped waiting for a done (error capture, ttc_clk)
        .error_trig_num(error_trig_num_from_tt),     // trigger number error
        .error_trig_type(error_trig_type_from_tt)    // trigger type error
    );

    
    // create a DAQ ready signal to indicate that it's ready to receive data words, used by the command manager
    // pull down DAQ link 'ready' whenever its 'almost_full' is asserted for the previous two clock cycles
    wire daq_ready_for_data;
    assign daq_ready_for_data = daq_ready & ~daq_almost_full;

    // command manager module
    command_manager_selftrigc command_manager_selftrigc (
        // user interface clock and reset
        .clk(clk125),       // input
        .rst(rst_from_ipb), // input

        // interface to TX channel FIFO (through AXI4-Stream TX Switch)
        .chan_tx_fifo_ready(axi_stream_to_channel_from_cm_tready), // input
        .chan_tx_fifo_valid(axi_stream_to_channel_from_cm_tvalid), // output
        .chan_tx_fifo_last(axi_stream_to_channel_from_cm_tlast),   // output
        .chan_tx_fifo_dest(axi_stream_to_channel_from_cm_tdest),   // output [ 3:0]
        .chan_tx_fifo_data(axi_stream_to_channel_from_cm_tdata),   // output [31:0]

        // interface to RX channel FIFO (through AXI4-Stream RX Switch)
        .chan_rx_fifo_valid(axi_stream_to_cm_from_channel_tvalid), // input
        .chan_rx_fifo_last(axi_stream_to_cm_from_channel_tlast),   // input
        .chan_rx_fifo_data(axi_stream_to_cm_from_channel_tdata),   // input [31:0]
        .chan_rx_fifo_ready(axi_stream_to_cm_from_channel_tready), // output

        // interface to IPbus AXI output
        .ipbus_cmd_valid(axi_stream_to_cm_from_ipbus_tvalid), // input
        .ipbus_cmd_last(axi_stream_to_cm_from_ipbus_tlast),   // input
        .ipbus_cmd_dest(axi_stream_to_cm_from_ipbus_tdest),   // input [ 3:0]
        .ipbus_cmd_data(axi_stream_to_cm_from_ipbus_tdata),   // input [31:0]
        .ipbus_cmd_ready(axi_stream_to_cm_from_ipbus_tready), // output

        // interface to IPbus AXI input
        .ipbus_res_ready(axi_stream_to_ipbus_from_cm_tready), // input
        .ipbus_res_valid(axi_stream_to_ipbus_from_cm_tvalid), // output
        .ipbus_res_last(axi_stream_to_ipbus_from_cm_tlast),   // output
        .ipbus_res_data(axi_stream_to_ipbus_from_cm_tdata),   // output [31:0]

        // interface to AMC13 DAQ Link
        .daq_ready(daq_ready_for_data),    // input
        .daq_almost_full(daq_almost_full), // input
        .daq_valid(daq_valid),             // output
        .daq_header(daq_header),           // output
        .daq_trailer(daq_trailer),         // output
        .daq_data(daq_data),               // output [63:0]

        // interface to trigger processor
        .send_empty_event(send_empty_event),     // request an empty event
        .skip_payload(skip_payload),             // request to skip channel payloads
        .initiate_readout(initiate_readout),     // request for the channels to be read out
        //.accept_self_triggers(accept_self_triggers), // uncomment for debugging
        .event_num(ttc_event_num),               // channel's trigger number
        .trig_num(ttc_trig_num),                 // global trigger number, starts at 1
        .trig_type(ttc_trig_type),               // trigger type
        .trig_timestamp(ttc_trig_timestamp),     // trigger timestamp, defined by when trigger is received by trigger receiver module
        .ttc_xadc_alarms(ttc_xadc_alarms),       // XADC alarms
        .readout_ready(readout_ready),           // ready to readout data, i.e., when in idle state
        .readout_done(readout_done),             // finished readout flag
        .hdr_peek_strobe(hdr_peek_strobe),       // each fill header seen, for hdr_monitor_selftrigc (6.8.0)
        .hdr_read_strobe(hdr_read_strobe),
        .hdr_chan(hdr_chan),
        .hdr_wfms(hdr_wfms),
        .burst_count_selftrig(burst_count_selftrig),     // the total number

        // status connections
        .i2c_mac_adr(i2c_mac_adr[15:0]),         // input  [15:0], lower 2 MAC address bytes from EEPROM
        .chan_en(chan_en),                       // input  [ 4:0], enabled channels from IPbus
        .endianness_sel(endianness_sel),         // input, from IPbus
        .thres_data_corrupt(thres_data_corrupt), // input  [31:0], from IPbus
        .state(cm_state),                        // output [34:0]

        // error connections
        .cs_mismatch_count(cs_mismatch_count),     // number of checksum mismatches
        .error_data_corrupt(error_data_corrupt),   // output, data corruption error
        .error_trig_num(error_trig_num_from_cm),   // output, trigger number mismatch between channel and master
        .error_trig_type(error_trig_type_from_cm), // output, trigger type mismatch between channel and master
        .trig_num_error_count(trig_num_error_count), // output [7:0], count of the above (status register 34)
        .err_loss_pulse(err_loss_pulse),             // error capture (6.6.10)
        .err_fault_pulse(err_fault_pulse),
        .err_warn_pulse(err_warn_pulse),
        .peeking(cm_peeking),
        .chan_err_word(chan_err_word),
        .chan_err_valid(chan_err_valid),
        .last_rsn_word(last_rsn_word),
        .last_rc_word(last_rc_word),
        .last_info1_word(last_info1_word),
        .last_info4_word(last_info4_word),
        .retry_status(cm_retry_status),
        .err_summary(err_summary),
        .chan_error_sn(chan_error_sn[4:0]),        // output [ 4:0]
        .chan_error_rc(chan_error_rc[4:0]),        // output [ 4:0]
        
//        // for debugging
//        .rst_trigger_num(rst_trigger_num_125)
         .cs_mismatch_found(cs_mismatch_found)
    );
    
    // Per-channel waveform totals (status 29-33), bursts in the last fill (status 21-25) and the DDR3
    // overflow warning (TTS OFW), from the fill headers (6.8.0; were from the trigger-line counters)
    wire rst_trigger_num_125;
    sync_2stage rst_trig_num_sync_125 (.clk(clk125), .in(rst_trigger_num_stretch), .out(rst_trigger_num_125));   // 120 ns level
    hdr_monitor_selftrigc hdr_monitor (
        .clk(clk125),
        .rst(rst_from_ipb),
        .reset_totals(rst_trigger_num_125),
        .clear(clear_trigger_counts),
        .hdr_peek_strobe(hdr_peek_strobe),
        .hdr_read_strobe(hdr_read_strobe),
        .hdr_chan(hdr_chan),
        .hdr_wfms(hdr_wfms),
        .burst_count(burst_count_selftrig),
        .thres_ddr3_overflow(thres_ddr3_overflow[22:0]),
        .chan_en(chan_en),
        .wfms_read(hdr_wfms_read),
        .fill_bursts(hdr_fill_bursts),
        .ddr3_almost_full(ddr3_almost_full)
    );
    assign chan_trig_num_0 = hdr_wfms_read[ 23:  0];
    assign chan_trig_num_1 = hdr_wfms_read[ 47: 24];
    assign chan_trig_num_2 = hdr_wfms_read[ 71: 48];
    assign chan_trig_num_3 = hdr_wfms_read[ 95: 72];
    assign chan_trig_num_4 = hdr_wfms_read[119: 96];
    assign stored_bursts_chan0_clk125 = hdr_fill_bursts[ 22:  0];
    assign stored_bursts_chan1_clk125 = hdr_fill_bursts[ 45: 23];
    assign stored_bursts_chan2_clk125 = hdr_fill_bursts[ 68: 46];
    assign stored_bursts_chan3_clk125 = hdr_fill_bursts[ 91: 69];
    assign stored_bursts_chan4_clk125 = hdr_fill_bursts[114: 92];

    wire ttc_ready_clk125_n;
    assign ttc_ready_clk125_n = ~ttc_ready_clk125;

    // TTS state reported to DAQ link
    // Error capture (6.6.10): sticky data-loss / fault / warning flags with their causes, a snapshot of
    // the state machines and key signals at the first error (status registers 35-49), cleared by
    // SYS.CLEAR_ERRORS.  Data loss drives TTS sync-lost and a fault TTS error (both abort the run).
    error_capture error_capture (   // hdl/error_capture.v (common to the master images since 6.8.0)
        .clk(clk125),
        .rst(rst_from_ipb),
        .clear(clear_errors),
        .err_loss_pulse(err_loss_pulse),
        .err_fault_pulse(err_fault_pulse),
        .err_warn_pulse(err_warn_pulse),
        .empty_midrun(empty_midrun),
        .cac_wait_gave_up(cac_wait_gave_up),
        .chan_err_word(chan_err_word),
        .chan_err_valid(chan_err_valid),
        .cm_state({1'b0, cm_state}),
        .trig_states({ttr_state_clk125, cac_state_clk125, tp_state}),
        .trig_states_extra(6'd0),
        .acq_dones(acq_dones_clk125),
        .chan_error_rc(chan_error_rc),
        .chan_error_sn(chan_error_sn),
        .acq_readout_pause(acq_readout_pause),
        .chan_en(chan_en),
        .cm_rx_valid(c_axi_stream_to_cm_tvalid),
        .cm_tx_ready(c_axi_stream_to_channel_tready),
        .cm_rx_ready(axi_stream_to_cm_from_channel_tready),
        .cm_tx_valid(axi_stream_to_channel_from_cm_tvalid),
        .cm_tx_dest(axi_stream_to_channel_from_cm_tdest),
        .event_num(ttc_event_num),
        .trig_num(trig_num_clk125),
        .trig_timestamp(trig_timestamp_clk125),
        .last_rsn_word(last_rsn_word),
        .last_rc_word(last_rc_word),
        .last_info1_word(last_info1_word),
        .last_info4_word(last_info4_word),
        .retry_status(cm_retry_status),
        // status register 48: live flags at the moment of the error
        .misc_live({16'd0, ipb_accept_self_triggers, ttc_accept_self_triggers, accept_self_triggers, ttc_ready_clk125,
                    daq_almost_full, daq_ready, trig_fifo_full, acq_fifo_full, ddr3_almost_full, error_trig_rate,
                    error_data_corrupt, fill_type_clk125[4:0]}),
        .data_loss(data_loss),
        .hw_fault(hw_fault),
        .warning(err_warning),
        .err_summary(err_summary),
        .status_reg35(status_reg35),
        .status_reg36(status_reg36),
        .status_reg37(status_reg37),
        .status_reg38(status_reg38),
        .status_reg39(status_reg39),
        .status_reg40(status_reg40),
        .status_reg41(status_reg41),
        .status_reg42(status_reg42),
        .status_reg43(status_reg43),
        .status_reg44(status_reg44),
        .status_reg45(status_reg45),
        .status_reg46(status_reg46),
        .status_reg47(status_reg47),
        .status_reg48(status_reg48),
        .status_reg49(status_reg49)
    );

    tts_reporter tts_reporter (
        //.clk(clk125),
        //.reset(rst_from_ipb),

        // error status
        .error_ttc_ready(ttc_ready_clk125_n),
        .error_data_corrupt(error_data_corrupt | hw_fault),   // a fault latched by the error capture is a TTS error
        .error_pll_unlock(error_pll_unlock),
        .error_trig_rate(error_trig_rate),
        .error_unknown_ttc(error_unknown_ttc),

        // sync lost status.  The command manager's trigger-number / type mismatches are no longer
        // terminal (6.6.9): the channel is re-read or skipped for that one event, and the
        // readout stays in step with the TTC trigger numbers.  They are therefore reported in the
        // status registers (sticky flags, and the count in status register 34) but not as a TTS
        // sync-lost, which would have been permanent before and would now be a one-event glitch.
        .error_trig_num_from_tt(error_trig_num_from_tt),
        .error_trig_num_from_cm(data_loss),                   // data loss latched by the error capture is a TTS sync-lost
        .error_trig_type_from_tt(error_trig_type_from_tt),
        .error_trig_type_from_cm(1'b0),

        // overflow warning status
        .overflow_warning_ddr3(ddr3_almost_full),

        // TTS state output
        .tts_state(tts_state)
    );

    wire daq_link_reset;
    assign daq_link_reset = ttc_evt_reset | rst_from_ipb;

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
        .BcntRes(daq_link_reset),
        .trig({ 8{trigger_from_ttc} }),

        .TTSclk(clk125),
        .TTS(tts_state),

	    .ReSyncAndEmpty(1'b0),           // added input signal ReSyncAndEmpty for proper ReSync operation; set to 0 because likely won't be used
        .EventDataClk(clk125),
        .EventData_valid(daq_valid),
        .EventData_header(daq_header),   // flag to indicate first AMC13 header word
        .EventData_trailer(daq_trailer), // flag to indicate AMC13 trailer word
        .EventData(daq_data),            // 64-bit data words to send to AMC13
        .AlmostFull(daq_almost_full),    // DAQ link buffer is almost full (space for only 10 additional words)
        .Ready(daq_ready)                // flag to indicate link status during initialization
                                         // Mr. Wu: "It goes low when initialization starts and goes up when initialization is done."
    );


    // AXIS TX Switch
    axis_switch_tx tx_switch (
        .aclk(clk125),            // input
        .aresetn(rst_from_ipb_n), // input

        // command manager side
        .s_axis_tvalid(axi_stream_to_channel_from_cm_tvalid), // input
        .s_axis_tready(axi_stream_to_channel_from_cm_tready), // output
        .s_axis_tdata(axi_stream_to_channel_from_cm_tdata),   // input [31:0]
        .s_axis_tdest(axi_stream_to_channel_from_cm_tdest),   // input [ 3:0]
        .s_axis_tlast(axi_stream_to_channel_from_cm_tlast),   // input

        // channel FPGA side
        .m_axis_tvalid(c_axi_stream_to_channel_tvalid), // output [  4:0]
        .m_axis_tready(c_axi_stream_to_channel_tready), // input  [  4:0]
        .m_axis_tdata(c_axi_stream_to_channel_tdata),   // output [159:0]
        .m_axis_tdest(c_axi_stream_to_channel_tdest),   // output [ 19:0]
        .m_axis_tlast(c_axi_stream_to_channel_tlast),   // output [  4:0]
        
        // unused output port
        .s_decode_err()
    );


    // AXIS RX Switch
    // Only the channel the command manager is currently addressing may be granted the RX switch.
    // The switch is configured to re-arbitrate within a frame (ARB_ON_TLAST = 0), and its output
    // carries no source id, so if a second channel's RX FIFO ever held data while a response was in
    // flight (a late reply after an RSN timeout, a stray word after a link error) the two would be
    // interleaved into the one stream the command manager reads.  Suppressing every other port
    // keeps such words in their own FIFO instead.  'chan_tx_fifo_dest' is 0..4 for a channel
    // readout or an IPbus channel access, 5 once the last channel has been read.
    wire [4:0] s_req_suppress;   // active-high: port is excluded from arbitration
    assign s_req_suppress = (axi_stream_to_channel_from_cm_tdest < 4'd5) ?
                            ~(5'b00001 << axi_stream_to_channel_from_cm_tdest) : 5'b11111;
    axis_switch_rx rx_switch (
        .aclk(clk125),                   // input
        .aresetn(rst_from_ipb_n),        // input
        .s_req_suppress(s_req_suppress), // input [4:0]

        // channel FPGA side
        .s_axis_tvalid(c_axi_stream_to_cm_tvalid), // input  [  4:0]
        .s_axis_tready(c_axi_stream_to_cm_tready), // output [  4:0]
        .s_axis_tlast(c_axi_stream_to_cm_tlast),   // input  [  4:0]
        .s_axis_tdata(c_axi_stream_to_cm_tdata),   // input  [159:0]

        // command manager side
        .m_axis_tvalid(axi_stream_to_cm_from_channel_tvalid), // output
        .m_axis_tready(axi_stream_to_cm_from_channel_tready), // input
        .m_axis_tlast(axi_stream_to_cm_from_channel_tlast),   // output
        .m_axis_tdata(axi_stream_to_cm_from_channel_tdata),   // output [31:0]
        
        // unused output port
        .s_decode_err()
    );

endmodule
