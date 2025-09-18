#!env python
# Convert PNG file to raw data file or assembler format
# Currently only RGB565 format is supported
# MIT license, Copyright (c) 2025,  Runar Tenfjord
import sys
import os
import io
import argparse
import struct

import png

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputfile")
    parser.add_argument("-a", "--asm", action="store_true")
    parser.add_argument("-o", "--output", type=str, default = '')
    args = parser.parse_args()
    ifile = open(args.inputfile, 'rb')

    if not args.output:
        assert args.asm, 'output expects a file'
        fh = sys.stdout
    else:
        if args.asm:
            fh = open(args.output, 'w')
        else:
            fh = open(args.output, 'wb')

    reader = png.Reader(file = ifile)
    width, height, pixels, metadata = reader.asRGBA()

    data = []
    for dat in pixels:
        i = 0;
        while i < len(dat):
            r, b, g = dat[i + 0], dat[i + 1], dat[i + 2]
            val = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
            data.append(val)
            i = i + 4

    if args.asm:
        name,ext = os.path.splitext(os.path.basename(args.inputfile))
        name = name.replace(' ', '_')
        
        fh.write('.const %s;' % (name,))
        fh.write(' RGB565 %dx%dx%d, ' % (width, height, 16))
        fh.write(' %d dbytes\n' % (len(data),))
        fh.write('    .align 4\n')
        fh.write('    .dbyte ')

        i, col = 1, 1
        for val in data:
            fh.write('0x{:02x}'.format(val))
            col = col + 1

            if i < len(data):
                if col == 8:
                    fh.write('\n    .dbyte ')
                    col = 1
                else:
                    fh.write(', ')
            
            i = i + 1
    else:
        for val in data:
            fh.write(struct.pack('H', val))
    
    fh.close()

if __name__ == '__main__':
    main()