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

    // channel interface
    input  wire [4:0] chan_dones,
    output wire [9:0] chan_enable,
    output wire [4:0] chan_trig,

    // command manager interface
    input  wire readout_ready,         // command manager is idle
    input  wire readout_done,          // initiated readout has finished
    input  wire [22:0] readout_size,   // burst count of readout event
    output wire send_empty_event,      // request an empty event
    output wire initiate_readout,      // request for the channels to be read out
    output wire [23:0] pulse_trig_num, // pulse trigger number

    input  wire m_pulse_fifo_tready,
    output wire m_pulse_fifo_tvalid,
    output wire [127:0] m_pulse_fifo_tdata,

    output wire [23:0] ttc_event_num,      // channel's trigger number
    output wire [23:0] ttc_trig_num,       // global trigger number
    output wire [ 4:0] ttc_trig_type,      // trigger type
    output wire [43:0] ttc_trig_timestamp, // trigger timestamp

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
    output wire [ 3:0] ttr_state,      // TTC trigger receiver state
    output wire [ 3:0] ptr_state,      // pulse trigger receiver state
    output wire [ 3:0] cac_state,      // channel acquisition controller state
    output wire [ 3:0] caca_state,     // channel acquisition controller (asynchronous) state
    output wire [ 6:0] tp_state,       // trigger processor state
    output wire [23:0] trig_num,       // global trigger number
    output wire [43:0] trig_timestamp, // timestamp for latest trigger received
    output wire trig_fifo_full,        // TTC trigger FIFO is almost full
    output wire acq_fifo_full,         // acquisition event FIFO is almost full

    // number of bursts stored in the DDR3
    output wire [22:0] stored_bursts_chan0,
    output wire [22:0] stored_bursts_chan1,
    output wire [22:0] stored_bursts_chan2,
    output wire [22:0] stored_bursts_chan3,
    output wire [22:0] stored_bursts_chan4,

    // error connections
    output wire [31:0] ddr3_overflow_count, // number of triggers received that would overflow DDR3
    output wire ddr3_overflow_warning,      // DDR3 overflow warning
    output wire error_trig_rate,            // trigger rate error
    output wire error_trig_num,             // trigger number error
    output wire error_trig_type             // trigger type error
);

    // -------------------
    // signal declarations
    // -------------------

    // signals between Channel Acquisition Controllers and Channel FPGAs
    wire [9:0] chan_enable_sync, chan_enable_async;
    wire [4:0] chan_trig_sync, chan_trig_async;

    // signals between TTC Trigger Receiver and Channel Acquisition Controllers
    wire acq_ready;
    wire acq_ready_sync, acq_ready_async;
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

    // signals to/from Pulse Trigger FIFO
    wire s_pulse_fifo_tready;
    wire s_pulse_fifo_tvalid;
    wire [127:0] s_pulse_fifo_tdata;

    // signals to/from Acquisition Event FIFO
    wire s_acq_fifo_tready;
    wire s_acq_fifo_tvalid;
    wire [31:0] s_acq_fifo_tdata;

    wire s_acq_fifo_tvalid_sync;
    wire [31:0] s_acq_fifo_tdata_sync;

    wire s_acq_fifo_tvalid_async;
    wire [31:0] s_acq_fifo_tdata_async;

    wire m_acq_fifo_tready;
    wire m_acq_fifo_tvalid;
    wire [31:0] m_acq_fifo_tdata;

    // error signals
    wire [31:0] ddr3_overflow_count_ttr;
    wire [31:0] ddr3_overflow_count_ptr;

    wire ddr3_overflow_warning_ttr;
    wire ddr3_overflow_warning_ptr;

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
    wire readout_done_clk40;
    toggle_sync_2stage readout_done_sync (
        .clk_in(clk125),
        .clk_out(ttc_clk),
        .n_extra_cycles(8'h0F),
        .in(readout_done),
        .out(readout_done_clk40)
    );

    // synchronize readout_size
    wire [22:0] readout_size_clk40;
    sync_2stage #(
        .WIDTH(23)
    ) readout_size_sync (
        .clk(ttc_clk),
        .in(readout_size),
        .out(readout_size_clk40)
    );

    // -------------------
    // signal multiplexers
    // -------------------

    // signals between Channel Acquisition Controllers and Channel FPGAs
    assign chan_enable[9:0] = (async_mode) ? chan_enable_async[9:0] : chan_enable_sync[9:0];
    assign chan_trig[4:0]   = (async_mode) ? chan_trig_async[4:0]   : chan_trig_sync[4:0];

    // signals between TTC Trigger Receiver and Channel Acquisition Controllers
    assign acq_ready = (async_mode) ? acq_ready_async : acq_ready_sync;

    // signals to/from Acquisition Event FIFO
    assign s_acq_fifo_tvalid      = (async_mode) ? s_acq_fifo_tvalid_async      : s_acq_fifo_tvalid_sync;
    assign s_acq_fifo_tdata[31:0] = (async_mode) ? s_acq_fifo_tdata_async[31:0] : s_acq_fifo_tdata_sync[31:0];

    // error signals
    assign ddr3_overflow_count[31:0] = (async_mode) ? ddr3_overflow_count_ptr[31:0] : ddr3_overflow_count_ttr[31:0];
    assign ddr3_overflow_warning     = (async_mode) ? ddr3_overflow_warning_ptr     : ddr3_overflow_warning_ttr;
    
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

        // command manager interface
        .readout_done(readout_done_clk40), // a readout has completed
        .readout_size(readout_size_clk40), // burst count of readout event

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
        .acq_trigger(acq_trigger),     // trigger signal
        .acq_trig_type(acq_trig_type), // recongized trigger type (muon fill, laser, pedestal, async readout)
        .acq_trig_num(acq_trig_num),   // trigger number, starts at 1

        // interface to TTC Trigger FIFO
        .fifo_ready(s_trig_fifo_tready),
        .fifo_valid(s_trig_fifo_tvalid),
        .fifo_data(s_trig_fifo_tdata),

        // status connections
        .async_mode(async_mode),         // asynchronous mode select
        .state(ttr_state),               // state of finite state machine
        .trig_num(trig_num),             // global trigger number
        .trig_timestamp(trig_timestamp), // global trigger timestamp
        
        // number of bursts stored in the DDR3
        .stored_bursts_chan0(stored_bursts_chan0),
        .stored_bursts_chan1(stored_bursts_chan1),
        .stored_bursts_chan2(stored_bursts_chan2),
        .stored_bursts_chan3(stored_bursts_chan3),
        .stored_bursts_chan4(stored_bursts_chan4),

        // error connections
        .ddr3_overflow_count(ddr3_overflow_count_ttr),     // number of triggers received that would overflow DDR3
        .ddr3_overflow_warning(ddr3_overflow_warning_ttr), // DDR3 overflow warning
        .error_trig_rate(error_trig_rate)                  // trigger rate error
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
        .pulse_trigger(pulse_trigger),                   // channel trigger signal
        .trig_num(pulse_trig_num),                       // pulse trigger number

        // interface to Pulse Trigger FIFO
        .fifo_ready(s_pulse_fifo_tready),
        .fifo_valid(s_pulse_fifo_tvalid),
        .fifo_data(s_pulse_fifo_tdata),

        // command manager interface
        .readout_done(readout_done_clk40), // for counter reset

        // set burst count for each channel
        .burst_count_chan0(burst_count_chan0), // burst count set for Channel 0
        .burst_count_chan1(burst_count_chan1), // burst count set for Channel 1
        .burst_count_chan2(burst_count_chan2), // burst count set for Channel 2
        .burst_count_chan3(burst_count_chan3), // burst count set for Channel 3
        .burst_count_chan4(burst_count_chan4), // burst count set for Channel 4

        // status connections
        .state(ptr_state), // state of finite state machine

        // error connections
        .ddr3_overflow_count(ddr3_overflow_count_ptr),    // number of triggers received that would overflow DDR3
        .ddr3_overflow_warning(ddr3_overflow_warning_ptr) // DDR3 overflow warning
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
        .state(cac_state)        // state of finite state machine
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
        .ttc_trigger(acq_trigger),       // trigger signal
        .ttc_trig_type(acq_trig_type),   // recognized trigger type (muon fill, laser, async readout)
        .ttc_trig_num(acq_trig_num),     // trigger number
        .ttc_acq_ready(acq_ready_async), // channels are ready to readout data

        // interface from pulse trigger receiver
        .pulse_trigger(pulse_trigger), // trigger signal

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
        .initiate_readout(initiate_readout), // request for the channels to be read out

        .ttc_event_num(ttc_event_num),           // channel's trigger number
        .ttc_trig_num(ttc_trig_num),             // global trigger number
        .ttc_trig_type(ttc_trig_type),           // trigger type
        .ttc_trig_timestamp(ttc_trig_timestamp), // trigger timestamp

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
    // holds the trigger timestamp, trigger nuber, and trigger type from the front panel
    trigger_info_fifo pulse_trigger_fifo (
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
