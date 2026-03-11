# Experiment: ELF Format Analysis

## Objective

Dissect ELF files to understand their structure, including headers, sections, segments, symbols, and relocations.

## Setup Requirements

- binutils (readelf, objdump, nm, strings)
- GCC compiler
- Linux environment

## Step-by-Step Commands

### Part 1: ELF Header Analysis

1. Create a simple program:

```c
// simple.c
#include <stdio.h>

int main(void) {
    printf("Hello, ELF!\n");
    return 0;
}
```

2. Compile and examine the ELF header:

```bash
gcc simple.c -o simple
readelf -h simple
```

3. Identify key fields:

```bash
# Magic bytes
xxd simple | head -1

# Entry point
readelf -h simple | grep Entry

# Architecture
readelf -h simple | grep Machine
```

**Expected Output**:
```
Magic:   7f 45 4c 46 02 01 01 00 ...
Class:                             ELF64
Data:                              2's complement, little endian
Machine:                           Advanced Micro Devices X86-64
Entry point address:               0xXXXX
```

### Part 2: Section Analysis

1. List all sections:

```bash
readelf -S simple
objdump -h simple
```

2. Examine specific sections:

```bash
# Code section
objdump -d -j .text simple | head -20

# Read-only data
readelf -x .rodata simple

# Data section
readelf -x .data simple

# Dynamic symbols
readelf --dyn-syms simple
```

3. Find the largest sections:

```bash
readelf -S simple | awk '{print $2, $6}' | sort -k2 -n
size -A simple
```

### Part 3: Program Headers (Segments)

1. View program headers:

```bash
readelf -l simple
```

2. Identify loadable segments:

```bash
readelf -l simple | grep -A1 LOAD
```

3. Understand segment mapping:

```bash
# View section-to-segment mapping
readelf -l simple | grep -A20 "Section to Segment"
```

4. Check security features:

```bash
# Stack executable flag
readelf -l simple | grep GNU_STACK

# RELRO
readelf -l simple | grep GNU_RELRO
```

### Part 4: Symbol Table Deep Dive

1. Create a file with various symbols:

```c
// symbols.c
#include <stdio.h>

int global_initialized = 42;
int global_uninitialized;
static int file_local = 10;
const int const_value = 100;

extern int external_symbol;

int my_function(int x) {
    return x * 2;
}

static int static_function(int x) {
    return x + 1;
}

int main(void) {
    int local = my_function(global_initialized);
    printf("%d\n", local);
    return 0;
}
```

2. Compile and examine symbols:

```bash
gcc -c symbols.c -o symbols.o
readelf -s symbols.o
```

3. Decode symbol information:

```bash
# Symbol types: OBJECT, FUNC, etc.
readelf -s symbols.o | grep -E "OBJECT|FUNC"

# Symbol bindings: LOCAL, GLOBAL, WEAK
readelf -s symbols.o | grep -E "LOCAL|GLOBAL|WEAK"

# Symbol visibility
readelf -s symbols.o | grep -E "DEFAULT|HIDDEN"
```

4. Use nm for quick symbol listing:

```bash
nm symbols.o
nm -C symbols.o    # Demangle C++ names
nm -S symbols.o    # Show symbol sizes
nm --size-sort symbols.o
```

### Part 5: Dynamic Linking Analysis

1. View dynamic section:

```bash
readelf -d simple
```

2. Check library dependencies:

```bash
ldd simple
readelf -d simple | grep NEEDED
```

3. Examine the dynamic linker:

```bash
readelf -x .interp simple
readelf -l simple | grep interpreter
```

4. View PLT and GOT:

```bash
objdump -d -j .plt simple
objdump -s -j .got.plt simple
```

### Part 6: Relocation Analysis

1. Create an object file with relocations:

```c
// relocs.c
extern int external_var;
extern void external_func(void);

int test(void) {
    return external_var + 1;
}

void call_test(void) {
    external_func();
}
```

2. View relocations:

```bash
gcc -c relocs.c -o relocs.o
readelf -r relocs.o
```

3. Examine relocation types:

```bash
readelf -r relocs.o | grep R_X86_64
```

4. See the code with relocation offsets:

```bash
objdump -d relocs.o
objdump -r -d relocs.o  # Combined view
```

### Part 7: Comparing Object File vs Executable

1. Create object and executable:

```bash
gcc -c simple.c -o simple.o
gcc simple.c -o simple
```

2. Compare sections:

```bash
echo "=== Object File ===" && readelf -S simple.o | head -20
echo "=== Executable ===" && readelf -S simple | head -20
```

3. Compare symbols:

```bash
echo "=== Object Symbols ===" && nm simple.o
echo "=== Executable Symbols ===" && nm simple | head -20
```

4. Check for program headers:

```bash
# Object files typically don't have program headers
readelf -l simple.o 2>&1 | head -5
readelf -l simple | head -10
```

### Part 8: ELF File Types

1. Create different ELF types:

```bash
# Object file
gcc -c simple.c -o object.o
readelf -h object.o | grep Type

# Executable (PIE)
gcc simple.c -o executable
readelf -h executable | grep Type

# Shared library
gcc -shared -fPIC simple.c -o shared.so
readelf -h shared.so | grep Type

# Static library
ar rcs static.a object.o
file static.a
```

### Part 9: Binary Analysis Tools

1. Extract strings:

```bash
strings simple | head -20
strings -t x simple  # With hex offset
```

2. Find specific strings:

```bash
strings simple | grep -i hello
```

3. View file identification:

```bash
file simple
file simple.o
file shared.so
```

4. Check for stripping:

```bash
strip simple -o simple_stripped
ls -l simple simple_stripped
nm simple_stripped 2>&1
readelf --dyn-syms simple_stripped  # Dynamic symbols remain
```

### Part 10: Debug Information

1. Compile with debug info:

```bash
gcc -g simple.c -o simple_debug
readelf -S simple_debug | grep debug
```

2. View debug info:

```bash
readelf --debug-dump=info simple_debug | head -50
readelf --debug-dump=line simple_debug | head -30
```

3. Use addr2line:

```bash
# Get address from disassembly
objdump -d simple_debug | grep -A2 "<main>"

# Translate address to source line
addr2line -e simple_debug 0xXXXX  # Replace with actual address
```

## Questions for Reader

1. **Magic Bytes**: What does the ELF magic number `7f 45 4c 46` represent? Why is it needed?

2. **Sections vs Segments**: How many sections does your executable have? How many segments? Why is there a difference?

3. **Symbol Resolution**: In the `symbols.c` example, which symbols are undefined? What will the linker do to resolve them?

4. **PLT/GOT**: How does the PLT enable lazy binding? What happens on the first call to `printf`?

5. **Relocation Types**: What is the difference between `R_X86_64_64` (absolute) and `R_X86_64_PC32` (PC-relative)?

6. **Stripping**: After stripping, why do dynamic symbols remain? What are they used for?

## Further Exploration

- Use `elfedit` to modify ELF headers
- Explore the `objcopy` command for section manipulation
- Study how ASLR affects segment loading
- Analyze core dump files with `readelf`
- Create a minimal ELF executable by hand
