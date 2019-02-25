; ------------------------------------------------------------------------
; r2 - device number
; RETURN: r1 - >0 character
; RETURN: r1 - <0 operation result
getc:
	.res	1

	lw	r3, devices + r2
	lw	r2, [r3 + dev.ioaddr]
	md	[r3 + dev.drv]
	rj	r4, [driver.getc]
	uj	[getc]

; ------------------------------------------------------------------------
; r1 - character to print (on right byte)
; r2 - device number
; RETURN: r1 - operation result
putc:
	.res	1

	lw	r1, devices + r2
	lw	r2, [r1 + dev.ioaddr]
	md	[r1 + dev.drv]
	rj	r4, [driver.putc]
	uj	[putc]

; ------------------------------------------------------------------------
; r1 - address of a 0-terminated string to print
; r2 - device number
; RETURN: r1 - operation result
puts:
	.res	1
	rw	r7, .regs

	lw	r3, r1 ; string address
	md	[devices + dev.drv + r2]
	lw	r7, [driver.putc] ; device putc function address
	lw	r2, [devices + dev.ioaddr + r2] ; device I/O address

	slz	r3 ; shift string address so it's a byte address

.loop:
	lb	r1, r3
	zlb	r1
	cwt	r1, 0
	jes	.done

	rj	r4, r7

	cwt	r1, RET_OK
	jls	.done
	awt	r3, 1
	ujs	.loop

.done:	lw	r7, [.regs]
	uj	[puts]
.regs:	.res	1

; ------------------------------------------------------------------------
; r1 - buffer address
; r2 - device number
; r3 - byte count
write:
	.res	1
	rl	.regs

	lw	r6, r3 ; requested write len
	lwt	r3, 0 ; buf offset
	lw	r5, r1 ; buf base addr
	slz	r5
	md	[devices + dev.drv + r2]
	lw	r7, [driver.putc] ; device putc function address
	lw	r2, [devices + dev.ioaddr + r2] ; device I/O address

.loop:
	cw	r6, r3
	jes	.done

	lb	r1, r5 + r3
	rj	r4, r7

	cwt	r1, RET_OK
	jls	.done
	awt	r3, 1
	ujs	.loop

.done:	ll	.regs
	uj	[write]
.regs:	.res	3
