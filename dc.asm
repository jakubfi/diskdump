
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
	lw	r5, buf<<1
.read_next_char:
	lwt	r2, 0
	lj	getc

	rb	r1, r5
	awt	r5, 1

	cwt	r1, '\x0d'
	jes	.print
	ujs	.read_next_char

.print:	
	lwt	r1, 0
	rb	r1, r5

	lwt	r2, 0
	lw	r1, txt
	lj	puts

	lwt	r2, 0
	lw	r1, buf
	lj	puts

	lwt	r2, 0
	lw	r1, nl
	lj	puts

	ujs	.loop

txt:	.asciiz "Dostałem: "
nl:	.asciiz "\n\r"

; ------------------------------------------------------------------------
stack:	.res	11*4
buf:
