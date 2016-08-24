`ifndef __QUEUE_SPI_H_
`define __QUEUE_SPI_H_

// Request an SPI write from top-level SPI master instance
`define SPI_NONE        4'h0
`define SPI_DDS         4'h1
`define SPI_MSYN        4'h2
`define SPI_RSYN		4'h3
`define SPI_FR          4'h4
`define SPI_MBW			4'h5
`define SPI_PWR         4'h6

`ifdef X7_CORE
    // Write out initialization values to all SPI registers on enable
    `define DDS_CFR1_BYTES      5
    `define DDS_CFR2_BYTES      6
    `define DDS_PCR_BYTES       9
    `define RSYN_BYTES          3
    `define FR_BYTES            3
    `define MSYN_BYTES          3
    `define MBW_BYTES           1
`endif    

`endif
