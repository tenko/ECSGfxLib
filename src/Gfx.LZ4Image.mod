(**
LZ4I - Custom image format

Simple compressed image format using the LZ4 block format.
Falls back to uncompressed data if unable to perform
compression (small file or random data).

The image is stored in the original format and potential
decompressed into the target FrameBuffer.

The pngtolz4i.py tool can be used to convert a PNG file to
the custom format. The pngtomono.py tool can fix problems
with applications not supporting proper 1-bit depth monochrome
PNG images.
*)
MODULE LZ4Image IN Gfx;

IMPORT SYSTEM;

IN Std IMPORT Type, DataLZ4;
IN Gfx IMPORT FrameBuffer;

CONST
	CFLAG* = SET({7}); (* Flag for (un)compressed image type *)
	(* Error codes *)
	OK = 0;
	ERROR_FAILED_TO_READ_DATA = -1;
	ERROR_IN_FILE_FORMAT = -2;
	ERROR_MEMORY = -3;
TYPE
	BYTE = SYSTEM.BYTE;
	ADDRESS = SYSTEM.ADDRESS;
	U8 = UNSIGNED8;
	U16 = UNSIGNED16;
	U32 = UNSIGNED32;
	
	Image* = RECORD
		width- : INTEGER;
		height- : INTEGER;
		type- : BYTE;
		stride- : INTEGER;
		data- : ADDRESS;
		size- : INTEGER;
		array- : POINTER TO ARRAY OF BYTE;
	END;

(** Disposes image allocated data *)
PROCEDURE (VAR this : Image) Dispose*;
BEGIN
	IF this.array # NIL THEN DISPOSE(this.array) END
END Dispose;

(** Return TRUE if image is compressed *)
PROCEDURE (VAR this : Image) IsCompressed*(): BOOLEAN;
BEGIN RETURN SET(this.type) * CFLAG = CFLAG
END IsCompressed;

(** Return bit depth of image *)
PROCEDURE (VAR this : Image) BitDepth*(): INTEGER;
BEGIN RETURN INTEGER(SET(this.type) - CFLAG);	
END BitDepth;

(**
Copy image to FrameBuffer.
Size, depth must match. Stride of framebuffer must be equal to width.
This procedure decompress the image directly to the FrameBuffer and
this puts limit in the FrameBuffer.
*)
PROCEDURE (VAR this : Image) ToFrameBuffer*(fb : FrameBuffer.FrameBuffer): BOOLEAN;
VAR
	size : INTEGER;
