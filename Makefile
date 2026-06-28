# ccomp
# Copyright (C) 2026 lrisguan <lrisguan@outlook.com>
# 
# This program is released under the terms of the MIT license. 
# See https://github.com/lrisguan/ccomp/blob/main/LICENSE for more information.
# 
# Project homepage: https://github.com/lrisguan/ccomp
# Description: Deep into the process of C language compilation.

LATEXMK := latexmk
TEX := ccomp.tex
DIST := dist
CHAPTERS := $(sort $(filter-out ch*/*-exp/*.tex,$(wildcard ch*/*.tex)))
CHAPTERS_TEX := chapters.tex

.PHONY: all clean rebuild

all: $(DIST)/ccomp-book.pdf

$(CHAPTERS_TEX): $(CHAPTERS)
	@rm -f $(CHAPTERS_TEX)
	@for f in $(CHAPTERS); do echo "\\input{$$f}" >> $(CHAPTERS_TEX); done

$(DIST)/ccomp-book.pdf: $(TEX) $(CHAPTERS_TEX) ccomp-style.sty
	@mkdir -p $(DIST)
	$(LATEXMK) -xelatex -interaction=nonstopmode -halt-on-error -outdir=$(DIST) $(TEX)
	@if [ -f "$(DIST)/ccomp.pdf" ]; then mv "$(DIST)/ccomp.pdf" "$(DIST)/ccomp-book.pdf"; fi

clean:
	$(LATEXMK) -C -outdir=$(DIST) $(TEX)
	@rm -f $(CHAPTERS_TEX)
	@rm -f $(DIST)/ccomp-book.pdf

rebuild: clean all
