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
    input wire trig_hold_reset,    // in 125 MHz domain: hold the trigger processor until the trigger block is clean
    input wire trig_hold_reset40,  // the same, in the 40 MHz domain: holds the trigger receiver and acquisition controller
    output wire trig_fifo_rst_busy, // the trigger / acquisition event FIFOs are still resetting (mixed domains, level)
    output wire readout_trigger_stretch, // a readout trigger has been passed to the acquisition controller (ttc_clk, 160 ns)
    output wire event_readout_pending,   // a trigger is queued or being processed (clk125)

    input wire rst_trigger_num,       // from TTC Channel B
    input wire rst_trigger_timestamp,

    // trigger interface
    input wire ttc_trigger,                // TTC trigger signal
    input wire accept_self_triggers,       // enabled channels should start accepting triggers
    input wire [ 4:0] trig_type,           // trigger type (muon fill, laser, pedestal, async readout)
    //input wire [31:0] trig_settings,       // trigger settings
    input wire [ 4:0] chan_en,             // enabled channels
    input wire channel_acq_enabled,

    // channel interface:  these use the direct i/o lines to pins on the channel FPGAs
    input  wire [4:0] chan_dones,          // the last event before starting readout has been moved to DDR3 memory
    output wire [4:0] chan_enable,         // the channel should accept triggers
    // (6.8.0: the channels' trigger lines are no longer used here; the per-channel pulse counters,
    // channel_triggerc_receiver, went with them.  Per-channel counts now come from the fill
    // headers: hdr_monitor_selftrigc in wfd_selftrigc_top.)

    // command manager interface
    input  wire readout_ready,          // command manager is idle
    input  wire readout_done,           // initiated readout has finished
    output wire new_fill_pause_triggers, // TTC Async readout received, switch to new buffer
    output wire send_empty_event,       // request an empty event
    output wire skip_payload,           // request to skip channel payloads
    output wire initiate_readout,       // request for the channels to be read out

    output wire [23:0] ttc_event_num,      // channel's trigger number
    output wire [23:0] ttc_trig_num,       // global trigger number
    output wire [ 4:0] ttc_trig_type,      // trigger type
    output wire [43:0] ttc_trig_timestamp, // trigger timestamp
    output wire [ 3:0] ttc_xadc_alarms,    // XADC alarms

    // status connections
    input  wire [ 3:0] xadc_alarms,    // XADC alarm signals
    output wire [ 3:0] ttr_state,      // TTC trigger receiver state
    output wire [ 5:0] cac_state,      // channel acquisition controller state
    output wire [ 6:0] tp_state,       // trigger processor state
    output wire [23:0] trig_num,       // global trigger number
    output wire [43:0] trig_timestamp, // timestamp for latest trigger received
    output wire trig_fifo_full,        // TTC trigger FIFO is almost full
    output wire acq_fifo_full,         // acquisition event FIFO is almost full

    // error connections
    output wire error_trig_rate,            // trigger rate error
    output wire [7:0] triggers_downgraded,  // TTC triggers turned into empty events because the acquisition controller stayed busy
    output wire       empty_midrun,         // one TTC clock: a readout trigger answered empty while the run was active (error capture)
    output wire       cac_wait_gave_up,     // one TTC clock: the acquisition controller stopped waiting for a channel's done (error capture)
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
    // for acq_encode2's end-of-run handling: the readout trigger, stretched for the clk125 domain,
    // and whether anything is still queued or in flight
    signal_stretch readout_trigger_stretcher (
        .signal_in(acq_trigger),
        .clk(ttc_clk),
        .n_extra_cycles(8'h07),            // 8 ttc_clk cycles = 200 ns, plenty for a clk125 synchroniser
        .signal_out(readout_trigger_stretch)
    );
    assign event_readout_pending = m_trig_fifo_tvalid | ~tp_state[0] | ~readout_ready;   // trigger queued, processor busy, or readout under way
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


    wire s_acq_fifo_tready;
    wire s_acq_fifo_tvalid;
    wire [31:0] s_acq_fifo_tdata;

    wire m_acq_fifo_tready;
    wire m_acq_fifo_tvalid;
    wire [31:0] m_acq_fifo_tdata;

    // ----------------
    // synchronizations
    // ----------------

    // synchronize chan_dones
wire [4:0] chan_dones_clk40;
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


    // ----------------
    // module instances
    // ----------------

    // TTC trigger receiver module
    ttc_trigger_receiver_selftrigc ttc_trigger_receiver_selftrigc (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40 | trig_hold_reset40),

        // TTC Channel B resets
        .reset_trig_num(rst_trigger_num),
        .reset_trig_timestamp(rst_trigger_timestamp),

        // trigger interface
        .ttc_trigger(ttc_trigger),                       // TTC trigger signal
        .trig_type(trig_type),                           // trigger type
        //.trig_settings(trig_settings),                   // trigger settings
        //.chan_en(chan_en_clk40),                         // enabled channels

        // channel acquisition controller interface
        .acq_ready(acq_ready),         // channels are ready to acquire/readout data
        .acq_activated(acq_activated), // acquisition controller is in ACQUIRE: a trigger will be acted on
        .run_active(accept_self_triggers),                // the FC7 has not stopped the run
        .acq_trigger(acq_trigger),     // trigger signal
        .acq_trig_type(acq_trig_type), // recongized trigger type (muon fill, laser, pedestal, async readout)
        .acq_trig_num(acq_trig_num),   // trigger number, starts at 1
        .channel_acq_enabled(channel_acq_enabled),

        // interface to TTC Trigger FIFO
        .fifo_ready(s_trig_fifo_tready),
        .fifo_valid(s_trig_fifo_tvalid),
        .fifo_data(s_trig_fifo_tdata),

        // status connections
        //.selftriggers_seen(selftriggers_seen),             // there are triggers in the current buffer
        .xadc_alarms(xadc_alarms[3:0]),                // XADC alarm signals
        .state(ttr_state),                             // state of finite state machine
        .trig_num(trig_num),                           // global trigger number
        .trig_timestamp(trig_timestamp),               // global trigger timestamp
        
        // error connections
        .error_trig_rate(error_trig_rate),             // trigger rate error
        .triggers_downgraded(triggers_downgraded),     // triggers turned into empty events (status)
        .empty_midrun(empty_midrun)                    // ... while the run was active (error capture)
    );

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
        .reset(reset40 | trig_hold_reset40),

        // trigger configuration
        .chan_en(chan_en_clk40),                       // which channels should receive the trigger
        .accept_self_triggers(accept_self_triggers),   // accept self panel triggers in enabled channels

        // command manager interface
        .new_fill_pause_triggers(new_fill_pause_triggers),

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
        .state(cac_state),      // state of finite state machine
        .wait_gave_up(cac_wait_gave_up)   // WAIT ended on its time-out (error capture)
    );

    
    // trigger processor module
    trigger_processor trigger_processor (
        // clock and reset
        .clk(clk125),         // 125 MHz clock
        .reset(rst_from_ipb | trig_hold_reset),

        // interface to TTC Trigger FIFO
        .trig_fifo_valid(m_trig_fifo_tvalid),
        .trig_fifo_data(m_trig_fifo_tdata[102:0]),
        .trig_fifo_ready(m_trig_fifo_tready),

        // interface to Acquisition Event FIFO
        .acq_fifo_valid(m_acq_fifo_tvalid),
        .acq_fifo_data(m_acq_fifo_tdata[28:0]),
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


    wire trig_fifo_wr_rst_busy, trig_fifo_rd_rst_busy, acq_fifo_wr_rst_busy, acq_fifo_rd_rst_busy;
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

        // handshaking
        .wr_rst_busy(trig_fifo_wr_rst_busy),
        .rd_rst_busy(trig_fifo_rd_rst_busy)
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

        // handshaking
        .wr_rst_busy(acq_fifo_wr_rst_busy),        // output wire wr_rst_busy
        .rd_rst_busy(acq_fifo_rd_rst_busy)         // output wire rd_rst_busy

    );
    assign trig_fifo_rst_busy = trig_fifo_wr_rst_busy | trig_fifo_rd_rst_busy | acq_fifo_wr_rst_busy | acq_fifo_rd_rst_busy;

endmodule
