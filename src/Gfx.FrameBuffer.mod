(**
Framebuffer for simple 2d bitmap graphics usable for embedded systems.

The FrameBuffer class provides a pixel buffer which can be drawn upon with pixels,
lines, rectangles, ellipses, polygons, text and even other FrameBuffers.
It is useful when generating output for displays.

This is a port of the Micropython framebuf module under license:
	The MIT License (MIT), Copyright (c) 2016 Damien P. George
*)
MODULE FrameBuffer IN Gfx;

IMPORT SYSTEM;

CONST
	(** Monochrome vertical mapped with bit 0 at the top of the screen *)
	MONO_VLSB* = 0;
	(** Monochrome horizontal mapped with bit 7 beeing the leftmost pixel *)
	MONO_HLSB* = 1;
	(** Monochrome horizontal mapped with bit 0 beeing the leftmost pixel *)
	MONO_HMSB* = 2;
	(** Red Green Blue (16-bit, 5+6+5) color format *)
	RGB565* = 3;
	(** Red Green Blue (24bit-bit 8+8+8) color format *)
	RGB888* = 4;
	(**  Grayscale (2-bit) color format *)
	GS2_HMSB* = 5;
	(**  Grayscale (4-bit) color format *)
	GS4_HMSB* = 6;
	(**  Grayscale (8-bit) color format *)
	GS8* = 7;

	(** Draw 1st quadrant *)
	Q1* = SET({0});
	(** Draw 2nd quadrant *)
	Q2* = SET({1});
	(** Draw 3rd quadrant *)
	Q3* = SET({2});
	(** Draw 3th quadrant *)
	Q4* = SET({3});
	(** Draw all quadrants *)
	QALL* = SET({0..3});

	MAXPOLY = 50;

TYPE
	ADDRESS = SYSTEM.ADDRESS;
	BYTE = SYSTEM.BYTE;
	SetPixelType = PROCEDURE(pixels : ADDRESS; stride, x, y, color : INTEGER);
	GetPixelType = PROCEDURE(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
	FillRectType = PROCEDURE(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
	FrameBuffer* = RECORD
		pixels- : ADDRESS;
		format- : INTEGER;
		width- : INTEGER;
		height- : INTEGER;
		stride- : INTEGER;
		SetPixelProc- : SetPixelType;
		GetPixelProc- : GetPixelType;
		FillRectProc- : FillRectType;
	END;
	FrameBufferArray* = RECORD(FrameBuffer)
		array- : POINTER TO ARRAY OF BYTE;
	END;

(* MONO_VLSB implementation *)
PROCEDURE SetPixelMONO_VLSB(pixels : ADDRESS; stride, x, y, color : INTEGER);
VAR s : SET8;
BEGIN
	pixels := pixels + SYSTEM.LSH(y, -3)*stride + x;
	SYSTEM.GET(pixels, s);
	IF color = 0 THEN EXCL(s, y MOD 8)
	ELSE INCL(s, y MOD 8) END;
	SYSTEM.PUT(pixels, s)
END SetPixelMONO_VLSB;

PROCEDURE GetPixelMONO_VLSB(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR s : SET8;
BEGIN
	SYSTEM.GET(pixels + SYSTEM.LSH(y, -3)*stride + x, s);
	IF (y MOD 8) IN s THEN RETURN 1
	ELSE RETURN 0 END;
END GetPixelMONO_VLSB;

PROCEDURE FillRectMONO_VLSB(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR
	b : ADDRESS;
	s : SET8;
	i : INTEGER;
BEGIN
	WHILE h > 0 DO
		b := pixels + SYSTEM.LSH(y, -3) * stride + x;
		FOR i := 0 TO w - 1 DO
			SYSTEM.GET(b, s);
			IF color = 0 THEN EXCL(s, y MOD 8)
			ELSE INCL(s, y MOD 8) END;
			SYSTEM.PUT(b, s);
			INC(b);
		END;
		INC(y);
		DEC(h);
	END;
END FillRectMONO_VLSB;

(* MONO_HLSB implementation *)
PROCEDURE SetPixelMONO_HLSB(pixels : ADDRESS; stride, x, y, color : INTEGER);
VAR s : SET8;
BEGIN
	pixels := pixels + SYSTEM.LSH(x + y*stride, -3);
	SYSTEM.GET(pixels, s);
	IF color = 0 THEN EXCL(s, 7 - x MOD 8)
	ELSE INCL(s, 7 - x MOD 8) END;
	SYSTEM.PUT(pixels, s)
END SetPixelMONO_HLSB;

PROCEDURE GetPixelMONO_HLSB(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR s : SET8;
BEGIN
	SYSTEM.GET(pixels + SYSTEM.LSH(x + y*stride, -3), s);
	IF (7 - x MOD 8) IN s THEN RETURN 1
	ELSE RETURN 0 END;
END GetPixelMONO_HLSB;

PROCEDURE FillRectMONO_HLSB(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR
	b : ADDRESS;
	s : SET8;
	i, advance : INTEGER;
BEGIN
	advance := SYSTEM.LSH(stride, -3);
	WHILE w > 0 DO
		b := pixels + SYSTEM.LSH(x, -3) + y*advance;
		FOR i := 0 TO h - 1 DO
			SYSTEM.GET(b, s);
			IF color = 0 THEN EXCL(s, 7 - x MOD 8)
			ELSE INCL(s, 7 - x MOD 8) END;
			SYSTEM.PUT(b, s);
			b := b + advance;
		END;
		INC(x); DEC(w);
	END;
END FillRectMONO_HLSB;

(* MONO_HMSB implementation *)
PROCEDURE SetPixelMONO_HMSB(pixels : ADDRESS; stride, x, y, color : INTEGER);
VAR s : SET8;
BEGIN
	pixels := pixels + SYSTEM.LSH(x + y*stride, -3);
	SYSTEM.GET(pixels, s);
	IF color = 0 THEN EXCL(s, x MOD 8)
	ELSE INCL(s, x MOD 8) END;
	SYSTEM.PUT(pixels, s)
END SetPixelMONO_HMSB;

PROCEDURE GetPixelMONO_HMSB(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR s : SET8;
BEGIN
	SYSTEM.GET(pixels + SYSTEM.LSH(x + y*stride, -3), s);
	IF (x MOD 8) IN s THEN RETURN 1
	ELSE RETURN 0 END;
END GetPixelMONO_HMSB;

PROCEDURE FillRectMONO_HMSB(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR
	b : ADDRESS;
	s : SET8;
	i, advance : INTEGER;
BEGIN
	advance := SYSTEM.LSH(stride, -3);
	WHILE w > 0 DO
		b := pixels + SYSTEM.LSH(x, -3) + y*advance;
		FOR i := 0 TO h - 1 DO
			SYSTEM.GET(b, s);
			IF color = 0 THEN EXCL(s, x MOD 8)
			ELSE INCL(s, x MOD 8) END;
			SYSTEM.PUT(b, s);
			b := b + advance;
		END;
		INC(x); DEC(w);
	END;
END FillRectMONO_HMSB;

(* RGB565 implementation *)
PROCEDURE SetPixelRGB565(pixels : ADDRESS; stride, x, y, color : INTEGER);
BEGIN SYSTEM.PUT(pixels + 2*(x + y*stride), UNSIGNED16(color))
END SetPixelRGB565;

PROCEDURE GetPixelRGB565(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR col : UNSIGNED16;
BEGIN
	SYSTEM.GET(pixels + 2*(x + y*stride), col);
	RETURN INTEGER(col)
END GetPixelRGB565;

PROCEDURE FillRectRGB565(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR
	adr : ADDRESS;
	i : INTEGER;
BEGIN
	adr := pixels + 2*(x + y*stride);
	WHILE h > 0 DO
		FOR i := 0 TO w - 1 DO
			SYSTEM.PUT(adr, UNSIGNED16(color));
			adr := adr + 2;
		END;
		adr := adr + 2*(stride - w);
		DEC(h)
	END;
END FillRectRGB565;

(* RGB888 implementation *)
PROCEDURE SetPixelRGB888(pixels : ADDRESS; stride, x, y, color : INTEGER);
VAR
	adr : ADDRESS;
	col : UNSIGNED8;
BEGIN
	adr := pixels + 3*(x + y*stride);
	col := UNSIGNED8(SYSTEM.LSH(color, -16) MOD 256);
	SYSTEM.PUT(adr + 0, col);
	col := UNSIGNED8(SYSTEM.LSH(color, -8) MOD 256);
	SYSTEM.PUT(adr + 1, col);
	col := UNSIGNED8(color MOD 256);
	SYSTEM.PUT(adr + 2, col);
END SetPixelRGB888;

PROCEDURE GetPixelRGB888(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR
	adr : ADDRESS;
	ret : INTEGER;
	col : UNSIGNED8;
BEGIN
	adr := pixels + 3*(x + y*stride);
	SYSTEM.GET(adr + 0, col);
	ret := SYSTEM.LSH(INTEGER(col), 16);
	SYSTEM.GET(adr + 1, col);
	ret := ret + SYSTEM.LSH(INTEGER(col), 8);
	SYSTEM.GET(adr + 2, col);
	ret := ret + INTEGER(col);
	RETURN ret
END GetPixelRGB888;

PROCEDURE FillRectRGB888(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR
	adr : ADDRESS;
	r, g, b : UNSIGNED8;
	i : INTEGER;
BEGIN
	adr := pixels + 3*(x + y*stride);
	r := UNSIGNED8(SYSTEM.LSH(color, -16) MOD 256);
	g := UNSIGNED8(SYSTEM.LSH(color, -8) MOD 256);
	b := UNSIGNED8(color MOD 256);
	
	WHILE h > 0 DO
		FOR i := 0 TO w - 1 DO
			SYSTEM.PUT(adr + 0, r);
			SYSTEM.PUT(adr + 1, g);
			SYSTEM.PUT(adr + 2, b);
			adr := adr + 3;
		END;
		adr := adr + 3*(stride - w);
		DEC(h)
	END;
END FillRectRGB888;

(* GS2_HMSB implementation *)
PROCEDURE SetPixelGS2_HMSB(pixels : ADDRESS; stride, x, y, color : INTEGER);
VAR
	s : SET8;
	mask, shift : INTEGER;
BEGIN
	pixels := pixels + SYSTEM.LSH(x + y*stride, -2);
	shift := (x MOD 4) * 2;
	mask := SYSTEM.LSH(3, shift);
	SYSTEM.GET(pixels, s);
	s := s * (-SET8(mask)) + SET8(SYSTEM.LSH(color MOD 4, shift));
	SYSTEM.PUT(pixels, s)
END SetPixelGS2_HMSB;

PROCEDURE GetPixelGS2_HMSB(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR
	pixel : UNSIGNED8;
	shift : INTEGER;
BEGIN
	pixels := pixels + SYSTEM.LSH(x + y*stride, -2);
	shift := SYSTEM.LSH(x MOD 4, 1);
	SYSTEM.GET(pixels, pixel);
	RETURN SYSTEM.LSH(INTEGER(pixel), -shift) MOD 4
END GetPixelGS2_HMSB;

PROCEDURE FillRectGS2_HMSB(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR xx, yy : INTEGER;
BEGIN
	FOR xx := x TO x + w - 1 DO
		FOR yy := y TO y + h - 1 DO
			SetPixelGS2_HMSB(pixels, stride, xx, yy, color)
		END;
	END;
END FillRectGS2_HMSB;

(* GS4_HMSB implementation *)
PROCEDURE SetPixelGS4_HMSB(pixels : ADDRESS; stride, x, y, color : INTEGER);
VAR s : SET8;
BEGIN
	pixels := pixels + SYSTEM.LSH(x + y*stride, -1);
	SYSTEM.GET(pixels, s);
	IF ODD(x) THEN
		s := (s * {4..7}) + SET8(color MOD 16);
	ELSE
		s := (s * {0..3}) + SET8(SYSTEM.LSH(color MOD 16, 4));
	END;
	SYSTEM.PUT(pixels, s)
END SetPixelGS4_HMSB;

PROCEDURE GetPixelGS4_HMSB(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR
	pixel : UNSIGNED8;
BEGIN
	pixels := pixels + SYSTEM.LSH(x + y*stride, -1);
	SYSTEM.GET(pixels, pixel);
	IF ODD(x) THEN
		RETURN INTEGER(pixel) MOD 16;
	ELSE
		RETURN SYSTEM.LSH(INTEGER(pixel), -4)
	END;
END GetPixelGS4_HMSB;

PROCEDURE FillRectGS4_HMSB(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR xx, yy : INTEGER;
BEGIN
	FOR xx := x TO x + w - 1 DO
		FOR yy := y TO y + h - 1 DO
			SetPixelGS4_HMSB(pixels, stride, xx, yy, color)
		END;
	END;
END FillRectGS4_HMSB;

(* GS8 implementation *)
PROCEDURE SetPixelGS8(pixels : ADDRESS; stride, x, y, color : INTEGER);
VAR s : UNSIGNED8;
BEGIN
	pixels := pixels + x + y*stride;
	s := UNSIGNED8(color MOD 256);
	SYSTEM.PUT(pixels, s)
END SetPixelGS8;

PROCEDURE GetPixelGS8(pixels : ADDRESS; stride, x, y: INTEGER): INTEGER;
VAR
	pixel : UNSIGNED8;
BEGIN
	pixels := pixels + x + y*stride;
	SYSTEM.GET(pixels, pixel);
	RETURN INTEGER(pixel)
END GetPixelGS8;

PROCEDURE FillRectGS8(pixels : ADDRESS; stride, x, y, w, h, color : INTEGER);
VAR
	s : UNSIGNED8;
	i : INTEGER;
BEGIN
	pixels := pixels + x + y*stride;
	s := UNSIGNED8(color MOD 256);
	WHILE h > 0 DO
		FOR i := 0 TO w - 1 DO
			SYSTEM.PUT(pixels + i, s)
		END;
		pixels := pixels + stride;
		DEC(h)
	END;
END FillRectGS8;

(**
Initialize framebuffer from raw memory location.

 * `pixels` - Address of framebuffer data.
 * `format` - One of the valid formats.
 * `width` - Width in pixels.
 * `height` - Height in pixels.
 * `stride` - Offset in pixels between lines. Normal this is the width.

 The color value is specific to the format of the framebuffer.
*)
PROCEDURE Init*(VAR fb : FrameBuffer; pixels : ADDRESS; format, width, height, stride: INTEGER);
BEGIN
	ASSERT((width > 0) & (height > 0) & (stride > 0));
	ASSERT((format >= MONO_VLSB) & (format <= GS8));
	CASE format OF
		MONO_VLSB :
			fb.SetPixelProc := SetPixelMONO_VLSB;
        	fb.GetPixelProc := GetPixelMONO_VLSB;
        	fb.FillRectProc := FillRectMONO_VLSB;
   		| MONO_HLSB :
			fb.SetPixelProc := SetPixelMONO_HLSB;
        	fb.GetPixelProc := GetPixelMONO_HLSB;
        	fb.FillRectProc := FillRectMONO_HLSB;
   		| MONO_HMSB :
			fb.SetPixelProc := SetPixelMONO_HMSB;
        	fb.GetPixelProc := GetPixelMONO_HMSB;
        	fb.FillRectProc := FillRectMONO_HMSB;
        | RGB565 :
        	fb.SetPixelProc := SetPixelRGB565;
        	fb.GetPixelProc := GetPixelRGB565;
        	fb.FillRectProc := FillRectRGB565;
        | RGB888 :
        	fb.SetPixelProc := SetPixelRGB888;
        	fb.GetPixelProc := GetPixelRGB888;
        	fb.FillRectProc := FillRectRGB888;
        | GS2_HMSB :
			fb.SetPixelProc := SetPixelGS2_HMSB;
        	fb.GetPixelProc := GetPixelGS2_HMSB;
        	fb.FillRectProc := FillRectGS2_HMSB;
   		| GS4_HMSB :
			fb.SetPixelProc := SetPixelGS4_HMSB;
        	fb.GetPixelProc := GetPixelGS4_HMSB;
        	fb.FillRectProc := FillRectGS4_HMSB;
  		| GS8 :
			fb.SetPixelProc := SetPixelGS8;
        	fb.GetPixelProc := GetPixelGS8;
        	fb.FillRectProc := FillRectGS8;
    ELSE
    	;
    END;
	fb.pixels := pixels;
	fb.format := format;
	fb.width := width;
	fb.height := height;
	fb.stride := stride;
END Init;

(** Dispose framebuffer resources *)
PROCEDURE (VAR this : FrameBuffer) Dispose*;
BEGIN END Dispose;

PROCEDURE (VAR this : FrameBuffer) BitDepth*(): INTEGER;
BEGIN
	CASE this.format OF
		MONO_VLSB, MONO_HLSB, MONO_HMSB :
			RETURN 1;
        | RGB565 :
        	RETURN 16;
        | RGB888 :
        	RETURN 24;
        | GS2_HMSB :
			RETURN 2;
   		| GS4_HMSB :
			RETURN 4;
  		| GS8 :
			RETURN 8;
    END;
    RETURN -1
END BitDepth;

(** Set pixel to color at location x, y. *)
PROCEDURE (VAR this : FrameBuffer) SetPixel*(x, y, color : INTEGER);
BEGIN
	IF (x >= 0) & (x < this.width) & (y >= 0) & (y < this.height) THEN
		this.SetPixelProc(this.pixels, this.stride, x, y, color)
	END
END SetPixel;

(** Get pixel color at location x, y. *)
PROCEDURE (VAR this : FrameBuffer) GetPixel*(x, y : INTEGER): INTEGER;
BEGIN
	IF (x >= 0) & (x < this.width) & (y >= 0) & (y < this.height) THEN
		RETURN this.GetPixelProc(this.pixels, this.stride, x, y)
	ELSE
		RETURN 0
	END
END GetPixel;

(** Fill framebuffer with color *)
PROCEDURE (VAR this : FrameBuffer) Fill*(color : INTEGER);
BEGIN this.FillRectProc(this.pixels, this.stride, 0, 0, this.width, this.height, color)
END Fill;

(** Draw a filled rectangle at the given location, size and color. *)
PROCEDURE (VAR this : FrameBuffer) FilledRect*(x, y, w, h, color : INTEGER);
VAR
	xend, yend : INTEGER;
	
	PROCEDURE Min(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x < y THEN RETURN x;
	    ELSE RETURN y END;
	END Min;
	PROCEDURE Max(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x > y THEN RETURN x;
	    ELSE RETURN y END;
	END Max;
BEGIN
	IF (w < 1) OR (h < 1) OR (x + w <= 0) OR (y + h <= 0) OR
	   (y >= this.height) OR (x >= this.width) THEN RETURN
	END;
	xend := Min(this.width, x + w);
	yend := Min(this.height, y + h);
	x := Max(x, 0);
	y := Max(y, 0);
	this.FillRectProc(this.pixels, this.stride, x, y, xend - x, yend - y, color)
END FilledRect;

(** Draw a rectangle at the given location, size and color. *)
PROCEDURE (VAR this : FrameBuffer) Rect*(x, y, w, h, color : INTEGER);
BEGIN
	this.FilledRect(x, y, w, 1, color);
 	this.FilledRect(x, y + h - 1, w, 1, color);
 	this.FilledRect(x, y, 1, h, color);
 	this.FilledRect(x + w - 1, y, 1, h, color)
END Rect;

(** Draw a horizontal line with width, w and given color. *)
PROCEDURE (VAR this : FrameBuffer) HLine*(x, y, w, color : INTEGER);
BEGIN this.FilledRect(x, y, w, 1, color)
END HLine;

(** Draw a vertical line with height, h and given color. *)
PROCEDURE (VAR this : FrameBuffer) VLine*(x, y, h, color : INTEGER);
BEGIN this.FilledRect(x, y, 1, h, color)
END VLine;

(** Draw a line from (x1,y1) to (x2, y2) with given color *)
PROCEDURE (VAR this : FrameBuffer) Line*(x1, y1, x2, y2, color : INTEGER);
VAR
	i, e, dx, sx, dy, sy : INTEGER;
	steep : BOOLEAN;
	PROCEDURE Swap(VAR x, y : INTEGER);
	VAR tmp : INTEGER;
	BEGIN
		tmp := x;
		x := y;
		y := tmp;
	END Swap;
BEGIN
	dx := x2 - x1;
	sx := 1;
	IF dx < 0 THEN
		dx := -dx;
		sx := -1;
	END;
	dy := y2 - y1;
	sy := 1;
	IF dy < 0 THEN
		dy := -dy;
		sy := -1;
	END;
	steep := FALSE;
	IF dy > dx THEN
		Swap(x1, y1);
		Swap(dx, dy);
		Swap(sx, sy);
		steep := TRUE;
	END;
	e := 2 * dy - dx;
	FOR i := 0 TO dx - 1 DO
		IF steep THEN
			IF (0 <= y1) & (y1 < this.width) & (0 <= x1) & (x1 < this.height) THEN
				this.SetPixelProc(this.pixels, this.stride, y1, x1, color)
			END
		ELSE
			IF (0 <= x1) & (x1 < this.width) & (0 <= y1) & (y1 < this.height) THEN
				this.SetPixelProc(this.pixels, this.stride, x1, y1, color)
			END
		END;
		WHILE e >= 0 DO
			y1 := y1 + sy;
			e := e - 2*dx;
		END;
		x1 := x1 + sx;
		e := e + 2*dy;
	END;
	IF (0 <= x2) & (x2 < this.width) & (0 <= y2) & (y2 < this.height) THEN
		this.SetPixelProc(this.pixels, this.stride, x2, y2, color)
	END
END Line;

(** Draw an ellipse with center (xc, yc), radius (xr, yr) limited to a quadrant *)
PROCEDURE (VAR this : FrameBuffer) EllipseSegment*(xc, yc, xr, yr, color : INTEGER; filled : BOOLEAN; quad : SET);
VAR
	x, y, xchange, ychange : INTEGER;
	stoppingx, stoppingy: INTEGER;
	twoASquare, twoBSquare : INTEGER;
	ellipseError : INTEGER;
	PROCEDURE DrawPoints();
	BEGIN
		IF filled THEN
			IF Q1 * quad = Q1 THEN this.FilledRect(xc - 0, yc - y, x + 1, 1, color) END;
			IF Q2 * quad = Q2 THEN this.FilledRect(xc - x, yc - y, x + 1, 1, color) END;
			IF Q3 * quad = Q3 THEN this.FilledRect(xc - x, yc + y, x + 1, 1, color) END;
			IF Q4 * quad = Q4 THEN this.FilledRect(xc - 0, yc + y, x + 1, 1, color) END;
		ELSE
			IF Q1 * quad = Q1 THEN this.SetPixel(xc + x, yc - y, color) END;
			IF Q2 * quad = Q2 THEN this.SetPixel(xc - x, yc - y, color) END;
			IF Q3 * quad = Q3 THEN this.SetPixel(xc - x, yc + y, color) END;
			IF Q4 * quad = Q4 THEN this.SetPixel(xc + x, yc + y, color) END;
		END;
	END DrawPoints;
BEGIN
	IF quad = {} THEN quad := QALL END;
	IF (xr = 0) & (yr = 0) THEN
		IF quad * QALL = QALL THEN
			this.SetPixel(xc, yc, color)
		END
	END;
	twoASquare := 2 * xr * xr;
	twoBSquare := 2 * yr * yr;
	x := xr;
	y := 0;
	xchange := yr * yr * (1 - 2 * xr);
	ychange := xr * xr;
	ellipseError := 0;
	stoppingx := twoBSquare * xr;
	stoppingy := 0;
	WHILE stoppingx >= stoppingy DO (* 1st set of points,  y' > -1 *)
		DrawPoints();
		y := y + 1;
		stoppingy := stoppingy + twoASquare;
		ellipseError := ellipseError + ychange;
		ychange := ychange + twoASquare;
		IF (2 * ellipseError + xchange) > 0 THEN
			x := x - 1;
			stoppingx := stoppingx - twoBSquare;
			ellipseError := ellipseError + xchange;
			xchange := xchange + twoBSquare;
		END;
	END;
	(* 1st point set is done start the 2nd set of points *)
    x := 0;
	y := yr;
	xchange := yr * yr;
	ychange := xr * xr * (1 - 2 * yr);
	ellipseError := 0;
	stoppingx := 0;
	stoppingy := twoASquare * yr;
	WHILE stoppingx <= stoppingy DO (* 2nd set of points, y' < -1 *)
		DrawPoints();
		x := x + 1;
		stoppingx := stoppingx + twoBSquare;
		ellipseError := ellipseError + xchange;
		xchange := xchange + twoBSquare;
		IF (2 * ellipseError + ychange) > 0 THEN
			y := y - 1;
			stoppingy := stoppingy - twoASquare;
			ellipseError := ellipseError + ychange;
			ychange := ychange + twoASquare;
		END;
	END;
END EllipseSegment;

(** Draw an ellipse with center (xc, yc), radius (xr, yr) and given color *)
PROCEDURE (VAR this : FrameBuffer) Ellipse*(xc, yc, xr, yr, color : INTEGER);
BEGIN this.EllipseSegment(xc, yc, xr, yr, color, FALSE, {})
END Ellipse;

(** Draw a filled ellipse with center (xc, yc), radius (xr, yr) and given color *)
PROCEDURE (VAR this : FrameBuffer) FilledEllipse*(xc, yc, xr, yr, color : INTEGER);
BEGIN this.EllipseSegment(xc, yc, xr, yr, color, TRUE, {})
END FilledEllipse;

(** Draw outline of the polygon at location (x,y) and offset coordinates (dx,dy) *)
PROCEDURE (VAR this : FrameBuffer) Polygon*(x, y: INTEGER; dx-, dy- : ARRAY OF INTEGER; color : INTEGER);
VAR
	dx1, dy1, dx2, dy2 : INTEGER;
	i, xlen, ylen : LENGTH;
BEGIN
	xlen := LEN(dx);
	ylen := LEN(dy);
	ASSERT(xlen = ylen);
	IF xlen < 3 THEN RETURN END;
	dx1 := dx[0];
	dy1 := dy[0];
	i := xlen - 1;
	REPEAT
		dx2 := dx[i];
		dy2 := dy[i];
		this.Line(x + dx1, y + dy1, x + dx2, y + dy2, color);
		dx1 := dx2;
		dy1 := dy2;	
		DEC(i);
	UNTIL i < 0;
END Polygon;

(** Draw a filled polygon at location (x,y) and offset coordinates (dx,dy) *)
PROCEDURE (VAR this : FrameBuffer) FilledPolygon*(x, y: INTEGER; dx-, dy- : ARRAY OF INTEGER; color : INTEGER);
VAR
	VAR nodes : ARRAY 2*MAXPOLY OF INTEGER;
	ymin, ymax, py, row : INTEGER;
	px1, py1, px2, py2 : INTEGER;
	swap, node, nnodes : INTEGER;
	i, xlen, ylen : LENGTH;
	PROCEDURE Min(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x < y THEN RETURN x;
	    ELSE RETURN y END;
	END Min;
	PROCEDURE Max(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x > y THEN RETURN x;
	    ELSE RETURN y END;
	END Max;
BEGIN
	(* This implements an integer version of http://alienryderflex.com/polygon_fill/ *)  
	xlen := LEN(dx);
	ylen := LEN(dy);
	ASSERT(xlen = ylen);
	IF xlen < 3 THEN RETURN END;
	ymin := MAX(INTEGER);
	ymax := MIN(INTEGER);
	FOR i := 0 TO ylen - 1 DO
		py := dy[i];
		ymin := Min(ymin, py);
		ymax := Max(ymax, py);
	END;
	FOR row := ymin TO ymax DO
		nnodes := 0;
		px1 := dx[0];
		py1 := dy[0];
		i := ylen - 1;
		REPEAT
			px2 := dx[i];
			py2 := dy[i];
			IF (py1 # py2) & (((py1 > row) & (py2 <= row)) OR ((py1 <= row) & (py2 > row))) THEN
					node := (32 * px1 + 32 * (px2 - px1) * (row - py1) DIV (py2 - py1) + 16) DIV 32;
					nodes[nnodes] := node;
					INC(nnodes);
			ELSIF row = Max(py1, py2) THEN
				(* At local-minima, try and manually fill in the pixels that get missed above. *)
				IF py1 < py2 THEN
					this.SetPixel(x + px2, y + py2, color)
				ELSIF py2 < py1 THEN
					this.SetPixel(x + px1, y + py1, color)
				ELSE
					(* Even though this is a hline and would be faster to
                       use fill_rect, use line() because it handles x2 < x1. *)
                     this.Line(x + px1, y + py1, x + px2, y + py2, color);
				END;
			END;
			px1 := px2;
   			py1 := py2;  
			DEC(i);
		UNTIL i < 0;
		IF nnodes > 0 THEN
			(* Sort the nodes left-to-right (bubble-sort for code size). *)
			i := 0;
			WHILE i < nnodes - 1 DO
				IF nodes[i] > nodes[i + 1] THEN
					swap := nodes[i];
					nodes[i] := nodes[i + 1];
					nodes[i + 1] := swap;
					IF i > 0 THEN DEC(i) END;
				ELSE INC(i) END;
			END;
			(* Fill between each pair of nodes. *)
			i := 0;
			WHILE i < nnodes - 1 DO
				this.FilledRect(x + nodes[i], y + row, (nodes[i + 1] - nodes[i]) + 1, 1, color);
				INC(i, 2)
			END;
		END;
	END;
END FilledPolygon;

(**
Draw a source framebuffer of same format where the color equal to key is transparent.
Set key to -1 to ignore transparent handling.
*)
PROCEDURE (VAR this : FrameBuffer) Blit*(source-: FrameBuffer; x, y, key: INTEGER);
VAR
	x0, y0, x1, y1, x0end, y0end : INTEGER;
	cx0, cx1, col : INTEGER;
	
	PROCEDURE Min(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x < y THEN RETURN x;
	    ELSE RETURN y END;
	END Min;
	PROCEDURE Max(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x > y THEN RETURN x;
	    ELSE RETURN y END;
	END Max;
BEGIN
    IF (x >= this.width) OR (y >= this.height) OR (-x >= source.width) OR (-y >= source.height) THEN
    	RETURN (* Out of bounds, no-op. *)
    END;
    (* Clip. *)
    x0 := Max(0, x);
    y0 := Max(0, y);
    x1 := Max(0, -x);
    y1 := Max(0, -y);
    x0end := Min(this.width, x + source.width);
    y0end := Min(this.height, y + source.height);

	WHILE y0 < y0end DO
		cx1 := x1;
		FOR cx0 := x0 TO x0end - 1 DO
			col := source.GetPixelProc(source.pixels, source.stride, cx1, y1);
			IF col # key THEN
				this.SetPixelProc(this.pixels, this.stride, cx0, y0, col)
			END;
			INC(cx1);
		END;
		INC(y0);
		INC(y1);
	END;
END Blit;

(**
Draw a source framebuffer where the palette array translates the colors.
The palette array must have a size equal or larger then the number of colors.
The key argument is compared to the palette color and treated as transparent color.
*)
PROCEDURE (VAR this : FrameBuffer) BlitPalette*(source-: FrameBuffer; x, y, key: INTEGER; palette- : ARRAY OF INTEGER);
VAR
	x0, y0, x1, y1, x0end, y0end : INTEGER;
	cx0, cx1, col : INTEGER;
	
	PROCEDURE Min(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x < y THEN RETURN x;
	    ELSE RETURN y END;
	END Min;
	PROCEDURE Max(x, y : INTEGER) : INTEGER;
	BEGIN
	    IF x > y THEN RETURN x;
	    ELSE RETURN y END;
	END Max;
BEGIN
    IF (x >= this.width) OR (y >= this.height) OR (-x >= source.width) OR (-y >= source.height) THEN
    	RETURN (* Out of bounds, no-op. *)
    END;
    (* Clip. *)
    x0 := Max(0, x);
    y0 := Max(0, y);
    x1 := Max(0, -x);
    y1 := Max(0, -y);
    x0end := Min(this.width, x + source.width);
    y0end := Min(this.height, y + source.height);
	WHILE y0 < y0end DO
		cx1 := x1;
		FOR cx0 := x0 TO x0end - 1 DO
			col := source.GetPixelProc(source.pixels, source.stride, cx1, y1);
			col := palette[col];
			IF col # key THEN
				this.SetPixelProc(this.pixels, this.stride, cx0, y0, col)
			END;
			INC(cx1);
		END;
		INC(y0);
		INC(y1);
	END;
END BlitPalette;

(** Scroll framebuffer content with vector (xstep, ystep) *)
PROCEDURE (VAR this : FrameBuffer) Scroll*(xstep, ystep: INTEGER);
VAR
	x, sx, y, xend, yend, dx, dy, col : INTEGER;
BEGIN
	IF xstep < 0 THEN
		sx := 0;
		xend := this.width + xstep;
		IF xend <= 0 THEN RETURN END;
		dx := 1;
	ELSE
		sx := this.width - 1;
		xend := xstep - 1;
		IF xend >= sx THEN RETURN END;
		dx := -1;
	END;
	IF ystep < 0 THEN
		y := 0;
		yend := this.height + ystep;
		IF yend <= 0 THEN RETURN END;
		dy := 1;
	ELSE
		y := this.height - 1;
		yend := ystep - 1;
		IF yend >= y THEN RETURN END;
		dy := -1;
	END;
	WHILE y # yend DO
		x := sx;
		WHILE x # xend DO
			col := this.GetPixelProc(this.pixels, this.stride, x - xstep, y - ystep);
			this.SetPixelProc(this.pixels, this.stride, x, y, col);
			x := x + dx;
		END;
		y := y + dy;
	END;
END Scroll;

(** 
Allocate framebuffer on heap.

 * `format` - One of the valid formats.
 * `width` - Width in pixels.
 * `height` - Height in pixels.

 The color value is specific to the format of the framebuffer.
 *)
PROCEDURE InitArray*(VAR fb : FrameBufferArray; format, width, height: INTEGER);
VAR
	bpp, stride, h  : INTEGER;
BEGIN
	ASSERT((width > 0) & (height > 0));
	stride := width;
	h := height;
	bpp := 1;
	CASE format OF
	    MONO_VLSB:
	    	h := INTEGER(SET(height + 7) * {3..15});
      | MONO_HLSB, MONO_HMSB:
        	stride := INTEGER(SET(stride + 7) * {3..15});
      | GS2_HMSB  :
 			stride := INTEGER(SET(stride + 3) * {2..15});
    		bpp := 2;
      | GS4_HMSB  :
      		stride := INTEGER(SET(stride + 1) * {1..15});
			bpp := 4;
      | GS8 : bpp := 8;
      | RGB565 : bpp := 16;
      | RGB888 : bpp := 24;
    ELSE
    	;
    END;
	NEW(fb.array, (stride * h * bpp) DIV 8);
	Init(fb, SYSTEM.ADR(fb.array[0]), format, width, height, stride);
END InitArray;

(** Disposes framebuffer allocated data *)
PROCEDURE (VAR this : FrameBufferArray) Dispose*;
BEGIN
	IF this.array # NIL THEN DISPOSE(this.array) END
END Dispose;

END FrameBuffer.