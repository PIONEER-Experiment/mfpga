// Top-level module for trigger handling and management

// question -- do we need to capture the last number of triggers obtained?

module selftriggerc_top (
    // clocks
    input wire ttc_clk, //  40 MHz
    input wire clk125,  // 125 MHz

    // resets
    input wire reset40,      // in  40 MHz clock domain
    input wire reset40_n,    // in  40 MHz clock domain
    input wire rst_from_ipb, // in 125 MHz clock domain
//    input wire reset_fifos,  // in  40 MHz clock domain

    input wire rst_trigger_num,       // from TTC Channel B
    input wire rst_trigger_timestamp,

    // trigger interface
    input wire ttc_trigger,                // TTC trigger signal
    input wire accept_self_triggers,       // enabled channels should start accepting triggers
    input wire [ 4:0] trig_type,           // trigger type (muon fill, laser, pedestal, async readout)
    input wire [31:0] trig_settings,       // trigger settings
    input wire [ 4:0] chan_en,             // enabled channels
    input wire [31:0] thres_ddr3_overflow, // DDR3 overflow threshold
    input wire channel_acq_enabled,
    input wire clear_trigger_counts,       // after end of run, make sure both hi and lo trigger/burst counters cleared

    // channel interface:  these use the direct i/o lines to pins on the channel FPGAs
    input  wire [4:0] chan_dones,          // the last event before starting readout has been moved to DDR3 memory
    output wire [4:0] chan_enable,         // the channel should accept triggers
    input  wire [4:0] chan_trigs,          // a self-trigger condition has been seen on a channel

    // command manager interface
    input  wire readout_ready,          // command manager is idle
    input  wire readout_done,           // initiated readout has finished
    output wire new_fill_pause_triggers, // TTC Async readout received, switch to new buffer
    output wire selftrigger_fifo_wr_en, // push the latched number of self-triggers onto the fifo's
    output wire send_empty_event,       // request an empty event
    output wire skip_payload,           // request to skip channel payloads
    output wire initiate_readout,       // request for the channels to be read out
    output wire [23:0] chan_trig_num_0, // # of triggers seen per channel
    output wire [23:0] chan_trig_num_1, // # of triggers seen per channel
    output wire [23:0] chan_trig_num_2, // # of triggers seen per channel
    output wire [23:0] chan_trig_num_3, // # of triggers seen per channel
    output wire [23:0] chan_trig_num_4, // # of triggers seen per channel

    output wire [23:0] ttc_event_num,      // channel's trigger number
    output wire [23:0] ttc_trig_num,       // global trigger number
    output wire [ 4:0] ttc_trig_type,      // trigger type
    output wire [43:0] ttc_trig_timestamp, // trigger timestamp
    output wire [ 3:0] ttc_xadc_alarms,    // XADC alarms

    input [22:0] burst_count_selftrig,

    // the number of triggers each channel has accumulated since the last readout trigger, live
    output wire [19:0] selftriggers_chan0,
    output wire [19:0] selftriggers_chan1,
    output wire [19:0] selftriggers_chan2,
    output wire [19:0] selftriggers_chan3,
    output wire [19:0] selftriggers_chan4,
    // the number of triggers each channel has accumulated after the previous readout trigger, latched
    output wire [19:0] selftriggers_chan0_latched,
    output wire [19:0] selftriggers_chan1_latched,
    output wire [19:0] selftriggers_chan2_latched,
    output wire [19:0] selftriggers_chan3_latched,
    output wire [19:0] selftriggers_chan4_latched,

    // status connections
    input  wire [ 3:0] xadc_alarms,    // XADC alarm signals
    output wire [ 3:0] ttr_state,      // TTC trigger receiver state
    output wire [ 1:0] ctr_state_chan0,// channel trigger receiver state
    output wire [ 1:0] ctr_state_chan1,// channel trigger receiver state
    output wire [ 1:0] ctr_state_chan2,// channel trigger receiver state
    output wire [ 1:0] ctr_state_chan3,// channel trigger receiver state
    output wire [ 1:0] ctr_state_chan4,// channel trigger receiver state
    output wire [ 5:0] cac_state,      // channel acquisition controller state
    output wire [ 6:0] tp_state,       // trigger processor state
    output wire [23:0] trig_num,       // global trigger number
    output wire [43:0] trig_timestamp, // timestamp for latest trigger received
    output wire trig_fifo_full,        // TTC trigger FIFO is almost full
    output wire acq_fifo_full,         // acquisition event FIFO is almost full

    // number of bursts stored in the DDR3 for the buffer being written to
    output wire [22:0] stored_bursts_chan0,
    output wire [22:0] stored_bursts_chan1,
    output wire [22:0] stored_bursts_chan2,
    output wire [22:0] stored_bursts_chan3,
    output wire [22:0] stored_bursts_chan4,

    // error connections
    output wire ddr3_almost_full,           // DDR3 overflow warning
    output wire error_trig_rate,            // trigger rate error
    output wire error_trig_num,             // trigger number error
    output wire error_trig_type             // trigger type error
);

    // -------------------
    // signal declarations
    // -------------------

    // signals between TTC Trigger Receiver and Channel Acquisition Controllers
    wire acq_ready;
    wire acq_activated;
    wire acq_trigger;