BEGIN
	IF this.BitDepth() # fb.BitDepth() THEN RETURN FALSE END;
	IF (this.width # fb.width) OR (this.height # fb.height) THEN RETURN FALSE END;
	IF this.stride # fb.stride THEN RETURN FALSE END;
	size := (this.stride * this.height * this.BitDepth()) DIV 8;
	IF ~this.IsCompressed() THEN
		SYSTEM.MOVE(this.data, fb.pixels, size);
		RETURN TRUE;
	END;
	RETURN DataLZ4.BlockDecodeRaw(fb.pixels, size, this.data, this.size) = size
END ToFrameBuffer;

(** Write image to stream. *)
PROCEDURE (VAR this : Image) Write*(VAR fh : Type.Stream): BOOLEAN;
VAR
	data : POINTER TO ARRAY OF BYTE;
	ret : INTEGER;
BEGIN
	fh.WriteString("LZ4I");
	fh.WriteU16(U16(this.width));
	fh.WriteU16(U16(this.height));
	NEW(data, DataLZ4.MaxEncodeSize(this.size));
	IF data = NIL THEN RETURN FALSE END;
	ret := DataLZ4.BlockEncodeRaw(SYSTEM.ADR(data[0]), LEN(data^), this.data, this.size);
	IF ret < 0 THEN RETURN FALSE END;
	IF ret < this.size THEN
		fh.WriteByte(BYTE(SET(this.type) + CFLAG));
		fh.WriteU32(U32(ret));
		IGNORE(fh.WriteBytes(data^, 0, ret));
	ELSE
		fh.WriteByte(this.type);
		IGNORE(fh.WriteBytes(this.array^, 0, this.size));
	END;
	DISPOSE(data);
	RETURN fh.HasError() = FALSE
END Write;

(** Initialize Image from memory address *)
PROCEDURE InitRaw*(VAR image : Image; adr : ADDRESS): INTEGER;
VAR
	magic : ARRAY 4 OF CHAR;
	u32 : UNSIGNED32;
	u16 : UNSIGNED16;
	u8 : UNSIGNED8;
	bpp : INTEGER;
	idx : LENGTH;
	PROCEDURE ReadU32();
	BEGIN
		SYSTEM.GET(adr + idx, u32);
		INC(idx, SIZE(UNSIGNED32));
	END ReadU32;
	PROCEDURE ReadU16();
	BEGIN
		SYSTEM.GET(adr + idx, u16);
		INC(idx, SIZE(UNSIGNED16));
	END ReadU16;
	PROCEDURE ReadU8();
	BEGIN
		SYSTEM.GET(adr + idx, u8);
		INC(idx, SIZE(UNSIGNED8));
	END ReadU8;
BEGIN
	idx := 0;
	ReadU32();
	SYSTEM.MOVE(SYSTEM.ADR(u32), SYSTEM.ADR(magic[0]), 4);
	IF (magic[0] # 'L') OR (magic[1] # 'Z') OR (magic[2] # '4') OR (magic[3] # 'I') THEN
		RETURN ERROR_IN_FILE_FORMAT
	END;
	ReadU16();
	image.width := INTEGER(u16);
	IF (image.width <= 0) OR (image.width > 0FFFFH) THEN
		RETURN ERROR_IN_FILE_FORMAT
	END;
	ReadU16();
	image.height := INTEGER(u16);
	IF (image.height <= 0) OR (image.height > 0FFFFH) THEN
		RETURN ERROR_IN_FILE_FORMAT
	END;
	ReadU8();
	image.type := u8;

	bpp := image.BitDepth();
	IF (bpp # 1) & (bpp # 2) & (bpp # 4) & (bpp # 8)  &
	   (bpp # 16)  & (bpp # 24)  & (bpp # 32) THEN
	   RETURN ERROR_IN_FILE_FORMAT
	END;
	
	image.stride := image.width;
	CASE bpp OF
        1 : image.stride := INTEGER(SET(image.width + 7) * {3..15});
      | 2 : image.stride := INTEGER(SET(image.width + 3) * {2..15});
      | 4 : image.stride := INTEGER(SET(image.width + 1) * {1..15});
	ELSE ;
    END;
	
	IF ~image.IsCompressed() THEN
		image.size := (image.stride * image.height * bpp) DIV 8;
	ELSE
		ReadU32();
		image.size := INTEGER(u32);
	END;

	image.data := adr + idx;
	RETURN OK
END InitRaw;

(**
Set image data from FrameBuffer.
The image created is uncompressed.
Used for debuging purpose.
*)
PROCEDURE InitFromFrameBuffer*(VAR image : Image; VAR src : FrameBuffer.FrameBuffer): INTEGER;
VAR
	dst : FrameBuffer.FrameBuffer;
	bpp, fmt : INTEGER;
BEGIN
	image.width := src.width;
	image.height := src.height;
	bpp := src.BitDepth();
	image.type := BYTE(bpp);
	image.stride := image.width;
	CASE bpp OF
        1 : image.stride := INTEGER(SET(image.width + 7) * {3..15});
      | 2 : image.stride := INTEGER(SET(image.width + 3) * {2..15});
      | 4 : image.stride := INTEGER(SET(image.width + 1) * {1..15});
	ELSE ;
    END;

	image.size := (image.stride * image.height * bpp) DIV 8;
	image.data := 0;
	NEW(image.array, image.size);
	IF image.array = NIL THEN RETURN ERROR_MEMORY END;
	image.data := SYSTEM.ADR(image.array[0]);
	
	IF (src.format = FrameBuffer.MONO_VLSB) OR (src.format = FrameBuffer.MONO_HLSB) THEN
		fmt := FrameBuffer.MONO_HMSB
	ELSE
		fmt := src.format
	END;
	
	FrameBuffer.Init(dst, image.data, fmt, image.width, image.height, image.stride);
	dst.Blit(src, 0, 0, -1);
	RETURN 0
END InitFromFrameBuffer;

(** Read image form Stream *)
PROCEDURE InitFromStream*(VAR image : Image; VAR fh : Type.Stream): INTEGER;
VAR
	magic : ARRAY 4 OF CHAR;
	u32 : UNSIGNED32;
	u16 : UNSIGNED16;
	bpp : INTEGER;
BEGIN
	IF ~fh.ReadU32(u32) THEN RETURN ERROR_FAILED_TO_READ_DATA END;
	SYSTEM.MOVE(SYSTEM.ADR(u32), SYSTEM.ADR(magic[0]), 4);
	IF (magic[0] # 'L') OR (magic[1] # 'Z') OR (magic[2] # '4') OR (magic[3] # 'I') THEN
		RETURN ERROR_IN_FILE_FORMAT
	END;
	IF ~fh.ReadU16(u16) THEN RETURN ERROR_FAILED_TO_READ_DATA END;
	image.width := INTEGER(u16);
	IF (image.width <= 0) OR (image.width > 0FFFFH) THEN
		RETURN ERROR_IN_FILE_FORMAT
	END;
	IF ~fh.ReadU16(u16) THEN RETURN ERROR_FAILED_TO_READ_DATA END;
	image.height := INTEGER(u16);
	IF (image.height <= 0) OR (image.height > 0FFFFH) THEN
		RETURN ERROR_IN_FILE_FORMAT
	END;
	IF ~fh.ReadByte(image.type) THEN RETURN ERROR_FAILED_TO_READ_DATA END;
	
	bpp := image.BitDepth();
	IF (bpp # 1) & (bpp # 2) & (bpp # 4) & (bpp # 8)  &
	   (bpp # 16)  & (bpp # 24)  & (bpp # 32) THEN
	   RETURN ERROR_IN_FILE_FORMAT
	END;
	
	image.stride := image.width;
	CASE bpp OF
        1 : image.stride := INTEGER(SET(image.width + 7) * {3..15});
      | 2 : image.stride := INTEGER(SET(image.width + 3) * {2..15});
      | 4 : image.stride := INTEGER(SET(image.width + 1) * {1..15});
	ELSE ;
    END;
	
	IF ~image.IsCompressed() THEN
		image.size := (image.stride * image.height * bpp) DIV 8;
	ELSE
		IF ~fh.ReadU32(u32) THEN RETURN ERROR_FAILED_TO_READ_DATA END;
		image.size := INTEGER(u32);
	END;
	
	image.data := 0;
	NEW(image.array, image.size);
	IF image.array = NIL THEN RETURN ERROR_MEMORY END;
	
	image.data := SYSTEM.ADR(image.array[0]);
	IF fh.ReadBytes(image.array^, 0, image.size) # image.size THEN
		RETURN ERROR_FAILED_TO_READ_DATA
	END;
	
	RETURN OK
END InitFromStream;

END LZ4Image.