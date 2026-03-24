.SUFFIXES:
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# Installation prefix
PREFIX = /usr/local

ifdef MSYSTEM
	PRG = .exe
	SYS = Win
	RTS = -r std.lib -r win64api.obf
	SDL = -r win64sdl.obf
else
	PRG = 
	SYS = Lin
	RTS = -r std.lib
	SDL = -r amd64libsdl.obf
endif

OLS += Canvas Framebuffer Font LZ4Image
MOD = $(addprefix src/, $(addprefix Gfx., $(addsuffix .mod, $(OLS))))
OBF = $(addprefix build/, $(addprefix Gfx., $(addsuffix .obf, $(OLS))))

.PHONY: all
all : gfx.lib

build/Gfx.Framebuffer.obf : src/Gfx.Canvas.mod
build/Gfx.Font.obf : src/Gfx.Framebuffer.mod
build/Gfx.LZ4Image.obf : src/Gfx.Framebuffer.mod

build/%.obf: src/%.mod
	@echo compiling $< 
	@mkdir -p build
	@cd build && ecsd -c $(addprefix ../, $<)

build/%.obf: misc/%.asm
	@echo compiling $<
	@mkdir -p build
	@cd build && ecsd -c $(addprefix ../, $<)

gfx.lib : $(OBF)
	@echo linking $@
	@-rm $@
	@touch $@
	@linklib $@ $^

Test$(PRG) : misc/Test.mod build/spleen6x12Font.obf build/OberonLogo.obf gfx.lib
	@echo compiling $<
	@mkdir -p build
	@cd build && cp -f ../misc/Test.mod .
	@cd build && ecsd $(RTS) $(SDL) Test.mod ../gfx.lib spleen6x12Font.obf OberonLogo.obf
	@cp build/$@ .
	@./$@

Tests$(PRG) : tests/Tests.mod build/spleen6x12Font.obf build/OberonLogo.obf gfx.lib
	@echo compiling $<
	@mkdir -p build
	@cd build && cp -f ../tests/Tests.mod .
	@cd build && ecsd $(RTS) Tests.mod ../gfx.lib spleen6x12Font.obf OberonLogo.obf
	@cp build/$@ .
	@./$@

Viewer$(PRG) : misc/Viewer.mod gfx.lib
	@echo compiling $<
	@mkdir -p build
	@cd build && cp -f ../misc/Viewer.mod .
	@cd build && ecsd  $(RTS) $(SDL) Viewer.mod ../gfx.lib
	@cp build/$@ .

.PHONY: install
install: gfx.lib
	@echo Install
	@cp -f gfx.lib $(PREFIX)/lib/ecs/runtime/
	@cp -f build/gfx.*.sym $(PREFIX)/lib/ecs/libraries/oberon/

.PHONY: clean
clean:
	@echo Clean
	@-rm -rf build