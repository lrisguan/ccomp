# ccomp 

Deep Dive into the C Compilation Process: From Source Code to Machine Execution

## Project motivation
This project provides a rigorous, systems-level explanation of how C source code becomes machine-executable programs. It focuses on real toolchains, binary formats, and runtime behavior without oversimplifying the underlying mechanisms.

## Learning goals
- Build a mental model of CPU execution and memory behavior.
- Understand each stage of the C compilation pipeline.
- Inspect real artifacts such as preprocessed output, assembly, object files, and ELF binaries.
- Explain linking, relocation, and dynamic loading at a practical level.
- Reason about ABIs and platform differences.

## Target audience
Learners who want a precise, low-level view of how C programs are built and executed.

## Knowledge prerequisites
- Basic C programming and command-line use.
- Familiarity with basic computer architecture terms is helpful.

## Directory structure
- `chXX-name/` contains chapter content in both Markdown and LaTeX.
- `chXX-name/assets/` stores figures and diagrams for the chapter.
- `chXX-name/exp/` contains a guided experiment in Markdown and LaTeX.
- `ccomp-style.sty` defines LaTeX styling used across chapters.
- `Makefile` builds the PDF book with `latexmk`.

## How to build the PDF version
- Install a LaTeX distribution that includes `latexmk`.
- Run `make` from the project root.
- The final PDF is written to `dist/ccomp-book.pdf`.

## How to read the online version
- Open each `chXX-name/chXX-name.md` file in order.
- Each chapter includes an experiment in `exp/exp.md`.

## Contribution guidelines
- Keep terminology precise and consistent with existing chapters.
- Prefer small, focused changes with clear rationales.
- Add experiments that are reproducible with standard toolchains.

## License suggestion
MIT
