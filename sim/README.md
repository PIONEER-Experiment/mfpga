# Master firmware simulations (Icarus Verilog, `iverilog -g2012`)

`tb_eor.v` — `ttc_trigger_receiver_selftrigc` + `channel_acq_controller_selftrigc` + `trigger_processor`:
triggers during the run, a trigger while the controller is still flushing the previous one, the FC7
end-of-run stop followed by regular and final triggers. The processor must end in IDLE with both FIFOs
drained and the receiver must never reach ERROR.

    iverilog -g2012 -o sim tb_eor.v ../hdl/selftrigc_mode_only/ttc_trigger_receiver_selftrigc.v \
        ../hdl/selftrigc_mode_only/channel_acq_controller_selftrigc.v ../hdl/trigger_processor.v ../hdl/sync_2stage.v && vvp sim

`tb_error_capture.v` — `error_capture_selftrigc` (6.6.10): the first loss or fault freezes the snapshot
(status 35-49) and sets the TTS flags, later errors accumulate, warnings do not snapshot, a TTC-domain
pulse is caught, the clear empties everything and the next error snapshots again.

    iverilog -g2012 -o sim tb_error_capture.v ../hdl/selftrigc_mode_only/error_capture_selftrigc.v && vvp sim

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