//    wire [ 4:0] acq_ready_channel;
    wire [ 4:0] acq_trig_type;
    wire [23:0] acq_trig_num;

    // signals to/from TTC Trigger FIFO
    wire s_trig_fifo_tready;
    wire s_trig_fifo_tvalid;
    wire [127:0] s_trig_fifo_tdata;

    wire m_trig_fifo_tready;
    wire m_trig_fifo_tvalid;
    wire [127:0] m_trig_fifo_tdata;


    // signals to/from channel Pulse self-triggered FIFOs
    wire  [1:0] s_pulse_fifo_tready[4:0];
    wire  [1:0] s_pulse_fifo_tvalid[4:0];
    wire [63:0] s_pulse_fifo_tdata[4:0];

    wire s_acq_fifo_tready;
    wire s_acq_fifo_tvalid;
    wire [31:0] s_acq_fifo_tdata;

    wire m_acq_fifo_tready;
    wire m_acq_fifo_tvalid;
    wire [31:0] m_acq_fifo_tdata;

    // error or warning signals
    wire [4:0] ddr3_almost_full_chan;

    wire [19:0] selftriggers[4:0];
    assign selftriggers_chan0[19:0] = selftriggers[0][19:0];
    assign selftriggers_chan1[19:0] = selftriggers[1][19:0];
    assign selftriggers_chan2[19:0] = selftriggers[2][19:0];
    assign selftriggers_chan3[19:0] = selftriggers[3][19:0];
    assign selftriggers_chan4[19:0] = selftriggers[4][19:0];

    wire [19:0] selftriggers_latch[4:0];
    assign selftriggers_chan0_latched[19:0] = selftriggers_latch[0][19:0];
    assign selftriggers_chan1_latched[19:0] = selftriggers_latch[1][19:0];
    assign selftriggers_chan2_latched[19:0] = selftriggers_latch[2][19:0];
    assign selftriggers_chan3_latched[19:0] = selftriggers_latch[3][19:0];
    assign selftriggers_chan4_latched[19:0] = selftriggers_latch[4][19:0];

    wire [45:0] stored_bursts[4:0];
    assign stored_bursts_chan0[22:0] = stored_bursts[0][22:0];
    assign stored_bursts_chan1[22:0] = stored_bursts[1][22:0];
    assign stored_bursts_chan2[22:0] = stored_bursts[2][22:0];
    assign stored_bursts_chan3[22:0] = stored_bursts[3][22:0];
    assign stored_bursts_chan4[22:0] = stored_bursts[4][22:0];

    assign selftriggers_seen = (selftriggers_chan0[19:0] > 0) |
                               (selftriggers_chan1[19:0] > 0) |
                               (selftriggers_chan2[19:0] > 0) |
                               (selftriggers_chan3[19:0] > 0) |
                               (selftriggers_chan4[19:0] > 0);

    wire [23:0] chan_trig_num[4:0];
    assign chan_trig_num_0[23:0] = chan_trig_num[0][23:0];
    assign chan_trig_num_1[23:0] = chan_trig_num[1][23:0];
    assign chan_trig_num_2[23:0] = chan_trig_num[2][23:0];
    assign chan_trig_num_3[23:0] = chan_trig_num[3][23:0];
    assign chan_trig_num_4[23:0] = chan_trig_num[4][23:0];

    wire [1:0] ctr_state[4:0];
    assign ctr_state_chan0[1:0] = ctr_state[0][1:0];
    assign ctr_state_chan1[1:0] = ctr_state[1][1:0];
    assign ctr_state_chan2[1:0] = ctr_state[2][1:0];
    assign ctr_state_chan3[1:0] = ctr_state[3][1:0];
    assign ctr_state_chan4[1:0] = ctr_state[4][1:0];

    // ----------------
    // synchronizations
    // ----------------

    // synchronize and the chan_trigs and reduce to a single clock cycle
    reg  [4:0] ct_sync1, ct_sync2, ct_sync3;
    wire [4:0] chan_trigs_clk40;
    always @(posedge ttc_clk) begin
        ct_sync1 <= chan_trigs;
        ct_sync2 <= ct_sync1;
        ct_sync3 <= ct_sync2;
    end
    assign chan_trigs_clk40 = ct_sync2 & ~ct_sync3;

    // synchronize chan_dones
