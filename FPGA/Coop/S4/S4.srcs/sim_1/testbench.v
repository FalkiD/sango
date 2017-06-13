`timescale 1ns / 1ps

`define BUF_WIDTH 8
`define ENTRIES 512

module testbench();

    reg         clk = 0, rst;
    
    wire [3:0]  led;
    wire [3:0]  sw;
    wire [2:0]  BTN;
    wire [3:0]  rgb_grn;

    reg         SYN_MISO = 0;
    wire        SYN_MOSI;
    wire        SYN_SCLK;
    wire        DDS_SSN;
    wire        RSYN_SSN;
    wire        MSYN_SSN;
    wire        FR_SSN;
    wire        MBW_SSN;

    wire        gp107;
    wire        gp106;
    wire        gp105;
    wire        gp104;
    wire        gp103;
    wire        gp102;
    wire        gp101;
    wire        gp100;
    wire        uart_txd;
    wire        uart_rxd;

    top main(.CLK(clk),
            .RST(rst),
            .LED(led),

            .SYN_MISO(SYN_MISO),
            .SYN_MOSI(SYN_MOSI),
            .SYN_SCLK(SYN_SCLK),

            .DDS_SSN(DDS_SSN),
            .RSYN_SSN(RSYN_SSN),
            .MSYN_SSN(MSYN_SSN),
            .FR_SSN(FR_SSN),
            .MBW_SSN(MBW_SSN),

            // Coop's debugger uart module!
            .SW(sw),               // ARTY slide switches.
            .btn(BTN),              // ARTY pushbuttons (Using BTN[3] as external reset).
            .RGB_GRN(rgb_grn),          // ARTY regular LEDs               (ARTY LD7 - LD4).
            .JD_GPIO7(gp107),         // JD is farthest PMod from USB, Ethernet, Power barrel end of ARTY
            .JD_GPIO6(gp106),
            .JD_GPIO5(gp105),
            .JD_GPIO4(gp104),
            .JD_GPIO3(gp103),
            .JD_GPIO2(gp102),
            .JD_GPIO1(gp101),
            .JD_GPIO0(gp100),
            .UART_TXD(uart_txd),         // ARTY USB-SerialBridge ---> FPGA (Not JTAG).
            .UART_RXD(uart_rxd)          // ARTY USB-SerialBridge <--- FPGA (Not JTAG).
            );

    initial
    begin
        clk = 0;
        rst = 1;
        #15 rst = 0;
    end

    // let it rip...
    always
        begin
            #5 clk = ~clk;
        end

endmodule