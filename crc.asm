; ------------------------------------------------------------------------
; r1 - address of the buffer
; r2 - length (in bytes)
; RETURN: r1 - crc-16-ccitt
crc16:
	.const	CRC_INIT 0x1d0f
	.res	1
	rl	tmpregs

	slz	r1
	lw	r3, r1		; r3 = buffer address
	lw	r1, CRC_INIT	; crc = 0x1D0F;
.loop:
	cwt	r2, 1		; len<1 ?
	jls	.done

	lw	r4, r1
	shc	r4, 8
	zlb	r4		; x = crc >> 8;

	lb	r5, r3
	zlb	r5
	xr	r4, r5		; x = x ^ *data;

	lw	r6, r4
	shc	r6, 4		; t = x >> 4;
	zlb	r6

	xr	r4, r6		; x = x ^ t;

	shc	r1, -8
	zrb	r1		; crc = crc << 8;
	xr	r1, r4		; crc = crc ^ x;

	shc	r4, -5
	er	r4, 0b11111	; x = x << 5;

	xr	r1, r4		; crc = crc ^ x;

	shc	r4, -7
	er	r4, 0b1111111	; x = x << 7;

	xr	r1, r4		; crc = crc ^ x;

	awt	r3, 1		; data++;

	awt	r2, -1		; len--
	ujs	.loop
.done:
	ll	tmpregs
	uj	[crc16]

; vim: tabstop=8 shiftwidth=8 autoindent syntax=emas
