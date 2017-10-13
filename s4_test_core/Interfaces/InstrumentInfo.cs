
namespace Interfaces
{
    public class InstrumentInfo
    {
        public enum InstrumentType
        {
            Source,
            Meter,
            Analyzer,
            General
        };

        public enum Interface
        {
            GPIB,
            USB,
            LXI,
            PXI,
            RS232,
            RS485,
            Other
        }
    }
}
