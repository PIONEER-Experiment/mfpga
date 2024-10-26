// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (lin64) Build 4029153 Fri Oct 13 20:13:54 MDT 2023
// Date        : Thu Oct 10 16:32:11 2024
// Host        : lkgVivadoContainer running 64-bit Ubuntu 22.04.4 LTS
// Command     : write_verilog -force -mode synth_stub /home/user/mfpga/ip/ila_master/ila_master_stub.v
// Design      : ila_master
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k160tfbg676-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2023.2" *)
module ila_master(clk, probe0, probe1, probe2, probe3, probe4, probe5, 
  probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13, probe14, probe15, probe16, probe17, 
  probe18, probe19, probe20, probe21)
/* synthesis syn_black_box black_box_pad_pin="probe0[19:0],probe1[19:0],probe2[127:0],probe3[127:0],probe4[19:0],probe5[19:0],probe6[19:0],probe7[0:0],probe8[0:0],probe9[23:0],probe10[23:0],probe11[34:0],probe12[21:0],probe13[31:0],probe14[31:0],probe15[3:0],probe16[3:0],probe17[3:0],probe18[31:0],probe19[0:0],probe20[0:0],probe21[0:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input clk /* synthesis syn_isclock = 1 */;
  input [19:0]probe0;
  input [19:0]probe1;
  input [127:0]probe2;
  input [127:0]probe3;
  input [19:0]probe4;
  input [19:0]probe5;
  input [19:0]probe6;
  input [0:0]probe7;
  input [0:0]probe8;
  input [23:0]probe9;
  input [23:0]probe10;
  input [34:0]probe11;
  input [21:0]probe12;
  input [31:0]probe13;
  input [31:0]probe14;
  input [3:0]probe15;
  input [3:0]probe16;
  input [3:0]probe17;
  input [31:0]probe18;
  input [0:0]probe19;
  input [0:0]probe20;
  input [0:0]probe21;
endmodule
