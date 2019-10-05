	.const	RET_OK 0
	.const	RET_NODEV -1
	.const	RET_PARITY -2
	.const	RET_IOERR -3

imask_noch:
        .word   IMASK_ALL & ~(IMASK_CPU_H | IMASK_GROUP_L | IMASK_ALL_CH)

kz_dev_waiting:
	.res	1
kz_last_intspec:
	.word	1

; ------------------------------------------------------------------------
; r1 - channel number
; r2 - UZ-DAT list (-1 terminated)
kz_init:
	.res	1

.loop:
	lw	r3, [r2]
	cwt	r3, -1
	jes	.done

	in	r3, r3 + KZ_CMD_DEV_READ
	.word	.next, .next, .next, .next

.next:	
	awt	r2, 1
	ujs	.loop

.done:
	; wait for UZ-DATs to get their states straight
	lw	r4, -1000
.wait:	irb	r4, .wait

	lw	r4, kz_irq
	rw	r4, INTV_CH0 + r1

	uj	[kz_init]

; ------------------------------------------------------------------------
kz_irq:
	rws	r4, .r4
	rws	r4, .r7

	lw	r4, [kz_idle]
	cwt	r4, 0
	jes	.done

	md	[STACKP]
	lw	r4, [-SP_SPEC]

	lw	r7, 0b111\10
	bs	r4, [kz_dev_waiting]
	ujs	.dev_mismatch

	shc	r4, 8
	zlb	r4
	rw	r4, kz_last_intspec
	cw	r4, KZ_INT_MEDIUM_END
	jes	.done

	lw	r4, [kz_idle]
	md	[STACKP]
	rw	r4, -SP_IC
	rz	kz_idle
.done:
	lws	r4, .r4
	lws	r4, .r7
	lip
.dev_mismatch:
	hlt	077
	ujs	.dev_mismatch
.r4:	.res	1
.r7:	.res	1

; ------------------------------------------------------------------------
kz_idle:
	.word	0
	im	imask
.halt:	hlt
	ujs	.halt

; ------------------------------------------------------------------------
; r2 - device specification as for IN/OU
kz_reset:
	.res	1
	ou	r2, r2 + KZ_CMD_DEV_RESET
	.word	.no, .en, .ok, .pe
.no:
.en:
.ok:
.pe:
	uj	[kz_reset]

; ------------------------------------------------------------------------
; r2 - device specification as for IN/OU
; RETURN: r1 - result
; FIXME: to nie będzie działać
kz_detach:
	.res	1
.retry:	im	imask_noch
	rw	r2, kz_dev_waiting

	ou	r2, r2 + KZ_CMD_DEV_DETACH
	.word	.no, .en, .ok, .pe

.en:	lj	kz_idle
	ujs	.retry

.no:	lwt	r1, RET_NODEV
	ujs	.done
.pe:
.ok:	lwt	r1, RET_OK
.done:	im	imask

	uj	[kz_detach]

; ------------------------------------------------------------------------
; r1 - floppy address specification
; r2 - device specification as for IN/OU
; RETURN: r1 - result
kz_seek:
	.res	1
	rw	r2, kz_dev_waiting
.retry:
	ou	r1, r2 + KZ_CMD_CTL4
	.word	.no, .retry, .ok, .pe
.no:	lwt	r1, RET_NODEV
	ujs	.done
.pe:
.ok:	lwt	r1, RET_OK
.done:
	uj	[kz_seek]

; ------------------------------------------------------------------------
; r1 - character to print (on right byte)
; r2 - device specification as for IN/OU
; RETURN: r1 - operation result
kz_putc:
	.res	1
.retry:	im	imask_noch
	rw	r2, kz_dev_waiting

	ou	r1, r2 + KZ_CMD_DEV_WRITE
	.word	.no, .en, .ok, .pe

.en:	lj	kz_idle
	ujs	.retry

.no:	lwt	r1, RET_NODEV
	ujs	.done
.pe:
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
	rw	r2, kz_dev_waiting

	in	r1, r2 + KZ_CMD_DEV_READ
	.word	.no, .en, .ok, .pe

.en:	lj	kz_idle
	lwt	r1, KZ_INT_DEVICE_READY
	cl	r1, [kz_last_intspec]
	jes	.retry
	lwt	r1, RET_IOERR
	ujs	.ok
.pe:	lwt	r1, RET_PARITY
	ujs	.ok
.no:	lwt	r1, RET_NODEV
.ok:	im	imask
	uj	[kz_getc]

; vim: tabstop=8 shiftwidth=8 autoindent syntax=emas
