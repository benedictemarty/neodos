# Makefile — NeoDOS : interpréteur de commandes façon MS-DOS pour Neo6502
#
# Cibles :
#   make            build/neodos.bin (brut, $E000) + build/neodos.neo
#   make run        lance NeoDOS dans Phosphoneo (fenêtre SDL) sur storage/
#   make run-neo    lance NeoDOS dans l'émulateur officiel neo
#   make test       tous les tests (émulateur headless)
#   make dist       copie neodos.neo dans storage/ (image de démo)
#   make clean

NEO_FW     ?= $(HOME)/Neo6502firmware
PHOSPHONEO ?= $(HOME)/Phosphoneo/build/phosphoneo
NEO_EMU    ?= $(NEO_FW)/bin/neo

AS      = 64tass
AFLAGS  = --mw65c02 --nostart --quiet --case-sensitive -I src

BUILD   = build
BIN     = $(BUILD)/neodos.bin
NEO     = $(BUILD)/neodos.neo
LST     = $(BUILD)/neodos.lst
LBL     = $(BUILD)/neodos.lbl

SRC     = $(wildcard src/*.asm src/*.inc)

.PHONY: all run run-neo test dist clean

all: $(NEO) examples

$(BUILD):
	mkdir -p $(BUILD)

$(BIN): $(SRC) | $(BUILD)
	$(AS) $(AFLAGS) --list $(LST) --labels $(LBL) -o $@ src/neodos.asm

$(NEO): $(BIN) tools/mkneo.py
	python3 tools/mkneo.py $(BIN) $(NEO) D000 D000 "NeoDOS"

dist: $(NEO) examples
	cp $(NEO) storage/NEODOS.NEO

run: $(NEO)
	$(PHOSPHONEO) --sdl --scale 3 --storage storage $(NEO)

run-neo: $(NEO)
	cd storage && $(NEO_EMU) ../$(NEO)@D000 run@D000

test: $(NEO)
	tests/run.sh

clean:
	rm -rf $(BUILD)

# Exemples : programme HELLO.NEO et scripts .BAT copiés dans storage/
EXAMPLES = storage/HELLO.NEO storage/AUTOEXEC.BAT storage/DEMO.BAT

examples: $(EXAMPLES)

storage/HELLO.NEO: examples/hello.asm tools/mkneo.py | $(BUILD)
	$(AS) --mw65c02 --nostart --quiet -o $(BUILD)/hello.bin examples/hello.asm
	python3 tools/mkneo.py $(BUILD)/hello.bin $@ 0800 0800 "Hello"

storage/%.BAT: examples/%.BAT
	cp $< $@
