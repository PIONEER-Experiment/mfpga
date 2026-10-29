# Master firmware simulations (Icarus Verilog, `iverilog -g2012`)

`tb_eor.v` — `ttc_trigger_receiver_selftrigc` + `channel_acq_controller_selftrigc` + `trigger_processor`:
triggers during the run, a trigger while the controller is still flushing the previous one, the FC7
end-of-run stop followed by regular and final triggers. The processor must end in IDLE with both FIFOs
drained and the receiver must never reach ERROR.

    iverilog -g2012 -o sim tb_eor.v ../hdl/selftrigc_mode_only/ttc_trigger_receiver_selftrigc.v \
        ../hdl/selftrigc_mode_only/channel_acq_controller_selftrigc.v ../hdl/trigger_processor.v ../hdl/sync_2stage.v && vvp sim

`tb_command_manager.v` — `command_manager_selftrigc` recovery from bad channel replies: a stale frame in
front of a live channel's reply (flushed, retried, the fill read), a channel that never answers (time-out,
skipped), a channel that answers late (its reply is the next readout's stale frame), a stale fill header
(read fill re-issued), a newer header (channel skipped, not fatal), an IPbus transaction to a dead channel
(time-out, back to IDLE) and one with a stale frame in front of the reply, and an event in which every
channel was skipped (a well-formed empty event). The time-outs are forced short with `force`.
Needs `constants.vh` on the include path.

    iverilog -g2012 -I ../hdl -o sim tb_command_manager.v ../hdl/selftrigc_mode_only/command_manager_selftrigc.v pipeline_2stage_model.v && vvp sim
