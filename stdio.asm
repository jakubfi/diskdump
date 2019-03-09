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

	lw	r3, devices + r2
	lw	r2, [r3 + dev.ioaddr]
	md	[r3 + dev.drv]
	rj	r4, [driver.putc]
	uj	[putc]

; ------------------------------------------------------------------------
; r1 - two characters to print
; r2 - device number
; RETURN: r1 - operation result
put2c:
	.res	1
	rw	r5, .regs

	lw	r5, r1
	lw	r3, devices + r2
	lw	r2, [r3 + dev.ioaddr]

	md	[r3 + dev.drv]
	rj	r4, [driver.putc]

	cwt	r1, RET_OK
	jls	.done

	lw	r1, r5
	shc	r1, 8
	md	[r3 + dev.drv]
	rj	r4, [driver.putc]
.done:
	lw	r5, [.regs]
	uj	[put2c]
.regs:	.res	1

; ------------------------------------------------------------------------
; r1 - byte address of a 0-terminated string to print
; r2 - device number
; RETURN: r1 - operation result
puts:
	.res	1
	rw	r7, .regs

	lw	r3, r1 ; string address
	md	[devices + dev.drv + r2]
	lw	r7, [driver.putc] ; device putc function address
	lw	r2, [devices + dev.ioaddr + r2] ; device I/O address
.loop:
	lb	r1, r3
	zlb	r1
	cwt	r1, '\0'
	jes	.done

	rj	r4, r7

	cwt	r1, RET_OK
	jls	.done
	awt	r3, 1
	ujs	.loop
.done:
	lw	r7, [.regs]
	uj	[puts]
.regs:	.res	1

; ------------------------------------------------------------------------
; r1 - byte address of the buffer
; r2 - device number
; r3 - byte count
write:
	.res	1
	rl	.regs

	lw	r6, r3 ; requested write len
	lwt	r3, 0 ; buf offset
	lw	r5, r1 ; buf base addr
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
.done:
	ll	.regs
	uj	[write]
.regs:	.res	3

; ------------------------------------------------------------------------
; r1 - byte address of the buffer
; r2 - device number
; r3 - byte count
read:
	.res	1
	rl	.regs
	lw	r7, r1 ; buffer addr
	lw	r5, r2 ; device
	lw	r6, r3 ; count

.loop:
	lj	getc
	rb	r1, r7
	awt	r7, 1
	lw	r2, r5
	drb	r6, .loop

	ll	.regs
	uj	[read]
.regs:	.res	3

; ------------------------------------------------------------------------
; r1 - byte address of the buffer
; r2 - device number
readln:
	.res	1
	rl	.regs
	lw	r7, r1 ; buffer addr
	lw	r5, r2 ; device

.loop:
	lj	getc
	cwt	r1, '\n'
	jes	.done
	cwt	r1, '\r'
	jes	.done
	rb	r1, r7
	awt	r7, 1
	lw	r2, r5
	ujs	.loop
.done:
	lwt	r1, 0
	rb	r1, r7
	ll	.regs
	uj	[readln]
.regs:	.res	3

; ------------------------------------------------------------------------
; r1 - value
; r2 - buffer byte address
bin2asc:
	.res	1

	lwt	r4, -16
.loop:
	; '0' or '1'?
	lwt	r3, '0'
	slz	r1
	blc	?Y
	lwt	r3, '1'

	; store
	rb	r3, r2
	awt	r2, 1
	irb	r4, .loop

	; store ending '\0'
	lwt	r3, 0
	rb	r3, r2

	uj	[bin2asc]

; ------------------------------------------------------------------------
; r1 - value
; r2 - buffer byte address
hex2asc:
	.res	1

	lwt	r4, 4 ; 4 digits
.loop:
	shc	r1, -4 ; shift quad into position
	lw	r3, r1
	nr	r3, 0xf
	cwt	r3, 9
	blc	?G
	awt	r3, 'a'-'0'-10
	awt	r3, '0'
	rb	r3, r2

	awt	r2, 1
	drb	r4, .loop
	lwt	r3, 0
	rb	r3, r2

	uj	[hex2asc]

