# Experiment: Tracing the Complete Compilation Pipeline

## Objective

This experiment will guide you through every stage of the C compilation pipeline, producing each intermediate artifact and understanding what happens at each step:
1. Preprocessing: source code transformation
2. Compilation: C to assembly
3. Assembly: assembly to object code
4. Linking: object files to executable

## Setup Requirements

- GCC or Clang compiler
- Linux or WSL recommended
- Basic command line familiarity
- Tools: gcc, as, ld, nm, objdump, readelf

## Experiment 1: The Complete Pipeline

### Step 1: Create a Multi-File Program

Create a header file `calc.h`:

```c
#ifndef CALC_H
#define CALC_H

int add(int a, int b);
int multiply(int a, int b);

#endif
```

Create `calc.c`:

```c
#include "calc.h"

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}
```

Create `main.c`:

```c
#include <stdio.h>
#include "calc.h"

#define RESULT_VALUE 42

int main(void) {
    int x = add(10, 20);
    int y = multiply(3, 4);
    printf("add: %d, multiply: %d, result: %d\n", x, y, RESULT_VALUE);
    return 0;
}
```

### Step 2: Stage 1 - Preprocessing

Generate preprocessed output:

```bash
gcc -E main.c -o main.i
gcc -E calc.c -o calc.i
```

Examine the preprocessed output:

```bash
head -50 main.i
tail -30 main.i
wc -l main.c main.i
```

**What to observe:**
- `#include <stdio.h>` is expanded to hundreds of lines
- `#include "calc.h"` is replaced with the header contents
- `RESULT_VALUE` is replaced with `42`
- Header guards prevent double inclusion

Search for our code:

```bash
grep -n "int main" main.i
grep -n "RESULT_VALUE" main.i  # Should find nothing - macro expanded!
```

### Step 3: Stage 2 - Compilation to Assembly

Generate assembly from preprocessed source:

```bash
gcc -S main.i -o main.s
gcc -S calc.i -o calc.s
```

Or directly from C source:

```bash
gcc -S main.c -o main.s
gcc -S calc.c -o calc.s
```

Examine the assembly:

```bash
cat main.s
cat calc.s
```

**What to observe:**
- Function labels (`main:`, `add:`, `multiply:`)
- Assembly directives (`.text`, `.globl`, `.type`)
- Instructions (`pushq`, `movl`, `call`, `ret`)
- References to `printf` (external symbol)

### Step 4: Stage 3 - Assembly to Object Code

Generate object files:

```bash
gcc -c main.s -o main.o
gcc -c calc.s -o calc.o
```

Or directly:

```bash
gcc -c main.c -o main.o
gcc -c calc.c -o calc.o
```

Examine object files:

```bash
file main.o
file calc.o
nm main.o
nm calc.o
```

**What to observe:**
- Object files are "relocatable"
- `main.o` has undefined references to `add`, `multiply`, `printf`
- `calc.o` defines `add` and `multiply`

View relocations:

```bash
readelf -r main.o
objdump -r main.o
```

### Step 5: Stage 4 - Linking

Link object files into executable:

```bash
gcc main.o calc.o -o program
```

Or link directly:

```bash
gcc main.c calc.c -o program
```

Run the program:

```bash
./program
```

Expected output:
```
add: 30, multiply: 12, result: 42
```

## Experiment 2: Examining Each Artifact

### Artifact Sizes

Compare sizes at each stage:

```bash
ls -l main.c main.i main.s main.o program
size main.o program
```

**Why sizes change:**
- `.i` file: Much larger due to header expansion
- `.s` file: Smaller, just assembly instructions
- `.o` file: Binary, includes symbol tables and relocations
- Executable: Largest, includes all linked code

### Symbol Tables

Examine symbols in object files vs executable:

```bash
echo "=== main.o symbols ===" && nm main.o
echo "=== calc.o symbols ===" && nm calc.o
echo "=== program symbols ===" && nm program | head -20
```

**What to observe:**
- Object files have undefined (`U`) symbols for external references
- Executable has resolved symbols
- Many new symbols from C runtime (crt*.o)

### Section Contents

View sections in object file:

```bash
objdump -h main.o
readelf -S main.o
```

View sections in executable:

```bash
objdump -h program
readelf -S program | head -20
```

## Experiment 3: Using Individual Tools

### The Preprocessor (cpp)

Run preprocessor standalone:

```bash
cpp main.c -o main.i
# or
gcc -E main.c -o main.i
```

### The Compiler (cc1)

The actual compiler is typically invoked through gcc:

```bash
/usr/lib/gcc/x86_64-linux-gnu/11/cc1 main.c -o main.s
```

### The Assembler (as)

Assemble directly:

```bash
as main.s -o main.o
```

