.SUFFIXES:
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

ifdef MSYSTEM
	PRG = .exe
	SYS = Win
	ECS = /c/EigenCompilerSuite/runtime
	RTS = $(ECS)/std.lib $(ECS)/win64api.obf
	SDL = win64sdl.obf
else
	PRG = 
	SYS = Lin
	ECS = ~/.local/lib/ecs/runtime
	RTS = $(ECS)/std.lib
	SDL = amd64libsdl.obf
endif

OLS += FrameBuffer Font LZ4Image
MOD = $(addprefix src/, $(addprefix Gfx., $(addsuffix .mod, $(OLS))))
OBF = $(addprefix build/, $(addprefix Gfx., $(addsuffix .obf, $(OLS))))

.PHONY: all
all : gfx.lib

build/Gfx.Font.obf : src/Gfx.FrameBuffer.mod
build/Gfx.LZ4Image.obf : src/Gfx.FrameBuffer.mod

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
	@cd build && ecsd Test.mod ../gfx.lib spleen6x12Font.obf OberonLogo.obf $(RTS) ${ECS}/$(SDL)
	@cp build/$@ .
	@./$@

Tests$(PRG) : tests/Tests.mod build/spleen6x12Font.obf build/OberonLogo.obf gfx.lib
	@echo compiling $<
	@mkdir -p build
	@cd build && cp -f ../tests/Tests.mod .
	@cd build && ecsd Tests.mod ../gfx.lib spleen6x12Font.obf OberonLogo.obf $(RTS)
	@cp build/$@ .
	@./$@

Viewer$(PRG) : misc/Viewer.mod gfx.lib
	@echo compiling $<
	@mkdir -p build
	@cd build && cp -f ../misc/Viewer.mod .
	@cd build && ecsd Viewer.mod ../gfx.lib $(RTS) ${ECS}/$(SDL)
	@cp build/$@ .

.PHONY: install
install: std.lib
	@echo Install
	@cp -f gfx.lib /c/EigenCompilerSuite/runtime/
	@cp -f build/std.*.sym /c/EigenCompilerSuite/libraries/oberon/

.PHONY: clean
clean:
	@echo Clean
	@-rm -rf build