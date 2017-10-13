using System;
using System.Collections.Generic;
using Interfaces;
using ExternalPowerMeter;
using System.Reflection;
using System.Linq;
using System.IO;

namespace PowerMeterCal
{
    public class CalEntry
    {
        public string Name { get; set; }
        public double Value { get; set; }
        public bool IsDirty { get; set; }
    }

    public class MeterCal
    {
        // Notes from ctrl4_xdig firmware, probably from Jim Hall.
        // ******** Zmon cal Tag defs
        //"ZC1_AIO", "ZC1_AIG", "ZC1_AQO", "ZC1_AQG", "ZC1_BIO", "ZC1_BIG", "ZC1_BQO", "ZC1_BQG"
        // Z= Zmon cal data, 1=chan, F/R=forward or reverse chan, I/Q= I or Q, O/G= offset or gain 
        // S4, M2 will only support one channel
        public string[] ZCalTagNames = { "Z_FIO", "Z_FIG", "Z_FQO", "Z_FQG", "Z_RIO", "Z_RIG", "Z_RQO", "Z_RQG" };

        ///* ******** Pmon cal Tag defs
        //"PC1_AO", "PC1_AG", "PC1_BO", "PC1_BG"
        //PC= Pmon cal data, 1=chan, A/B power reading A or B, O/G= offset or gain 
        public string[] PCalTagNames = { "P_FIO", "P_FIG", "P_FQO", "P_FQG", "P_RIO", "P_RIG", "P_RQO", "P_RQG" };

        public List<CalEntry> CalData { get; set; }

        public double ZmonFwdIOffset { get; set; }
        public double ZmonFwdIGain { get; set; }
        public double ZmonFwdQOffset { get; set; }
        public double ZmonFwdQGain { get; set; }
        public double ZmonRefIOffset { get; set; }
        public double ZmonRefIGain { get; set; }
        public double ZmonRefQOffset { get; set; }
        public double ZmonRefQGain { get; set; }

        public double CombinerFwdIOffset { get; set; }
        public double CombinerFwdIGain { get; set; }
        public double CombinerFwdQOffset { get; set; }
        public double CombinerFwdQGain { get; set; }
        public double CombinerRefIOffset { get; set; }
        public double CombinerRefIGain { get; set; }
        public double CombinerRefQOffset { get; set; }
        public double CombinerRefQGain { get; set; }

        ICommands _cmds;
        IDebugging _dbg;
        IInstrument _meter;

        public MeterCal()
        {
            CalData = new List<CalEntry>();
        }

        /// <summary>
        /// Tosses ApplicationException on error
        /// </summary>
        /// <param name="cmds"></param>
        /// <param name="dbg"></param>
        /// <returns></returns>
        public int Initialize(ICommands cmds, IDebugging dbg)
        {
            _cmds = cmds;
            _dbg = dbg;

            foreach (var name in ZCalTagNames)
            {
                var entry = new CalEntry
                {
                    Name = name,
                    Value = 0.0,
                    IsDirty = false
                };
                byte[] data = null;
                int status = _dbg.GetTag(name, ref data);
                if (status == 0)
                    entry.Value = BitConverter.ToDouble(data, 0);
                CalData.Add(entry);

            }

            //FindLoadableDrivers();
            _meter = new ExternalMeter();
            IInstrument itmp = (IInstrument)_meter;
            itmp.Startup();
            itmp.OffsetEnable = true;
            itmp.Offset = 40.0;
            itmp.SetPowerUnits(0);
            itmp.SetFrequency(2450.0);
            itmp.SetAverages(75);
            double dbm = itmp.ReadCw(false);


            return 0;
        }

        public int WritePowerMeterTags()
        {

            return 0;
        }

        public int ReadPowerMeterTags()
        {
            return 0;
        }

        public int CollectPowerData(double startPwr, double endPower,
                                    int steps,
                                    bool calEnabled,
                                    bool useZMon,
                                    bool useExternal,
                                    out double[] setPower,
                                    out double[] resultsCombiner,
                                    out double[] resultsZmon,
                                    out double[] resultsExternal)
        {
            setPower = null;
            resultsCombiner = null;
            resultsZmon = null;
            resultsExternal = null;
            return 0;
        }

