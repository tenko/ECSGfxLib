(*
Simple drawing tests.
MIT license, Copyright (c) 2025,  Runar Tenfjord
*)
MODULE Test;

IMPORT SYSTEM;
IMPORT SDL IN API;
IN Gfx IMPORT FrameBuffer, Font, LZ4Image;
IN Std IMPORT OSStream;

CONST
	WIDTH = 640;
	HEIGHT = 480;

TYPE
	SDLPreview* = RECORD
		framebuffer-: FrameBuffer.FrameBuffer;
		scale-: INTEGER;
		window-: POINTER TO VAR SDL.Window;
		surface-: POINTER TO VAR SDL.Surface;
		event-: SDL.Event;
	END;

VAR ^ spleen6x12Font ["spleen6x12Font"]: ARRAY 1 OF SYSTEM.BYTE;
VAR ^ oberonLogo ["OberonLogo"]: ARRAY 1 OF SYSTEM.BYTE;

PROCEDURE Init*(VAR render : SDLPreview; fb- : FrameBuffer.FrameBuffer; scale : INTEGER);
BEGIN
	ASSERT(scale >= 1);
	render.framebuffer := fb;
	render.scale := scale;
	IF SDL.Init(SDL.INIT_VIDEO) < 0 THEN RETURN END;
	render.window := SDL.CreateWindow(NIL, INTEGER(SDL.WINDOWPOS_UNDEFINED), INTEGER(SDL.WINDOWPOS_UNDEFINED), fb.width*scale, fb.height*scale, 0);
	IF render.window = NIL THEN RETURN END;
	render.surface := SDL.GetWindowSurface(render.window);
END Init;

PROCEDURE (VAR this : SDLPreview) Render*;
VAR
	rect: SDL.Rect;
	color : SDL.Uint32;
	r, g, b : INTEGER;
	x, y, col : INTEGER;
BEGIN
	rect.w := this.scale; rect.h := this.scale;
	FOR y := 0 TO this.framebuffer.height - 1 DO
		rect.y := y * this.scale;
		FOR x := 0 TO this.framebuffer.width - 1 DO
			rect.x := x * this.scale;
			col := this.framebuffer.GetPixel(x, y);
			CASE this.framebuffer.format OF
				FrameBuffer.MONO_VLSB, FrameBuffer.MONO_HLSB, FrameBuffer.MONO_HMSB :
					r := col * 255;
					g := col * 255;
					b := col * 255;
		        | FrameBuffer.RGB565 :
		        	r := (SYSTEM.LSH(col, -11) * 255) DIV 31;
					g := (INTEGER(SET(SYSTEM.LSH(col, -5)) * SET(03FH)) * 255) DIV 63;
					b := (INTEGER(SET(col) * SET(01FH)) * 255) DIV 31;
				| FrameBuffer.RGB888 :
					r := SYSTEM.LSH(col, -16) MOD 256;
					g := SYSTEM.LSH(col, -8) MOD 256;				
					b := col MOD 256;
		        | FrameBuffer.GS2_HMSB :
					r := col * 85;
					g := col * 85;
					b := col * 85;
		   		| FrameBuffer.GS4_HMSB :
					r := col * 17;
					g := col * 17;
					b := col * 17;
		  		| FrameBuffer.GS8 :
					r := col;
					g := col;
					b := col;
		    END;
			color := SDL.MapRGB(this.surface.format, SDL.Uint8(r), SDL.Uint8(g), SDL.Uint8(b));
			IGNORE(SDL.FillRect(this.surface, PTR(rect), color));
		END;
	END;
	IGNORE(SDL.UpdateWindowSurface(this.window));
END Render;

PROCEDURE (VAR this : SDLPreview) PollEvent*(): BOOLEAN;
BEGIN RETURN SDL.PollEvent(PTR(this.event)) = 1
END PollEvent;

PROCEDURE (VAR this : SDLPreview) Dispose*;
BEGIN
	SDL.DestroyWindow(this.window);
	SDL.Quit;
END Dispose;

PROCEDURE Draw(VAR fb : FrameBuffer.FrameBuffer);
VAR
	fba : FrameBuffer.FrameBufferArray;
	fnt : Font.Font;
	img : LZ4Image.Image;
	dx, dy : ARRAY 3 OF INTEGER;
	palette : ARRAY 2 OF INTEGER;
	bg, fg, line, txt : INTEGER;
	logo : INTEGER;
