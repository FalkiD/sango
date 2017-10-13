namespace Interfaces
{
    public class RfSettings
    {
        public RfSettings()
        {
            ErrorMessage = "";  // used as an error flag in some cases
        }
        public double   Frequency;
        public double   Power;
        public double   Phase;
        public int      PwmDutyCycle;
        public int      PwmRateHz;
        public int      AdcDelayUs;
        public double   PwrInDb;
        public string   ErrorMessage;
    }
}
