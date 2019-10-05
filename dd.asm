
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

	.const	TRACKS	76
	.const	SPT	26
	.const	HEADER_LEN 4
	.const	SECT_LEN 128

drive:	.word	0
retries:.word	0
conf_retries:
	.word	0

; ------------------------------------------------------------------------
dly:
	.res	1
	lw	r2, 500
.loop1:	lw	r1, 1000	; ~2.2ms
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
configure:
	.res	1

	; load disk address, initial track number, and retries
	; provided on keys: (mmdstttttttRRRRR)
	;
	; mm - module: (00 - left, 10 - right)
	; d - disk (0 - left, 1 - right)
	; s - side (0 - A, 1 - B)
	; t - track (1-73)
	; R - number of retries
	;
	; sector is always set to 1 (sectors are numbered from 1)
	; if retries == 0 retries = 1

	rky	r1

	; drive
	lw	r2, r1
	er	r2, 0b111111111111
	rw	r2, drive

	; retries
	lw	r2, r1
	nr	r2, 0b11111
	blc	?Z
	lwt	r2, 1 ; always at least 1 repetition (helps)
	rw	r2, conf_retries
	rw	r2, retries

	; track
	shc	r1, 5
	lw	r6, r1
	nr	r6, 0b1111111

	; sector
	lw	r5, 1 ; always start with sector 1

	uj	[configure]

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

; r5 - sector number
; r6 - track number
; r4 - data pointer

start:
	lj	configure

	; initialize KZ

	lw	r1, CH
	lw	r2, uzdat_list
	lj	kz_init

	im	imask

	; set initial head position

	lj	reposition

dump_sector:

	lw	r4, header<<1

	; store track number byte

	rb	r6, r4
	awt	r4, 1

	; store sector number byte

	rb	r5, r4
	awt	r4, 1

	; clear the data buffer

	lw	r1, buf
	lw	r2, SECT_LEN/2
	lw	r3, '__'
	lj	memset

	; read data from disk
retry:
	lw	r1, buf
	lw	r2, FLOP
	lw	r3, SECT_LEN
	lj	read

	cw	r1, 0
	jls	error_sector

	; reset retry counter
	lw	r7, [conf_retries]
	rw	r7, retries

frame_write:

	; store return code byte

	rb	r1, r4
	awt	r4, 1

	; store I/O status byte

	lw	r1, [kz_last_intspec]
	rb	r1, r4
	awt	r4, 1

	; send header

	lw	r1, header
	lw	r2, PC
	lw	r3, HEADER_LEN
	lj	write

	; calculate header crc

	lw	r1, header
	lw	r2, HEADER_LEN
	lj	crc16

	; send header crc word

	lw	r2, PC
	lj	put2c

	; send data

	lw	r1, buf
	lw	r2, PC
	lw	r3, SECT_LEN
	lj	write

	; calculate data crc

	lw	r1, buf
	lw	r2, SECT_LEN
	lj	crc16

	; send data crc word

	lw	r2, PC
	lj	put2c

	uj	loop_restart

error_sector:
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
	uj	retry

.old_regs:	.res 7
.done_retrying:
	; reset retry counter
	lw	r7, [conf_retries]
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
	lw	r2, SECT_LEN/2
	lw	r3, '??'
	lj	memset

	la	.old_regs

	; continue with writting the frame as if nothing happened

	uj	frame_write

empty_sector:

	; send frame type (1: fill)

	lw	r1, 1
	lw	r2, PC
	lj	putc

	; send data len word

	lw	r1, 2
	lw	r2, PC
	lj	put2c

	; send data

	lw	r1, [buf]
	lw	r2, PC
	lj	put2c

loop_restart:

	; loop over

	awt	r5, 1
	cw	r5, SPT+1
	jl	dump_sector

	lwt	r5, 1
	awt	r6, 1
	cw	r6, TRACKS+1
	jl	dump_sector

	; stop the drive

        lw      r2, FLOP
        lj      kz_reset

hltl:	hlt
	ujs	hltl

; ------------------------------------------------------------------------
header:	.res	16
buf:
