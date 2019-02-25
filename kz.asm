
drv_kz:
	.word	kz_init
	.word	kz_reset
	.word	kz_getc
	.word	kz_putc

imask_noch:
        .word   IMASK_ALL-IMASK_ALL_CH

; ------------------------------------------------------------------------
; r1 - channel number
; r2 - device table
kz_init:
	.res	1
	lw	r6, r2
.loop:
	lw	r5, [r6+dev.type]
	cwt	r5, DEV_NONE
	jes	.done
	; is this a terminal?
	cwt	r5, DEV_TERM
	jn	.next
	; is this terminal in channel that is being configured?
	lw	r5, [r6+dev.ioaddr]
	srz	r5
	nr	r5, 0b1111
	cw	r5, r1
	jn	.next
	; send initial 'read' command to the terminal
	md	[r6+dev.ioaddr]
	in	r5, KZ_CMD_DEV_READ
	.word	.next, .next, .next, .next

.next:	
	awt	r6, dev
	ujs	.loop
.done:	; wait for UZ-DATs to get their states straight
	lw	r6, -1000
.wait:	irb	r6, .wait

	lw	r6, kz_irq
	rw	r6, INTV_CH0 + r1

	uj	[kz_init]

; ------------------------------------------------------------------------
kz_reset:
	.res	1
	uj	[kz_reset]

; ------------------------------------------------------------------------
kz_irq:
	lw	r4, [kz_idle]
	cwt	r4, 0
	jes	.done
	md	[STACKP]
	rw	r4, -SP_IC
	rz	kz_idle
.done:	
	lip

; ------------------------------------------------------------------------
kz_idle:
	.res	1
	im	imask
.halt:	hlt
	ujs	.halt

; ------------------------------------------------------------------------
; r1 - character to print (on right byte)
; r2 - device specification as for IN/OU
; RETURN: r1 - operation result
kz_putc:
	.res	1

.retry:	im	imask_noch

	ou	r1, r2 + KZ_CMD_DEV_WRITE
	.word	.no, .en, .ok, .ok

.en:	lj	kz_idle
	ujs	.retry

.no:	lwt	r1, RET_NODEV
	ujs	.done
.ok:	lwt	r1, RET_OK
.done:	im	imask
	uj	[kz_putc]

; ------------------------------------------------------------------------
; r2 - device specification as for IN/OU
; RETURN: r1 - >0 character on the right byte if OK
; RETURN: r1 - <0 if error
kz_getc:
	.res	1

.retry:	im	imask_noch

	in	r1, r2 + KZ_CMD_DEV_READ
	.word	.no, .en, .ok, .ok

.en:	lj	kz_idle
	ujs	.retry

.no:	lwt	r1, RET_NODEV
.ok:	im	imask
	uj	[kz_getc]

