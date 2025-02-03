(*
Viewer application for .lz4i images
MIT license, Copyright (c) 2025,  Runar Tenfjord
*)
MODULE Viewer;

IMPORT SYSTEM;
IMPORT SDL IN API;
IN Gfx IMPORT FrameBuffer, LZ4Image;
IN Std IMPORT String, OS, OSStream;

TYPE
	SDLPreview* = RECORD
		framebuffer-: FrameBuffer.FrameBuffer;
		scale-: INTEGER;
		window-: POINTER TO VAR SDL.Window;
		surface-: POINTER TO VAR SDL.Surface;
		event-: SDL.Event;
	END;

PROCEDURE Init*(VAR render : SDLPreview; fb- : FrameBuffer.FrameBuffer; scale : INTEGER);
VAR
    width, height : INTEGER;
BEGIN
	ASSERT(scale >= 1);
	render.framebuffer := fb;
	render.scale := scale;
    width := fb.width*scale;
    IF width < 128 THEN width := 128 END;
    height := fb.height*scale;
    IF height < 128 THEN height := 128 END;
	IF SDL.Init(SDL.INIT_VIDEO) < 0 THEN RETURN END;
	render.window := SDL.CreateWindow(NIL, INTEGER(SDL.WINDOWPOS_UNDEFINED), INTEGER(SDL.WINDOWPOS_UNDEFINED), width, height, 0);
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

PROCEDURE Main;
VAR
    fb : FrameBuffer.FrameBufferArray;
	preview : SDLPreview;
	exit : BOOLEAN;
	img : LZ4Image.Image;
	fh : OSStream.File;
    str : String.STRING;
    fmt : INTEGER;
BEGIN
    IF OS.Args() <= 1 THEN
        OSStream.StdOut.WriteString("Viewer.exe : missing argument"); OSStream.StdOut.WriteNL;
        RETURN
    END;
    OS.Arg(str, 1);
    IF fh.Open(str^, OSStream.AccessRead) THEN
        IF LZ4Image.InitFromStream(img, fh) < 0 THEN
            OSStream.StdOut.WriteChar("'");
            OSStream.StdOut.WriteString(str^);
            OSStream.StdOut.WriteString("' not a valid image");
            OSStream.StdOut.WriteNL;
            String.Dispose(str);
            fh.Close;
            RETURN
        END;
    ELSE
        OSStream.StdOut.WriteString("failed to open '");
        OSStream.StdOut.WriteString(str^);
        OSStream.StdOut.WriteChar("'");
        OSStream.StdOut.WriteNL;
        String.Dispose(str);
        RETURN
    END;

    CASE img.BitDepth() OF
      | 1 : fmt := FrameBuffer.MONO_HMSB;
      | 2 : fmt := FrameBuffer.GS2_HMSB;
      | 4 : fmt := FrameBuffer.GS4_HMSB;
      | 8 : fmt := FrameBuffer.GS8;
      | 16 : fmt := FrameBuffer.RGB565;
      | 24 : fmt := FrameBuffer.RGB888;
    END;
    
    FrameBuffer.InitArray(fb, fmt, img.width, img.height);
    IGNORE(img.ToFrameBuffer(fb));

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
    img.Dispose();
    fh.Close;
    String.Dispose(str);
END Main;

BEGIN
    Main;
END Viewer.