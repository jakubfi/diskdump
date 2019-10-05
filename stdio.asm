	.const	putc kz_putc
	.const	getc kz_getc

; ------------------------------------------------------------------------

tmpregs:
	.res	3

divs:	.word	10000
	.word	1000
	.word	100
ten:	.word	10
	.word	0
minus1:	.word	-1

; ------------------------------------------------------------------------
; Print two characters
;
; r1 - two characters to print
; r2 - device specification
; RETURN: r1 - operation result
put2c:
	.res	1
	rw	r5, tmpregs

	lw	r5, r1
	shc	r1, 8

	lj	putc

	cwt	r1, RET_OK
	jls	.done

	lw	r1, r5
	lj	putc
.done:
	lw	r5, [tmpregs]
	uj	[put2c]

; ------------------------------------------------------------------------
; Print 0-terminated string
;
; r1 - address of a 0-terminated string to print
; r2 - device specification
; RETURN: r1 - operation result
puts:
	.res	1
	rw	r5, tmpregs

	slz	r1
	lw	r5, r1 ; string address

.loop:
	lb	r1, r5
	zlb	r1
	cwt	r1, '\0'
	jes	.done

	lj	putc
	cwt	r1, RET_OK
	jls	.done

	awt	r5, 1
	ujs	.loop
.done:
	lw	r5, [tmpregs]
	uj	[puts]

; ------------------------------------------------------------------------
; Write bytes to a device
;
; r1 - address of the buffer
; r2 - device specification
; r3 - byte count
; RETURN: r1 - operation result
write:
	.res	1
	rl	tmpregs

	slz	r1
	lw	r5, r1 ; buf addr
	lw	r6, r1
	aw	r6, r3 ; end address

.loop:
	lwt	r1, RET_OK
	cw	r5, r6
	jes	.done

	lb	r1, r5
	lj	putc
	cwt	r1, RET_OK
	jls	.done

	awt	r5, 1
	ujs	.loop
.done:
	ll	tmpregs
	uj	[write]

; ------------------------------------------------------------------------
; Write words to a device
;
; r1 - word address of the buffer
; r2 - device specification
; r3 - word count
; RETURN: r1 - operation result
writew:
	.res	1
	rl	tmpregs

	lw	r5, r1 ; buf base addr
	lw	r6, r1
	aw	r6, r3

.loop:
	lwt	r1, RET_OK
	cw	r5, r6
	jes	.done

	lw	r1, [r5]
	shc	r1, 8
	zlb	r1
	lj	putc
	cwt	r1, RET_OK
	jls	.done

	lw	r1, [r5]
	zlb	r1
	lj	putc
	cwt	r1, RET_OK
	jls	.done

	awt	r5, 1
	ujs	.loop
.done:
	ll	tmpregs
	uj	[writew]

; ------------------------------------------------------------------------
; Read bytes from device
;
; r1 - address of the buffer
; r2 - device specification
; r3 - byte count
; RETURN: r1 - operation result
read:
	.res	1
	rl	tmpregs

	slz	r1
	lw	r5, r1 ; buffer addr
	lw	r6, r1
	aw	r6, r3

.loop:
	lwt	r1, RET_OK
	cw	r5, r6
	jes	.done

	lj	getc
	cwt	r1, RET_OK
	jls	.done

	rb	r1, r5
	awt	r5, 1
	ujs	.loop

	lwt	r1, RET_OK
.done:
	ll	tmpregs
	uj	[read]

; ------------------------------------------------------------------------
; Read words from device
;
; r1 - word address of the buffer
; r2 - device specification
; r3 - word count
; RETURN: r1 - operation result
readw:
	.res	1
	rl	tmpregs

	lw	r5, r1 ; buffer addr
	lw	r6, r1
	aw	r6, r3

.loop:
	lwt	r1, RET_OK
	cw	r5, r6
	jes	.done

	lj	getc
	cwt	r1, RET_OK
	jls	.done

	shc	r1, 8
	zrb	r1
	rw	r1, r5

	lj	getc
	cwt	r1, RET_OK
	jls	.done

	zlb	r1
	om	r1, r5

	awt	r5, 1
	ujs	.loop

	lwt	r1, RET_OK
