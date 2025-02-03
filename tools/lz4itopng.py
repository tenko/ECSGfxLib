#!env python
# Convert LZ4 image to PNG image.
# MIT license, Copyright (c) 2025,  Runar Tenfjord
import sys
import os
import io
import argparse
import struct

import png
import lz4.block

def readData(fh, fmt):
    data = fh.read(struct.calcsize(fmt))
    return struct.unpack(fmt, data)
    
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputfile")
    parser.add_argument("-o", "--output", type=str, default = '')
    args = parser.parse_args()
    ifile = open(args.inputfile, 'rb')

    if not args.output:
        name, _ = os.path.splitext(args.inputfile)
        output = name + '.png'
    else:
        output = args.output
    
    magic = ifile.read(4)
    assert magic == b'LZ4I', "not a valid formatted file"     

    width, = readData(ifile, '<h')
    assert width > 0, "width = 0"

    height, = readData(ifile, '<h')
    assert height > 0, "height = 0"

    fmt, = readData(ifile, '<B')

    compressed = bool(fmt & 0x80)
    bpp = fmt & 0x7F
    
    stride = width
    if bpp == 1 : stride = (width + 7) & ~7
    elif bpp == 2 : stride = (width + 3) & ~3
    elif bpp == 4 : stride = (width + 2) & ~2
    
    if compressed:
        size, = readData(ifile, '<l')
    else:
        size = (stride * height * bpp) // 8

    assert bpp in (1,2, 4, 8, 16, 24)
    
    rows = []

    if bpp == 1:
        fmt = "<B"
        for y in range(height):
            row = []
            x = 0
            while x < width:
                v, = readData(ifile, fmt)
                col = 0
                while (col < 8) & (x < width):
                    row.append(bool((1 << col) & v))
                    col = col + 1
                    x = x + 1
            rows.append(row)
        image = png.from_array(rows, "L;%d" % (bpp,))
    elif bpp == 2:
        fmt = "<B"
        for y in range(height):
            row = []
            x = 0
            while x < width:
                v, = readData(ifile, fmt)
                col = 0
                while (col < 8) & (x < width):
                    row.append(v & 3)
                    v = v >> 2
                    col = col + 2
                    x = x + 1
            rows.append(row)
        image = png.from_array(rows, "L;%d" % (bpp,))
    elif bpp == 4:
        fmt = "<B"
        for y in range(height):
            row = []
            x = 0
            while x < width:
                v, = readData(ifile, fmt)
                col = 0
                while (col < 8) & (x < width):
                    row.append(v & 15)
                    v = v >> 4
                    col = col + 4
                    x = x + 1
            rows.append(row)
        image = png.from_array(rows, "L;%d" % (bpp,))      
    elif bpp == 8:
        fmt = "B" * stride
        for i in range(height):
            rows.append(readData(ifile, '<' + fmt))
        image = png.from_array(rows, "L;%d" % (bpp,))
    elif bpp == 16:
        fmt = "<BB"
        for y in range(height):
            row = []
            x = 0
            while x < width:
                lo, hi = readData(ifile, fmt)
                v = (hi << 8) + lo
                g = (v & 0x1F) * 255 // 31
                v = v >> 5
                b = (v & 0x3F) * 255 // 63
                v = v >> 6
                r = (v & 0x1F) * 255 // 31
                row.append(r)
                row.append(b)
                row.append(g)
                x = x + 1
            rows.append(row)
        image = png.from_array(rows, "RGB")
    elif bpp == 24:
        fmt = "<BBB"
        for i in range(height):
            row = [c for rgb in struct.iter_unpack(fmt, ifile.read(size // height)) for c in rgb]
            rows.append(row)
        image = png.from_array(rows, "RGB")
        
    image.save(output)

if __name__ == '__main__':
    main()