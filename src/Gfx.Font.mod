(**
Font module for pre-render monochrome glyphs stored in uncompressed
data embeded in the executable/image.

The fonttoasm.py tool can be used to convert any TTF, BDF font to a
be used with this module.
*)
MODULE Font IN Gfx;

IMPORT SYSTEM;

IN Std IMPORT Type;
IN Gfx IMPORT FrameBuffer;

CONST
	ERROR_IN_DATA = -1;
	INDEX_ENTRY_SIZE = SIZE(UNSIGNED16) + 5*SIZE(UNSIGNED8);
	
TYPE
	U8 = UNSIGNED8;
	U16 = UNSIGNED16;
	ADDRESS = SYSTEM.ADDRESS;
	
	Font* = RECORD
		first-, last- : INTEGER;
		height- : INTEGER;
		index : ADDRESS;
		data : ADDRESS;
	END;

(** Draw char at (x0, y0) and return advance distance in x *)
PROCEDURE (VAR this : Font) Char*(VAR fb : FrameBuffer.FrameBuffer; ch : CHAR; x0, y0, color: INTEGER): INTEGER;
VAR
	adr : ADDRESS;
	c, offset, width, rows : INTEGER;
	dy, x, advance, idx : INTEGER;
	row, pitch, col, i, j : INTEGER;
	s : SET8;
	
	PROCEDURE ReadU16(): UNSIGNED16;
	VAR u16 : UNSIGNED16;
	BEGIN
		SYSTEM.GET(this.index + idx, u16);
		INC(idx, SIZE(UNSIGNED16));
		RETURN u16;
	END ReadU16;
	
	PROCEDURE ReadU8(): UNSIGNED8;
	VAR u8 : UNSIGNED8;
	BEGIN
		SYSTEM.GET(this.index + idx, u8);
		INC(idx, SIZE(UNSIGNED8));
		RETURN u8;
	END ReadU8;

	PROCEDURE ReadS8(): SIGNED8;
	VAR s8 : SIGNED8;
	BEGIN
		SYSTEM.GET(this.index + idx, s8);
		INC(idx, SIZE(UNSIGNED8));
		RETURN s8;
	END ReadS8;
BEGIN
	c := ORD(ch);
	IF (c < this.first) OR (c > this.last) THEN
		c := this.first
	END;
	idx := (c - this.first) * INDEX_ENTRY_SIZE;
	offset := ReadU16();
	width := ReadU8();
	rows := ReadU8();
	x0 := x0 + ReadS8();
	dy := ReadS8();
	advance := ReadU8();
	y0 := y0 + this.height - dy;
	pitch := (width + 7) DIV 8;
	adr := this.data + offset;
	FOR row := 0 TO rows - 1 DO
		x := x0; col := 0; i := 0;
		LOOP
			IF (y0 < 0) OR (y0 >= fb.height) THEN EXIT END;
			IF (i > pitch) OR (col >= width) THEN EXIT END;
			SYSTEM.GET(adr + i, s);
			j := 7;
			LOOP
				IF (j < 0) OR (col >= width) THEN EXIT END;
				IF (j IN s) & (0 <= x) & (x < fb.width) THEN
					fb.SetPixelProc(fb.pixels, fb.stride, x0 + col, y0, color);
				END;
				INC(x);
				INC(col);
				DEC(j)
			END;
			INC(i, 1);
		END;
		INC(adr, pitch);
		INC(y0);
	END;
	RETURN advance
END Char;

(** Calculate string width and height *)
PROCEDURE (VAR this : Font) StringSize*(s- : ARRAY OF CHAR; VAR width, height: INTEGER);
VAR
	c, rows, dy, advance : INTEGER;
	idx, ch : INTEGER;
	i : LENGTH;
	PROCEDURE ReadU8(): UNSIGNED8;
	VAR u8 : UNSIGNED8;
	BEGIN
		SYSTEM.GET(this.index + idx, u8);
		INC(idx, SIZE(UNSIGNED8));
		RETURN u8;
	END ReadU8;

	PROCEDURE ReadS8(): SIGNED8;
	VAR s8 : SIGNED8;
	BEGIN
		SYSTEM.GET(this.index + idx, s8);
		INC(idx, SIZE(UNSIGNED8));
		RETURN s8;
	END ReadS8;
