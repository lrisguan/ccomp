# ch05-elf-format-deep-dive

## Purpose
- Provide a detailed, field-by-field understanding of the ELF format.

## Outline
1. ELF header
2. Section header table
3. Program header table
4. Symbol table and string tables
5. Relocation entries
6. Static vs dynamic ELF

## Content plan
- Identify magic bytes, class, endianness, and ABI fields.
- Section headers: names, offsets, sizes, and flags.
- Program headers: loadable segments and memory mapping.
- Symbol tables: bindings, visibility, and section index.
- Relocations: addends, types, and targets.
- Differences between static and dynamic binaries.

## Key terms
- ELF header
- section header table
- program header table
- relocation

## Diagrams planned
- ELF file layout
- Section vs program header mapping

## Experiment
See elf-format-deep-dive-exp/elf-format-deep-dive-exp.md in this chapter.
