/*
    Created 13-Jul-2016
    Different modules will request access from the SPI bus arbiter 
    to the single SPI processor. Definitions here for the arbiter
    module.
*/
`ifndef __spi_arbiter_v_
`define __spi_arbiter_v_

`define SPI_ACCESSORS   8

// Modules that need SPI access
`define INIT_SPI    8'b00000001
`define FREQ_SPI    5'b00000010
`define PWR_SPI     5'b00000100
`define PHS_SPI     5'b00001000
`define PAT_SPI     5'b00010000
`define BIAS_SPI    5'b00100000

// Corresponding mux selectors, 5 of 8 used so far
`define MUX_INIT    0
`define MUX_FREQ    1
`define MUX_POWER   2
`define MUX_PHASE   3
`define MUX_PATN    4
`define MUX_BIAS    5

`endif