BEGIN
	width := 0;
	height := 0;
	FOR i := 0 TO LEN(s) - 1 DO
		c := ORD(s[i]);
		IF ch = 0 THEN RETURN END;
		IF (c < this.first) OR (c > this.last) THEN
			c := this.first
		END;
		idx := (c - this.first) * INDEX_ENTRY_SIZE;
		INC(idx, SIZE(UNSIGNED16) + SIZE(UNSIGNED8));
		rows := ReadU8();
		INC(idx, SIZE(UNSIGNED8));
		dy := ReadS8();
		ch := this.height - dy + rows;
		IF ch > height THEN height := ch END;
		advance := ReadU8();
		width := width + advance;
	END;
END StringSize;

(** Draw string at (x0, y0) *)
PROCEDURE (VAR this : Font) String*(VAR fb : FrameBuffer.FrameBuffer; s- : ARRAY OF CHAR; x0, y0, color: INTEGER);
VAR
	ch : CHAR;
	i : LENGTH;
BEGIN
	FOR i := 0 TO LEN(s) - 1 DO
		ch := s[i];
		IF ch = 00X THEN RETURN END;
		x0 := x0 + this.Char(fb, ch, x0, y0, color);
	END;
END String;

(** Preview eaw font data rendering to ascii for debug purpose *)
PROCEDURE (VAR this : Font) Preview*(VAR fh : Type.Stream; ch : CHAR);
VAR
	adr : ADDRESS;
	c, offset, width, rows : INTEGER;
	dx, dy, advance, idx : INTEGER;
	row, pitch, col, i, j : INTEGER;
	s : SET8;
	
	PROCEDURE ReadU16(): UNSIGNED16;
	VAR u16 : UNSIGNED16;
	BEGIN
		SYSTEM.GET(this.index + idx, u16);
		INC(idx, SIZE(UNSIGNED16));
		RETURN u16;
	END ReadU16;
	
	PROCEDURE ReadU8(): UNSIGNED8;
	VAR u8 : UNSIGNED8;
	BEGIN
		SYSTEM.GET(this.index + idx, u8);
		INC(idx, SIZE(UNSIGNED8));
		RETURN u8;
	END ReadU8;

	PROCEDURE ReadS8(): SIGNED8;
	VAR s8 : SIGNED8;
	BEGIN
		SYSTEM.GET(this.index + idx, s8);
		INC(idx, SIZE(UNSIGNED8));
		RETURN s8;
	END ReadS8;
BEGIN
	c := ORD(ch);
	IF (c < this.first) OR (c > this.last) THEN
		c := this.first
	END;
	idx := (c - this.first) * INDEX_ENTRY_SIZE;
	offset := ReadU16();
	width := ReadU8();
	rows := ReadU8();
	dx := ReadS8();
	dy := ReadS8();
	advance := ReadU8();
	pitch := (width + 7) DIV 8;
	adr := this.data + offset;
	FOR row := 0 TO rows - 1 DO
		col := 0; i := 0;
		LOOP
			IF (i > pitch) OR (col >= width) THEN EXIT END;
			SYSTEM.GET(adr + i, s);
			j := 7;
			LOOP
				IF (j < 0) OR (col >= width) THEN EXIT END;
				IF j IN s THEN fh.WriteChar("*")
				ELSE fh.WriteChar(".") END;
				INC(col);
				DEC(j)
			END;
			INC(i, 1);
		END;
		fh.WriteNL;
		INC(adr, pitch);
	END;
END Preview;

(** Initialize font data from memory location. *)
PROCEDURE InitRaw*(VAR font : Font; adr : ADDRESS): INTEGER;
VAR
	idx : LENGTH;
	
	PROCEDURE ReadU16(): UNSIGNED16;
	VAR u16 : UNSIGNED16;
	BEGIN
		SYSTEM.GET(adr + idx, u16);
		INC(idx, SIZE(UNSIGNED16));
		RETURN u16;
	END ReadU16;
	
	PROCEDURE ReadU8(): UNSIGNED8;
	VAR u8 : UNSIGNED8;
	BEGIN
		SYSTEM.GET(adr + idx, u8);
		INC(idx, SIZE(UNSIGNED8));
		RETURN u8;
	END ReadU8;
BEGIN
	idx := 0;
	font.height := ReadU8();
	IF (font.height < 5) OR (font.height > 128) THEN RETURN ERROR_IN_DATA END;
	font.first := ReadU8();
	font.last := ReadU8();
	IF font.last <= font.first THEN RETURN ERROR_IN_DATA END;
	font.data := ReadU16();
	font.index := adr + idx;
	font.data := font.data + font.index;
	IF font.data = font.index THEN RETURN ERROR_IN_DATA END;
	RETURN 0
END InitRaw;

END Font.