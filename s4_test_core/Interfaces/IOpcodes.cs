/*
 *  Generate opcodes for the (S4/X7) MMC interface 
 */
 namespace Interfaces
{
    public interface IOpcodes
    {
        int FrequencyOpcode(double frequency, ref byte[] opcode);
        int PowerOpcode(short channel, double power, ref byte[] opcode);
        int PhaseOpcode(short channel, double phase, ref byte[] opcode);
        int PulseOpcode(short channel, double width, double measureAt, ref byte[] opcode);
        int BiasOpcode(short channel, bool state, ref byte[] opcode);
        int EchoOpcode(byte[] dataIn, ref byte[] opcode);
        int StatusOpcode(ref byte[] opcode);
        int ModeOpcode(uint bits, ref byte[] opcode);
        int TrigConfOpcode(int word1, int word2, ref byte[] opcode);
        int SyncConfOpcode(int sync1, int sync2, ref byte[] opcode);
        int PaintfOpcode(int pat1, int oat2, ref byte[] opcode);
        int MeasureOpcode(int channel, int expected, ref byte[] opcode);
        int ParseReadings(byte[] readings, double[] magnitude, double[] phase);
        int ResetOpcode(ref byte[] opecode);
        int PatclkOpcode(int tick, ref byte[] opcode);
        int PatadrOpcode(int address, ref byte[] opcode);
        int PatctlOpcode(int patbits, ref byte[] opcode);
    }
}
