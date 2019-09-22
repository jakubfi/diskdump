
	.cpu	mera400

	.include cpu.inc
	.include io.inc

	uj	start

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
	.include crc.asm

; ------------------------------------------------------------------------

	.const	CH	15
	.const	PC	CH\IO_CHAN | 3\IO_DEV
	.const	FLOP	CH\IO_CHAN | 2\IO_DEV
uzdat_list:
	.word	PC, -1

	.const	TRACKS 73
	.const	SPT 26
	.const	SECT_LEN 128
	.const	READ_LEN SECT_LEN
	.const	RETRY	0

drive:	.word	KZ_FLOPPY_DRIVE_0 | KZ_FLOPPY_SIDE_A
retries:.res	1

; ------------------------------------------------------------------------
dly:
	.res	1
	lw	r2, 500
.loop1:	lw	r1, 1000	; ~1ms
.loop2:	drb	r1, .loop2
	drb	r2, .loop1
	uj	[dly]

; ------------------------------------------------------------------------
reposition:
	.res	1

	; current sector
	lw	r1, r5

	; current track
	lw	r2, r6
	shc	r2, -5
	or	r1, r2

	; drive
	lw	r2, [drive]
	or	r1, r2

	lw	r2, FLOP
	lj	kz_seek

	uj	[reposition]

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
	; set initial retries
	lw	r1, RETRY
	rw	r1, retries

	; read left/right door selection
	rky	r1
	cl	r1, 1
	jn	.init
	lw	r1, KZ_FLOPPY_DRIVE_1 | KZ_FLOPPY_SIDE_A
	rw	r1, drive

.init:
	; initialize KZ
	lw	r1, CH
	lw	r2, uzdat_list
	lj	kz_init

	im	imask

; ------------------------------------------------------------------------

	; load initial track and sector

	lw	r6, 1
	lw	r5, 1

;	lj	reposition

.loop_sector:

	; write track number byte

	lw	r1, r6
	lw	r2, PC
	lj	putc

	; write sector number byte

	lw	r1, r5
	lw	r2, PC
	lj	putc

	; clear the buffer

	lw	r1, buf
	lw	r2, READ_LEN/2
	lw	r3, '__'
	lj	memset

	; read data from disk
.retry:
	lw	r1, buf
	lw	r2, FLOP
	lw	r3, READ_LEN
	lj	read

	cw	r1, 0
	jls	.error_sector

.frame_write:

	; write return code byte

	lw	r2, PC
	lj	putc

	; write I/O status byte

	lw	r1, [kz_last_intspec]
	lw	r2, PC
	lj	putc

	; calculate crc

	lw	r1, buf
	lw	r2, READ_LEN
	lj	crc16

	; write crc word

	lw	r2, PC
	lj	put2c

	; check for blank sector

	lw	r3, (READ_LEN/2)-1
	lw	r2, [buf]
	awt	r1, 1
.chkloop:
	cw	r2, [buf+r3]
	jn	.regular_sector
	drb	r3, .chkloop
	uj	.empty_sector

.error_sector:
	; retries exhausted?
	lw	r7, [retries]
	cwt	r7, 0
	jes	.done_retrying

	; retries--
	awt	r7, -1
	rw	r7, retries

	; reposition the head in the same spot
	; because failed read resets the head to initial position
	lj	reposition
	uj	.retry

.old_regs:	.res 7
.done_retrying:
	; reset retry counter
	lw	r7, RETRY
	rw	r7, retries

	ra	.old_regs

	; reposition the head on the next sector/track
	awt	r5, 1
	cw	r5, SPT+1
	jl	.repos
	lwt	r5, 1
	awt	r6, 1
	cw	r6, TRACKS+1
	jl	.repos
	ujs	.no_repos
.repos:
	lj	reposition
.no_repos:

	; fill the sector data with '?'
	lw	r1, buf
	lw	r2, READ_LEN/2
	lw	r3, '??'
	lj	memset

	la	.old_regs

	; continue with writting the frame as if nothing happened

	uj	.frame_write

.regular_sector:

	; write frame type (0: regular)

	lw	r1, 0
	lw	r2, PC
	lj	putc

	; write data len word

	lw	r1, READ_LEN
	lw	r2, PC
	lj	put2c

	; write data

	lw	r1, buf
	lw	r2, PC
	lw	r3, READ_LEN
	lj	write

	ujs	.loop_restart

.empty_sector:

	; write frame type (1: fill)

	lw	r1, 1
	lw	r2, PC
	lj	putc

	; write data len word

	lw	r1, 2
	lw	r2, PC
	lj	put2c

	; write data

	lw	r1, [buf]
	lw	r2, PC
	lj	put2c

.loop_restart:

	; loop over

	awt	r5, 1
	cw	r5, SPT+1
	jl	.loop_sector

	lwt	r5, 1
	awt	r6, 1
	cw	r6, TRACKS+1
	jl	.loop_sector

        lw      r2, FLOP
        lj      kz_reset

	hlt

; ------------------------------------------------------------------------
;txt:	.res	8
;track:	.asciiz	"Track: "
buf:
