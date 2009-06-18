VHDLC=vcom
VHDLS=vsim
WORKDIR=work
all: hw comp sim

$(WORKDIR)/devicelink/behavioral.dat: $(WORKDIR)/touched ../../vhdl/devicelink.vhd
	mkdir -p $(WORKDIR)
	$(VHDLC) ../../vhdl/devicelink.vhd

hw: $(WORKDIR)/devicelink/behavioral.dat 

$(WORKDIR)/dlencode8b10b/dlencode8b10b_a.dat: $(WORKDIR)/touched dlencode8b10b.vhd
	mkdir -p $(WORKDIR)
	$(VHDLC) dlencode8b10b.vhd

$(WORKDIR)/dldecode8b10b/dldecode8b10b_a.dat: $(WORKDIR)/touched dlencode8b10b.vhd dldecode8b10b.vhd
	mkdir -p $(WORKDIR)
	$(VHDLC) dldecode8b10b.vhd

comp: $(WORKDIR)/dlencode8b10b/dlencode8b10b_a.dat $(WORKDIR)/dldecode8b10b/dldecode8b10b_a.dat 

$(WORKDIR)/devicelinktest/behavioral.dat: $(WORKDIR)/touched dlencode8b10b.vhd dldecode8b10b.vhd devicelinktest.vhd
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
