#!env python
# Convert binary file to asm syntax for embedding of data.
# MIT license, Copyright (c) 2025,  Runar Tenfjord
import sys
import os
import io
import argparse

import png
import lz4.block

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputfile")
    parser.add_argument("-o", "--output", type=str, default = '')
    args = parser.parse_args()
    data = open(args.inputfile, 'rb').read()
    
    if not args.output:
        fh = sys.stdout
    else:
        fh = open(args.output, 'w')
    
    name,ext = os.path.splitext(os.path.basename(args.inputfile))
    name = ''.join(ch for ch in name if ch.isalnum())
    fh.write('.const %s;' % (name,))
    fh.write(' %d bytes\n' % (len(data),))
    fh.write('    .align 4\n')
    fh.write('    .byte ')

    i, col = 1, 1
    for v in data:
        fh.write('0x{:02x}'.format(v))
        col = col + 1
        
        if col == 8:
            fh.write('\n    .byte ')
            col = 1
        elif i < len(data):
            fh.write(', ')

        i = i + 1
    
    fh.close()

if __name__ == '__main__':
    main()