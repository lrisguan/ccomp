# Experiment: Explore ELF headers and tables

## Objective
- Use `readelf` to examine the ELF header, sections, segments, symbols, and relocations.

## Setup requirements
- gcc or clang installed.
- binutils tools (`readelf`).

## Step-by-step commands
1. Build a small executable:
   ```bash
   gcc -o hello hello.c
   ```
2. Inspect the ELF header:
   ```bash
   readelf -h hello
   ```
3. Inspect section headers:
   ```bash
   readelf -S hello
   ```
4. Inspect program headers:
   ```bash
   readelf -l hello
   ```
5. Inspect symbols and relocations:
   ```bash
   readelf -s -r hello
   ```

## Expected output explanation
- The ELF header identifies class, endianness, and ABI.
- Section headers show how data is organized.
- Program headers show loadable segments.
- Symbol and relocation tables show linkage metadata.

## Questions for reader
1. Which sections are mapped into memory at runtime?
2. Why do some binaries have no relocation entries?
3. How does a PIE binary change the program headers?