; ------------------------------------------------------------------------
; r1 - value
; r2 - buffer byte address
; RETURN: none
unsigned2asc:
	.res	1

	lw	r4, divs ; current divider
	lw	r3, r2 ; buffer address
	lw	r2, r1 ; value
	or	r0, ?1 ; 'only 0s so far' indicator

	; special case for '0'
	cwt	r2, 0
	jn	.loop
	awt	r2, '0'
	ujs	.last
.loop:
	lwt	r1, 0
	dw	r4 ; r1 = remainder, r2 = r2/[r4]

	cwt	r2, '\0'
	jn	.store ; this is not '0' -> store this digit
	; this is '0'
	brc	?1 ; branch if there were digits other than 0 already
	jes	.skip ; there were no other digits than '0' yet
.store:
	er	r0, ?1
	awt	r2, '0'
	rb	r2, r3
	awt	r3, 1
.skip:
	lw	r2, r1 ; move remaider to r2
	lwt	r1, 0

	cw	r1, [r4] ; was it the last digit?
	jes	.last
	awt	r4, 1
	ujs	.loop
.last:
	rb	r2, r3 ; store remainder
	awt	r3, 1
	lwt	r2, 0 ; store ending '\0'
	rb	r2, r3

	uj	[unsigned2asc]
.regs:	.res	1

; ------------------------------------------------------------------------
; r1 - value
; r2 - buffer byte address
; RETURN: none
signed2asc:
	.res	1

	sxu	r1
	bb	r0, ?X
	ujs	.go ; if number is positive or 0

	; if number is negative, store '-'
	nga	r1
	lw	r4, '-'
	rb	r4, r2
	awt	r2, 1
.go:
	lj	unsigned2asc
	uj	[signed2asc]

; ------------------------------------------------------------------------
; r1 - dest (byte address)
; r2 - src (byte address)
; r3 - count
strncpy:
	.res	1
	lwt	r4, 1 ; make sure first loop reads a byte
.loop:
	cwt	r4, '\0'
	blc	?G ; skip if there is no more bytes to read
	lb	r4, r2
	rb	r4, r1
	awt	r1, 1
	awt	r2, 1
	drb	r3, .loop

	uj	[strncpy]

; ------------------------------------------------------------------------
; r1 - dest
; d2 - src
strcpy:
	.res	1

	lw	r3, -1
	lj	strncpy

	uj	[strcpy]

; ------------------------------------------------------------------------
; r1 - string byte address
; RETURN: r1 - length
strlen:
	.res	1

	lwt	r2, 0
.loop:
	lb	r4, r1
	cwt	r4, '\0'
	jes	.done
	awt	r2, 1
	awt	r1, 1
	ujs	.loop
.done:
	lw	r1, r2
	uj	[strlen]

; ------------------------------------------------------------------------
; r1 - string byte addres
; RETURN: r1 - integer
atoi:
	.res	1

	lw	r3, r1 ; address
	lwt	r2, 0 ; the integer
	lwt	r1, 0 ; clear before MW
	lwt	r4, 0
	er	r0, ?1 ; set if number is negative

	; check sign
	lb	r4, r3
	cwt	r4, '-'
	jn	.cont
	awt	r3, 1
	or	r0, ?1
.loop:
	lb	r4, r3
.cont:
	cwt	r4, '0'
	jls	.done
	cwt	r4, '9'
	jgs	.done
	mw	ten
	awt	r4, -'0'
	aw	r2, r4
	awt	r3, 1
	ujs	.loop
.done:
	brc	?1
	mw	minus1
	lw	r1, r2

	uj	[atoi]

; ------------------------------------------------------------------------
divs:	.word	10000
	.word	1000
	.word	100
ten:	.word	10
	.word	0
minus1:	.word	-1

; ------------------------------------------------------------------------
; r1 - address
; r2 - length (words)
; RETURN: r1 - control sum
ctlsum:
	.res	1

	lwt	r3, 0
	cwt	r2, 0
	jes	.done
.loop:
	aw	r3, [r1]
	awt	r1, 1
	drb	r2, .loop
.done:
	lw	r1, r3
	uj	[ctlsum]
