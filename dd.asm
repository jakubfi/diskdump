
	.cpu	mera400

	.include cpu.inc
	.include io.inc

	.const	RET_OK 0
	.const	RET_NODEV -1
	.const	RET_PARITY -2

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
	.getc:	.res 1
	.putc:	.res 1
.endstruct

	uj	start

devices:
	.word	DEV_TERM,	7\IO_CHAN | 0\IO_DEV,	drv_kz
	.word	DEV_FLOP,	7\IO_CHAN | 5\IO_DEV,	drv_kz
	.word	DEV_NONE,	0,			0

imask:	.res	1

dummy:	lip

stack:	.res	11*4, 0x0ded

	.org	INTV
	.res	32, dummy
	.org	OS_START

	.include kz.asm
	.include stdio.asm

; ------------------------------------------------------------------------
; ------------------------------------------------------------------------
; ------------------------------------------------------------------------
start:
	mcl

	lw	r1, stack
	rw	r1, STACKP
	lw	r1, IMASK_ALL
	rw	r1, imask

	; initialize KZ in channel 7
	lw	r1, 7
	lw	r2, devices
	lj	kz_init

	im	imask
.loop:
	lw	r1, test
	lwt	r2, 4
	lj	ctlsum

	lw	r2, buf<<1
	lj	unsigned2asc

	lw	r1, buf<<1
	lw	r2, 0
	lj	puts

	lw	r2, 0
	lw	r1, '\n\t'
	lj	put2c

	hlt

; ------------------------------------------------------------------------
txt:	.asciiz	"Mam: "
	.asciiz	"------------------------------------------------------\r\n"
buf:	.asciiz	"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r\n"
test:	.word	1, 2, 1000, 20000
