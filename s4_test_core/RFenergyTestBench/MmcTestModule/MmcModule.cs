using System;
using RFModule;
using Interfaces;

namespace MmcTestModule
{
    public class MmcModule : RFBaseModule, IOpcodes
    {
        MmcDebug.MmcDebug   _mmc { get; set; }
        Opcodes             _opcodes { get; set; }

        public override int Initialize(string logFile)
        {
            _opcodes = new Opcodes();
            _mmc = new MmcDebug.MmcDebug();
            return _mmc.OpenMmcDevice("\\\\.\\PhysicalDrive1");
        }

        public override void Close()
        {
            if(_mmc != null)
                _mmc.CloseMmcDevice();
        }

        public override string Status
        {
            get
            {
                string abc = "";
                _mmc.GetLastMmcStatus(ref abc);
                return abc;
            }
        }

        public override string ErrorDescription(int errorCode)
        {
            if (errorCode == 5)
            {
                return "Access Denied, must run as Administrator, " + Status;
            }
            else if(errorCode == 87)
            {
                return "Opcode block must be ingegral multiple of 512 bytes.";
            }
            else return Status;
        }

        public override string FPGAversion
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public override int LoopDelayMs
        {
            get
            {
                throw new NotImplementedException();
            }

            set
            {
                throw new NotImplementedException();
            }
        }

        public override bool LoopReadings
        {
            get
            {
                throw new NotImplementedException();
            }

            set
            {
                throw new NotImplementedException();
            }
        }

        public override int RunCmd(string command)
        {
            throw new NotImplementedException();
        }

        public override int RunCmd(byte[] command)
        {
            throw new NotImplementedException();
        }

        public override int RunCmd(string command, ref string response)
        {
            throw new NotImplementedException();
        }

        public override int RunCmd(byte[] command, ref byte[] response)
        {
            // Offset opcodes to sector 2
            byte[] cmd = new byte[Opcodes.OPCODE_BLOCK * 2];
            Array.Copy(command, 0, cmd, 512, command.Length);
            int status, s2;
            status = _mmc.WriteMmcDevice(cmd);
            s2 = _mmc.ReadMmcDevice(ref response);
            if (status == 0)
                status = s2;
            return status;
        }

        public override int WrRdSPI(int device, ref byte[] data)
        {
            throw new NotImplementedException();
        }

        public int FrequencyOpcode(double frequency, ref byte[] opcode)
        {
            _opcodes.frequency(frequency, ref opcode);
            return 0;
        }

        public int PowerOpcode(short channel, double power, ref byte[] opcode)
        {
            _opcodes.power(channel, power, ref opcode);
            return 0;
        }

        public int PhaseOpcode(short channel, double phase, ref byte[] opcode)
        {
            _opcodes.phase(channel, phase, ref opcode);
            return 0;
        }

        public int PulseOpcode(short channel, double width, double measureAt, ref byte[] opcode)
        {
            _opcodes.pulse(channel, width, measureAt, ref opcode);
            return 0;
        }

        public int BiasOpcode(short channel, bool state, ref byte[] opcode)
        {
            _opcodes.bias(channel, state, ref opcode);
            return 0;
        }

        public int EchoOpcode(byte[] dataIn, ref byte[] opcode)
        {
            _opcodes.echo(dataIn, ref opcode);
            return 0;
        }

        public int StatusOpcode(ref byte[] opcode)
        {
            _opcodes.status(ref opcode);
            return 0;
        }

        public int ModeOpcode(uint bits, ref byte[] opcode)
        {
            _opcodes.mode(bits, ref opcode);
            return 0;
        }

        public int TrigConfOpcode(int word1, int word2, ref byte[] opcode)
        {
            throw new NotImplementedException();
        }

        public int SyncConfOpcode(int sync1, int sync2, ref byte[] opcode)
        {
            throw new NotImplementedException();
        }

        public int PaintfOpcode(int pat1, int oat2, ref byte[] opcode)
        {
            throw new NotImplementedException();
        }

        public int MeasureOpcode(int channel, int expected, ref byte[] opcode)
        {
            throw new NotImplementedException();
        }

        public int ParseReadings(byte[] readings, double[] magnitude, double[] phase)
        {
            throw new NotImplementedException();
        }

        public int ResetOpcode(ref byte[] opecode)
        {
            throw new NotImplementedException();
        }

        public int PatclkOpcode(int tick, ref byte[] opcode)
        {
            throw new NotImplementedException();
        }

        public int PatadrOpcode(int address, ref byte[] opcode)
        {
            throw new NotImplementedException();
        }

        public int PatctlOpcode(int patbits, ref byte[] opcode)
        {
            throw new NotImplementedException();
        }

        public override int SetFrequency(double frequency)
        {
            int status;
            byte[] cmd = null;
            byte[] rsp = null;
            status = FrequencyOpcode(frequency * 1.0e6, ref cmd);
            if (status == 0)
                status = RunCmd(cmd, ref rsp);
            return status;
        }
    }
}
