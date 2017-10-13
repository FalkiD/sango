using System;

namespace MmcTestModule
{
    public class Opcodes
    {
        public const double POWER_MULTIPLIER = 255.0;      //pow(2,8)-1.0)
        public const double POWER_LSB = (1.0 / POWER_MULTIPLIER);
        public const ushort OPCODE_BLOCK = 512;

        //#define PHASE_MULTIPLIER	(pow(2,6)-1.0)
        //#define PHASE_LSB			(1.0/PHASE_MULTIPLIER)

        //#define BIAS_MULTIPLIER		(pow(2,12)-1.0)
        //#define BIAS_LSB			(1.0/BIAS_MULTIPLIER)

        //public void bytesFromUint16(ushort data, ref byte[] next, ref short pIndex)
        //{
        //    next[pIndex++] = (byte)(data & 0xff);
        //    next[pIndex++] = (byte)((data >> 8) & 0xff);
        //}

        //public ushort uint16FromBytes(ref byte[] data)
        //{
        //    ushort tmp = data[0];
        //    tmp |= (byte)(data[1] << 8);
        //    return tmp;
        //}

        //public void bytesFromUint32(uint data, ref byte[] next, ref short pIndex)
        //{
        //    next[pIndex++] = (byte)(data & 0xff);
        //    next[pIndex++] = (byte)((data >> 8) & 0xff);
        //    next[pIndex++] = (byte)((data >> 16) & 0xff);
        //    next[pIndex++] = (byte)((data >> 24) & 0xff);
        //}

        //public uint uint32FromBytes(ref byte[] data)
        //{
        //    uint tmp = data[0];
        //    tmp |= (uint)(data[1] << 8);
        //    tmp |= (uint)(data[2] << 16);
        //    tmp |= (uint)(data[3] << 24);
        //    return tmp;
        //}

        //public void bytesFromUint64(ulong data, ref byte[] next, ref short pIndex)
        //{
        //    next[pIndex++] = (byte)(data & 0xff);
        //    next[pIndex++] = (byte)((data >> 8) & 0xff);
        //    next[pIndex++] = (byte)((data >> 16) & 0xff);
        //    next[pIndex++] = (byte)((data >> 24) & 0xff);
        //    next[pIndex++] = (byte)((data >> 32) & 0xff);
        //    next[pIndex++] = (byte)((data >> 40) & 0xff);
        //    next[pIndex++] = (byte)((data >> 48) & 0xff);
        //    next[pIndex++] = (byte)((data >> 56) & 0xff);
        //}

        //public ulong uint64FromBytes(ref byte[] data)
        //{
        //    ulong tmp = data[0];
        //    tmp |= (uint)(data[1] << 8);
        //    tmp |= (uint)(data[2] << 16);
        //    tmp |= (uint)(data[3] << 24);
        //    tmp |= (uint)(data[4] << 32);
        //    tmp |= (uint)(data[5] << 40);
        //    tmp |= (uint)(data[6] << 48);
        //    tmp |= (uint)(data[7] << 56);
        //    return tmp;
        //}

        public void buildOpcode(byte opcode, ushort length, ref byte[] next, ref short pIndex)
        {
            ushort tmp = (ushort)((opcode << 9) | length);
            next[pIndex++] = (byte)(tmp & 0xff);
            next[pIndex++] = (byte)(tmp >> 8);
        }

        public void frequency(double frequency, ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.FREQ, 4, ref opcode, ref index);
            byte[] fr = BitConverter.GetBytes((uint)frequency);
            Array.Copy(fr, 0, opcode, 2, fr.Length);
        }

        public void power(short channel, double dbm, ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.POWER, 4, ref opcode, ref index);
            opcode[2] = (byte)channel;
            byte[] pwr = BitConverter.GetBytes((ushort)(dbm*256.0));
            Array.Copy(pwr, 0, opcode, 4, pwr.Length);
        }

        public void phase(short channel, double phase, ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.PHASE, 4, ref opcode, ref index);
            opcode[2] = (byte)channel;
            byte[] phs = BitConverter.GetBytes((short)(phase*64.0));
            Array.Copy(phs, 0, opcode, 4, phs.Length);
        }

        /// <summary>
        /// PULSE opcode
        /// </summary>
        /// <param name="width">in ns</param>
        /// <param name="measureAt">in ns, -1.0 if no measurement</param>
        /// <param name="opcode"></param>
        public void pulse(short channel, double width, double measureAt, ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.PULSE, 8, ref opcode, ref index);
            opcode[2] = (byte)channel;
            byte[] pls = BitConverter.GetBytes(((uint)(width/10.0) & 0xffffff));    // 24 bits, 10ns ticks
            Array.Copy(pls, 0, opcode, 3, 3);   // only 24 bits
            if (measureAt < 0.0)
                opcode[6] = 0;
            else
            {
                byte[] meas = BitConverter.GetBytes(((uint)(measureAt / 10.0) & 0xffffff));    // 24 bits, 10ns ticks
                Array.Copy(meas, 0, opcode, 7, 3);   // only 24 bits
            }
        }

        public void bias(short channel, bool bias, ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.BIAS, 2, ref opcode, ref index);
            opcode[2] = (byte)channel;
            opcode[3] = bias ? (byte)1 : (byte)0;
        }

        public void mode(uint bits, ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.MODE, 4, ref opcode, ref index);
            byte[] data = BitConverter.GetBytes(bits);
            Array.Copy(data, 0, opcode, 2, data.Length);
        }

        public void echo(byte[] data, ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.ECHO, (ushort)data.Length, ref opcode, ref index);
        }

        public void status(ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.STATUS, (ushort)0, ref opcode, ref index);
        }

        public void length(ref byte[] opcode)
        {
            opcode = new byte[OPCODE_BLOCK];
            short index = 0;
            buildOpcode(OpcodeDefs.LENGTH, (ushort)0, ref opcode, ref index);
        }
    }
}