### The Linker (ld)

Link directly (requires runtime files):

```bash
ld main.o calc.o -o program -lc --dynamic-linker /lib64/ld-linux-x86-64.so.2
```

Note: This is complex; `gcc` handles this automatically.

## Experiment 4: Understanding the Driver

The `gcc` command is a "driver" that orchestrates all tools:

```bash
# See what gcc actually does
gcc -v main.c calc.c -o program 2>&1 | grep -E "cc1|as|collect2"
```

**What happens:**
1. `cc1` compiles C to assembly
2. `as` assembles to object files
3. `collect2` (linker wrapper) links everything

## Experiment 5: Pipeline Visualization

Create a visual summary:

```bash
echo "=== Compilation Pipeline Summary ===" && \
echo "Source:     main.c (create this file)" && \
echo "Preprocess: gcc -E main.c -o main.i" && \
ls -l main.i && \
echo "Compile:    gcc -S main.i -o main.s" && \
ls -l main.s && \
echo "Assemble:   gcc -c main.s -o main.o" && \
ls -l main.o && \
echo "Link:       gcc main.o calc.o -o program" && \
ls -l program && \
echo "Run:        ./program"
```

## Experiment 6: Examining Dependencies

### Include Dependencies

View all included files:

```bash
gcc -M main.c
gcc -MM main.c  # System headers excluded
gcc -H main.c 2>&1 | head -20
```

### Library Dependencies

View shared library dependencies:

```bash
ldd program
readelf -d program | grep NEEDED
```

## Experiment 7: Detailed Artifact Analysis

### Preprocessed File Analysis

Count lines and tokens:

```bash
wc -l main.c main.i
grep -c "^#" main.i  # Count line markers
```

### Assembly Analysis

Count instructions:

```bash
grep -c "^\t" main.s  # Count instructions (indented lines)
grep "call" main.s    # Find function calls
```

### Object File Analysis

View detailed info:

```bash
readelf -a main.o | head -50
objdump -x main.o
```

### Executable Analysis

View program headers:

```bash
readelf -l program
readelf -h program
```

## Questions for Reader

### Basic Understanding

1. **Pipeline Stages**: List the four main stages of compilation. What does each stage produce?

2. **Artifact Sizes**: Why is the preprocessed file (`.i`) so much larger than the original source?

3. **Symbol Resolution**: In `main.o`, why are `add` and `multiply` listed as undefined?

4. **Tool Responsibility**: Which tool handles macro expansion? Which handles symbol resolution?

### Intermediate Understanding

5. **Header Expansion**: What happens when `#include <stdio.h>` is processed? How many lines does it add?

6. **Relocation**: What are relocation entries? Why are they needed?

7. **Linker Role**: What does the linker do that the compiler cannot?

8. **Driver Function**: Why is `gcc` called a "driver" rather than a compiler?

### Advanced Understanding

9. **Separate Compilation**: Why is separate compilation (compiling each `.c` file independently) useful?

10. **Incremental Builds**: If you change only `calc.c`, which stages need to be re-run? Why?

11. **Cross-Compiling**: How would the pipeline differ if you were compiling for a different architecture?

12. **Static vs Dynamic**: What would change in the linking stage if you used `-static`?

## Challenge Exercises

### Challenge 1: Manual Pipeline

Perform each compilation step manually without using `gcc` for orchestration:

```bash
# Step 1: Preprocess
cpp main.c -o main.i

# Step 2: Compile (use cc1 directly)
# Step 3: Assemble
as main.s -o main.o

# Step 4: Link (most challenging)
ld ...  # You'll need to find the right flags
```

### Challenge 2: Custom Toolchain

Swap out tools:
- Use `clang` instead of `gcc`
- Use `nasm` instead of `as`
- Document the differences

### Challenge 3: Pipeline Script

Write a shell script that:
1. Takes a C source file as input
2. Runs each pipeline stage
3. Reports size of each artifact
4. Shows symbol count at each stage

### Challenge 4: Artifact Diff

Create two similar programs and diff each artifact:

```c
// version1.c
int main(void) { return 0; }

// version2.c
int main(void) { return 1; }
```

Compare: `diff -u <(objdump -d version1.o) <(objdump -d version2.o)`

## Summary

Through these experiments, you should now understand:

1. **Pipeline Stages**: Preprocessing → Compilation → Assembly → Linking
2. **Artifacts**: Each stage produces a distinct file type (`.i`, `.s`, `.o`, executable)
3. **Tool Roles**: Each tool (cpp, cc1, as, ld) has a specific responsibility
4. **Symbol Resolution**: Linker matches references to definitions
5. **Driver Orchestration**: gcc coordinates all tools automatically

This foundation is essential for understanding the detailed topics in subsequent chapters.
