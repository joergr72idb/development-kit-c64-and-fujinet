# Development kit for the C64 + FujiNet: cc65 (C + ca65 assembler), fujinet-lib, VICE (FujiNet fork
# with the NetIEC bridge, incl. petcat and c1541) and FujiNet-PC built for IEC (incl. Meatloaf drives).
# All tools live in opt/ (built by tools/setup.sh).
#
#   make              build the samples into build/ (PRGs + build/samples.d64)
#   make run          FujiNet-PC + VICE with build/hello-c.prg (other program: make run PRG=path)
#   make stop         stop this kit's FujiNet-PC
#
# FujiNet devices on the emulated bus: 16 network, 29 clock, 30 FujiNet. More with
#   make run UNITS="8 16 29 30"   (drive 8 from FujiNet-PC instead of VICE's own drive)

DEV       := $(CURDIR)
CL65      := $(DEV)/opt/cc65/bin/cl65
FNLIB     := $(DEV)/opt/fujinet-lib
FNLIBA    := $(wildcard $(FNLIB)/fujinet-c64-*.lib)
VICE      := $(DEV)/opt/vice/bin
BRIDGE    := $(DEV)/opt/vice-bridge
FUJINET   := $(DEV)/opt/fujinet-pc
export CC65_HOME := $(DEV)/opt/cc65/share/cc65

CFLAGS    := -t c64 -O -I $(FNLIB) -g
PRG       ?= build/hello-c.prg
UNITS     ?= 16 29 30

# units 8-11 replace VICE's own drives (no drive, OpenCBM backend), 12-30 become real devices
VICE_UNITS := $(foreach u,$(UNITS),$(if $(filter 8 9 10 11,$(u)),\
                -drive$(u)type 0 +drive$(u)truedrive -devicebackend$(u) 2 -trapdevice$(u),\
                -realdevice$(u)))

.PHONY: all run fujinet stop clean

all: build/hello-c.prg build/hello-asm.prg build/hello-bas.prg build/samples.d64

build/hello-c.prg: samples/hello.c | build
	$(CL65) $(CFLAGS) -m build/hello-c.map -Ln build/hello-c.lbl -o $@ $< $(FNLIBA)

build/hello-asm.prg: samples/hello.s | build
	$(CL65) -t c64 -C c64-asm.cfg -u __EXEHDR__ -Ln build/hello-asm.lbl -o $@ $<

build/hello-bas.prg: samples/hello.bas | build
	$(VICE)/petcat -w2 -o $@ -- $<

build/samples.d64: build/hello-c.prg build/hello-asm.prg build/hello-bas.prg
	rm -f $@
	$(VICE)/c1541 -silent -format "samples,01" d64 $@ \
	  -write build/hello-c.prg hello-c -write build/hello-asm.prg hello-asm -write build/hello-bas.prg hello-bas

build:
	mkdir -p build/logs

# FujiNet-PC: NetIEC on TCP 1541, web UI http://localhost:8000, SD card = opt/fujinet-pc/SD
fujinet: | build
	@pgrep -f "$(FUJINET)/fujinet" >/dev/null || \
	  ( nohup $(DEV)/tools/run-fujinet >> $(DEV)/build/logs/fujinet.log 2>&1 & sleep 2 )

# -config: VICE's settings live in build/, never in ~/.config/vice
run: $(PRG) fujinet
	DYLD_LIBRARY_PATH=$(BRIDGE) $(VICE)/x64sc -config $(DEV)/build/vicerc \
	  $(VICE_UNITS) -autostart $(PRG)

# only this kit's instance (matched by its path), never other projects' FujiNet-PC
stop:
	@pkill -f "$(DEV)/tools/run-fujinet" || true
	@pkill -f "$(FUJINET)/fujinet" || true

clean:
	rm -f build/*.prg build/*.d64 build/*.map build/*.lbl build/*.o