BEGIN
	CASE fb.format OF
		FrameBuffer.MONO_VLSB, FrameBuffer.MONO_HLSB, FrameBuffer.MONO_HMSB :
			bg := 0;			(* Black *)
			fg := 1;			(* White *)
			line := 0;			(* Black *)
			txt := 1;			(* White *)
			logo := 1;			(* White *)
		| FrameBuffer.RGB565 :
			bg := 0047FH;		(* Blue *)
			fg := 08410H;		(* Grey *)
			line := 0FD20H;		(* Orange *)
			txt := 0FFFFH;		(* White *)
			logo := 0FFFFH;		(* White *)
		| FrameBuffer.RGB888 :
			bg := 08CFFH;		(* Blue *)
			fg := 808080;		(* Grey *)
			line := 0FFA500H;	(* Orange *)
			txt := 0FFFFFFH;	(* White *)
			logo := 0FFFFFFH;	(* White *)
		| FrameBuffer.GS2_HMSB :
			bg := 00H;			(* Black *)
			fg := 02H;			(* Grey 80% *)
			line := 01H;		(* Grey 50% *)
			txt := 03H;			(* White *)
			logo := 03H;			(* White *)
		| FrameBuffer.GS4_HMSB :
			bg := 03H;			(* Grey 20% *)
			fg := 0CH;			(* Grey 80% *)
			line := 07H;		(* Grey 50% *)
			txt := 0FH;			(* White *)
			logo := 0FH;			(* White *)
		| FrameBuffer.GS8 :
			bg := 033H;			(* Grey 20% *)
			fg := 0CCH;			(* Grey 80% *)
			line := 07FH;		(* Grey 50% *)
			txt := 0FFH;		(* White *)
			logo := 0FFH;		(* White *)
	END;
	IGNORE(Font.InitRaw(fnt, SYSTEM.ADR(spleen6x12Font[0])));

	palette[0] := bg; palette[1] := logo;
	IGNORE(LZ4Image.InitRaw(img, SYSTEM.ADR(oberonLogo[0])));
	FrameBuffer.InitArray(fba, FrameBuffer.MONO_HMSB, img.width, img.height);
    IGNORE(img.ToFrameBuffer(fba));

	fb.Fill(bg);
	fb.FilledRect(35, 20, 150, 80, fg);
	fb.FilledRect(40, 25, 140, 70, fg);
	fb.Rect(37, 22, 146, 76, bg);
	fb.Line(35, 20, 35+150, 20+80, line);
	fb.Line(35, 20+80, 35+150, 20, line);
	fb.Ellipse(75, 175, 50, 25, fg);
	fb.FilledEllipse(75, 175, 48, 23, fg);
	dx[0] := -50; dx[1] := 50; dx[2] := 0;
	dy[0] := -50; dy[1] := -50; dy[2] := 50;
	fb.Polygon(175, 175, dx, dy, fg);
	fb.FilledPolygon(175, 300, dx, dy, fg);
	fnt.String(fb, "Testing123", 50, 300, txt);
	fb.BlitPalette(fba, 250, 10, bg, palette);
	palette[1] := bg; palette[0] := logo;
	fb.BlitPalette(fba, 250, 250, bg, palette);
END Draw;

PROCEDURE TestDraw(fmt : INTEGER);
VAR
	fb : FrameBuffer.FrameBufferArray;
	preview : SDLPreview;
	exit : BOOLEAN;
BEGIN
	FrameBuffer.InitArray(fb, fmt, WIDTH, HEIGHT);
	Draw(fb);
	Init(preview, fb, 1);
    preview.Render;
    exit := FALSE;
    WHILE ~exit DO
        WHILE preview.PollEvent() DO
            IF preview.event.type = SDL.QUIT THEN exit := TRUE END
        END;
    END;
    preview.Dispose();
	fb.Dispose();
END TestDraw;

PROCEDURE TestSave(fmt : INTEGER; filename- : ARRAY OF CHAR);
VAR
	fb : FrameBuffer.FrameBufferArray;
	img : LZ4Image.Image;
	fh : OSStream.File;
BEGIN
	FrameBuffer.InitArray(fb, fmt, WIDTH, HEIGHT);
	Draw(fb);
	IGNORE(LZ4Image.InitFromFrameBuffer(img, fb));
	IF fh.Open(filename, OSStream.AccessWrite + OSStream.ModeNew) THEN
		IGNORE(img.Write(fh));
		fh.Close();
	ELSE
		OSStream.StdOut.WriteString("failed to open file'");
		OSStream.StdOut.WriteString(filename);
		OSStream.StdOut.WriteChar("'");
		OSStream.StdOut.WriteNL;
	END;
	img.Dispose();
	fb.Dispose();
END TestSave;

BEGIN
	TestDraw(FrameBuffer.GS8);
	(* TestSave(FrameBuffer.GS8, 'gs8_expected.lz4i'); *)
END Test.