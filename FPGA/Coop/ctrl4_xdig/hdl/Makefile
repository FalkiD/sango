TARGET = xdig
timestamp=`date '+%m%d%H%M'`

SYN = xst
BLD = ngdbuild
MAP = map
PAR = par
BITS = bitgen
PROM = promgen
PROG = impact
TIMING = trce

BINDIR = ./bin
SYNDIR = ./syn
SYNOUT = $(SYNDIR)/out
PARDIR = ./par
PAROUT = $(PARDIR)/out
SRCDIR = ./rtl

SYNFLAGS = -ifn ../$(TARGET).scr
BLDFLAGS = -sd ../../$(SYNOUT) -uc ../$(TARGET).ucf $(TARGET)
MAPFLAGS = -ol high -xe n -pr b -timing -w $(TARGET).ngd -o $(TARGET).ncd $(TARGET).pcf
PARFLAGS = -ol high -xe n -w $(TARGET).ncd $(TARGET)_routed $(TARGET).pcf
BITFLAGS = -wm -g LCK_cycle:3 -g Reset_on_err:Yes -g next_config_addr:080000 -g ICAP_Enable:Yes -g DriveDone:Yes -g UserID:0x$(timestamp) -g Compress $(TARGET)_routed.ncd $(TARGET)
PROMFLAGS = -w -p mcs -o $(TARGET) -x xc3s400an -u 0 $(TARGET).bit
MULTIPROMFLAGS = -w -p mcs -spi -s 512 -c FF -o $(TARGET)_multi -u 0 xdig-1.7.3.bit -u 42000 $(TARGET).bit
PREFLAGS = -v 100 $(TARGET).ncd $(TARGET).pcf
POSTFLAGS = -e 100 -u 100 -o $(TARGET)_routed.twr $(TARGET)_routed.ncd $(TARGET).pcf

SRC =	$(SRCDIR)/version.v $(SRCDIR)/registers.v $(SRCDIR)/xdig.v $(SRCDIR)/trig_filter.v $(SRCDIR)/tg.v \
	$(SYNDIR)/$(TARGET).prj $(SYNDIR)/$(TARGET).scr $(SYNDIR)/$(TARGET).xcf

SYNOBJS = $(SYNOUT)/$(TARGET).ngc
BLDOBJS = $(PAROUT)/$(TARGET).ngd
MAPOBJS = $(PAROUT)/$(TARGET).ncd
PAROBJS = $(PAROUT)/$(TARGET)_routed.ncd
PROMOBJS = $(PAROUT)/$(TARGET).bit $(PAROUT)/$(TARGET).mcs $(PAROUT)/$(TARGET)_multi.mcs
PREOBJS = $(PAROUT)/$(TARGET).twr
POSTOBJS = $(PAROUT)/$(TARGET)_routed.twr

all : syn bld map par prom post-trce

syn : $(SYNOBJS)

bld : $(BLDOBJS)

map : $(MAPOBJS)

par : $(PAROBJS)

prom : $(PROMOBJS)

pre-trce : $(PREOBJS)

post-trce : $(POSTOBJS)

clean :
	rm -rf $(SYNOUT)/*; rm -rf $(PAROUT)/*

# Synthesise HDL into NGC netlist files
$(SYNOBJS) : $(SRC) # Makefile
	rm -f $@; cd $(SYNOUT); $(SYN) $(SYNFLAGS)

# Translate and merge the various netlist files into a single NGD Native Generic Database
$(BLDOBJS) : $(SYNOBJS) $(PARDIR)/$(TARGET).ucf
	rm -f $@; cd $(PAROUT); $(BLD) $(BLDFLAGS)

# Map the logical NGD design into the FPGA NCD Native Circuit Description
$(MAPOBJS) : $(BLDOBJS)
	rm -f $@; cd $(PAROUT); $(MAP) $(MAPFLAGS)

# Place and route NCD design into routed NCD
$(PAROBJS) : $(MAPOBJS)
	rm -f $@; cd $(PAROUT); $(PAR) $(PARFLAGS)

# Generate a PROM file for FPGA configuration
$(PROMOBJS) : $(PAROBJS)
	rm -f $@; cd $(PAROUT); $(BITS) $(BITFLAGS)
	cd $(PAROUT); $(PROM) $(PROMFLAGS); $(PROM) $(MULTIPROMFLAGS)

# Generate a timing report before PAR
$(PREOBJS) : $(MAPOBJS)
	rm -f $@; cd $(PAROUT); $(TIMING) $(PREFLAGS)

# Generate a timing report after PAR
$(POSTOBJS) : $(PAROBJS)
	rm -f $@; cd $(PAROUT); $(TIMING) $(POSTFLAGS)
