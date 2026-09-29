# Makefile — NeoDOS : interpréteur de commandes façon MS-DOS pour Neo6502
#
# Cibles :
#   make            build/neodos.bin (brut, $B800) + build/neodos.neo
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

.PHONY: fixtures all run run-neo test dist clean

all: $(NEO) examples

$(BUILD):
	mkdir -p $(BUILD)

$(BIN): $(SRC) | $(BUILD)
	$(AS) $(AFLAGS) --list $(LST) --labels $(LBL) -o $@ src/neodos.asm

$(NEO): $(BIN) tools/mkneo.py
	python3 tools/mkneo.py $(BIN) $(NEO) B800 B800 "NeoDOS"

run: $(NEO)
	$(PHOSPHONEO) --sdl --scale 3 --storage storage $(NEO)

run-neo: $(NEO)
	cd storage && $(NEO_EMU) ../$(NEO)@B800 run@B800

test: $(NEO)
	tests/run.sh

clean:
	rm -rf $(BUILD)

# Exemples : programmes HELLO.NEO, BIN/ARGS.NEO et scripts .BAT copiés dans storage/
EXAMPLES = storage/HELLO.NEO storage/BIN/ARGS.NEO storage/BIN/MORE.NEO storage/BIN/TREE.NEO storage/BIN/XCOPY.NEO storage/BIN/DELTREE.NEO storage/BIN/FIND.NEO storage/BIN/SORT.NEO storage/BIN/EDIT.NEO storage/BIN/ATTRIB.NEO storage/BIN/REBOOT.NEO storage/BIN/COLOR.NEO storage/BIN/CONCAT.NEO storage/BIN/HELP.NEO storage/BIN/CHOICE.NEO storage/BIN/HEAD.NEO storage/BIN/TAIL.NEO storage/BIN/WC.NEO storage/AUTOEXEC.BAT storage/DEMO.BAT

examples: $(EXAMPLES)

storage/HELLO.NEO: examples/hello.asm tools/mkneo.py | $(BUILD)
	$(AS) --mw65c02 --nostart --quiet -o $(BUILD)/hello.bin examples/hello.asm
	python3 tools/mkneo.py $(BUILD)/hello.bin $@ 0800 0800 "Hello"

storage/BIN/ARGS.NEO: examples/args.asm tools/mkneo.py | $(BUILD)
	mkdir -p storage/BIN
	$(AS) --mw65c02 --nostart --quiet -o $(BUILD)/args.bin examples/args.asm
	python3 tools/mkneo.py $(BUILD)/args.bin $@ 0800 0800 "Args"

# Commandes externes (examples/ext/NOM.asm, base neoext.inc) -> storage/BIN/NOM.NEO
storage/BIN/%.NEO: examples/ext/%.asm examples/ext/neoext.inc examples/ext/walk.inc examples/ext/glob.inc examples/ext/textfile.inc tools/mkneo.py | $(BUILD)
	mkdir -p storage/BIN
	$(AS) --mw65c02 --nostart --quiet --case-sensitive -I examples/ext -o $(BUILD)/$*.bin $<
	python3 tools/mkneo.py $(BUILD)/$*.bin $@ 0800 0800 "$*"

# Fixtures de test binaires (non livrées) : BIG.NEO se charge par-dessus NeoDOS
fixtures: tests/fixtures/BIG.NEO tests/fixtures/WAITKEY.NEO \
          tests/fixtures/POKER/TBWIN.NEO tests/fixtures/POKER/TBWINX.NEO tests/fixtures/POKER/TBFRONT.NEO
tests/fixtures/BIG.NEO: examples/big.asm tools/mkneo.py | $(BUILD)
	$(AS) --mw65c02 --nostart --quiet -o $(BUILD)/big.bin examples/big.asm
	python3 tools/mkneo.py $(BUILD)/big.bin $@ B000 B000 "Big"
tests/fixtures/WAITKEY.NEO: examples/waitkey.asm tools/mkneo.py | $(BUILD)
	$(AS) --mw65c02 --nostart --quiet -o $(BUILD)/waitkey.bin examples/waitkey.asm
	python3 tools/mkneo.py $(BUILD)/waitkey.bin $@ 0800 0800 "WaitKey"

# Toolbox Reset (Trinity T-88) : fenêtre laissée ouverte, relue au programme suivant
tests/fixtures/POKER/TBWIN.NEO: examples/tbwin.asm tools/mkneo.py | $(BUILD)
	$(AS) --mw65c02 --nostart --quiet -o $(BUILD)/tbwin.bin examples/tbwin.asm
	python3 tools/mkneo.py $(BUILD)/tbwin.bin $@ 0800 0800 "TbWin"
tests/fixtures/POKER/TBWINX.NEO: examples/tbwin.asm tools/mkneo.py | $(BUILD)
	$(AS) --mw65c02 --nostart --quiet -D SMASH=1 -o $(BUILD)/tbwinx.bin examples/tbwin.asm
	python3 tools/mkneo.py $(BUILD)/tbwinx.bin $@ 0800 0800 "TbWinX"
tests/fixtures/POKER/TBFRONT.NEO: examples/tbfront.asm tools/mkneo.py | $(BUILD)
	$(AS) --mw65c02 --nostart --quiet -o $(BUILD)/tbfront.bin examples/tbfront.asm
	python3 tools/mkneo.py $(BUILD)/tbfront.bin $@ 0800 0800 "TbFront"

storage/%.BAT: examples/%.BAT
	cp $< $@

# Image de clé USB pour Trinity (firmware de référence) : boot/neodos.neo lancé
# automatiquement (boot/auto.txt), AUTOEXEC.BAT, BIN/ (commandes externes)
DIST = $(BUILD)/dist
dist: $(NEO) examples
	rm -rf $(DIST)
	mkdir -p $(DIST)/boot $(DIST)/BIN
	cp $(NEO) $(DIST)/boot/neodos.neo
	echo neodos.neo > $(DIST)/boot/auto.txt
	cp storage/AUTOEXEC.BAT storage/DEMO.BAT storage/HELLO.NEO $(DIST)/
	cp storage/BIN/*.NEO $(DIST)/BIN/
	@echo "Image prête : $(DIST)/ (copier son contenu à la racine de la clé USB)"