        public int PowerSweepFunc(string calfile, double[] freqs, double[] pouts, double pgen1, double pmax, string csvfile)
        {
            // f_pout_sweep_p cal_file freqs_MHz Pouts_dBm gen_start_pwr max_pin[csvfile]
            // sweep frequency at various input power, measure Pout, ACPR, and Id
            // if csvfile is defined, write data to the specified CSV file
            // designed for pulse measurements with E4417A

            // $Id: f_pout_sweep_p.m 923 2015 - 05 - 28 17:47:37Z nxp20190 $

            //function R = f_pout_sweep_p(calfile, freqs, pouts, pgen1, pmax, csvfile)
            //    % --------Define user - settable measurement parameters--------
            double IOFF = 0.0;           // offset current(e.g.bias circuit quiescent drain)
            double DUTY = 0.01;
            bool PULSED_ID = false;     // if 1, make pulsed Id measurement with DMM2, override IG meas
            string EFFTYPE = "DRAIN";   // 'PAE' or 'DRAIN'
            int COMP = 3;               // if defined, stop testing this freq at this compression
            double IG_MAX = 36.0;       // stop testing this freq when Ig hits this mA limit
            double Rjc = 3;             // 0.23; % 0.67; % 0.15; % K/W transistor junction-case
            int THM_ADR = 0;            // 25; DMM with thermocouple
            string THR_ADR = null;  //"COM13";      // Omega HH309A temperature logger
            bool PLOT = false;          // enable realtime plotting
            // -------- Define GPIB addresses and constants --------
            //    INTF = 'ni';
            string PWR_ADR = "GPIB0::13::INSTR";
            string GEN = "EPM";          // 'SRS';
            string GEN_ADR = "GPIB0::28::INSTR";
            //string    GEN_ADR = "192.168.10.228";
            string PS_ADR = "GPIB0::6::INSTR";
            // DMM_ADR = 'GPIB0::24::INSTR'; % if not defined, measure current from PS
            // DMM2_ADR = 'GPIB0::25::INSTR'; % measure GaN gate current
            double IG_GAIN = 20;         // resistance of gate shunt resistor
            double ID_GAIN = 0.001;      // resistance of CW drain shunt resistor
            double ID2_GAIN = 0.002;     // resistance of pulse drain shunt resistor
            string DMM_QUERY = "MEAS:VOLT:DC?";  // '?' for older DMMs
            string PS_I_QUERY = "MEAS:CURR:DC?";
            double MAXPGEN = 10;         // maximum generator output level
            int MAXSTEP = 1;          // maximum generator step
            double PTOL = 0.25;          // dB
            double NTOL = 0.05;          // dB
            // ------------------------------------------------------------------
            // sweepcleanup executes when f_pout_acp_sweep ends
            // c = onCleanup(@()sweepcleanup(GEN));
            int nfreqs = freqs.Length;  //size(freqs,2);

            StreamWriter csv = null;
            if (File.Exists(csvfile))
                csv = new StreamWriter(csvfile, false);
            if (COMP == null)
                COMP = 100;

            OpenInstruments();
            //    oldobjs = instrfind;
            //    if (size(oldobjs,2))
            //        fclose(oldobjs);
            //        end
            //        pwr = visa(INTF, PWR_ADR);
            //    if (strcmp(GEN, 'SRS'))
            //        gen = tcpip(GEN_ADR,5024,'Timeout',1);
            //    else
            //        gen = visa(INTF, GEN_ADR);
            //        end
            //    if (exist('DMM_ADR','var'))
            //        dmm = visa(INTF, DMM_ADR);
            //        end
            //    if (exist('DMM2_ADR','var'))
            //        dmm2 = visa(INTF, DMM2_ADR);
            //        end
            //    if (exist('THM_ADR','var'))
            //        thm = visa(INTF, THM_ADR);
            //    elseif(exist('THR_ADR','var'))
            //        thr = serial(THR_ADR,'BaudRate',9600,'Terminator','','Timeout',1);
            //        end
            //        ps = visa(INTF, PS_ADR);

            // read cal file containing rows of[freq, A offset, B offset]
            CalFileEntry[] Cal = dlmread(calfile);
            printf("Cal file {0}\n", calfile);
            printf("contains {0} frequencies from {1:f} to {2:f} MHz\n", 
                    Cal.Length, Cal[0].frequency, Cal[Cal.Length-1].frequency);
            if (freqs[1] < Cal[0].frequency || freqs[Cal.Length-1] > Cal[Cal.Length-1].frequency)
            {
                printf("Specified frequency range is outside of cal file range, quitting\n");
                return 1;
            }

            // build tables of offsets for the specified frequencies
            // Off1 = interp1(Cal(:, 1), Cal(:, 2), freqs);
            printf("**Need interpolation & build Offset tables**\n");
            double[] Off1 = new double[freqs.Length];
            // Off2 = interp1(Cal(:,1),Cal(:,3),freqs);
            double[] Off2 = new double[freqs.Length];

            // preallocate space for result
            int ncols = 0;
            if (THM_ADR != 0)
                ncols = 6;
            else if(THR_ADR != null)
                ncols = 7;
            else
                ncols = 5;

            //    R = zeros(size(pouts, 2), size(freqs, 2), ncols);

            //    fopen(pwr);
            //    clrdevice(pwr);
            //    fopen(gen);
            //    if (exist('dmm','var'))
            //        fopen(dmm);
            //        end
            //    if (exist('dmm2','var'))
            //        fopen(dmm2);
            //        if (PULSED_ID)
            //            fprintf(dmm2,'CONF:VOLT:DC 1'); % Id measurement
            //        else
            //            fprintf(dmm2,'CONF:VOLT:DC 1'); % Ig measurement
            //        end
            //        fprintf(dmm2,'VOLT:APER 20e-6');
            //        fprintf(dmm2,'TRIG:DELAY:AUTO OFF');
            //        fprintf(dmm2,'TRIG:DELAY 40e-6');
            //        fprintf(dmm2,'TRIG:SOUR EXT');
            //        fprintf(dmm2,'TRIG:SLOPE POS');
            //        fprintf(dmm2,'SAMP:SOUR TIMER');
            //        fprintf(dmm2,'SAMP:TIMER 20e-6');
            //        fprintf(dmm2,'SAMP:COUNT 1');
            //        end
            //        fopen(ps);
            //    if (exist('THM_ADR','var'))
            //        fopen(thm);
            //    elseif(exist('THR_ADR','var'))
            //        fopen(thr);
            //        end
            // Set up power meter for software triggering, but don't change the
            // filtering, already tweaked by the user
            _meter.Write("*CLS");
            _meter.Write("CALC1:GAIN:STAT ON");
            _meter.Write("CALC2:GAIN:STAT ON");
            _meter.Write("TRIG1:DEL:AUTO ON");
            _meter.Write("TRIG2:DEL:AUTO ON");
            _meter.Write("INIT:CONT OFF");


            //    fprintf(ps,'MEAS:VOLT?');
            //        voltage = fscanf(ps,'%f');

            //    if (strcmp(GEN,'SRS'))
            //        fprintf(gen,'ENBR 0\n');
            //    else
            //        fprintf(gen,':OUTP:STAT OFF');
            //        end
            //    if (PULSED_ID)
            //        fprintf(dmm2,'READ?');
            //        curr = fscanf(dmm2,'%f') / ID2_GAIN;
            //        idq = curr;
            //    elseif(exist('dmm','var'))
            //        fprintf(dmm, DMM_QUERY);
            //        curr = fscanf(dmm,'%f') / ID_GAIN;
            //        idq = curr - IOFF;
            //    else
            //        fprintf(ps, PS_I_QUERY);
            //        curr = fscanf(ps,'%f');
            //        idq = curr - IOFF;
            //    end
            //    fprintf('Duty cycle = %4.2f%%, Idq = %0.3fA, Vd = %0.1fV\n', DUTY*100, idq, voltage);
            //    if (csv)
            //        fprintf(csv,'"Duty cycle = %4.2f%%, Idq = %0.3fA, Vd = %0.1fV"\n', DUTY*100, idq, voltage);
            //        end

            //    if (strcmp(GEN,'SRS'))
            //        fprintf(gen,'FREQ %f MHz\n', freqs(1));
            //        fprintf(gen,'AMPR %f\n', pgen1);
            //        fprintf(gen,'ENBR 1\n');
            //    else
            //        fprintf(gen,':FREQ %fMHZ', freqs(1));
            //        fprintf(gen,':POW %f', pgen1);
            //        fprintf(gen,':OUTP:STAT ON');
            //        end

            //    if (strcmp(EFFTYPE,'PAE'))
            //        hdr1 = sprintf('Freq\t\tPin\t\tPout\tGain\tPout\tId\t\tPAE\t\tPdiss');
            //        hdr1c = sprintf('Freq,Pin,Pout,Gain,Pout,Id,PAE,Pdiss');
            //    else
            //        hdr1 = sprintf('Freq\t\tPin\t\tPout\tGain\tPout\tId\t\tDrn_Eff\tPdiss');
            //        hdr1c = sprintf('Freq,Pin,Pout,Gain,Pout,Id,Drn_Eff,Pdiss');
            //        end
            //        hdr2 = sprintf('(MHz)\t\t(dBm)\t(dBm)\t(dB)\t(W)\t\t(A)\t\t(%%)\t\t(W)');
            //        hdr2c = sprintf('(MHz),(dBm),(dBm),(dB),(W),(A),(%%),(W)');
            //    if (exist('THM_ADR','var'))
            //        hdr1 = sprintf('%s\tTc\t\tTj\t', hdr1);
            //        hdr2 = sprintf('%s\t\t(C)\t\t(C)', hdr2);
            //        hdr1c = sprintf('%s,Tc,Tj', hdr1c);
            //        hdr2c = sprintf('%s,(C),(C)', hdr2c);
            //    elseif(exist('THR_ADR','var'))
            //        hdr1 = sprintf('%s\tTc\t\tTj\t\tT2\t', hdr1);
            //        hdr2 = sprintf('%s\t\t(C)\t\t(C)\t\t(C)', hdr2);
            //        hdr1c = sprintf('%s,Tc,Tj,T2', hdr1c);
            //        hdr2c = sprintf('%s,(C),(C),(C)', hdr2c);
            //        end
            //    if (exist('dmm2','var') && ~PULSED_ID)
            //        hdr1 = sprintf('%s\tIg', hdr1);
            //        hdr2 = sprintf('%s\t\t(mA)', hdr2);
            //        hdr1c = sprintf('%s,Ig', hdr1c);
            //        hdr2c = sprintf('%s,(mA)', hdr2c);
            //        end
            //        fprintf('%s\n%s\n', hdr1, hdr2);
            //    if (csv)
            //        fprintf(csv,'%s\n%s\n', hdr1c, hdr2c);
            //        end

            //
            // Ported from MATLAB(fou_sweep_p.m) for M2 power cal
            // 27-Apr-2017
            //
            // M2 will use its Synthesizer for generator
            // Find the IQ Dac setting required to achieve desired power
            // Do this in 0.5 dBm steps?
            // Do this for some number of frequencies
            // Later - incorporate variations in temperature

            bool[] below_comp = new bool[freqs.Length];
            for (int idx = 0; idx < below_comp.Length; ++idx) below_comp[idx] = true;                
            bool[] below_igmax = new bool[freqs.Length];
            for (int idx = 0; idx < below_igmax.Length; ++idx) below_igmax[idx] = true;
            bool[] below_genmax = new bool[freqs.Length];
            for (int idx = 0; idx < below_genmax.Length; ++idx) below_genmax[idx] = true;
            double[] maxgain = new double[freqs.Length];  // = -100;
            for (int idx = 0; idx < maxgain.Length; ++idx) maxgain[idx] = -100.0;
            double[] pgen = new double[freqs.Length];
            for (int idx = 0; idx < pgen.Length; ++idx) pgen[idx] = pgen1;  // start sig gen at specified power @ all freqs


            double pout, pin;
            pout = pin = 0.0;
            double pout_err, last_pin, pin_new;
            last_pin = pgen[0];
            double pout_avg = 0.0;
            double gain = 0.0;

            for (int p = 0; p < pouts.Length; ++p)
            {
                for (int f = 0; f < freqs.Length; ++f)
                {
                    if (below_comp[f] && below_igmax[f] && below_genmax[f])
                    {
                        double freq = freqs[f];
                        printf("{0,7:f2}", freq);
                        _cmds.SetFrequency(freq);
                        _meter.Write(string.Format("SENS1:FREQ {0}MHZ", freq));
                        _meter.Write(string.Format("SENS2:FREQ {0}MHZ", freq));
                        _meter.Write(string.Format("CALC1:GAIN {0}", Off1[f]));
                        _meter.Write(string.Format("CALC2:GAIN {0}", Off2[f]));
                        bool adjusted = false;          // force the first pass through the while loop
                        double last_pout = -99;
                        while (!adjusted)
                        {
                            if (pgen[f] > MAXPGEN)
                            {
                                if (p == 1)
                                {
                                    //fprintf(2, ' Generator level exceeds limit: %5.2f\n', pgen(f));
                                    return 2;
                                }
                                else
                                {
                                    // if not the first pass, keep looking other freqs
                                    below_genmax[f] = false;
                                }
                                break;
                            }
                            else
                            {
                                _cmds.SetPower(pgen[f]);
                            }
                            System.Threading.Thread.Sleep(30);
                            _meter.Write("INIT1;INIT2'");
                            pout = _meter.Result("FETC1?");
                            pin = pgen[f];
                            //        pin = fscanf(pwr,'%f');
                            //                    fprintf(pwr,'FETC2?');
                            //        pout = fscanf(pwr,'%f');
                            pout_avg = pout * DUTY;
                            //        pout = pout;
                            gain = pout - pin;
                            if ((pout< (pouts[p]+PTOL) && gain < (maxgain[f]-COMP)) || (gain < (maxgain[f]-1) && pout < last_pout-NTOL))
                            {
                                //                        % this clause causes a lot of grief with GaN, but is needed for gain foldback
                                //                        % || (gain< (maxgain(f)-1) && pout<last_pout-NTOL))
                                below_comp[f] = false;
                                if (pout < last_pout)
                                {
                                    pout = last_pout;
                                    pin = last_pin;
                                }
                                break;
                            }
                            if (pout >= pouts[p] - NTOL && pout < pouts[p] + PTOL)
                                adjusted = true;
                            else
                            { 
                                pout_err = pouts[p] - pout;
                                if (pout_err< 0)
                                    pout_err = pout_err / 2;
                                else if(pout_err > MAXSTEP)
                                    pout_err = MAXSTEP;
                                pgen[f] = pgen[f] + pout_err;
                                pin_new = pin + pout_err;
                                if (pin_new > pmax)
                                {
                                    printf(" Drive level exceeds limit: %5.2f\n", pin_new);
                                    return 3;
                                }
                                else if(pin_new > Off1[f] + 20)
                                {
                                    printf(" Drive level too high for sensor A: %5.2f\n", pin_new);
                                    return 4;
                                }
                            }

                            if (!PULSED_ID)
                            {
                                // fprintf(dmm2,'READ?');
                                // ig = 1000 / IG_GAIN* fscanf(dmm2,'%f');
                                // if (abs(ig) >= IG_MAX)
                                // {
                                //     below_igmax[f] = false;
                                //     break;
                                // }
                            }
                            last_pout = pout;
                            last_pin = pin;
                        }
                        // if (~below_genmax(f))
                        //     // if we hit MAXPGEN, we never made a measurement
                        //     continue;
                        if (THR_ADR != null)
                        {
                            // fprintf(thr,'A'); % measure device case temperature
                        }
                        double poutw = Math.Pow(10.0, ((pout - 30.0) / 10.0));
                        double poutw_avg = Math.Pow(10.0, ((pout_avg - 30) / 10));
                        double pinw = Math.Pow(10.0, ((pin - 30) / 10));
                        gain = pout - pin;
                        if (gain > maxgain[f])
                            maxgain[f] = gain;
                        //csv.fprintf('\t\t%5.2f\t%5.2f\t%5.2f\t%5.2f', pin, pout, gain, poutw);
                        //        result=sprintf('%.2f,%.2f,%.2f,%.2f,%.2f', freq, pin, pout, gain, poutw);

                        //                if (PLOT)
                        //                    plotf(f)=freq;
                        //                    plotg(f)=gain;
                        //                    if (f==1)
                        //                        h = plot(plotf, plotg,'b-square');
                        //                        set(gca,'Xlim', [freqs(1) freqs(nfreqs)]);
                        //                        set(h,'XDataSource','plotf');
                        //                        set(h,'YDataSource','plotg');
                        //        end
                        //        refreshdata(h,'caller');
                        //        end

                        //                if (PULSED_ID)
                        //                    fprintf(dmm2,'READ?');
                        //        curr = fscanf(dmm2,'%f') / ID2_GAIN;
                        //                elseif(exist('dmm','var'))
                        //                    fprintf(dmm, DMM_QUERY);
                        //        curr = fscanf(dmm,'%f') / ID_GAIN;
                        //                else
                        //                    fprintf(ps, PS_I_QUERY);
                        //        curr = fscanf(ps,'%f');
                        //        end
                        //                if (PULSED_ID)
                        //                    pdc = voltage* curr * DUTY;
                        //                    equiv_curr = curr;
                        //                else
                        //                    pdc = voltage* curr;
                        //        equiv_curr = idq + (curr - idq - IOFF) / DUTY;
                        //                end
                        //                pdiss = pdc - poutw_avg;
                        //        tjc = Rjc* pdiss;
                        //                if (strcmp(EFFTYPE,'PAE'))
                        //                    eff = 100 * (poutw - pinw) / (voltage* equiv_curr);
                        //                else
                        //                    eff = 100 * poutw / (voltage* equiv_curr);
                        //        end
                        //                if (exist('THM_ADR','var'))
                        //                    fprintf(thm,'MEAS:VOLT:DC?');
                        //        tc = 1000 * fscanf(thm,'%f');
                        //        tj = tc + tjc;
                        //                    fprintf('\t%5.2f\t%5.2f\t%5.1f\t%5.1f\t%5.1f', equiv_curr, eff, pdiss, tc, tj);
                        //        result=sprintf('%s,%.2f,%.2f,%.1f,%.1f,%.1f', result, equiv_curr, eff, pdiss, tc, tj);
                        //                elseif(exist('THR_ADR','var'))
                        //                    T = fread(thr,11);
                        //        tc = (256 * T(8) + T(9)) / 10;
                        //                    tj = tc + tjc;
                        //                    t2 = (256 * T(10) + T(11)) / 10;
                        //                    fprintf('\t%5.2f\t%5.2f\t%5.1f\t%5.1f\t%5.1f\t%5.1f', equiv_curr, eff, pdiss, tc, tj, t2);
                        //        result=sprintf('%s,%.2f,%.2f,%.1f,%.1f,%.1f,%.1f', result, equiv_curr, eff, pdiss, tc, tj, t2);
                        //                else
                        //                    fprintf('\t%5.2f\t%5.2f\t%5.1f', equiv_curr, eff, pdiss);
                        //        result=sprintf('%s,%.2f,%.2f,%.1f', result, equiv_curr, eff, pdiss);
                        //        end
                        //                if (exist('dmm2','var') && ~PULSED_ID)
                        //                    fprintf('\t%5.2f', ig);
                        //        result=sprintf('%s,%.2f', result, ig);
                        //        end
                        //                if (~below_comp(f))
                        //                    fprintf(2,' %d dB compression', COMP);
                        //        result=sprintf('%s,"%d dB compression"', result, COMP);
                        //                elseif(~below_igmax(f))
                        //                    fprintf(2,' Ig at limit');
                        //        result=sprintf('%s,"Ig at limit"', result);
                        //                elseif(~below_genmax(f))
                        //                    fprintf(2,' Generator at limit');
                        //        end
                        //        fprintf('\n');
                        //                csvdata(f)=cellstr(result);
                        //        end
                    }
                    //if (csv)
                    //    fprintf(csv,'%s\n', char(csvdata(f)));
                }
            }
            return 0;
        }

