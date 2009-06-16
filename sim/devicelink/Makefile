VHDLC=vcom
VHDLS=vsim
WORKDIR=work
all: hw comp sim

$(WORKDIR)/devicelink/behavioral.dat: $(WORKDIR)/touched ../../vhdl/devicelink.vhd
	mkdir -p $(WORKDIR)
	$(VHDLC) ../../vhdl/devicelink.vhd

hw: $(WORKDIR)/devicelink/behavioral.dat 

$(WORKDIR)/encode8b10b/encode8b10b_a.dat: $(WORKDIR)/touched encode8b10b.vhd
	mkdir -p $(WORKDIR)
	$(VHDLC) encode8b10b.vhd

$(WORKDIR)/decode8b10b/decode8b10b_a.dat: $(WORKDIR)/touched encode8b10b.vhd decode8b10b.vhd
	mkdir -p $(WORKDIR)
	$(VHDLC) decode8b10b.vhd

comp: $(WORKDIR)/encode8b10b/encode8b10b_a.dat $(WORKDIR)/decode8b10b/decode8b10b_a.dat 

$(WORKDIR)/devicelinktest/behavioral.dat: $(WORKDIR)/touched encode8b10b.vhd decode8b10b.vhd devicelinktest.vhd
	mkdir -p $(WORKDIR)
	$(VHDLC) devicelinktest.vhd

sim: $(WORKDIR)/devicelinktest/behavioral.dat 
runsim: all
	$(VHDLS) devicelinktest


clean:
	rm -Rf work 

work/touched:
	vlib  work
	touch  work/touched
