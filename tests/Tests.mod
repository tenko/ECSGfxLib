(*
Tests module.
MIT license, Copyright (c) 2025,  Runar Tenfjord
*)
MODULE Test;

IMPORT SYSTEM;
IN Gfx IMPORT FrameBuffer, LZ4Image, Font;
IN Std IMPORT OSStream;

CONST
	WIDTH = 640;
	HEIGHT = 480;

VAR ^ spleen6x12Font ["spleen6x12Font"]: ARRAY 1 OF SYSTEM.BYTE;
VAR ^ oberonLogo ["OberonLogo"]: ARRAY 1 OF SYSTEM.BYTE;

PROCEDURE Check(VAR fb : FrameBuffer.FrameBufferArray; expected-, diff- : ARRAY OF CHAR): BOOLEAN;
VAR
	imgfb, errfb : FrameBuffer.FrameBufferArray;
	img : LZ4Image.Image;
	fh : OSStream.File;
	x, y, col, c, errors : INTEGER;
	r, g, b : INTEGER;
	ret : BOOLEAN;
	
	PROCEDURE Error(msg- : ARRAY OF CHAR);
	BEGIN
		OSStream.StdOut.WriteString("Error: ");
		OSStream.StdOut.WriteString(msg);
		OSStream.StdOut.WriteNL;
		imgfb.Dispose();
	END Error;
BEGIN
	IF fh.Open(expected, OSStream.AccessRead) THEN
        IGNORE(LZ4Image.InitFromStream(img, fh));
        fh.Close;
		IF (fb.format = FrameBuffer.MONO_VLSB) OR (fb.format = FrameBuffer.MONO_HLSB) THEN
			FrameBuffer.InitArray(imgfb, FrameBuffer.MONO_HMSB, img.width, img.height)
		ELSE
			FrameBuffer.InitArray(imgfb, fb.format, img.width, img.height)
		END;
		IGNORE(img.ToFrameBuffer(imgfb));
  	ELSE
  		Error("failed to read image");
  		RETURN FALSE;
    END;

    IF img.width # fb.width THEN Error("width does not match"); RETURN FALSE END;
	IF img.height # fb.height THEN Error("height does not match"); RETURN FALSE END;
	IF img.BitDepth() # fb.BitDepth() THEN Error("bit depth does not match"); RETURN FALSE END;

	FrameBuffer.InitArray(errfb, FrameBuffer.RGB888, img.width, img.height);
	img.Dispose();
	
	ret := TRUE;
	errors := 0;
	FOR x := 0 TO fb.width - 1 DO
		FOR y := 0 TO fb.height - 1 DO
			col := fb.GetPixel(x, y);
			c := imgfb.GetPixel(x, y);
			IF c # col THEN
				INC(errors);
				col := 0FF00FFH;
			ELSE
				CASE fb.format OF
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
			    col := SYSTEM.LSH(r, 16) + SYSTEM.LSH(g, 8) + b;
			END;
			errfb.SetPixel(x, y, col);
		END;
	END;
	IF errors > 0 THEN
		OSStream.StdOut.WriteChar("'"); OSStream.StdOut.WriteString(expected); OSStream.StdOut.WriteChar("'");
		OSStream.StdOut.WriteString(" failed, check '");
		OSStream.StdOut.WriteString(diff); OSStream.StdOut.WriteChar("'");
		OSStream.StdOut.WriteNL;
		IF fh.Open(diff, OSStream.AccessWrite + OSStream.ModeNew) THEN
			IGNORE(LZ4Image.InitFromFrameBuffer(img, errfb));
			IGNORE(img.Write(fh));
			fh.Close();
			img.Dispose();
	  	ELSE
	  		OSStream.StdOut.WriteString(" failed to write '");
			OSStream.StdOut.WriteString(diff); OSStream.StdOut.WriteChar("'");
			OSStream.StdOut.WriteNL;
	    END;
		ret := FALSE;
	ELSE
		OSStream.StdOut.WriteChar("'"); OSStream.StdOut.WriteString(expected); OSStream.StdOut.WriteChar("'");
		OSStream.StdOut.WriteString(" passed"); OSStream.StdOut.WriteNL;
	END;
	imgfb.Dispose();
	errfb.Dispose();
	RETURN ret
END Check;

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

PROCEDURE TestDraw(fmt : INTEGER; exp-, diff- : ARRAY OF CHAR);
VAR
	fb : FrameBuffer.FrameBufferArray;
BEGIN
	FrameBuffer.InitArray(fb, fmt, WIDTH, HEIGHT);
	Draw(fb);
	IGNORE(Check(fb, exp, diff));
	fb.Dispose();
END TestDraw;

BEGIN
	TestDraw(FrameBuffer.GS2_HMSB, "tests/gs2_expected.lz4i", "build/gs2_diff.lz4i");
	TestDraw(FrameBuffer.GS4_HMSB, "tests/gs4_expected.lz4i", "build/gs4_diff.lz4i");
	TestDraw(FrameBuffer.GS8, "tests/gs8_expected.lz4i", "build/gs8_diff.lz4i");
	TestDraw(FrameBuffer.RGB565, "tests/rgb565_expected.lz4i", "build/rgb565_diff.lz4i");
	TestDraw(FrameBuffer.RGB888, "tests/rgb888_expected.lz4i", "build/rgb888_diff.lz4i");
	TestDraw(FrameBuffer.MONO_VLSB, "tests/mono_expected.lz4i", "build/mono_vlsb_diff.lz4i");
	TestDraw(FrameBuffer.MONO_HLSB, "tests/mono_expected.lz4i", "build/mono_hlsb_diff.lz4i");
	TestDraw(FrameBuffer.MONO_HMSB, "tests/mono_expected.lz4i", "build/mono_hmsb_diff.lz4i");
END Test.