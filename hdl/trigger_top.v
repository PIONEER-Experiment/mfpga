// Top-level module for trigger handling and management

module trigger_top (
    // clocks
    input wire ttc_clk, //  40 MHz
    input wire clk125,  // 125 MHz

    // resets
    input wire reset40,      // in  40 MHz clock domain
    input wire reset40_n,    // in  40 MHz clock domain
    input wire rst_from_ipb, // in 125 MHz clock domain

    input wire rst_trigger_num,       // from TTC Channel B
    input wire rst_trigger_timestamp, // from TTC Channel B

    // trigger interface
    input wire ttc_trigger,                // TTC trigger signal
    input wire ext_trigger,                // front panel trigger signal
    input wire accept_pulse_triggers,      // accept front panel triggers select
    input wire [ 4:0] trig_type,           // trigger type (muon fill, laser, pedestal, async readout)
    input wire [31:0] trig_settings,       // trigger settings
    input wire [ 4:0] chan_en,             // enabled channels
    input wire [31:0] trig_delay,          // trigger delay
    input wire [31:0] thres_ddr3_overflow, // DDR3 overflow threshold
    input wire [ 3:0] fp_trig_width,       // width to separate short from long front panel triggers

    // channel interface
    input  wire [4:0] chan_dones,
    output wire [9:0] chan_enable,
    output wire [4:0] chan_trig,

    // command manager interface
    input  wire readout_ready,         // command manager is idle
    input  wire readout_done,          // initiated readout has finished
    input  wire async_readout_done,    // asynchronous readout has finished
    output wire send_empty_event,      // request an empty event
    output wire skip_payload,          // request to skip channel payloads
    output wire initiate_readout,      // request for the channels to be read out
    output wire [23:0] pulse_trig_num, // pulse trigger number
    output wire [31:0] accepted_ext_trigger_count, // cumulative # of pulse triggers this run
    output wire [23:0] pulse_trigs_last_readout,   // # of pulse triggers during last readout

    input  wire m_pulse_fifo_tready,
    output wire m_pulse_fifo_tvalid,
    output wire [127:0] m_pulse_fifo_tdata,

    output wire [23:0] ttc_event_num,      // channel's trigger number
    output wire [23:0] ttc_trig_num,       // global trigger number
    output wire [ 4:0] ttc_trig_type,      // trigger type
    output wire [43:0] ttc_trig_timestamp, // trigger timestamp
    output wire [ 3:0] ttc_xadc_alarms,    // XADC alarms

    input wire [22:0] readout_size_chan0,
    input wire [22:0] readout_size_chan1,
    input wire [22:0] readout_size_chan2,
    input wire [22:0] readout_size_chan3,
    input wire [22:0] readout_size_chan4,

    input wire [22:0] burst_count_chan0,
    input wire [22:0] burst_count_chan1,
    input wire [22:0] burst_count_chan2,
    input wire [22:0] burst_count_chan3,
    input wire [22:0] burst_count_chan4,

    input wire [11:0] wfm_count_chan0,
    input wire [11:0] wfm_count_chan1,
    input wire [11:0] wfm_count_chan2,
    input wire [11:0] wfm_count_chan3,
    input wire [11:0] wfm_count_chan4,

    // status connections
    input  wire async_mode,            // asynchronous mode select
    input  wire cbuf_mode,             // TTC-triggered circular buffer mode select
    input  wire [ 3:0] xadc_alarms,    // XADC alarm signals
    output wire [ 3:0] ttr_state,      // TTC trigger receiver state
    output wire [ 4:0] ptr_state,      // pulse trigger receiver state
    output wire [ 3:0] cac_state,      // channel acquisition controller state
    output wire [ 3:0] caca_state,     // channel acquisition controller (asynchronous) state
    output wire [ 3:0] cacc_state,     // channel acquisition controller (cbuf) state
    output wire [ 6:0] tp_state,       // trigger processor state
    output wire [23:0] trig_num,       // global trigger number
    output wire [43:0] trig_timestamp, // timestamp for latest trigger received
    output wire trig_fifo_full,        // TTC trigger FIFO is almost full
    output wire pulse_fifo_full,       // pulse trigger FIFO is almost full
    output wire acq_fifo_full,         // acquisition event FIFO is almost full
    //output wire [31:0] ext_pulse_delta_t,    // latched time between triggers in this processor

    // number of bursts stored in the DDR3
    output wire [22:0] stored_bursts_chan0,
    output wire [22:0] stored_bursts_chan1,
    output wire [22:0] stored_bursts_chan2,
    output wire [22:0] stored_bursts_chan3,
    output wire [22:0] stored_bursts_chan4,

    // error connections
    output wire [31:0] ddr3_overflow_count, // number of triggers received that would overflow DDR3
    output wire ddr3_almost_full,           // DDR3 overflow warning
    (* mark_debug = "true" *) output wire error_trig_rate,            // trigger rate error
    output wire error_trig_num,             // trigger number error
    output wire error_trig_type             // trigger type error
);

    // -------------------
    // signal declarations
    // -------------------

    // signals between Channel Acquisition Controllers and Channel FPGAs
    wire [9:0] chan_enable_sync, chan_enable_async, chan_enable_cbuf;
    wire [4:0] chan_trig_sync, chan_trig_async, chan_trig_cbuf;

    // signals between TTC Trigger Receiver and Channel Acquisition Controllers
    (* mark_debug = "true" *) wire acq_ready;
    (* mark_debug = "true" *) wire acq_ready_sync, acq_ready_async, acq_ready_cbuf;
    wire acq_activated;
    wire acq_trigger;
    wire [ 4:0] acq_trig_type;
    wire [23:0] acq_trig_num;

    // signals between Pulse Trigger Receiver and Channel Acquisition Controllers
    wire pulse_trigger;

    // signals to/from TTC Trigger FIFO
    wire s_trig_fifo_tready;
    wire s_trig_fifo_tvalid;
    wire [127:0] s_trig_fifo_tdata;

    wire m_trig_fifo_tready;
    wire m_trig_fifo_tvalid;
    wire [127:0] m_trig_fifo_tdata;

    wire [22:0] stored_bursts_chan0_ttr;
    wire [22:0] stored_bursts_chan1_ttr;
    wire [22:0] stored_bursts_chan2_ttr;
    wire [22:0] stored_bursts_chan3_ttr;
    wire [22:0] stored_bursts_chan4_ttr;

    // signals to/from Pulse Trigger FIFO
    wire s_pulse_fifo_tready;
    wire s_pulse_fifo_tvalid;
    wire [127:0] s_pulse_fifo_tdata;

    wire [22:0] stored_bursts_chan0_ptr;
    wire [22:0] stored_bursts_chan1_ptr;
    wire [22:0] stored_bursts_chan2_ptr;
    wire [22:0] stored_bursts_chan3_ptr;
    wire [22:0] stored_bursts_chan4_ptr;

    // signals to/from Acquisition Event FIFO
    wire s_acq_fifo_tready;
    wire s_acq_fifo_tvalid;
    wire [31:0] s_acq_fifo_tdata;

    wire s_acq_fifo_tvalid_sync;
    wire [31:0] s_acq_fifo_tdata_sync;

    wire s_acq_fifo_tvalid_async;
    wire [31:0] s_acq_fifo_tdata_async;

    wire s_acq_fifo_tvalid_cbuf;
    wire [31:0] s_acq_fifo_tdata_cbuf;

    wire m_acq_fifo_tready;
    wire m_acq_fifo_tvalid;
    wire [31:0] m_acq_fifo_tdata;

    // error signals
    wire [31:0] ddr3_overflow_count_ttr;
    wire [31:0] ddr3_overflow_count_ptr;

    wire ddr3_almost_full_ttr;
    wire ddr3_almost_full_ptr;

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

    wire readout_done_clk40;
    sync_2stage readout_done_sync (
        .clk(ttc_clk),
        .in(readout_done_toggle),
        .out(readout_done_clk40)
    );

    // toggle synchronize async_readout_done
    wire async_readout_done_toggle;
    toggle_sync_2stage async_readout_done_toggle_sync (
        .clk_in(clk125),
        .clk_out(ttc_clk),
        .n_extra_cycles(8'h0A),
        .in(async_readout_done),
        .out(async_readout_done_toggle)
    );

    wire async_readout_done_clk40;
    sync_2stage async_readout_done_sync (
        .clk(ttc_clk),
        .in(async_readout_done_toggle),
        .out(async_readout_done_clk40)
    );

    // synchronize and delay readout_size
    wire [22:0] readout_size_chan0_delay1, readout_size_chan0_delay2, readout_size_chan0_delay3, readout_size_chan0_clk40;
    sync_2stage #( .WIDTH(23) ) readout_size_chan0_sync1 ( .clk(ttc_clk), .in(readout_size_chan0),        .out(readout_size_chan0_delay1) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan0_sync2 ( .clk(ttc_clk), .in(readout_size_chan0_delay1), .out(readout_size_chan0_delay2) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan0_sync3 ( .clk(ttc_clk), .in(readout_size_chan0_delay2), .out(readout_size_chan0_delay3) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan0_sync4 ( .clk(ttc_clk), .in(readout_size_chan0_delay3), .out(readout_size_chan0_clk40)  );

    wire [22:0] readout_size_chan1_delay1, readout_size_chan1_delay2, readout_size_chan1_delay3, readout_size_chan1_clk40;
    sync_2stage #( .WIDTH(23) ) readout_size_chan1_sync1 ( .clk(ttc_clk), .in(readout_size_chan1),        .out(readout_size_chan1_delay1) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan1_sync2 ( .clk(ttc_clk), .in(readout_size_chan1_delay1), .out(readout_size_chan1_delay2) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan1_sync3 ( .clk(ttc_clk), .in(readout_size_chan1_delay2), .out(readout_size_chan1_delay3) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan1_sync4 ( .clk(ttc_clk), .in(readout_size_chan1_delay3), .out(readout_size_chan1_clk40)  );

    wire [22:0] readout_size_chan2_delay1, readout_size_chan2_delay2, readout_size_chan2_delay3, readout_size_chan2_clk40;
    sync_2stage #( .WIDTH(23) ) readout_size_chan2_sync1 ( .clk(ttc_clk), .in(readout_size_chan2),        .out(readout_size_chan2_delay1) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan2_sync2 ( .clk(ttc_clk), .in(readout_size_chan2_delay1), .out(readout_size_chan2_delay2) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan2_sync3 ( .clk(ttc_clk), .in(readout_size_chan2_delay2), .out(readout_size_chan2_delay3) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan2_sync4 ( .clk(ttc_clk), .in(readout_size_chan2_delay3), .out(readout_size_chan2_clk40)  );

    wire [22:0] readout_size_chan3_delay1, readout_size_chan3_delay2, readout_size_chan3_delay3, readout_size_chan3_clk40;
    sync_2stage #( .WIDTH(23) ) readout_size_chan3_sync1 ( .clk(ttc_clk), .in(readout_size_chan3),        .out(readout_size_chan3_delay1) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan3_sync2 ( .clk(ttc_clk), .in(readout_size_chan3_delay1), .out(readout_size_chan3_delay2) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan3_sync3 ( .clk(ttc_clk), .in(readout_size_chan3_delay2), .out(readout_size_chan3_delay3) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan3_sync4 ( .clk(ttc_clk), .in(readout_size_chan3_delay3), .out(readout_size_chan3_clk40)  );

    wire [22:0] readout_size_chan4_delay1, readout_size_chan4_delay2, readout_size_chan4_delay3, readout_size_chan4_clk40;
    sync_2stage #( .WIDTH(23) ) readout_size_chan4_sync1 ( .clk(ttc_clk), .in(readout_size_chan4),        .out(readout_size_chan4_delay1) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan4_sync2 ( .clk(ttc_clk), .in(readout_size_chan4_delay1), .out(readout_size_chan4_delay2) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan4_sync3 ( .clk(ttc_clk), .in(readout_size_chan4_delay2), .out(readout_size_chan4_delay3) );
    sync_2stage #( .WIDTH(23) ) readout_size_chan4_sync4 ( .clk(ttc_clk), .in(readout_size_chan4_delay3), .out(readout_size_chan4_clk40)  );

    // ----------------
    // signal stretches
    // ----------------

    wire pulse_trigger_stretch;
    signal_stretch pulse_trigger_stretch_inst (
        .signal_in(pulse_trigger),
        .clk(ttc_clk),
        .n_extra_cycles(8'h02),
        .signal_out(pulse_trigger_stretch) // 75-ns wide
    );

    // -------------------
    // signal multiplexers
    // -------------------

    // signals between Channel Acquisition Controllers and Channel FPGAs
    assign chan_enable[9:0] = (async_mode) ? chan_enable_async[9:0] : (cbuf_mode) ? chan_enable_cbuf[9:0] : chan_enable_sync[9:0];
    assign chan_trig[4:0]   = (async_mode) ? chan_trig_async[4:0]   : (cbuf_mode) ? chan_trig_cbuf[4:0]   : chan_trig_sync[4:0];

    // signals between TTC Trigger Receiver and Channel Acquisition Controllers
    assign acq_ready = (async_mode) ? acq_ready_async : (cbuf_mode) ? acq_ready_cbuf : acq_ready_sync;

    // signals to/from Acquisition Event FIFO
    assign s_acq_fifo_tvalid      = (async_mode) ? s_acq_fifo_tvalid_async      : (cbuf_mode) ? s_acq_fifo_tvalid_cbuf      : s_acq_fifo_tvalid_sync;
    assign s_acq_fifo_tdata[31:0] = (async_mode) ? s_acq_fifo_tdata_async[31:0] : (cbuf_mode) ? s_acq_fifo_tdata_sync[31:0] : s_acq_fifo_tdata_sync[31:0];

    // signals between TTC Trigger Receiver and Pulse Trigger Receiver
    assign stored_bursts_chan0[22:0] = (async_mode) ? stored_bursts_chan0_ptr[22:0] : stored_bursts_chan0_ttr[22:0];
    assign stored_bursts_chan1[22:0] = (async_mode) ? stored_bursts_chan1_ptr[22:0] : stored_bursts_chan1_ttr[22:0];
    assign stored_bursts_chan2[22:0] = (async_mode) ? stored_bursts_chan2_ptr[22:0] : stored_bursts_chan2_ttr[22:0];
    assign stored_bursts_chan3[22:0] = (async_mode) ? stored_bursts_chan3_ptr[22:0] : stored_bursts_chan3_ttr[22:0];
    assign stored_bursts_chan4[22:0] = (async_mode) ? stored_bursts_chan4_ptr[22:0] : stored_bursts_chan4_ttr[22:0];

    // error signals
    assign ddr3_overflow_count[31:0] = (async_mode) ? ddr3_overflow_count_ptr[31:0] : ddr3_overflow_count_ttr[31:0];
    assign ddr3_almost_full          = (async_mode) ? ddr3_almost_full_ptr          : ddr3_almost_full_ttr;


    // ----------------
    // module instances
    // ----------------

    // TTC trigger receiver module
    ttc_trigger_receiver ttc_trigger_receiver (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40),

        // TTC Channel B resets
        .reset_trig_num(rst_trigger_num),
        .reset_trig_timestamp(rst_trigger_timestamp),

        // trigger interface
        .trigger(ttc_trigger),                           // TTC trigger signal
        .trig_type(trig_type),                           // trigger type
        .trig_settings(trig_settings),                   // trigger settings
        .thres_ddr3_overflow(thres_ddr3_overflow[22:0]), // DDR3 overflow threshold
        .chan_en(chan_en_clk40),                         // enabled channels
        .pulse_trig_num(pulse_trig_num),                 // pulse trigger number
        .pulse_trigger(pulse_trigger_stretch),           // front panel trigger signal to channels

        // command manager interface
        .readout_done(readout_done_clk40), // a readout has completed

        .readout_size_chan0(readout_size_chan0_clk40), // readout size for Channel 0
        .readout_size_chan1(readout_size_chan1_clk40), // readout size for Channel 1
        .readout_size_chan2(readout_size_chan2_clk40), // readout size for Channel 2
        .readout_size_chan3(readout_size_chan3_clk40), // readout size for Channel 3
        .readout_size_chan4(readout_size_chan4_clk40), // readout size for Channel 4

        .burst_count_chan0(burst_count_chan0), // burst count set for Channel 0
        .burst_count_chan1(burst_count_chan1), // burst count set for Channel 1
        .burst_count_chan2(burst_count_chan2), // burst count set for Channel 2
        .burst_count_chan3(burst_count_chan3), // burst count set for Channel 3
        .burst_count_chan4(burst_count_chan4), // burst count set for Channel 4

        .wfm_count_chan0(wfm_count_chan0), // waveform count set for Channel 0
        .wfm_count_chan1(wfm_count_chan1), // waveform count set for Channel 1
        .wfm_count_chan2(wfm_count_chan2), // waveform count set for Channel 2
        .wfm_count_chan3(wfm_count_chan3), // waveform count set for Channel 3
        .wfm_count_chan4(wfm_count_chan4), // waveform count set for Channel 4

        // channel acquisition controller interface
        .acq_ready(acq_ready),         // channels are ready to acquire/readout data
        .acq_activated(acq_activated),
        .acq_trigger(acq_trigger),     // trigger signal
        .acq_trig_type(acq_trig_type), // recongized trigger type (muon fill, laser, pedestal, async readout)
        .acq_trig_num(acq_trig_num),   // trigger number, starts at 1

        // interface to TTC Trigger FIFO
        .fifo_ready(s_trig_fifo_tready),
        .fifo_valid(s_trig_fifo_tvalid),
        .fifo_data(s_trig_fifo_tdata),

        // status connections
        .async_mode(async_mode),                       // asynchronous mode select
        .accept_pulse_triggers(accept_pulse_triggers), // accept front panel triggers select
        .xadc_alarms(xadc_alarms[3:0]),                // XADC alarm signals
        .state(ttr_state),                             // state of finite state machine
        .trig_num(trig_num),                           // global trigger number
        .trig_timestamp(trig_timestamp),               // global trigger timestamp
        
        // number of bursts stored in the DDR3
        .stored_bursts_chan0(stored_bursts_chan0_ttr),
        .stored_bursts_chan1(stored_bursts_chan1_ttr),
        .stored_bursts_chan2(stored_bursts_chan2_ttr),
        .stored_bursts_chan3(stored_bursts_chan3_ttr),
        .stored_bursts_chan4(stored_bursts_chan4_ttr),

        // error connections
        .ddr3_overflow_count(ddr3_overflow_count_ttr), // number of triggers received that would overflow DDR3
        .ddr3_almost_full(ddr3_almost_full_ttr),       // DDR3 overflow warning
        .error_trig_rate(error_trig_rate)              // trigger rate error
    );


    // pulse trigger receiver module
    pulse_trigger_receiver pulse_trigger_receiver (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40),

        // TTC Channel B resets
        .reset_trig_num(rst_trigger_num),
        .reset_trig_timestamp(rst_trigger_timestamp),

        // trigger interface
        .trigger(ext_trigger),                           // front panel trigger signal
        .thres_ddr3_overflow(thres_ddr3_overflow[22:0]), // DDR3 overflow threshold
        .chan_en(chan_en_clk40),                         // enabled channels
        .fp_trig_width(fp_trig_width[3:0]),              // width to separate short from long front panel triggers
        .ttc_trigger(ttc_trigger),                       // backplane trigger signal
        .ttc_acq_ready(acq_ready_async),                 // channels are ready to acquire/readout data
        .pulse_trigger(pulse_trigger),                   // channel trigger signal
        .trig_num(pulse_trig_num),                       // pulse trigger number
        .accepted_ext_trigger_count(accepted_ext_trigger_count),  // cumulative asynchronous pulse trigger number
        .pulse_trigs_last_readout(pulse_trigs_last_readout),      // # asynchronous pulse triggers read by last TTC readout
        //.ext_pulse_delta_t(ext_pulse_delta_t),           // latched time between triggers in this processor

        // interface to Pulse Trigger FIFO
        .fifo_ready(s_pulse_fifo_tready),
        .fifo_valid(s_pulse_fifo_tvalid),
        .fifo_data(s_pulse_fifo_tdata),

        // command manager interface
        .readout_done(async_readout_done_clk40), // for counter reset

        // set burst count for each channel
        .burst_count_chan0(burst_count_chan0), // burst count set for Channel 0
        .burst_count_chan1(burst_count_chan1), // burst count set for Channel 1
        .burst_count_chan2(burst_count_chan2), // burst count set for Channel 2
        .burst_count_chan3(burst_count_chan3), // burst count set for Channel 3
        .burst_count_chan4(burst_count_chan4), // burst count set for Channel 4

        // number of bursts stored in the DDR3
        .stored_bursts_chan0(stored_bursts_chan0_ptr),
        .stored_bursts_chan1(stored_bursts_chan1_ptr),
        .stored_bursts_chan2(stored_bursts_chan2_ptr),
        .stored_bursts_chan3(stored_bursts_chan3_ptr),
        .stored_bursts_chan4(stored_bursts_chan4_ptr),

        // status connections
        .accept_pulse_triggers(accept_pulse_triggers), // accept front panel triggers select
        .async_mode(async_mode),                       // asynchronous mode select
        .state(ptr_state),                             // state of finite state machine

        // error connections
        .ddr3_overflow_count(ddr3_overflow_count_ptr), // number of triggers received that would overflow DDR3
        .ddr3_almost_full(ddr3_almost_full_ptr)       // DDR3 overflow warning
    );

    
    // channel acquisition controller module (synchronous)
    channel_acq_controller channel_acq_controller (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40),

        // trigger configuration
        .chan_en(chan_en_clk40), // which channels should receive the trigger
        .trig_delay(trig_delay), // delay between receiving trigger and passing it onto channels

        // interface from TTC trigger receiver
        .trigger(acq_trigger),      // trigger signal
        .trig_type(acq_trig_type),  // recognized trigger type (muon fill, laser, pedestal, async readout)
        .trig_num(acq_trig_num),    // trigger number
        .acq_ready(acq_ready_sync), // channels are ready to acquire data

        // interface to Channel FPGAs
        .acq_dones(chan_dones_clk40),
        .acq_enable(chan_enable_sync),
        .acq_trig(chan_trig_sync),

        // interface to Acquisition Event FIFO
        .fifo_ready(s_acq_fifo_tready),
        .fifo_valid(s_acq_fifo_tvalid_sync),
        .fifo_data(s_acq_fifo_tdata_sync),

        // status connections
        .async_mode(async_mode), // asynchronous mode select
        .cbuf_mode(cbuf_mode),
        .state(cac_state)        // state of finite state machine
    );

    // channel acquisition controller module (synchronous)
    channel_acq_controller_cbuf channel_acq_controller_cbuf (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40),
    
        // trigger configuration
        .chan_en(chan_en_clk40), // which channels should receive the trigger
        .trig_delay(trig_delay), // delay between receiving trigger and passing it onto channels
    
        // interface from TTC trigger receiver
        .trigger(acq_trigger),      // trigger signal
        .trig_type(acq_trig_type),  // recognized trigger type (muon fill, laser, pedestal, async readout)
        .trig_num(acq_trig_num),    // trigger number
        .acq_ready(acq_ready_cbuf), // channels are ready to acquire data
    
        // interface to Channel FPGAs
        .acq_dones(chan_dones_clk40),
        .acq_enable(chan_enable_cbuf),
        .acq_trig(chan_trig_cbuf),
    
        // interface to Acquisition Event FIFO
        .fifo_ready(s_acq_fifo_tready),
        .fifo_valid(s_acq_fifo_tvalid_cbuf),
        .fifo_data(s_acq_fifo_tdata_cbuf),
    
        // status connections
        .async_mode(async_mode), // asynchronous mode select
        .cbuf_mode(cbuf_mode),
        .state(cacc_state)        // state of finite state machine
    );



    // channel acquisition controller module (asynchronous)
    channel_acq_controller_async channel_acq_controller_async (
        // clock and reset
        .clk(ttc_clk),   // 40 MHz TTC clock
        .reset(reset40),

        // trigger configuration
        .chan_en(chan_en_clk40),                       // which channels should receive the trigger
        .accept_pulse_triggers(accept_pulse_triggers), // accept front panel triggers select

        // command manager interface
        .readout_done(readout_done_clk40), // a readout has completed

        // interface from TTC trigger receiver
        .ttc_trigger(acq_trigger),         // trigger signal
        .ttc_trig_type(acq_trig_type),     // recognized trigger type (muon fill, laser, async readout)
        .ttc_trig_num(acq_trig_num),       // trigger number
        .ttc_acq_ready(acq_ready_async),   // channels are ready to acquire/readout data
        .ttc_acq_activated(acq_activated),

        // interface from pulse trigger receiver
        .pulse_trigger(pulse_trigger_stretch), // trigger signal

        // interface to Channel FPGAs
        .acq_dones(chan_dones_clk40),
        .acq_enable(chan_enable_async),
        .acq_trig(chan_trig_async),

        // interface to Acquisition Event FIFO
        .fifo_ready(s_acq_fifo_tready),
        .fifo_valid(s_acq_fifo_tvalid_async),
        .fifo_data(s_acq_fifo_tdata_async),

        // status connections
        .async_mode(async_mode), // asynchronous mode select
        .state(caca_state)       // state of finite state machine
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

        .ttc_event_num(ttc_event_num),           // channel's trigger number
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
        .axis_prog_full(trig_fifo_full)     // output
    );


    // Pulse Trigger FIFO : 2048 depth, 2047 almost full threshold, 16-byte data width
    // Increased FIFO to 8192 depth, and 8191 almost full thresold, to accommodate higher
    // front panel trigger rates between TTC readouts
    // holds the trigger timestamp, trigger nuber, and trigger type from the front panel
    trigger_info_fifo_pulse pulse_trigger_fifo (
        // writing side
        .s_aclk(ttc_clk),                    // input
        .s_aresetn(reset40_n),               // input
        .s_axis_tvalid(s_pulse_fifo_tvalid), // input
        .s_axis_tready(s_pulse_fifo_tready), // output
        .s_axis_tdata(s_pulse_fifo_tdata),   // input  [127:0]

        // reading side
        .m_aclk(clk125),                     // input
        .m_axis_tvalid(m_pulse_fifo_tvalid), // output
        .m_axis_tready(m_pulse_fifo_tready), // input
        .m_axis_tdata(m_pulse_fifo_tdata),   // output [127:0]
      
        // FIFO almost full port
        .axis_prog_full(pulse_fifo_full)     // output
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
        .axis_prog_full(acq_fifo_full)     // output
    );

endmodule
