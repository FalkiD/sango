
using System.Collections.Generic;

namespace Interfaces
{
    // define useful delegates
    public delegate void MessageCallback(string msg);
    public delegate void BooleanEvent(bool parameter, string msg);
    public delegate void DoubleEvent(double parameter, string msg);
    public delegate void IntegerEvent(int parameter, string msg);
    public delegate void SetPowerEvent(double dbmOut, double dbIn, string msg);

    /// <summary>
    /// All functions throw ApplicationException on failure
    /// with the error description filled-in
    /// </summary>
    public interface IInstrument
    {
        event MessageCallback ShowMessage;
        event DoubleEvent FrequencyEvent;
        event IntegerEvent AveragesEvent;
        event BooleanEvent TrigInEnEvent;
        event BooleanEvent TrigInvertEvent;
        event IntegerEvent TrigInTmoEvent;
        event BooleanEvent TrigOutEnEvent;
        event BooleanEvent DutyCycleEnEvent;
        event IntegerEvent DutyCyclePcntEvent;
        event BooleanEvent OffsetEnEvent;
        event DoubleEvent OffsetEvent;
        event BooleanEvent ExtTrigEvent;

        string ID { get; }

        string Version { get; }

        string Name { get; }

        List<string> Names { get; }

        string Description { get; }

        InstrumentInfo.InstrumentType InstrumentType { get; }

        InstrumentInfo.Interface Interface { get; }

        bool Online { get; }

        double[] HeadOffsets { get; set; }
 
        /// <summary>
        /// Startup resource
        /// </summary>
        /// <param name="resourceEnumerator">Enumeration string such as NI VISA enumeration string</param>
        /// <param name="device">Specific device being sought, for example GPIB0::13::INSTR</param>
        void Startup(string resourceEnumerator, string device);

        void Startup();

        void Reset();

        void Shutdown();

        void SetFrequency(double mHz);

        void SetPowerUnits(int units);

        void SetAverages(int average);

        void Write(string scpi);

        void Write(byte[] data);

        string Read();

        string Read(string readCommand);

        double Result(string readCommand);

        double ReadCw(bool continuous);

        double ReadPulsed(bool continuous);

        bool TriggerInEnable { get; set; }

        bool TriggerInvert { get; set; }

        int TriggerInTimeout { get; set; }

        bool TriggerOutEnable { get; set; }

        bool DutyCycleEnable { get; set; }

        int DutyCyclePercent { get; set; }

        bool OffsetEnable { get; set; }

        double Offset { get; set; }

        bool ExternalTrigger { get; set; }
    }
}
