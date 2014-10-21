Revisions:

2014-04-30  initial version with some bugs
2014-05-07  release_1.0
2014-05-28  updated (but as yet untested) version; works with Kintex 0x8104 and 0x204
2014-06-02  another update with various bug fixes; REQUIRES Kintex >= 0x8106
  or >= 0x207
2014-06-02  trunk copied as release_1.1
2014-09-09  replace Xilinx FIFO with fifo66x512.vhd
	    Link version now 5
2014-10-18  Link version now 6 plus some other bug fixes

In module's declaration or its instantiation, set the following
two generic parameters accroding to your design:

F_REFCLK is the frequency of the GTX reference clock
USE_TRIGGER_PORT is default to false, but if you have trigger data
to be sent through the link, you must set it to true and provide
the trigger data together with BC0 and TTCclk.

please include the following line in your xst file:

create_clock -period 4.000 -name DAQ_usrclk [get_pins */i_DAQ_Link_7s/i_UsrClk/o]

where i_DAQ_Link_7s is the instance name of the module DAQ_Link_7s
in its upper level module.

This zip file includes following files:

DAQ_Link_7s.vhd		top level module
FIFO_rest_7S.vhd
EthernetCRCD32.vhd
CRC16D16.vhd
TTS_TRIG_if.vhd
RAM32x6Db.vhd
Hamming.vhd
DAQLINK_7s_init.vhd
DAQLINK_7s.vhd
DAQLINK_7s_gt.vhd
DAQLINK_7s_sync_block.vhd
DAQLINK_7s_tx_startup_fsm.vhd
DAQLINK_7s_rx_startup_fsm.vhd
ReadMe.txt		this file
