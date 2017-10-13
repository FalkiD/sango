
namespace Interfaces
{
    public class InstrumentInfo
    {
        public enum InstrumentType
        {
            Source,
            Meter,
            Analyzer,
            General,
            S4,
            M2,
            X7
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
