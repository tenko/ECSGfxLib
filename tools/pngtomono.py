#!env python
# Convert PNG file monochrome PNG
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
    parser.add_argument("-i", "--inverted", action="store_true")
    parser.add_argument("-o", "--output", type=str, default = '')
    args = parser.parse_args()
    ifile = open(args.inputfile, 'rb')

    if not args.output:
        name, _ = os.path.splitext(args.inputfile)
        output = name + '_mono.png'
    else:
        output = args.output

    reader = png.Reader(file = ifile)
    width, height, pixels, metadata = reader.asRGBA()

    rows = []
    if args.inverted:
        for data in pixels:
            row = []
            i = 0
            while i < len(data):
                r, b, g, a = data[i + 0], data[i + 1], data[i + 2], data[i + 3]
                row.append(int(r < 255 or b < 255 or g < 255))
                i = i + 4
            rows.append(row)
    else:
        for data in pixels:
            row = []
            i = 0
            while i < len(data):
                r, b, g, a = data[i + 0], data[i + 1], data[i + 2], data[i + 3]
                row.append(int(r > 0 or b > 0 or g > 0))
                i = i + 4
            rows.append(row)

    image = png.from_array(rows, "L;1")
    image.save(output)

if __name__ == '__main__':
    main()