        int sweepcleanup(int GEN)
        {
            // sleepcleanup executes when f_pin_sweep ends
            //if (strcmp(GEN, 'SRS'))
            //        fprintf(gen, 'ENBR 0\n');
            //    else
            //        fprintf(gen, ':OUTP:STAT OFF');
            //    end
            //fclose(gen);
            //    fprintf(pwr, 'INIT:CONT ON');
            //    fclose(pwr);
            //    if (csv)
            //        fclose(csv);
            //    end
            //if (exist('dmm', 'var'))
            //        fclose(dmm);
            //    end
            //if (exist('thm', 'var'))
            //        fclose(thm);
            //    end
            //if (exist('thr', 'var'))
            //        fclose(thr);
            //    end
            //if (exist('dmm2', 'var'))
            //        fclose(dmm2);
            //    end
            //fclose(ps);
            return 0;
        }

        int OpenInstruments()
        {
            //    oldobjs = instrfind;
            //    if (size(oldobjs,2))
            //        fclose(oldobjs);
            //        end
            //        pwr = visa(INTF, PWR_ADR);
            //    if (strcmp(GEN, 'SRS'))
            //        gen = tcpip(GEN_ADR,5024,'Timeout',1);
            //    else
            //        gen = visa(INTF, GEN_ADR);
            //        end
            //    if (exist('DMM_ADR','var'))
            //        dmm = visa(INTF, DMM_ADR);
            //        end
            //    if (exist('DMM2_ADR','var'))
            //        dmm2 = visa(INTF, DMM2_ADR);
            //        end
            //    if (exist('THM_ADR','var'))
            //        thm = visa(INTF, THM_ADR);
            //    elseif(exist('THR_ADR','var'))
            //        thr = serial(THR_ADR,'BaudRate',9600,'Terminator','','Timeout',1);
            //        end
            //        ps = visa(INTF, PS_ADR);
            return 0;
        }

