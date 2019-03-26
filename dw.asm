
; 1. załadować binarnie niniejszy program
; 2. uruchomić
; 3. przez port szeregowy przesłać dane do zapisania na dyskietce
; 4. kiedy wysłane zostaną wszystkie dane - podnieść OPRQ
; 5. dane zostaną zapisane na dyskietce

	.cpu	mera400

	.include cpu.inc
	.include io.inc

	uj	start

imask:	.word	IMASK_ALL & ~IMASK_CPU_H
imask0:	.word	IMASK_NONE

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

.ifdef DEBLIN
	.const	CH 15
	.const	TERM	CH\IO_CHAN | 0\IO_DEV
	.const	FLOP	CH\IO_CHAN | 2\IO_DEV
	.const	PC	CH\IO_CHAN | 4\IO_DEV
uzdat_list:
	.word	TERM, PC, -1
.else
	.const	CH 7
	.const	TERM	CH\IO_CHAN | 0\IO_DEV
	.const	FLOP	CH\IO_CHAN | 0\IO_DEV
	.const	PC	CH\IO_CHAN | 0\IO_DEV
uzdat_list:
	.word	PC, -1
.endif

; ------------------------------------------------------------------------
oprq:
	lw	r4, got_all
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

len:	.res	1
sum:	.res	1

read_data:

	lw	r1, oprq
	rw	r1, INTV_OPRQ

	; initialize KZ

	lw	r1, CH
	lw	r2, uzdat_list
	lj	kz_init

	im	imask

	; read data length

	lw	r1, len
	lw	r2, PC
	lw	r3, 1
	lj	readw

	; read control sum

	lw	r1, sum
	lw	r2, PC
	lw	r3, 1
	lj	readw

	; read data

	lw	r1, buf
	lw	r2, PC
	lw	r3, 65535-buf
	lj	readw

got_all:

	; check control sum

	lw	r1, buf
	lw	r2, [len]
	lj	ctlsum

	cw	r1, [sum]
	jes	write_data
	im	imask0
.loop_hlt:
	hlt	033
	ujs	.loop_hlt

write_data:

	im	imask

	lw	r1, buf
	lw	r2, FLOP
	lw	r3, [len]
	lj	writew

	lw	r2, FLOP
	lj	kz_detach

	lw	r2, FLOP
	lj	kz_reset

	hlt

; ------------------------------------------------------------------------
buf:
