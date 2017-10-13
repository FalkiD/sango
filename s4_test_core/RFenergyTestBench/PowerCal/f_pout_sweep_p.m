% f_pout_sweep_p cal_file freqs_MHz Pouts_dBm gen_start_pwr max_pin [csvfile]
% sweep frequency at various input power, measure Pout, ACPR, and Id
% if csvfile is defined, write data to the specified CSV file
% designed for pulse measurements with E4417A

% $Id: f_pout_sweep_p.m 923 2015-05-28 17:47:37Z nxp20190 $

function R = f_pout_sweep_p(calfile,freqs,pouts,pgen1,pmax,csvfile)
    % -------- Define user-settable measurement parameters --------
    IOFF = 0.0; % offset current (e.g. bias circuit quiescent drain)
    DUTY = 0.01;
    PULSED_ID = 0; % if 1, make pulsed Id measurement with DMM2, override IG meas
    EFFTYPE = 'DRAIN'; % 'PAE' or 'DRAIN'
    COMP = 3; % if defined, stop testing this freq at this compression
    IG_MAX = 36; % stop testing this freq when Ig hits this mA limit
    Rjc = 3; %0.23; % 0.67; % 0.15; % K/W transistor junction-case
    % THM_ADR = 25; % DMM with thermocouple
    % THR_ADR = 'COM13'; % Omega HH309A temperature logger
    PLOT = 0; % enable realtime plotting
    % -------- Define GPIB addresses and constants --------
    INTF = 'ni';
    PWR_ADR = 'GPIB0::13::INSTR';
    GEN = 'EPM'; % 'SRS';
    GEN_ADR = 'GPIB0::28::INSTR';
    % GEN_ADR = '192.168.10.228';
    PS_ADR = 'GPIB0::6::INSTR';
    % DMM_ADR = 'GPIB0::24::INSTR'; % if not defined, measure current from PS
    % DMM2_ADR = 'GPIB0::25::INSTR'; % measure GaN gate current
    IG_GAIN = 20; % resistance of gate shunt resistor
    ID_GAIN = 0.001; % resistance of CW drain shunt resistor
    ID2_GAIN = 0.002; % resistance of pulse drain shunt resistor
    DMM_QUERY = 'MEAS:VOLT:DC?'; % '?' for older DMMs
    PS_I_QUERY = 'MEAS:CURR:DC?';
    MAXPGEN = 10; % maximum generator output level
    MAXSTEP = 1; % maximum generator step
    PTOL = 0.25; % dB
    NTOL = 0.05; % dB
    % ------------------------------------------------------------------
    % sweepcleanup executes when f_pout_acp_sweep ends
    c = onCleanup(@()sweepcleanup(GEN));
    nfreqs = size(freqs,2);
    
    if (exist('csvfile','var'))
        csv = fopen(csvfile,'wt');
    else
        csv = 0;
    end
    if (~exist('COMP','var'))
        COMP = 100;
    end

    oldobjs = instrfind;
    if (size(oldobjs,2))
        fclose(oldobjs);
    end
    pwr = visa(INTF,PWR_ADR);
    if (strcmp(GEN, 'SRS'))
        gen = tcpip(GEN_ADR,5024,'Timeout',1);
    else
        gen = visa(INTF,GEN_ADR);
    end
    if (exist('DMM_ADR','var'))
        dmm = visa(INTF,DMM_ADR);
    end
    if (exist('DMM2_ADR','var'))
        dmm2 = visa(INTF,DMM2_ADR);
    end
    if (exist('THM_ADR','var'))
        thm = visa(INTF,THM_ADR);
    elseif (exist('THR_ADR','var'))
        thr = serial(THR_ADR,'BaudRate',9600,'Terminator','','Timeout',1);
    end
    ps = visa(INTF,PS_ADR);
    
    % read cal file containing rows of [freq, A offset, B offset]
    Cal = dlmread(calfile);
    ncals = size(Cal,1);
    fprintf('Cal file "%s"\n', calfile);
    fprintf('contains %d frequencies from %0.1f to %0.1f MHz\n', ...
        ncals, Cal(1,1), Cal(ncals,1));
    if (freqs(1) < Cal(1,1) || freqs(nfreqs) > Cal(ncals,1))
        fprintf(2,'Specified frequency range is outside of cal file range\n');
        return;
    end
    
    % build tables of offsets for the specified frequencies
    Off1 = interp1(Cal(:,1),Cal(:,2),freqs);
    Off2 = interp1(Cal(:,1),Cal(:,3),freqs);
    % preallocate space for result
    if (exist('THM_ADR','var'))
        ncols = 6;
    elseif (exist('THR_ADR','var'))
        ncols = 7;
    else
        ncols = 5;
    end
    R = zeros(size(pouts,2),size(freqs,2),ncols);
    fopen(pwr);
    clrdevice(pwr);
    fopen(gen);
    if (exist('dmm','var'))
        fopen(dmm);
    end
    if (exist('dmm2','var'))
        fopen(dmm2);
        if (PULSED_ID)