(* mark_debug = "true" *) wire [4:0] chan_dones_clk40;
    sync_2stage #(
        .WIDTH(5)
    ) chan_dones_sync (
        .clk(ttc_clk),
        .in(chan_dones),
        .out(chan_dones_clk40)
    );

    // synchronize chan_en
    wire [4:0] chan_en_clk40;
    sync_2stage #(
        .WIDTH(5)
    ) chan_en_sync (
        .clk(ttc_clk),
        .in(chan_en),
        .out(chan_en_clk40)
    );

    // toggle synchronize readout_done
    wire readout_done_toggle;
    toggle_sync_2stage readout_done_toggle_sync (
        .clk_in(clk125),
        .clk_out(ttc_clk),
        .n_extra_cycles(8'h0A),
        .in(readout_done),
        .out(readout_done_toggle)
    );

    wire readout_done_clk40;
    sync_2stage readout_done_sync (
        .clk(ttc_clk),
        .in(readout_done_toggle),
        .out(readout_done_clk40)
    );


    // -------------------
    // signal multiplexers
    // -------------------

    // error signals
    assign ddr3_almost_full = |ddr3_almost_full_chan;


    // ----------------
    // module instances
    // ----------------

    // TTC trigger receiver module
    ttc_trigger_receiver_selftrigc ttc_trigger_receiver_selftrigc (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40),

        // TTC Channel B resets
        .reset_trig_num(rst_trigger_num),
        .reset_trig_timestamp(rst_trigger_timestamp),

        // trigger interface
        .ttc_trigger(ttc_trigger),                       // TTC trigger signal
        .trig_type(trig_type),                           // trigger type
        .trig_settings(trig_settings),                   // trigger settings
        .chan_en(chan_en_clk40),                         // enabled channels

        // command manager interface
        .readout_done(readout_done_clk40), // a readout has completed

        // channel acquisition controller interface
        .acq_ready(acq_ready),         // channels are ready to acquire/readout data
        .acq_activated(acq_activated), 
        .accept_self_triggers(accept_self_triggers), // enabled channels should start accepting triggers
        .acq_trigger(acq_trigger),     // trigger signal
        .acq_trig_type(acq_trig_type), // recongized trigger type (muon fill, laser, pedestal, async readout)
        .acq_trig_num(acq_trig_num),   // trigger number, starts at 1
        .channel_acq_enabled(channel_acq_enabled),

        // interface to TTC Trigger FIFO
        .fifo_ready(s_trig_fifo_tready),
        .fifo_valid(s_trig_fifo_tvalid),
        .fifo_data(s_trig_fifo_tdata),

        // status connections
        .selftriggers_seen(selftriggers_seen),             // there are triggers in the current buffer
        .xadc_alarms(xadc_alarms[3:0]),                // XADC alarm signals
        .state(ttr_state),                             // state of finite state machine
        .trig_num(trig_num),                           // global trigger number
        .trig_timestamp(trig_timestamp),               // global trigger timestamp
        
        // error connections
        .error_trig_rate(error_trig_rate)              // trigger rate error
    );

    // /////////////////////////////////////////////////////////////////////////
    // channel trigger receiver module
    // we will loop to instantiate one receiver per channel, along with the corresponding trigger fifo
    generate genvar iChan;
    for ( iChan = 0; iChan < 5; iChan = iChan + 1) begin : ctr_loop
      channel_triggerc_receiver channel_triggerc_receiver (
          // clock and reset
          .clk(ttc_clk),   // 40 MHz TTC clock
          .reset(reset40),
//          .reset_fifos(reset_fifos),
          .clear_trigger_counts(clear_trigger_counts),

          // TTC Channel B resets
          .reset_trig_num(rst_trigger_num),
  
          // trigger interface
          .trigger(chan_trigs_clk40[iChan]),               // channel self trigger pulse
          .thres_ddr3_overflow(thres_ddr3_overflow[22:0]), // DDR3 overflow threshold
          .chan_en(chan_en_clk40[iChan]),                  // enabled channels
          .ttc_trigger(ttc_trigger),                       // backplane trigger signal
//          .ttc_acq_ready(acq_ready_channel[iChan]),                       // channels are ready to acquire/readout data
          .trig_num(chan_trig_num[iChan]),                 // pulse trigger number
          .selftriggers(selftriggers[iChan]),              // pulses accumulated in current DDR3 buffer
          .selftriggers_latch(selftriggers_latch[iChan]),  // pulses accumulated in previous DDR3 buffer

          // command manager interface
          .new_fill_pause_triggers(new_fill_pause_triggers),                             // TTC Async readout came, switching to new fill

          // set burst count for each channel
          .burst_count_selftrig(burst_count_selftrig), // burst count captured for each self-trigger
  
          // number of bursts stored in the DDR3
          .stored_bursts(stored_bursts[iChan][22:0]),
  
          // status connections
          .state(ctr_state[iChan]),                             // state of finite state machine

          // error connections
          .ddr3_almost_full(ddr3_almost_full_chan[iChan])       // DDR3 overflow warning
      );
    end // of the channel trigger receiver instantiations
    endgenerate

//    ila_40 ila_debug_clk40 (
//    	.clk(ttc_clk), // input wire clk
//
//
//      .probe0(selftriggers_lo[0][9:0]), // input wire [9:0]  probe0
//      .probe1(selftriggers_hi[0][9:0]), // input wire [9:0]  probe1
//      .probe2(chan_trig_num[0][9:0]),   // input wire [9:0]  probe2
//      .probe3(chan_trigs_clk40[0]),     // input wire [0:0]  probe3
//      .probe4(new_fill_pause_triggers),                // input wire [0:0]  probe4
//      .probe5(chan_buffer_write[0] ),   // input wire [0:0]  probe5
//      .probe6(selftriggers_seen_hi ),   // input wire [0:0]  probe6
//      .probe7(selftriggers_seen_lo ),   // input wire [0:0]  probe7
//      .probe8(selftriggers_seen ),      // input wire [0:0]  probe8
//      .probe9(ttc_trigger ),            // input wire [0:0]  probe9
//      .probe10(trig_type ),             // input wire [4:0]  probe10
//      .probe11(empty_payload ),         // input wire [0:0]  probe11
//      .probe12(empty_event ),           // input wire [0:0]  probe12
//      .probe13(acq_trig_num[23:0]),     // input wire [23:0] probe13
//      .probe14(ttr_state[3:0])          // input wire [3:0]  probe14
//    );

    // channel acquisition controller module (asynchronous)
    channel_acq_controller_selftrigc channel_acq_controller_selftrigc (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40),

        // trigger configuration
        .chan_en(chan_en_clk40),                       // which channels should receive the trigger
        .accept_self_triggers(accept_self_triggers),   // accept self panel triggers in enabled channels

        // command manager interface
        .readout_done(readout_done_clk40), // a readout has completed
        .new_fill_pause_triggers(new_fill_pause_triggers),
        .selftrigger_fifo_wr_en(selftrigger_fifo_wr_en),

        // interface from TTC trigger receiver
        .ttc_trigger(acq_trigger),         // trigger signal
        .ttc_trig_type(acq_trig_type),     // recognized trigger type (muon fill, laser, async readout)
        .ttc_trig_num(acq_trig_num),       // trigger number
        .ttc_acq_ready(acq_ready),         // channels are ready to acquire/readout data
        .ttc_acq_activated(acq_activated),

        // interface to Channel FPGAs
        .acq_dones(chan_dones_clk40),
        .acq_enable(chan_enable),

        // interface to Acquisition Event FIFO
        .fifo_ready(s_acq_fifo_tready),
        .fifo_valid(s_acq_fifo_tvalid),
        .fifo_data(s_acq_fifo_tdata),

        // status connections
        .state(cac_state)       // state of finite state machine
    );

    
    // trigger processor module
    trigger_processor trigger_processor (
        // clock and reset
        .clk(clk125),         // 125 MHz clock
        .reset(rst_from_ipb),

        // interface to TTC Trigger FIFO
        .trig_fifo_valid(m_trig_fifo_tvalid),
        .trig_fifo_data(m_trig_fifo_tdata),
        .trig_fifo_ready(m_trig_fifo_tready),

        // interface to Acquisition Event FIFO
        .acq_fifo_valid(m_acq_fifo_tvalid),
        .acq_fifo_data(m_acq_fifo_tdata),
        .acq_fifo_ready(m_acq_fifo_tready),

        // interface to command manager
        .readout_ready(readout_ready),       // command manager is idle
        .readout_done(readout_done),         // initiated readout has finished
        .send_empty_event(send_empty_event), // request an empty event
        .skip_payload(skip_payload),         // request to skip channel payloads
        .initiate_readout(initiate_readout), // request for the channels to be read out

        .ttc_event_num(ttc_event_num),           // respond-to trigger number
        .ttc_trig_num(ttc_trig_num),             // global trigger number
        .ttc_trig_type(ttc_trig_type),           // trigger type
        .ttc_trig_timestamp(ttc_trig_timestamp), // trigger timestamp
        .ttc_xadc_alarms(ttc_xadc_alarms),       // XADC alarms

        // status connections
        .state(tp_state),                 // state of finite state machine
        .error_trig_num(error_trig_num),  // trigger number mismatch between FIFOs
        .error_trig_type(error_trig_type) // trigger type mismatch between FIFOs
    );


    // TTC Trigger FIFO : 2048 depth, 2047 almost full threshold, 16-byte data width
    // holds the trigger timestamp, trigger number, acquired event number, and trigger type
    trigger_info_fifo ttc_trigger_fifo (
        // writing side
        .s_aclk(ttc_clk),                   // input
        .s_aresetn(reset40_n),              // input
        .s_axis_tvalid(s_trig_fifo_tvalid), // input
        .s_axis_tready(s_trig_fifo_tready), // output
        .s_axis_tdata(s_trig_fifo_tdata),   // input  [127:0]

        // reading side
        .m_aclk(clk125),                    // input
        .m_axis_tvalid(m_trig_fifo_tvalid), // output
        .m_axis_tready(m_trig_fifo_tready), // input
        .m_axis_tdata(m_trig_fifo_tdata),   // output [127:0]
      
        // FIFO almost full port
        .axis_prog_full(trig_fifo_full),    // output

        // handshaking (currently unused)
        .wr_rst_busy(),
        .rd_rst_busy()
    );



    // Acquisition Event FIFO : 2048 depth, 2047 almost full threshold, 4-byte data width
    // holds the trigger number and trigger type
    acq_event_fifo acq_event_fifo (
        // writing side
        .s_aclk(ttc_clk),                  // input
        .s_aresetn(reset40_n),             // input
        .s_axis_tvalid(s_acq_fifo_tvalid), // input
        .s_axis_tready(s_acq_fifo_tready), // output
        .s_axis_tdata(s_acq_fifo_tdata),   // input  [31:0]

        // reading side
        .m_aclk(clk125),                   // input
        .m_axis_tvalid(m_acq_fifo_tvalid), // output
        .m_axis_tready(m_acq_fifo_tready), // input
        .m_axis_tdata(m_acq_fifo_tdata),   // output [31:0]
      
        // FIFO almost full port
        .axis_prog_full(acq_fifo_full),    // output

        // unused
        .wr_rst_busy(),        // output wire wr_rst_busy
        .rd_rst_busy()         // output wire rd_rst_busy

    );

endmodule
