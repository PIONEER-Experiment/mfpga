# Master firmware simulations (Icarus Verilog, `iverilog -g2012`)

`tb_eor.v` — `ttc_trigger_receiver_selftrigc` + `channel_acq_controller_selftrigc` + `trigger_processor`:
triggers during the run, a trigger while the controller is still flushing the previous one, the FC7
end-of-run stop followed by regular and final triggers. The processor must end in IDLE with both FIFOs
drained and the receiver must never reach ERROR.

    iverilog -g2012 -o sim tb_eor.v ../hdl/selftrigc_mode_only/ttc_trigger_receiver_selftrigc.v \
        ../hdl/selftrigc_mode_only/channel_acq_controller_selftrigc.v ../hdl/trigger_processor.v ../hdl/sync_2stage.v && vvp sim

`tb_command_manager.v` — `command_manager_selftrigc` readout with a stale frame in channel 0's RX FIFO
(serial-number mismatch: the frame must be flushed to its tlast and the readout continue with channel 1)
and a channel that never answers (time-out, then continue). Needs `constants.vh` on the include path.

    iverilog -g2012 -I ../hdl -o sim tb_command_manager.v ../hdl/selftrigc_mode_only/command_manager_selftrigc.v pipeline_2stage_model.v && vvp sim
