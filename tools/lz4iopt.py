#!env python
# Recompress LZ4 image official lz4 compressor
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
        output = name + '_opt.lz4i'
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

    data = ifile.read()
    assert len(data) == size

    if compressed:
        usize = (stride * height * bpp) // 8
        data = lz4.block.decompress(data, uncompressed_size = usize, return_bytearray = True)

    data = lz4.block.compress(data, mode = 'high_compression', store_size=False)

    of = io.BytesIO()
    of.write(b'LZ4I')
    of.write(struct.pack('<h', width))
    of.write(struct.pack('<h', height))
    of.write(struct.pack('<B', (bpp) | 0x80))
    of.write(struct.pack('<l', len(data)))
    of.write(data)

    ofile = open(output, 'wb')
    ofile.write(of.getvalue())

if __name__ == '__main__':
    main()