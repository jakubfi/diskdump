
drv_kz:
	.word	kz_init
	.word	kz_reset
	.word	kz_getc
	.word	kz_putc

imask_noch:
        .word   IMASK_ALL-IMASK_ALL_CH

kz_last_intspec:
	.res	1

; ------------------------------------------------------------------------
; r1 - channel number
; r2 - device table
kz_init:
	.res	1
	lw	r4, r2
.loop:
	lw	r3, [r4+dev.type]
	cwt	r3, DEV_NONE
	jes	.done
	; is this a terminal?
	cwt	r3, DEV_TERM
	jn	.next
	; is this terminal in channel that is being configured?
	lw	r3, [r4+dev.ioaddr]
	srz	r3
	nr	r3, 0b1111
	cw	r3, r1
	jn	.next
	; send initial 'read' command to the terminal
	md	[r4+dev.ioaddr]
	in	r3, KZ_CMD_DEV_READ
	.word	.next, .next, .next, .next

.next:	
	awt	r4, dev
	ujs	.loop
.done:	; wait for UZ-DATs to get their states straight
	lw	r4, -1000
.wait:	irb	r4, .wait

	lw	r4, kz_irq
	rw	r4, INTV_CH0 + r1

	uj	[kz_init]

; ------------------------------------------------------------------------
kz_reset:
	.res	1
	; TODO
	uj	[kz_reset]

; ------------------------------------------------------------------------
kz_irq:
	rws	r4, .regs

	lw	r4, [kz_idle]
	cwt	r4, 0
	jes	.done

	md	[STACKP]
	rw	r4, -SP_IC

	md	[STACKP]
	lw	r4, [-SP_SPEC]
	shc	r4, 8
	zlb	r4
	rw	r4, kz_last_intspec

	rz	kz_idle
.done:
	lws	r4, .regs
	lip
.regs:	.res	1

; ------------------------------------------------------------------------
kz_idle:
	.res	1
	im	imask
.halt:	hlt
	ujs	.halt

; ------------------------------------------------------------------------
; r1 - character to print (on right byte)
; r2 - device specification as for IN/OU
; r4 - return jump
; RETURN: r1 - operation result
kz_putc:
.retry:	im	imask_noch

	ou	r1, r2 + KZ_CMD_DEV_WRITE
	.word	.no, .en, .ok, .ok

.en:	lj	kz_idle
	ujs	.retry

.no:	lwt	r1, RET_NODEV
	ujs	.done
.ok:	lwt	r1, RET_OK
.done:	im	imask
	uj	r4

; ------------------------------------------------------------------------
; r2 - device specification as for IN/OU
; r4 - return jump
; RETURN: r1 - >0 character on the right byte if OK
; RETURN: r1 - <0 if error
kz_getc:
.retry:	im	imask_noch

	in	r1, r2 + KZ_CMD_DEV_READ
	.word	.no, .en, .ok, .pe

.en:	lj	kz_idle
	ujs	.retry
.pe:	lwt	r1, RET_PARITY
	ujs	.ok
.no:	lwt	r1, RET_NODEV
.ok:	im	imask
	uj	r4

