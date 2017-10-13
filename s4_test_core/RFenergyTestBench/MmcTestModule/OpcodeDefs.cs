namespace MmcTestModule
{
    public class OpcodeDefs
    {
        // We're processing opcode blocks received as 512 byte MMC sectors
        public const short MMC_SECTOR_SIZE  = 512;

        // Each hardware unit will have 64K of address space
        public const int UNIT_SIZE          = 0x10000;

        // MMC address targets what the command is for
        //#define MMC_ADR_MAINCTRL	0x00000000
        //#define MMC_ADR_CHANNEL1	(MMC_ADR_MAINCTRL + 1 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL2	(MMC_ADR_MAINCTRL + 2 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL3	(MMC_ADR_MAINCTRL + 3 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL4	(MMC_ADR_MAINCTRL + 4 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL5	(MMC_ADR_MAINCTRL + 5 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL6	(MMC_ADR_MAINCTRL + 6 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL7	(MMC_ADR_MAINCTRL + 7 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL8	(MMC_ADR_MAINCTRL + 8 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL9	(MMC_ADR_MAINCTRL + 9 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL10	(MMC_ADR_MAINCTRL + 10 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL11	(MMC_ADR_MAINCTRL + 11 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL12	(MMC_ADR_MAINCTRL + 12 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL13	(MMC_ADR_MAINCTRL + 13 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL14	(MMC_ADR_MAINCTRL + 14 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL15	(MMC_ADR_MAINCTRL + 15 * UNIT_SIZE)
        //#define MMC_ADR_CHANNEL16	(MMC_ADR_MAINCTRL + 16 * UNIT_SIZE)

        //#define MMC_ADR_MAINMEAS	0x00110000
        //#define MMC_ADR_MEAS1		(MMC_ADR_MAINMEAS + 1 * UNIT_SIZE)
        //#define MMC_ADR_MEAS2		(MMC_ADR_MAINMEAS + 2 * UNIT_SIZE)
        //#define MMC_ADR_MEAS3		(MMC_ADR_MAINMEAS + 3 * UNIT_SIZE)
        //#define MMC_ADR_MEAS4		(MMC_ADR_MAINMEAS + 4 * UNIT_SIZE)
        //#define MMC_ADR_MEAS5		(MMC_ADR_MAINMEAS + 5 * UNIT_SIZE)
        //#define MMC_ADR_MEAS6		(MMC_ADR_MAINMEAS + 6 * UNIT_SIZE)
        //#define MMC_ADR_MEAS7		(MMC_ADR_MAINMEAS + 7 * UNIT_SIZE)
        //#define MMC_ADR_MEAS8		(MMC_ADR_MAINMEAS + 8 * UNIT_SIZE)
        //#define MMC_ADR_MEAS9		(MMC_ADR_MAINMEAS + 9 * UNIT_SIZE)
        //#define MMC_ADR_MEAS10		(MMC_ADR_MAINMEAS + 10 * UNIT_SIZE)
        //#define MMC_ADR_MEAS11		(MMC_ADR_MAINMEAS + 11 * UNIT_SIZE)
        //#define MMC_ADR_MEAS12		(MMC_ADR_MAINMEAS + 12 * UNIT_SIZE)
        //#define MMC_ADR_MEAS13		(MMC_ADR_MAINMEAS + 13 * UNIT_SIZE)
        //#define MMC_ADR_MEAS14		(MMC_ADR_MAINMEAS + 14 * UNIT_SIZE)
        //#define MMC_ADR_MEAS15		(MMC_ADR_MAINMEAS + 15 * UNIT_SIZE)
        //#define MMC_ADR_MEAS16		(MMC_ADR_MAINMEAS + 16 * UNIT_SIZE)

        //#define MMC_ADR_MAINPTN		0x00210000
        //#define MMC_ADR_PTN1		(MMC_ADR_MAINPTN + 1 * UNIT_SIZE)
        //#define MMC_ADR_PTN2		(MMC_ADR_MAINPTN + 2 * UNIT_SIZE)
        //#define MMC_ADR_PTN3		(MMC_ADR_MAINPTN + 3 * UNIT_SIZE)
        //#define MMC_ADR_PTN4		(MMC_ADR_MAINPTN + 4 * UNIT_SIZE)
        //#define MMC_ADR_PTN5		(MMC_ADR_MAINPTN + 5 * UNIT_SIZE)
        //#define MMC_ADR_PTN6		(MMC_ADR_MAINPTN + 6 * UNIT_SIZE)
        //#define MMC_ADR_PTN7		(MMC_ADR_MAINPTN + 7 * UNIT_SIZE)
        //#define MMC_ADR_PTN8		(MMC_ADR_MAINPTN + 8 * UNIT_SIZE)
        //#define MMC_ADR_PTN9		(MMC_ADR_MAINPTN + 9 * UNIT_SIZE)
        //#define MMC_ADR_PTN10		(MMC_ADR_MAINPTN + 10 * UNIT_SIZE)
        //#define MMC_ADR_PTN11		(MMC_ADR_MAINPTN + 11 * UNIT_SIZE)
        //#define MMC_ADR_PTN12		(MMC_ADR_MAINPTN + 12 * UNIT_SIZE)
        //#define MMC_ADR_PTN13		(MMC_ADR_MAINPTN + 13 * UNIT_SIZE)
        //#define MMC_ADR_PTN14		(MMC_ADR_MAINPTN + 14 * UNIT_SIZE)
        //#define MMC_ADR_PTN15		(MMC_ADR_MAINPTN + 15 * UNIT_SIZE)
        //#define MMC_ADR_PTN16		(MMC_ADR_MAINPTN + 16 * UNIT_SIZE)

        //#define MMC_ADR_MAINCAL		0x00310000
        //#define MMC_ADR_CAL1		(MMC_ADR_MAINCAL + 1 * UNIT_SIZE)
        //#define MMC_ADR_CAL2		(MMC_ADR_MAINCAL + 2 * UNIT_SIZE)
        //#define MMC_ADR_CAL3		(MMC_ADR_MAINCAL + 3 * UNIT_SIZE)
        //#define MMC_ADR_CAL4		(MMC_ADR_MAINCAL + 4 * UNIT_SIZE)
        //#define MMC_ADR_CAL5		(MMC_ADR_MAINCAL + 5 * UNIT_SIZE)
        //#define MMC_ADR_CAL6		(MMC_ADR_MAINCAL + 6 * UNIT_SIZE)
        //#define MMC_ADR_CAL7		(MMC_ADR_MAINCAL + 7 * UNIT_SIZE)
        //#define MMC_ADR_CAL8		(MMC_ADR_MAINCAL + 8 * UNIT_SIZE)
        //#define MMC_ADR_CAL9		(MMC_ADR_MAINCAL + 9 * UNIT_SIZE)
        //#define MMC_ADR_CAL10		(MMC_ADR_MAINCAL + 10 * UNIT_SIZE)
        //#define MMC_ADR_CAL11		(MMC_ADR_MAINCAL + 11 * UNIT_SIZE)
        //#define MMC_ADR_CAL12		(MMC_ADR_MAINCAL + 12 * UNIT_SIZE)
        //#define MMC_ADR_CAL13		(MMC_ADR_MAINCAL + 13 * UNIT_SIZE)
        //#define MMC_ADR_CAL14		(MMC_ADR_MAINCAL + 14 * UNIT_SIZE)
        //#define MMC_ADR_CAL15		(MMC_ADR_MAINCAL + 15 * UNIT_SIZE)
        //#define MMC_ADR_CAL16		(MMC_ADR_MAINCAL + 16 * UNIT_SIZE)

        public const byte PTN_RUN           = 0x0001;
        public const byte PTN_STEP          = 0x0002;
        public const byte PTN_RST           = 0x0004;
        public const byte PTN_ABORT         = 0x0008;
        public const byte PTN_END           = 0x0010;

        // Opcodes, 7 bits
        // General & config opcodes, 0x00 based
        public const byte CMD_MAIN          = 0x00;
        public const byte TERMINATOR        = (0 + CMD_MAIN);
        public const byte STATUS            = (1 + CMD_MAIN);
        public const byte FREQ              = (2 + CMD_MAIN);
        public const byte POWER             = (3 + CMD_MAIN);
        public const byte PHASE             = (4 + CMD_MAIN);
        public const byte PULSE             = (5 + CMD_MAIN);
        public const byte BIAS              = (6 + CMD_MAIN);
        public const byte MODE              = (7 + CMD_MAIN);
        public const byte LENGTH            = (8 + CMD_MAIN);
        public const byte TRIGCONF          = (9 + CMD_MAIN);
        public const byte SYNCCONF          = (10 + CMD_MAIN);
        public const byte PAINTFCFG         = (11 + CMD_MAIN);
        public const byte ECHO              = (12 + CMD_MAIN);
        public const byte CMD_PATTERNS	    = 0x20;
        public const byte PATCLK            = (0 + CMD_PATTERNS);
        public const byte PATADR            = (1 + CMD_PATTERNS);
        public const byte PATCTL            = (2 + CMD_PATTERNS);
        public const byte BRANCH            = (3 + CMD_PATTERNS);

        public const byte CMD_MEASURE		= 0x30;
        public const byte MEAS_ZMSIZE       = (0 + CMD_MEASURE);
        public const byte MEAS_ZMCTL        = (1 + CMD_MEASURE);

        public const byte CMD_DEBUG			= 0x40;
        public const byte DBG_ATTENSPI      = (0 + CMD_DEBUG);
        public const byte DBG_LEVELSPI      = (1 + CMD_DEBUG);
        public const byte DBG_OPCTRL        = (2 + CMD_DEBUG);
        public const byte DBG_IQCTRL        = (3 + CMD_DEBUG);
        public const byte DBG_IQSPI         = (4 + CMD_DEBUG);
        public const byte DBG_IQDATA        = (5 + CMD_DEBUG);
        public const byte DBG_FLASHSPI      = (6 + CMD_DEBUG);
        public const byte DBG_DDSSPI        = (7 + CMD_DEBUG);
        public const byte DBG_RSYNSPI       = (8 + CMD_DEBUG);
        public const byte DBG_MSYNSPI       = (9 + CMD_DEBUG);
        public const byte DBG_MBWSPI        = (10 + CMD_DEBUG);
        public const byte DBG_READREG       = (11 + CMD_DEBUG);

            // Array sizes for debug SPI registers
        public const byte BYTES_ATTEN       = 4;
        public const byte BYTES_LEVEL		= 2;
        public const byte BYTES_OP			= 2;
        public const byte BYTES_IQCTRL		= 2;
        public const byte BYTES_IQSPI		= 8;
        public const byte BYTES_IQDATA		= 4;
        //public const byte BYTES_FLASH		= 260;
        public const byte BYTES_DDS			= 8;
        public const byte BYTES_RSYN		= 4;
        public const byte BYTES_MSYN		= 4;
        public const byte BYTES_MBW			= 2;

    }
}