        CalFileEntry[] dlmread(string calfile)
        {
            return new CalFileEntry[1];
        }

        public struct CalFileEntry
        {
            public double frequency;
            public double offsetA;
            public double offsetB;
        }

        void printf(string format, params object[] args)
        {
            string msg = string.Format(format, args);
            //AppendLine(msg);
        }
    }


    /* Example 1
    IEnumerable<Type> FindLoadableDrivers(AssemblyLoadEventArgs asm)
    {
        var it = typeof(IInstrument);
        return asm.GetLoadableTypes().Where(it.IsAssignableFrom).ToList();
    }


public static class TypeLoaderExtensions
{
    public static IEnumerable<Type> GetLoadableTypes(this Assembly assembly)
    {
        if (assembly == null) throw new ArgumentNullException("assembly");
        try
        {
            return assembly.GetTypes();
        }
        catch (ReflectionTypeLoadException e)
        {
            return e.Types.Where(t => t != null);
        }
    }
}
    /* End of example 1


    * Example 2
    /// *****************************
    static void Main()
    {
        const string qualifiedInterfaceName = "Interfaces.IMyInterface";
        var interfaceFilter = new TypeFilter(InterfaceFilter);

        var path = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

        var di = new DirectoryInfo(path);
        foreach (var file in di.GetFiles("*.dll"))
        {
            try
            {
                var nextAssembly = Assembly.ReflectionOnlyLoadFrom(file.FullName);

                foreach (var type in nextAssembly.GetTypes())
                {
                    var myInterfaces = type.FindInterfaces(interfaceFilter, qualifiedInterfaceName);
                    if (myInterfaces.Length > 0)
                    {
                        // This class implements the interface
                    }
                }
            }
            catch (BadImageFormatException)
            {
                // Not a .net assembly  - ignore
            }
        }
    }

    public static bool InterfaceFilter(Type typeObj, Object criteriaObj)
    {
        return typeObj.ToString() == criteriaObj.ToString();
    }
    ///**End of exampel 2 **********************
    */



}
