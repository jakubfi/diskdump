
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
	.getc:	.res 1
	.putc:	.res 1
.endstruct

	uj	start

devices:
	; Dęblin:
	;.word	DEV_TERM,	15\IO_CHAN | 0\IO_DEV,	drv_kz ; 0: UZ-DAT terminal znakowy
	;.word	DEV_FLOP,	15\IO_CHAN | 2\IO_DEV,	drv_kz ; 1: UZ-FX flop
	;.word	DEV_TERM,	15\IO_CHAN | 4\IO_DEV,	drv_kz ; 2: UZ-DAT usb<->PC
	;.word	DEV_NONE,	0,			0

	; Merusia:
	.word	DEV_TERM,	7\IO_CHAN | 0\IO_DEV,	drv_kz
	.word	DEV_NONE,	0,			0

	.const	PC 0
	.const	FLOP 0
	.const	TERM 0

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

; 1 ścieżka do celów specjalnych (0)
; 73 ścieżki użytkowe (1-73)
; 3 ścieżki zapasowe (74-76)
;
; 26 sektorów, 128 bajtów
; 3328 bajtów na ścieżkę
; 242944 bajtów na stronę
;
; przerwanie 'koniec nośnika' 00100 pojawia się przy próbie dostępu
; do ostatniego sektora (26) ostatniej ścieżki (73)
; i poprzedza przerwanie 'ponowna gotowość'

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

	lwt	r2, 0
	lw	r1, txt<<1
	lj	puts

	hlt

; ------------------------------------------------------------------------
txt:	.asciiz	"Test\r\n"
	.asciiz	"------------------------------------------------------\r\n"
buf:	.asciiz	"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r\n"
test:	.word	1, 2, 1000, 20000
