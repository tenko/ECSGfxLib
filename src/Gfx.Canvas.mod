(**
Canvas module for simple 2d bitmap graphics .

The Canvas type is an abstract type and the procedures, SetPixel, GetPixel,
FilledRect must be implemented in a subtype.

This is a partial port of the Micropython framebuf module under license:
	The MIT License (MIT), Copyright (c) 2016 Damien P. George
*)
MODULE Canvas IN Gfx;

CONST
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
	Canvas* = RECORD
		width- : INTEGER;
		height- : INTEGER;
	END;


(** Set canvas size. *)
PROCEDURE (VAR this : Canvas) SetSize*(width, height : INTEGER);
BEGIN
    this.width := width;
    this.height := height;
END SetSize;

(** Set pixel to color at location x, y. *)
PROCEDURE (VAR this : Canvas) SetPixel*(x, y, color : INTEGER);
BEGIN END SetPixel;

(** Get pixel color at location x, y. *)
PROCEDURE (VAR this : Canvas) GetPixel*(x, y : INTEGER): INTEGER;
BEGIN RETURN 0 END GetPixel;

(** Draw a filled rectangle at the given location, size and color. *)
PROCEDURE (VAR this : Canvas) FilledRect*(x, y, w, h, color : INTEGER);
BEGIN END FilledRect;

(** Fill canvas with color *)
PROCEDURE (VAR this : Canvas) Fill*(color : INTEGER);
BEGIN this.FilledRect(0, 0, this.width, this.height, color)
END Fill;

(** Draw a rectangle at the given location, size and color. *)
PROCEDURE (VAR this : Canvas) Rect*(x, y, w, h, color : INTEGER);
BEGIN
	this.FilledRect(x, y, w, 1, color);
 	this.FilledRect(x, y + h - 1, w, 1, color);
 	this.FilledRect(x, y, 1, h, color);
 	this.FilledRect(x + w - 1, y, 1, h, color)
END Rect;

(** Draw a horizontal line with width, w and given color. *)
PROCEDURE (VAR this : Canvas) HLine*(x, y, w, color : INTEGER);
BEGIN this.FilledRect(x, y, w, 1, color)
END HLine;

(** Draw a vertical line with height, h and given color. *)
PROCEDURE (VAR this : Canvas) VLine*(x, y, h, color : INTEGER);
BEGIN this.FilledRect(x, y, 1, h, color)
END VLine;

(** Draw a line from (x1,y1) to (x2, y2) with given color *)
PROCEDURE (VAR this : Canvas) Line*(x1, y1, x2, y2, color : INTEGER);
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
				this.SetPixel(y1, x1, color)
			END
		ELSE
			IF (0 <= x1) & (x1 < this.width) & (0 <= y1) & (y1 < this.height) THEN
				this.SetPixel(x1, y1, color)
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
		this.SetPixel(x2, y2, color)
	END
END Line;

(** Draw an ellipse with center (xc, yc), radius (xr, yr) limited to a quadrant *)
PROCEDURE (VAR this : Canvas) EllipseSegment*(xc, yc, xr, yr, color : INTEGER; filled : BOOLEAN; quad : SET);
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
PROCEDURE (VAR this : Canvas) Ellipse*(xc, yc, xr, yr, color : INTEGER);
BEGIN this.EllipseSegment(xc, yc, xr, yr, color, FALSE, {})
END Ellipse;

(** Draw a filled ellipse with center (xc, yc), radius (xr, yr) and given color *)
PROCEDURE (VAR this : Canvas) FilledEllipse*(xc, yc, xr, yr, color : INTEGER);
BEGIN this.EllipseSegment(xc, yc, xr, yr, color, TRUE, {})
END FilledEllipse;

(** Draw outline of the polygon at location (x,y) and offset coordinates (dx,dy) *)
PROCEDURE (VAR this : Canvas) Polygon*(x, y: INTEGER; dx-, dy- : ARRAY OF INTEGER; color : INTEGER);
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
PROCEDURE (VAR this : Canvas) FilledPolygon*(x, y: INTEGER; dx-, dy- : ARRAY OF INTEGER; color : INTEGER);
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

END Canvas.