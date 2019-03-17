
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

imask:	.word	IMASK_ALL & ~(IMASK_CPU_H | IMASK_GROUP_L)

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

.ifndef DEBLIN
	.include prng.inc

; ------------------------------------------------------------------------
; r1 - byte address of the buffer
; r2 - device number
; r3 - byte count
; RETURN: r1 - operation result
read_fake:
	.res	1
	rl	.regs

	lw	r5, r1
	lw	r6, r3

	lj	urand
	cw	r1, 10000
	jls	.loop_empty

.loop_rnd:
	lj	urand
	rb	r1, r5
	awt	r5, 1
	drb	r6, .loop_rnd
	ujs	.done

.loop_empty:
	rb	r1, r5
	awt	r5, 1
	drb	r6, .loop_empty

.done:
	lwt	r1, 0
	ll	.regs
	uj	[read_fake]
.regs:	.res	3

.endif

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

	; initialize KZ
	lw	r1, CH
	lw	r2, devices
	lj	kz_init

	im	imask

; ------------------------------------------------------------------------

.ifndef DEBLIN
	lwt	r1, 10
	lwt	r2, 33
	lj	seed
.endif

.ifdef DEBLIN
	.const	TRACKS 73+1
	.const	SPT 26
.else
	.const	TRACKS 3
	.const	SPT 2
.endif
	.const	SECT_LEN 128
	.const	READ_LEN SECT_LEN

	; seek to track 0, 'the special one'

.ifdef DEBLIN
	lw	r1, KZ_FLOPPY_DRIVE_0 | KZ_FLOPPY_SIDE_A | 0\KZ_FLOPPY_TRACK | 1\KZ_FLOPPY_SECTOR
	ou	r1, CH\IO_CHAN | 2\IO_DEV | KZ_CMD_CTL4
	.word	.no, .en, .ok, .pe
.no:
.en:
.pe:	hlt	044
.ok:
.endif
	; load track count

	lw	r6, -TRACKS

.loop_track:

	; load sector count

	lw	r5, -SPT

.loop_sector:

	; write track number byte

	lw	r1, r6 + TRACKS
	lwt	r2, PC
	lj	putc

	; write sector number byte

	lw	r1, r5 + SPT+1
	lwt	r2, PC
	lj	putc

	; clear the buffer

	lw	r1, buf
	lw	r2, READ_LEN/2
	lw	r3, '__'
	lj	memset

	; read data from disk

	lw	r1, buf<<1
	lwt	r2, FLOP
	lw	r3, READ_LEN
.ifdef DEBLIN
	lj	read
.else
	lj	read_fake
.endif

	; write return code byte

	lwt	r2, PC
	lj	putc

	; write I/O status byte

	lw	r1, [kz_last_intspec]
	lwt	r2, PC
	lj	putc

	; calculate control sum

	lw	r1, buf
	lw	r2, READ_LEN/2
	lj	ctlsum

	; write control sum word

	lwt	r2, PC
	lj	put2c

	; check for blank sector

	lw	r3, (READ_LEN/2)-1
	lw	r2, [buf]
	awt	r1, 1
.chkloop:
	cw	r2, [buf+r3]
	jn	.regular_sector
	drb	r3, .chkloop
	ujs	.empty_sector

.regular_sector:

	; write frame type (0: regular)

	lw	r1, 0
	lwt	r2, PC
	lj	putc

	; write data len word

	lw	r1, READ_LEN
	lwt	r2, PC
	lj	put2c

	; write data

	lw	r1, buf<<1
	lwt	r2, PC
	lw	r3, READ_LEN
	lj	write

	ujs	.loop_restart

.empty_sector:

	; write frame type (1: fill)

	lw	r1, 1
	lwt	r2, PC
	lj	putc

	; write data len word

	lw	r1, 2
	lwt	r2, PC
	lj	put2c

	; write data

	lw	r1, [buf]
	lwt	r2, PC
	lj	put2c

.loop_restart:

	; loop over

	awt	r5, 1
	jm	.loop_sector

	awt	r6, 1
	jm	.loop_track

	hlt

; ------------------------------------------------------------------------
buf:
