#!env python
# Convert PNG file to custom LZ4 compressed image type.
# MIT license, Copyright (c) 2025,  Runar Tenfjord
import sys
import os
import io
import argparse
import array
import struct

import png
import lz4.block

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputfile")
    parser.add_argument("-a", "--asm", action="store_true")
    parser.add_argument("-u", "--uncompressed", action="store_true")
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
    width, height, pixels, metadata = reader.read_flat()

    bpp = metadata['bitdepth']
    planes = metadata['planes']
    if (planes == 1) and (bpp in (1,2,4)):
        if bpp == 1:
            stride = (width + 7) & ~7
        elif bpp == 2:
            stride = (width + 3) & ~3
        elif bpp == 4:
            stride = (width + 1) & ~1
        size = (stride * height * bpp) // 8
        data = array.array('B', [0 for i in range(size)])
        i, j = 0, 0
        if bpp == 1:
            for y in range(height):
                val = []
                for x in range(width):
                    '''
                    if pixels[i] == 1:
                        print('*', end = '')
                    else:
                        print('.', end = '')
                    '''
                    val.append(pixels[i])
                    i = i + 1
                    if len(val) >= 8:
                        val.reverse()
                        v = val[0]
                        for k in range(7):
                            v = v << 1
                            v = v | val[k + 1]
                        data[j] = v
                        j = j + 1
                        val = []
                
                if len(val) > 0:
                    while len(val) < 8 : val.append(0)
                    val.reverse()
                    v = val[0]
                    for k in range(7):
                        v = v << 1
                        v = v | val[k + 1]
                    data[j] = v
                    j = j + 1
                #print('')
        elif bpp == 2:
            for y in range(height):
                val = []
                for x in range(width):
                    val.append(pixels[i])
                    i = i + 1
                    if len(val) >= 4:
                        val.reverse()
                        v = val[0]
                        for k in range(3):
                            v = v << 2
                            v = v | val[k + 1]
                        data[j] = v
                        j = j + 1
                        val = []
                
                if len(val) > 0:
                    while len(val) < 4 : val.append(0)
                    val.reverse()
                    v = val[0]
                    for k in range(3):
                        v = v << 2
                        v = v | val[k + 1]
                    data[j] = v
                    j = j + 1
                #print('')
        elif bpp == 4:
            for y in range(height):
                val = []
                for x in range(width):
                    val.append(pixels[i])
                    i = i + 1
                    if len(val) >= 2:
                        val.reverse()
                        v = val[0]
                        v = v << 4
                        v = v | val[1]
                        data[j] = v
                        j = j + 1
                        val = []
                
                if len(val) > 0:
                    if len(val) < 2 : val.append(0)
                    val.reverse()
                    v = val[0]
                    v = v << 4
                    v = v | val[1]
                    data[j] = v
                    j = j + 1
                #print('')

        pixels = data
    
    assert width < 0xFFFF and height < 0xFFFF, 'width or height out of bounds'

    of = io.BytesIO()
    of.write(b'LZ4I')
    of.write(struct.pack('<h', width))
    of.write(struct.pack('<h', height))

    compressed = lz4.block.compress(pixels, mode = 'high_compression', store_size=False)
    if args.uncompressed or len(compressed) >= len(pixels):
        of.write(struct.pack('<B', planes*bpp))
        of.write(pixels)
    else:
        of.write(struct.pack('<B', (planes*bpp) | 0x80))
        of.write(struct.pack('<l', len(compressed)))
        of.write(compressed)

    data = of.getvalue()
    
    if not args.asm:
        fh.write(data)
    else:
        name,ext = os.path.splitext(os.path.basename(args.inputfile))
        name = name.replace(' ', '_')
        fh.write('.const %s;' % (name,))
        fh.write(' LZ4Image %dx%dx%d, ' % (width, height, planes*bpp))
        fh.write(' %d bytes,' % (len(data),))
        fh.write(' c-ratio: %.1f\n' % (float(len(pixels)) / len(data)))
        fh.write('    .align 4\n')
        fh.write('    .byte ')

        i, col = 1, 1
        for v in data:
            fh.write('0x{:02x}'.format(v))
            col = col + 1
            
            if i < len(data):
                if col == 8:
                    fh.write('\n    .byte ')
                    col = 1
                else:
                    fh.write(', ')

            i = i + 1
    
    fh.close()

if __name__ == '__main__':
    main()