#!env python
# Convert font to asm syntax for embedding of data.
# MIT license, Copyright (c) 2025,  Runar Tenfjord
import sys
import os
import io
import struct
import argparse
import freetype as ft

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputfile")
    parser.add_argument("-o", "--output", type=str, default = '')
    parser.add_argument("-s", "--size", type=int, default = 12)
    args = parser.parse_args()
    
    if not args.output:
        fh = sys.stdout
    else:
        fh = open(args.output, 'w')

    if not args.size:
        height = 12
    else:
        height = args.size
        
    name,ext = os.path.splitext(os.path.basename(args.inputfile))
    name = ''.join(ch for ch in name if ch.isalnum())
    
    letters = ' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'
    first = ord(letters[0])
    last = ord(letters[-1])

    data = []

    face = ft.Face(args.inputfile)
    face.set_pixel_sizes(0, height)

    total = 0
    for letter in letters:
        face.load_char(letter, ft.FT_LOAD_RENDER | ft.FT_LOAD_TARGET_MONO)
        glyph = face.glyph
        bitmap = glyph.bitmap
        data.append({
            'letter' : letter,
            'offset' : total,                       # offset into bitmap data array
            'width' : bitmap.width,                 # pixel width of data
            'rows' : bitmap.rows,                   # pixel height of data
            'pitch' : bitmap.pitch,                 # byte width of data
            'buffer' : bitmap.buffer.copy(),        # byte data
            'dx' : glyph.metrics.horiBearingX,      # bearing x
            'dy' : glyph.metrics.horiBearingY,      # bearing y
            'advance' : glyph.metrics.horiAdvance   # x advance to next glyph
        })
        size = bitmap.rows * ((bitmap.width + 7) // 8)
        # print("%03d '%c' %02d %d" % (ord(letter), letter, size, total))
        total += size
    # print("total = ", total)

    of = io.BytesIO()
    of.write(struct.pack('<B', height))
    of.write(struct.pack('<B', first))
    of.write(struct.pack('<B', last))
    idxsize = struct.calcsize('<HBBBBB') * len(data) # size of index structure
    of.write(struct.pack('<H', idxsize)) 
    for glyph in data:
        of.write(struct.pack('<H', glyph['offset']))
        of.write(struct.pack('<B', glyph['width']))
        of.write(struct.pack('<B', glyph['rows']))
        of.write(struct.pack('<b', glyph['dx'] >> 6))
        of.write(struct.pack('<b', glyph['dy'] >> 6))
        of.write(struct.pack('<B', glyph['advance'] >> 6))
        
    header = of.getvalue()
    fh.write('.const %sFont; height: %d, first = %d, last = %d\n' % (name, height, first, last))
    fh.write('    .align 4\n')
    fh.write('    ; header and index\n')
    fh.write('    .byte ')

    i, col = 1, 1
    for v in header:
        fh.write('0x{:02x}'.format(v))
        col = col + 1
        if col == 8:
            fh.write('\n    .byte ')
            col = 1
        elif i < len(header):
            fh.write(', ')
        i = i + 1
    fh.write("\n") 
    fh.write("    ; glyph data start\n")

    for glyph in data:
        letter = glyph['letter']
        rows, width = glyph['rows'], glyph['width']
        pitch, buf = glyph['pitch'], glyph['buffer']
        fh.write("    ; @%02d '%c' %dx%d pixels\n" % (ord(letter), letter, width, rows))
        for row in range(rows):
            fh.write("    .byte ")
            col = 0
            for i in range(pitch):
                if col >= width : break
                x = buf[row*pitch + i]
                fh.write('0x{:02x}'.format(x))
                col = col + 8
                if col < width : fh.write(", ")

            fh.write(";  ")
            col = 0
            for i in range(pitch):
                if col >= width : break
                x = buf[row*pitch + i]
                for j in range(8):
                    if col >= width: break
                    if x & (1 << (7 - j)):
                        fh.write('*')
                    else:
                        fh.write('.')
                    col = col + 1
              
            fh.write("\n")

    fh.close()
    
if __name__ == '__main__':
    main()