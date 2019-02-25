; ------------------------------------------------------------------------
; r2 - device number
; RETURN: r1 - >0 character
; RETURN: r1 - <0 operation result
getc:
	.res	1

	lw	r6, r2

	lw	r2, [devices + dev.ioaddr + r6]
	md	[devices + dev.drv + r6]
	lj	[driver.getc]

	lw	r2, r6
	uj	[getc]

; ------------------------------------------------------------------------
; r1 - character to print (on right byte)
; r2 - device number
; RETURN: r1 - operation result
putc:
	.res	1

	lw	r6, r2

	lw	r2, [devices + dev.ioaddr + r6]
	md	[devices + dev.drv + r6]
	lj	[driver.putc]

	lw	r2, r6
	uj	[putc]

; ------------------------------------------------------------------------
; r1 - address of a 0-terminated string to print
; r2 - device number
; RETURN: r1 - operation result
puts:
	.res	1
	rf	.regs

	lw	r6, r1 ; string address
	md	[devices + dev.drv + r2]
	lw	r7, [driver.putc] ; device putc function address
	lw	r2, [devices + dev.ioaddr + r2] ; device I/O address

	slz	r6 ; shift string address so it's a byte address

.loop:	zlb	r1
	lb	r1, r6
	cwt	r1, 0
	jes	.done

	lj	r7

	cwt	r1, RET_OK
	jls	.done
	awt	r6, 1
	ujs	.loop

.done:	lf	.regs
	uj	[puts]
.regs:	.res	3