%            fprintf(dmm2,'CONF:VOLT:DC 0.1'); % Id measurement
            fprintf(dmm2,'CONF:VOLT:DC 1'); % Id measurement
        else
            fprintf(dmm2,'CONF:VOLT:DC 1'); % Ig measurement
        end
        fprintf(dmm2,'VOLT:APER 20e-6');
        fprintf(dmm2,'TRIG:DELAY:AUTO OFF');
        fprintf(dmm2,'TRIG:DELAY 40e-6');
        fprintf(dmm2,'TRIG:SOUR EXT');
        fprintf(dmm2,'TRIG:SLOPE POS');
        fprintf(dmm2,'SAMP:SOUR TIMER');
        fprintf(dmm2,'SAMP:TIMER 20e-6');
        fprintf(dmm2,'SAMP:COUNT 1');
    end
    fopen(ps);
    if (exist('THM_ADR','var'))
        fopen(thm);
    elseif (exist('THR_ADR','var'))
        fopen(thr);
    end
    % Set up power meter for software triggering, but don't change the
    % filtering, already tweaked by the user
    fprintf(pwr,'*CLS');
    fprintf(pwr,'CALC1:GAIN:STAT ON');
    fprintf(pwr,'CALC2:GAIN:STAT ON');
    fprintf(pwr,'TRIG1:DEL:AUTO ON');
    fprintf(pwr,'TRIG2:DEL:AUTO ON');
    fprintf(pwr,'INIT:CONT OFF');
    
    fprintf(ps,'MEAS:VOLT?');
    voltage = fscanf(ps,'%f');

    if (strcmp(GEN,'SRS'))
        fprintf(gen,'ENBR 0\n');
    else
        fprintf(gen,':OUTP:STAT OFF');
    end
    if (PULSED_ID)
        fprintf(dmm2,'READ?');
        curr = fscanf(dmm2,'%f') / ID2_GAIN;
        idq = curr;
    elseif (exist('dmm','var'))
        fprintf(dmm,DMM_QUERY);
        curr = fscanf(dmm,'%f') / ID_GAIN;
        idq = curr - IOFF;
    else
        fprintf(ps,PS_I_QUERY);
        curr = fscanf(ps,'%f');
        idq = curr - IOFF;
    end
    fprintf('Duty cycle = %4.2f%%, Idq = %0.3fA, Vd = %0.1fV\n',DUTY*100,idq,voltage);
    if (csv)
        fprintf(csv,'"Duty cycle = %4.2f%%, Idq = %0.3fA, Vd = %0.1fV"\n',DUTY*100, idq, voltage);
    end

    if (strcmp(GEN,'SRS'))
        fprintf(gen,'FREQ %f MHz\n',freqs(1));
        fprintf(gen,'AMPR %f\n',pgen1);
        fprintf(gen,'ENBR 1\n');
    else
        fprintf(gen,':FREQ %fMHZ',freqs(1));
        fprintf(gen,':POW %f',pgen1);
        fprintf(gen,':OUTP:STAT ON');
    end
    
    if (strcmp(EFFTYPE,'PAE'))
        hdr1 = sprintf('Freq\t\tPin\t\tPout\tGain\tPout\tId\t\tPAE\t\tPdiss');
        hdr1c = sprintf('Freq,Pin,Pout,Gain,Pout,Id,PAE,Pdiss');
    else
        hdr1 = sprintf('Freq\t\tPin\t\tPout\tGain\tPout\tId\t\tDrn_Eff\tPdiss');
        hdr1c = sprintf('Freq,Pin,Pout,Gain,Pout,Id,Drn_Eff,Pdiss');
    end
    hdr2 = sprintf('(MHz)\t\t(dBm)\t(dBm)\t(dB)\t(W)\t\t(A)\t\t(%%)\t\t(W)');
    hdr2c = sprintf('(MHz),(dBm),(dBm),(dB),(W),(A),(%%),(W)');
    if (exist('THM_ADR','var'))
        hdr1 = sprintf('%s\tTc\t\tTj\t',hdr1);
        hdr2 = sprintf('%s\t\t(C)\t\t(C)',hdr2);
        hdr1c = sprintf('%s,Tc,Tj',hdr1c);
        hdr2c = sprintf('%s,(C),(C)',hdr2c);
    elseif (exist('THR_ADR','var'))
        hdr1 = sprintf('%s\tTc\t\tTj\t\tT2\t',hdr1);
        hdr2 = sprintf('%s\t\t(C)\t\t(C)\t\t(C)',hdr2);
        hdr1c = sprintf('%s,Tc,Tj,T2',hdr1c);
        hdr2c = sprintf('%s,(C),(C),(C)',hdr2c);
    end
    if (exist('dmm2','var') && ~PULSED_ID)
        hdr1 = sprintf('%s\tIg',hdr1);
        hdr2 = sprintf('%s\t\t(mA)',hdr2);
        hdr1c = sprintf('%s,Ig',hdr1c);
        hdr2c = sprintf('%s,(mA)',hdr2c);
    end
    fprintf('%s\n%s\n',hdr1,hdr2);
    if (csv)
        fprintf(csv,'%s\n%s\n',hdr1c,hdr2c);
    end
    pgen(1:nfreqs,:) = pgen1; % start sig gen at specified power @ all freqs
    below_comp(1:nfreqs,:) = 1;
    below_igmax(1:nfreqs,:) = 1;
    below_genmax(1:nfreqs,:) = 1;
    maxgain(1:nfreqs,:) = -100;
    for p = 1:size(pouts,2)
        for f = 1:size(freqs,2)
            if (below_comp(f) && below_igmax(f) && below_genmax(f))
                freq = freqs(f);
                fprintf('%7.2f',freq);
                if (strcmp(GEN,'SRS'))
                    fprintf(gen,'FREQ %f MHz\n',freq);
                else
                    fprintf(gen,':FREQ %fMHZ',freq);
                end
                fprintf(pwr,'SENS1:FREQ %fMHZ',freq);
                fprintf(pwr,'SENS2:FREQ %fMHZ',freq);
                fprintf(pwr,'CALC1:GAIN %f',Off1(f));
                fprintf(pwr,'CALC2:GAIN %f',Off2(f));
                adjusted = 0; % force the first pass through the while loop
                last_pout = -99;
                while (~adjusted)
                    if (pgen(f) > MAXPGEN)
                        if (p == 1)
                            fprintf(2,' Generator level exceeds limit: %5.2f\n',pgen(f));
                            return;
                        else
                            % if not the first pass, keep looking other freqs
                            below_genmax(f) = 0;
                            break;
                        end
                    else
                        if (strcmp(GEN,'SRS'))
                            fprintf(gen,'AMPR %f\n',pgen(f));
                        else
                            fprintf(gen,':POW %f',pgen(f));
                        end
                    end
                    pause(0.03);
                    fprintf(pwr,'ABOR1;ABOR2');
                    fprintf(pwr,'INIT1;INIT2');
                    fprintf(pwr,'FETC1?');
                    pin = fscanf(pwr,'%f');
                    fprintf(pwr,'FETC2?');
                    pout = fscanf(pwr,'%f');
                    pout_avg = pout * DUTY;
                    pout = pout;
                    gain = pout - pin;
                    if ((pout < (pouts(p)+PTOL) && gain < (maxgain(f)-COMP))|| (gain < (maxgain(f)-1) && pout < last_pout-NTOL))
                        % this clause causes a lot of grief with GaN, but is needed for gain foldback
                        % || (gain < (maxgain(f)-1) && pout < last_pout-NTOL))
                        below_comp(f) = 0;
                        if (pout < last_pout)
                            pout = last_pout;
                            pin = last_pin;
                        end
                        break;
                    end
                    if (pout >= pouts(p) - NTOL && pout < pouts(p) + PTOL)
                        adjusted = 1;
                    else
                        pout_err = pouts(p) - pout;
                        if (pout_err < 0)
                            pout_err = pout_err / 2;
                        elseif (pout_err > MAXSTEP)
                            pout_err = MAXSTEP;
                        end
                        pgen(f) = pgen(f) + pout_err;
                        pin_new = pin + pout_err;
                        if (pin_new > pmax)
                            fprintf(2,' Drive level exceeds limit: %5.2f\n',pin_new);
                            return;
                        elseif (pin_new > Off1(f) + 20)
                            fprintf(2,' Drive level too high for sensor A: %5.2f\n',pin_new);
                            return;
                        end
                    end
                    if (exist('dmm2','var') && ~PULSED_ID)
                        fprintf(dmm2,'READ?');
                        ig = 1000 / IG_GAIN * fscanf(dmm2,'%f');
                        if (abs(ig) >= IG_MAX)
                            below_igmax(f) = 0;
                            break;
                        end
                    end
                    last_pout = pout;
                    last_pin = pin;
                end
                %if (~below_genmax(f))
                    % if we hit MAXPGEN, we never made a measurement
                %    continue;
                %end
                if (exist('THR_ADR','var'))
                    flushinput(thr);
                    fprintf(thr,'A'); % measure device case temperature
                end
                poutw = 10 ^ ((pout - 30) / 10);
                poutw_avg = 10 ^ ((pout_avg - 30) / 10);
                pinw = 10 ^ ((pin - 30) / 10);
                gain = pout - pin;
                if (gain > maxgain(f))
                    maxgain(f) = gain;
                end
                fprintf('\t\t%5.2f\t%5.2f\t%5.2f\t%5.2f', pin, pout, gain, poutw);
                result=sprintf('%.2f,%.2f,%.2f,%.2f,%.2f',freq,pin,pout,gain,poutw);
                
                if (PLOT)
                    plotf(f)=freq;
                    plotg(f)=gain;
                    if (f==1)
                        h = plot(plotf,plotg,'b-square');
                        set(gca,'Xlim',[freqs(1) freqs(nfreqs)]);
                        set(h,'XDataSource','plotf');
                        set(h,'YDataSource','plotg');
                    end
                    refreshdata(h,'caller');
                end
                
                if (PULSED_ID)
                    fprintf(dmm2,'READ?');
                    curr = fscanf(dmm2,'%f') / ID2_GAIN;
                elseif (exist('dmm','var'))
                    fprintf(dmm,DMM_QUERY);
                    curr = fscanf(dmm,'%f') / ID_GAIN;
                else
                    fprintf(ps,PS_I_QUERY);
                    curr = fscanf(ps,'%f');
                end
                if (PULSED_ID)
                    pdc = voltage * curr * DUTY;
                    equiv_curr = curr;
                else
                    pdc = voltage * curr;
                    equiv_curr = idq + (curr - idq - IOFF) / DUTY;
                end
                pdiss = pdc - poutw_avg;
                tjc = Rjc * pdiss;
                if (strcmp(EFFTYPE,'PAE'))
                    eff = 100 * (poutw - pinw) / (voltage * equiv_curr);
                else
                    eff = 100 * poutw / (voltage * equiv_curr);
                end
                if (exist('THM_ADR','var'))
                    fprintf(thm,'MEAS:VOLT:DC?');
                    tc = 1000 * fscanf(thm,'%f');
                    tj = tc + tjc;
                    fprintf('\t%5.2f\t%5.2f\t%5.1f\t%5.1f\t%5.1f', equiv_curr, eff, pdiss, tc, tj);
                    result=sprintf('%s,%.2f,%.2f,%.1f,%.1f,%.1f',result,equiv_curr,eff,pdiss,tc,tj);
                elseif (exist('THR_ADR','var'))
                    T = fread(thr,11);
                    tc = (256 * T(8) + T(9)) / 10;
                    tj = tc + tjc;
                    t2 = (256 * T(10) + T(11)) / 10;
                    fprintf('\t%5.2f\t%5.2f\t%5.1f\t%5.1f\t%5.1f\t%5.1f',equiv_curr,eff,pdiss,tc,tj,t2);
                    result=sprintf('%s,%.2f,%.2f,%.1f,%.1f,%.1f,%.1f',result,equiv_curr,eff,pdiss,tc,tj,t2);
                else
                    fprintf('\t%5.2f\t%5.2f\t%5.1f', equiv_curr, eff, pdiss);
                    result=sprintf('%s,%.2f,%.2f,%.1f',result,equiv_curr,eff,pdiss);
                end
                if (exist('dmm2','var') && ~PULSED_ID)
                    fprintf('\t%5.2f',ig);
                    result=sprintf('%s,%.2f',result,ig);
                end
                if (~below_comp(f))
                    fprintf(2,' %d dB compression',COMP);
                    result=sprintf('%s,"%d dB compression"',result,COMP);
                elseif (~below_igmax(f))
                    fprintf(2,' Ig at limit');
                    result=sprintf('%s,"Ig at limit"',result);
                elseif (~below_genmax(f))
                    fprintf(2,' Generator at limit');
                end
                fprintf('\n');
                csvdata(f)=cellstr(result);
            end
            if (csv)
                fprintf(csv,'%s\n',char(csvdata(f)));
            end
        end
    end

    function sweepcleanup(GEN)
        % sleepcleanup executes when f_pin_sweep ends
        if (strcmp(GEN,'SRS'))
            fprintf(gen,'ENBR 0\n');
        else
            fprintf(gen,':OUTP:STAT OFF');
        end
        fclose(gen);
        fprintf(pwr,'INIT:CONT ON');
        fclose(pwr);
        if (csv)
            fclose(csv);
        end
        if (exist('dmm','var'))
            fclose(dmm);
        end
        if (exist('thm','var'))
            fclose(thm);
        end
        if (exist('thr','var'))
            fclose(thr);
        end
        if (exist('dmm2','var'))
            fclose(dmm2);
        end
        fclose(ps);
    end
end
