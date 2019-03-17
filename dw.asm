
; 1. załadować binarnie niniejszy program, uruchomić
; 2. kiedy zatrzyma się na HLT, 0 zatrzymać maszynę
; 3. wprowadzić binarnie pod zastany adres w R7 dane do wgrania na dysk
; 4. IC=0
; 5. na kluczach ustawić wartość, jaka jest w AR (koniec danych)
; 6. START

	.cpu	mera400

	.include cpu.inc
	.include io.inc

	.const	RET_OK 0
	.const	RET_NODEV -1
	.const	RET_PARITY -2
	.const	RET_IOERR -3

	.const	DEV_NONE 0
	.const	DEV_TERM 1
	.const	DEV_FLOP 2

.struct dev:
	.type:	.res 1
	.ioaddr:.res 1
	.drv:	.res 1
.endstruct

.struct driver:
	.init:	.res 1
	.reset:	.res 1
	.detach:.res 1
	.getc:	.res 1
	.putc:	.res 1
.endstruct

	uj	start

devices:

.ifdef DEBLIN
	.const	CH 15

	.word	DEV_TERM,	CH\IO_CHAN | 0\IO_DEV,	drv_kz ; 0: UZ-DAT terminal znakowy
	.word	DEV_FLOP,	CH\IO_CHAN | 2\IO_DEV,	drv_kz ; 1: UZ-FX flop
	.word	DEV_TERM,	CH\IO_CHAN | 4\IO_DEV,	drv_kz ; 2: UZ-DAT usb<->PC
	.word	DEV_NONE,	0,			0

	.const	TERM 0
	.const	FLOP 1
	.const	PC 2
.else
	.const	CH 7

	.word	DEV_TERM,	CH\IO_CHAN | 0\IO_DEV,	drv_kz
	.word	DEV_NONE,	0,			0

	.const	TERM 0
	.const	FLOP 0
	.const	PC 0
.endif

imask:	.word	IMASK_ALL & ~IMASK_CPU_H

dummy:	hlt	045
	ujs	dummy

stack:	.res	11*4, 0x0ded

	.org	INTV
	.res	32, dummy
	.org	EXLV
	.word	dummy
	.org	STACKP
	.word	stack
	.org	OS_START

	.include kz.asm
	.include stdio.asm

; ------------------------------------------------------------------------
oprq:
	lw	r4, write_data
	md	[STACKP]
	rw	r4, -SP_IC
	lip

; ------------------------------------------------------------------------
; ------------------------------------------------------------------------
; ------------------------------------------------------------------------

start:

	mcl

	; configure OS memory: 64k, 2 modules 32k each
	lwt	r2, 2		; page number
.nx_cfg:
	lw	r1, r2
	shc	r1, 4		; move to the page number position
	aw	r1, 0\15	; segment is 0

	lw	r3, r2
	shc	r3, 11			; move to the frame number position
	nr	r3, 0b0000000011100000	; lower bits - frame number
	lw	r4, r2
	shc	r4, 2			; move to the memory module number position
	nr	r4, 0b0000000000000010	; highest bit - memory module number
	aw	r3, r4
	aw	r3, MEM_CFG
	ou	r1, r3
	.word	.no, .en, .ok, .pe
.no:	hlt	010
.en:	hlt	011
.pe:	hlt	012

.ok:
	awt	r2, 1
	cwt	r2, 16
	jes	read_data
	ujs	.nx_cfg

; ------------------------------------------------------------------------

read_data:

	lw	r1, oprq
	rw	r1, INTV_OPRQ

	; initialize KZ
	lw	r1, CH
	lw	r2, devices
	lj	kz_init

	im	imask

	lw	r1, buf
	lw	r2, PC
	lw	r3, 65535-buf
	lj	readw

write_data:

	im	imask

	lw	r1, buf
	lw	r2, FLOP
	lw	r3, r7
	sw	r3, buf
	lj	writew

	lw	r2, FLOP
	lj	detach

	lw	r2, FLOP
	lj	reset

	hlt

; ------------------------------------------------------------------------
buf: