#
# Copyright 2014, NICTA
#
# This software may be distributed and modified according to the terms of
# the GNU General Public License version 2. Note that NO WARRANTY is provided.
# See "LICENSE_GPLv2.txt" for details.
#
# @TAG(NICTA_GPL)
#

# This Makefile is not meant to be invoked manually because it relies on
# files generated by a run of `isabelle build`.

LaTeX      = pdflatex -interaction=nonstopmode
BibTeX     = bibtex


all: pdf
pdf: root.pdf

root.pdf: root.tex Makefile
	@echo generating document
	${LaTeX} root; ${BibTeX} root; ${LaTeX} root; ${LaTeX} root; echo ""
	@echo generated/root.pdf

clean:
	rm -f *.aux *.toc *.bbl *.blg *.dvi *.log *.pstex* *.brf \
		*.out .log

realclean: clean
	rm -f root.pdf
