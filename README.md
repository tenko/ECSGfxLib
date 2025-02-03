# ECSGfxLib
ECS Oberon-2 Compiler Gfx Library Work in progress.

This library contains the following:
 
 * FrameBuffer type supporting common drawing primitives.
 * LZ4Image type with good compression for monochrome images.
 * Font type which support pre rendered TTF/OBF (FreeType) fonts.
 * Various command line tool to work with fonts, lz4i & png images.

The use case for this library is embedded graphics on microcontrollers.

For testing the graphics can be run on a workstation with help of the SDL2 library.

MIT license, Copyright (c) 2025,  Runar Tenfjord

## TODO

 * Optimize performance
 * Add rounded rectangle primitive
 * Support blitting between different formats
