# Master firmware simulations (Icarus Verilog, `iverilog -g2012`)

`tb_eor.v` — `ttc_trigger_receiver_selftrigc` + `channel_acq_controller_selftrigc` + `trigger_processor`:
triggers during the run, a trigger while the controller is still flushing the previous one, the FC7
end-of-run stop followed by regular and final triggers. The processor must end in IDLE with both FIFOs
drained and the receiver must never reach ERROR.

    iverilog -g2012 -o sim tb_eor.v ../hdl/selftrigc_mode_only/ttc_trigger_receiver_selftrigc.v \
        ../hdl/selftrigc_mode_only/channel_acq_controller_selftrigc.v ../hdl/trigger_processor.v ../hdl/sync_2stage.v && vvp sim

`tb_error_capture.v` — `error_capture` (`hdl/error_capture.v`, common to the master images since 6.8.0; was
`error_capture_selftrigc` from 6.6.10): the first loss or fault freezes the snapshot
(status 35-49) and sets the TTS flags, later errors accumulate, warnings do not snapshot, a TTC-domain
pulse is caught, the clear empties everything and the next error snapshots again.

    iverilog -g2012 -o sim tb_error_capture.v ../hdl/error_capture.v && vvp sim

`tb_command_manager.v` — `command_manager_selftrigc` with the header-first readout (6.7.0: every channel's
fill header is peeked before any fill is read, the AMC13 event size is computed from the peeked waveform
counts and checked against the words actually sent; 6.8.0: no trigger-line count record, and
`hdr_monitor_selftrigc` is driven from the headers) and recovery
from bad channel replies (6.6.9/6.6.10, with the error pulses each case must raise and the marks in the data
stream): a stale frame in front of a live channel's reply (flushed, retried, the fill read), a channel that
never answers (time-out, skipped, left out of the event size), a channel that answers late (its reply is the
next readout's stale frame), a stale fill header (discarded by the channel at the peek, no re-issue), a newer
header (channel skipped, not fatal), an IPbus transaction to a dead channel (time-out, back to IDLE) and one
with a stale frame in front of the reply, an event in which every channel was skipped (a well-formed empty
event), channel-reported error words, a checksum mismatch, the header monitor (per-channel waveform totals =
waveforms read, bursts in the last fill, the DDR3 overflow warning set by a fill over the threshold and
cleared by the next one under it and by the end-of-run clear), CHECK_SELFTRIG_FIFO never entered, and a
peek answered with an error code. The channel model holds a queue of fill headers per channel and streams real waveform data with the
right checksum. The time-outs are forced short with `force`. Needs `constants.vh` on the include path
(a three-line stub with MAJOR/MINOR/PATCH_REV is enough; the run takes a few minutes).

    iverilog -g2012 -I ../hdl -o sim tb_command_manager.v ../hdl/selftrigc_mode_only/command_manager_selftrigc.v \
        ../hdl/selftrigc_mode_only/hdr_monitor_selftrigc.v pipeline_2stage_model.v && vvp sim

## Standard image (`hdl/standard_mode_only`, 6.8.0)

`tb_command_manager_std.v` — the standard `command_manager` with the readout hardening ported from the
self-triggering image: a stale frame in front of a reply (flushed, retried), a silent channel (time-out,
skipped, loss pulse), a late reply (the next readout's stale frame), a stale fill, a newer
fill (both terminal: ERROR_TRIG_NUM and a fill-number loss, then a reset clears it), IPbus to a dead channel and with a stale frame, every channel skipped (a
well-formed empty event), a checksum mismatch (fault), a trigger-type mismatch (skipped, not fatal), async mode
with a skipped channel (the pulse records stored for it are drained before the next readout), and a channel
that stops mid-fill (ERROR_DATA_CORRUPTION, fault).  The channel model streams real fills with the right
checksum in the standard header format.

    iverilog -g2012 -I ../hdl -o sim tb_command_manager_std.v ../hdl/standard_mode_only/command_manager.v \
        pulse_readout_fifo_model.v ../hdl/sync_2stage.v && vvp sim

`tb_ttc_trigger_receiver_std.v` — a trigger while the channels are still acquiring is answered with an empty
event at once (not passed on, not delayed), counted, pulses `empty_midrun` and latches `error_trig_rate`; the
receiver stays in service.

    iverilog -g2012 -o sim tb_ttc_trigger_receiver_std.v ../hdl/standard_mode_only/ttc_trigger_receiver.v && vvp sim

`tb_acq_controller_std.v` — `channel_acq_controller`: FILL is bounded; on the time-out the event is stored and
`wait_gave_up` pulses once (the cbuf and async controllers have the same bound).

    iverilog -g2012 -o sim tb_acq_controller_std.v ../hdl/standard_mode_only/channel_acq_controller.v && vvp sim

`tb_ttr_downgrade.v` — `ttc_trigger_receiver_selftrigc`: a readout trigger downgraded in SEND_TRIGGER (the
acquisition controller stayed busy past the bound) reaches the trigger FIFO marked empty.  Fails before 6.8.0:
the flag was set in the same clock as the FIFO word was taken, so the downgraded trigger was written as a real
one and the trigger processor waited for an acquisition record that never came.

    iverilog -g2012 -o sim tb_ttr_downgrade.v ../hdl/selftrigc_mode_only/ttc_trigger_receiver_selftrigc.v ../hdl/sync_2stage.v && vvp sim
