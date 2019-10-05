INCLUDES=stdio.asm kz.asm crc.asm
CFG=em400.cfg
UPLOAD_PORT=/dev/ttyUSB0

all: dd dw

dd: dd.asm $(INCLUDES)
	emas -o dd -c mera400 -Oraw dd.asm

dw: dw.asm $(INCLUDES)
	emas -o dw -c mera400 -Oraw dw.asm

emu: $(BIN)
	em400 -c $(CFG) -p dd

push: $(BIN)
	embin -o $(UPLOAD_PORT) dd

clean:
	rm -f dw dd *.log
