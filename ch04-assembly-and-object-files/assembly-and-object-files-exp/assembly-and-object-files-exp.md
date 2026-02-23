# Experiment: Inspect object file sections and symbols

## Objective
- Use `objdump` and `nm` to examine sections and symbols in a relocatable object.

## Setup requirements
- gcc or clang installed.
- binutils tools (`objdump`, `nm`).

## Step-by-step commands
1. Build an object file:
   ```bash
   gcc -c -o demo.o demo.c
   ```
2. List sections:
   ```bash
   objdump -h demo.o
   ```
3. Disassemble code:
   ```bash
   objdump -d demo.o
   ```
4. Display symbols:
   ```bash
   nm -C demo.o
   ```

## Expected output explanation
- Section headers show size, VMA, and flags.
- Disassembly uses section-relative addresses.
- Symbol output lists global, local, and undefined symbols.

## Questions for reader
1. Which symbols are undefined and why?
2. How do .bss and .data differ in size and type?
3. Which sections would the linker discard or merge?
