# ==============================================================================
#  Makefile - compila o projeto com ca65 (assembler) + ld65 (linker) do pacote cc65
#
#  Uso:
#     make            compila com os .inc de texto   -> build/hello_chr.nes
#     make nexxt      compila com os arquivos binários exportados do NEXXT em gfx/
#                     (gfx/tiles.chr, gfx/scene.nam, gfx/bg.pal, gfx/spr.pal)
#                                                    -> build/hello_chr_nexxt.nes
#     make clean      apaga a pasta build/
#
#  Cada variante tem seus próprios .o/.dbg/.map, então uma nunca "contamina" a outra.
#  Windows sem "make"? Use build.bat (mesmos comandos).
# ==============================================================================

NAME  := hello_chr
BUILD := build
SRC   := src/main.asm
INCS  := $(wildcard src/*.inc)
GFX   := $(wildcard gfx/*)

# Opções do ca65:
#   --cpu 6502   aceita só instruções do 6502 NMOS (o NES não tem as do 65C02)
#   -g           grava símbolos de depuração no .o (o Mesen lê isso via .dbg)
#   -I src       onde procurar os arquivos .include
CA65FLAGS := --cpu 6502 -g -I src

.PHONY: all nexxt clean

all: $(BUILD)/$(NAME).nes
nexxt: $(BUILD)/$(NAME)_nexxt.nes

# --- 1) montar: .asm -> .o (código de máquina ainda sem endereços finais) -----
$(BUILD)/$(NAME).o: $(SRC) $(INCS) | $(BUILD)
	ca65 $(CA65FLAGS) -o $@ $(SRC)

# variante NEXXT: o símbolo USE_NEXXT_FILES troca os .include por .incbin (ver main.asm)
$(BUILD)/$(NAME)_nexxt.o: $(SRC) $(INCS) $(GFX) | $(BUILD)
	ca65 $(CA65FLAGS) -D USE_NEXXT_FILES=1 -o $@ $(SRC)

# --- 2) linkar: .o + nes.cfg -> .nes (endereços definidos; vira ROM iNES) -----
#     --dbgfile  arquivo de símbolos para o Mesen (mesmo nome base do .nes!)
#     -m         mapa de memória: mostra onde cada segmento caiu
$(BUILD)/%.nes: $(BUILD)/%.o nes.cfg
	ld65 -C nes.cfg -o $@ --dbgfile $(BUILD)/$*.dbg -m $(BUILD)/$*.map $<

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