.done:
	ll	tmpregs
	uj	[readw]

; ------------------------------------------------------------------------
; Read string until a newline
;
; r1 - address of the buffer
; r2 - device number
readln:
	.res	1
	rl	tmpregs

	slz	r1
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
	ll	tmpregs
	uj	[readln]

; ------------------------------------------------------------------------
; Convert number to a binary ascii representation
;
; r1 - value
; r2 - buffer address
bin2asc:
	.res	1

	slz	r1
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
; Convert number to a hex ascii representation
;
; r1 - value
; r2 - buffer address
hex2asc:
	.res	1

	slz	r1
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
; Convert number to a unsigned ascii representation
;
; r1 - value
; r2 - buffer address
; RETURN: none
unsigned2asc:
	.res	1

	slz	r1
	lw	r4, divs ; current divider
	lw	r3, r2 ; buffer address
	lw	r2, r1 ; value

	; special case for '0'
	cwt	r2, 0
	blc	?E
	ujs	.last

.align:
	cw	r2, [r4]
	blc	?L
	irb	r4, .align

.loop:
	lwt	r1, 0
	cw	r1, [r4] ; was it the last digit?
	jes	.last

	dw	r4 ; r1 = remainder, r2 = r2/[r4]
	awt	r2, '0'
	rb	r2, r3
	awt	r3, 1
	awt	r4, 1
	lw	r2, r1 ; move remaider to r2
	ujs	.loop

.last:
	awt	r2, '0'
	rb	r2, r3 ; store remainder
	awt	r3, 1
	lwt	r2, 0 ; store ending '\0'
	rb	r2, r3

	uj	[unsigned2asc]

; ------------------------------------------------------------------------
; Convert number to a signed ascii representation
;
; r1 - value
; r2 - buffer address
; RETURN: none
signed2asc:
	.res	1

	slz	r1
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
; Copy n characters of a string
;
; r1 - dest
; r2 - src
; r3 - count
strncpy:
	.res	1

	slz	r1
	slz	r2
	cwt	r3, 0
	jes	.done

	lwt	r4, 1 ; make sure first loop reads a byte
.loop:
	cwt	r4, '\0'
	blc	?G ; skip if there is no more bytes to read
	lb	r4, r2
	rb	r4, r1
	awt	r1, 1
	awt	r2, 1
	drb	r3, .loop
.done:
	uj	[strncpy]

; ------------------------------------------------------------------------
; Copy a 0-terminated string
;
; r1 - dest
; r2 - src
strcpy:
	.res	1

	lw	r3, -1
	lj	strncpy

	uj	[strcpy]

; ------------------------------------------------------------------------
; Get string length
;
; r1 - string address
; RETURN: r1 - length
strlen:
	.res	1

	slz	r1
	lw	r2, r1
	lwt	r1, 0
	zlb	r4
.loop:
	lb	r4, r2+r1
	cwt	r4, '\0'
	jes	.done
	irb	r1, .loop
.done:
	uj	[strlen]

; ------------------------------------------------------------------------
; Convert ascii encoded number to a value
;
; r1 - string addres
; RETURN: r1 - integer
atoi:
	.res	1

	slz	r1
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
; Calculate control sum over a buffer
;
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

; ------------------------------------------------------------------------
; Set memory region to a value
;
; r1 - address
; r2 - length (words)
; r3 - filler word
memset:
	.res	1

	cwt	r2, 0
	jes	.done

.loop:

	ri	r1, r3
	drb	r2, .loop
.done:
	uj	[memset]

; ------------------------------------------------------------------------
; Copy memory contents
;
; r1 - dst
; r2 - src
; r3 - len
memcpy:
	.res	1

	cwt	r3, 0
	jes	.done
.loop:
	ri	r1, [r2]
	awt	r2, 1
	drb	r3, .loop
.done:
	uj	[memcpy]

; vim: tabstop=8 shiftwidth=8 autoindent syntax=emas
