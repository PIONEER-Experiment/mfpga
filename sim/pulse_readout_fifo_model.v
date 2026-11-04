// Behavioural model of the pulse_readout_fifo IP (AXI4-Stream FIFO, 128 bits) for tb_command_manager_std.v
module pulse_readout_fifo(input s_aclk, input s_aresetn, input s_axis_tvalid, output s_axis_tready, input [127:0] s_axis_tdata,
  output m_axis_tvalid, input m_axis_tready, output [127:0] m_axis_tdata, output axis_prog_full, output wr_rst_busy, output rd_rst_busy);
  reg [127:0] mem [0:2047]; integer wr=0, rd=0;
  assign s_axis_tready = 1'b1; assign m_axis_tvalid = (wr != rd); assign m_axis_tdata = mem[rd % 2048];
  assign axis_prog_full = 0; assign wr_rst_busy = 0; assign rd_rst_busy = 0;
  always @(posedge s_aclk) begin
    if (!s_aresetn) begin wr = 0; rd = 0; end
    else begin if (m_axis_tvalid && m_axis_tready) rd = rd + 1; if (s_axis_tvalid) begin mem[wr % 2048] = s_axis_tdata; wr = wr + 1; end end
  end
endmodule
