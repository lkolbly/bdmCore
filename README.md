BDM Core
========

This is a Verilog core that can talk the BDC interface to communicate with RS08 MCUs.

Also included is code which can convert a simple serial language into instructions for the BDM engine.

Dependencies
============

In order to use the bdm_interface module, you will need two FIFO modules with the following specifications:
```
module fifo_8x128(
  clk,
  rst,
  din,
  wr_en,
  rd_en,
  dout,
  full,
  empty,
  valid,
  underflow
);

input clk;
input rst;
input [7 : 0] din;
input wr_en;
input rd_en;
output [7 : 0] dout;
output full;
output empty;
output valid;
output underflow;

endmodule;
```

and a 16 bit wide core:

```
module fifo_16x1024(
  clk,
  rst,
  din,
  wr_en,
  rd_en,
  dout,
  full,
  empty,
  valid,
  underflow,
  data_count
);

input clk;
input rst;
input [15 : 0] din;
input wr_en;
input rd_en;
output [15 : 0] dout;
output full;
output empty;
output valid;
output underflow;
output [9 : 0] data_count;

endmodule;
```

These modules can be generated using the Xilinx FIFO Generator. (tested with FIFO Generator version 9.3)

Module Layout
=============

There are 6 modules in the src/ directory:
* bdc_interface.v: This module manages the lowest level of the protocol, and manages talking directly with the chip. It can read or write data in 8-bit words. If is_sending is high, then bkgd should be pulled low, otherwise it should be high Z and bkgd_in should be supplied the value of the bkgd pin.
* bdc_clk_pulse_generator.v: This module simply outputs a pulse at the calculated target clock frequency (set by pulsing set_sync_length when sync_length is set to the number of clock cycles that the SYNC reply consumed). The output pulse may not be regular, and may jitter by up to 1 FPGA clock cycle.
* sync_controller.v: This module manages the SYNC command. The BKGD pin I/O is the same as in bdc_interface.v. When the ready line is high, the start_sync line can be pulled high to start a SYNC command. After the SYNC command completes, sync_length_is_ready will be asserted and sync_length will contain the number of cycles that the target's SYNC response took. This value is passed to bdc_clk_pulse_generator.
* startup_controller.v: This module manages powering on (and off) the target chip. It will start the MCU when start is asserted (including pulling BKGD low while the chip is powering on), and will turn off power when stop is asserted.
* bdm.v: This module ties together the above four modules into a functional BDM. It can execute six commands, selected by asserting the corresponding line. See below for the BDM commands.
* bdm_interface.v: This module interfaces the bdm module to a serial interface. The serial format is described below. new_rx_data should be asserted when new serial data has arrived, with rx_data containing the data. new_tx_data is asserted when serial data should be sent, with tx_data being asserted. If serial data cannot be sent, tx_block should be held high. And data sent while tx_block is high will be re-sent once tx_block is pulled low.

BDM Commands
============

There are six commands, a data_in field, and a data_out field, each 8 bits. A command may only be asserted when ready is asserted. When a command returns data, valid will be asserted for a single clock cycle, with data_out containing the data to return.

* do_read: This reads 8 bits from the target MCU, returning the byte read.
* do_write: This writes 8 bits to the target MCU (data is from data_in).
* do_start_mcu: This powers on the MCU.
* do_stop_mcu: This powers down the MCU.
* do_delay: This will delay for 16*data_in number of clock cycles.
* do_echo_test: This simply returns data_in to data_out. Useful for testing communication with the BDM.

Serial Interface
================

The interface consists of a series of 8-bit commands, a 16-bit command FIFO, and an 8-bit return FIFO. Return data in the 8-bit FIFO is returned as fast as possible over the serial line. When the BDM engine is running, it consumes instructions from the 16-bit FIFO.

The 16-bit commands consist of three parts: 4 reserved bits (bits 15:12), 4 opcode bits (11:8), and 8 data_in bits (7:0). The opcodes are:

* 0: No-op
* 1: do_read
* 2: do_write
* 3: do_start_mcu
* 4: do_stop_mcu
* 5: do_echo_test
* 6: do_delay

The serial commands are as follows:

* If the high bit is 1, the remaining 7 bits (6:0) are interpreted as the number of 16-bit words to write directly into the command FIFO. The next 2*N bytes are written directly into the command FIFO.
* Otherwise... If the command == 0: The BDM engine will stop executing instructions.
* 1: The BDM engine will start executing instructions.
* 2: The value 55 (decimal) will be immediately written (echoed) to the serial port.
* 3: The BDM interface, BDM, and all subcomponents will be held in reset for 255 clock cycles.
* 4: Retrieves bits 7:0 of data_count of the 16-bit FIFO.
* 5: Retrieves bits 15:0 of data_count of the 16-bit FIFO.

TODO/Known Issues
=================

* There is a bug with the SYNC command, sometimes it doesn't come up. Once it runs, rst must be asserted before it runs again.
* do_delay should wait the specified number of _target_ clock cycles.
