# Chapter 1: C Compilation Overview

## Introduction

When you write a C program, you're creating human-readable source code. But computers don't execute C code directly—they execute machine instructions, binary patterns that the CPU understands. The **compilation pipeline** is the bridge between these two worlds, transforming your source code through a series of well-defined stages, each producing intermediate artifacts.

Understanding this pipeline is essential for:
- **Debugging build failures**: Knowing which stage failed helps pinpoint the problem
- **Optimizing performance**: Optimization happens at specific stages
- **Understanding errors**: Different stages produce different kinds of errors
- **Cross-compilation**: Each stage may run on different machines
- **Build system design**: Makefiles and other build tools orchestrate these stages

This chapter provides a complete map of the compilation pipeline, showing how C source code becomes an executable program and what tools make this transformation possible.

## 1.1 The Complete Compilation Pipeline

The C compilation pipeline consists of four main stages, each converting one file format into another:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    Complete Compilation Pipeline                         │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Source Code   Preprocessing   Preprocessed   Compilation   Assembly    │
│   (.c files) ────────> (.i files) ────────> (.s files) ────────>         │
│                                                                          │
│      │                        │                    │                     │
│      │                        │                    │                     │
│      ▼                        ▼                    ▼                     │
│   ┌──────┐                ┌──────┐              ┌──────┐                 │
│   │ .c   │  ──gcc -E──>   │ .i   │  ──gcc -S──>  │ .s   │                │
│   └──────┘                └──────┘              └──────┘                 │
│                                                                          │
│   Assembly        Assembly        Object Files     Linking     Executable│
│   (.s files) ───────────> (.o files) ───────────────────>                │
│                                                                          │
│      │                                 │                    │            │
│      │                                 │                    │            │
│      ▼                                 ▼                    ▼            │
│   ┌──────┐                        ┌──────┐              ┌──────┐         │
│   │ .s   │  ──as -o──>           │ .o   │  ──ld──>      │(none)│         │
│   └──────┘                        └──────┘              └──────┘         │
│                                                         (a.out)          │
└──────────────────────────────────────────────────────────────────────────┘
```

Each stage has a specific purpose and produces a distinct artifact:

| Stage | Input | Output | Tool | Purpose |
|-------|-------|--------|------|---------|
| Preprocessing | `.c` | `.i` | `cpp` (via `gcc -E`) | Macro expansion, file inclusion |
| Compilation | `.i` | `.s` | `cc1` (via `gcc -S`) | Parse, optimize, generate assembly |
| Assembly | `.s` | `.o` | `as` | Encode to machine code |
| Linking | `.o` | executable | `ld` | Combine objects, resolve symbols |

> **Key Insight**: While we usually invoke `gcc` or `clang` to go directly from `.c` to executable, internally these drivers invoke separate programs for each stage. We can stop at any intermediate stage to inspect the artifacts.

### Why Separate Stages Matter

The modular design of the compilation pipeline serves several important purposes:

1. **Separation of Concerns**: Each stage focuses on one transformation, making the toolchain easier to develop and maintain

2. **Optimization Opportunities**: Different optimization techniques apply at different stages. For example:
   - Preprocessor macros are expanded before compilation
   - Code optimization happens during compilation
   - Link-time optimization (LTO) can happen across translation units

3. **Debugging**: When something goes wrong, you can inspect intermediate files to understand where the problem occurred

4. **Language Interoperability**: Different frontends can produce the same intermediate representations, allowing code in different languages to be linked together

5. **Cross-compilation**: Each stage can theoretically run on different machines (e.g., compiling on a powerful build server for a target embedded system)

Let's now examine each stage in detail.

## 1.2 Stage 1: Preprocessing (.c → .i)

**Preprocessing** is the first stage of compilation. It transforms your source code through **textual substitution** before the compiler ever sees it. The preprocessor doesn't understand C syntax—it works purely on text manipulation.

### What the Preprocessor Does

The preprocessor performs three main operations:

1. **File Inclusion**: Inserting the contents of other files (via `#include`)
2. **Macro Expansion**: Replacing macros with their definitions (via `#define`)
3. **Conditional Compilation**: Including or excluding code based on conditions (via `#if`, `#ifdef`, etc.)

Consider this example:

```c
// main.c
#define MAX_SIZE 100
#define SQUARE(x) ((x) * (x))

#include <stdio.h>

#ifdef DEBUG
    #define LOG(msg) printf("DEBUG: %s\n", msg)
#else
    #define LOG(msg) /* do nothing */
#endif

int main(void) {
    int arr[MAX_SIZE];
    LOG("Program started");
    int result = SQUARE(5);
    return 0;
}
```

After preprocessing (run `gcc -E main.c -o main.i`), we get a massive file (typically thousands of lines) where:
- `#include <stdio.h>` has been replaced with the entire contents of `stdio.h` (and all headers it includes)
- `MAX_SIZE` has been replaced with `100`
- `SQUARE(5)` has been replaced with `((5) * (5))`
- The `LOG` macro has been replaced either with `printf` or nothing, depending on whether `DEBUG` is defined

### Preprocessing Example

Let's create a simpler example to see the transformation clearly:

```c
// example.c
#define PI 3.14159
#define AREA(r) (PI * (r) * (r))

double circle_area(double radius) {
    return AREA(radius);
}
```

Running `gcc -E example.c` produces:

```c
# 1 "example.c"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "example.c"

double circle_area(double radius) {
    return (3.14159 * (radius) * (radius));
}
```

Notice that:
- All `#define` directives are gone
- The macros have been expanded
- Preprocessor directives (lines starting with `#`) show the original source location for debugging

### Translation Units

The output of preprocessing is called a **translation unit**—a single, complete source file ready for compilation. Each `.c` file becomes one translation unit, which the compiler processes independently.

This is crucial for understanding compilation:
- Each `.c` file is compiled **separately**
- The compiler doesn't see other `.c` files
- Cross-file references are resolved during **linking**

> **Common Pitfall**: Because each `.c` file is compiled independently, you must ensure definitions are consistent across translation units. This is why we use header files (`.h` files)—to share declarations between compilation units.

We'll explore preprocessing in depth in Chapter 2.

## 1.3 Stage 2: Compilation (.i → .s)

**Compilation** proper transforms the preprocessed source code into assembly language. This is where the heavy lifting happens: parsing, semantic analysis, optimization, and code generation.

### What the Compiler Does

The compiler performs several sophisticated operations:

1. **Lexical Analysis**: Breaking the code into tokens (identifiers, keywords, operators)
2. **Parsing**: Building an Abstract Syntax Tree (AST) based on C grammar
3. **Semantic Analysis**: Type checking, ensuring variables are declared before use, etc.
4. **Intermediate Representation**: Converting the AST into an IR for optimization
5. **Optimization**: Applying various transformations to improve performance
6. **Code Generation**: Emitting assembly language for the target architecture

### Compilation Example

Let's compile a simple function:

```c
// add.c
int add(int a, int b) {
    return a + b;
}
```

First preprocess it:
```bash
gcc -E add.c -o add.i
```

Then compile to assembly:
```bash
gcc -S add.i -o add.s -fno-asynchronous-unwind-tables -fno-stack-protector
```

The resulting assembly (on x86-64 Linux):

```assembly
    .intel_syntax noprefix
    .globl  add
    .type   add, @function
add:
    mov eax, edi
    add eax, esi
    ret
```

Even from this simple example, we can see:
- The function is marked as global (`.globl`)
- Arguments are in registers (`edi` and `esi` per the calling convention)
- The return value goes in `eax`
- The `ret` instruction returns to the caller

### Why Assembly?

You might wonder: why generate assembly instead of going directly to machine code? Several reasons:

1. **Readability**: Assembly is human-readable, useful for debugging
2. **Portability**: The same compiler can use different assemblers for different targets
3. **Flexibility**: Developers can write hand-optimized assembly when needed
4. **Debugging**: Assembly listings with source annotations help understand what the compiler did

### Optimization Levels

The compiler's behavior changes dramatically based on optimization levels:

```bash
gcc -O0 add.c -o add.o    # No optimization (default for debugging)
gcc -O1 add.c -o add.o    # Basic optimization
gcc -O2 add.c -o add.o    # Standard optimization (recommended)
gcc -O3 add.c -o add.o    # Aggressive optimization
gcc -Os add.c -o add.o    # Optimize for code size
```

With `-O2`, our `add` function becomes even simpler (the compiler might inline it entirely if it's small enough).

We'll explore compilation internals in depth in Chapter 3.

## 1.4 Stage 3: Assembly (.s → .o)

**Assembly** converts human-readable assembly language into machine code, producing an **object file**. This is a binary format, but not yet executable.

### What the Assembler Does

The assembler:

1. **Parses Assembly**: Converts mnemonic instructions into their binary encodings
2. **Resolves Symbols**: Creates symbol table entries for labels and external references
3. **Generates Sections**: Places code and data into appropriate sections (`.text`, `.data`, etc.)
4. **Creates Relocations**: Records locations that need fixing during linking

### Assembly Example

Let's assemble our `add.s` file:

```bash
as add.s -o add.o
```

The resulting `add.o` is a binary file in **ELF format** (Executable and Linkable Format). We can inspect it:

```bash
$ file add.o
add.o: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), not stripped

$ ls -l add.o
-rw-r--r-- 1 user user 864 Nov 15 10:30 add.o
```

The file is only 864 bytes, containing:
- Machine code for the `add` function
- A symbol table noting that `add` is a global symbol
- Section headers marking where code and data are located
- Relocation information (none needed for this simple function)

### Object File Contents

Object files contain several key components:

| Component | Purpose |
|-----------|---------|
| **Section Headers** | Describe the sections (`.text`, `.data`, etc.) |
| **Code Sections** | Machine code (`.text` for executable code) |
| **Data Sections** | Initialized data (`.data`), zero-initialized data (`.bss`) |
| **Symbol Table** | List of defined and undefined symbols |
| **Relocation Entries** | Places needing address fixups during linking |
| **Debug Information** | (optional) Debug symbols for gdb |

### Why Object Files?

Object files are **relocatable**—they don't have fixed memory addresses. This allows:
- Multiple object files to be linked together
- Code to be loaded at any memory address
- Libraries to be shared across multiple programs

The linker will ultimately resolve all symbols and assign final addresses.

We'll explore assembly and object files in depth in Chapter 4.

## 1.5 Stage 4: Linking (.o → executable)

**Linking** is the final stage, combining multiple object files and libraries into a single executable program. This is where separate compilation units finally come together.

### What the Linker Does

The linker performs several critical tasks:

1. **Symbol Resolution**: Connecting references to definitions across object files
2. **Relocation**: Assigning final memory addresses and fixing references
3. **Library Linking**: Including code from standard and user libraries
4. **Executable Creation**: Setting up the executable file format with proper headers

### Linking Example

Let's create a complete program with two files:

```c
// main.c
extern int add(int a, int b);

int main(void) {
    int result = add(5, 3);
    return result == 8 ? 0 : 1;
}
```

```c
// add.c
int add(int a, int b) {
    return a + b;
}
```

Compile and assemble separately:

```bash
gcc -c main.c -o main.o    # Stops after assembly
gcc -c add.c -o add.o      # Stops after assembly
```

Now link them:

```bash
gcc main.o add.o -o program
```

Or using the linker directly:

```bash
ld main.o add.o -o program \
   /usr/lib/x86_64-linux-gnu/crt1.o \
   /usr/lib/x86_64-linux-gnu/crti.o \
   /usr/lib/x86_64-linux-gnu/crtn.o \
   -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2
```

The `gcc` version is simpler because it automatically includes:
- **C runtime startup code** (`crt1.o`, `crti.o`, `crtn.o`)
- **Standard library** (`-lc` for libc)
- **Dynamic linker** path

### Symbol Resolution

Symbol resolution is the linker's most critical job. Consider our example:

```
main.o:  UNDEFINED: add
         DEFINED:   main

add.o:   DEFINED:   add
```

The linker sees that `main.o` references `add`, finds it defined in `add.o`, and connects them. If `add` were not defined anywhere, the linker would error:

```
ld: main.o: in function 'main':
main.c:(.text+0x14): undefined reference to 'add'
```

### Static vs. Dynamic Linking

Linking can happen at different times:

**Static Linking**:
- All library code is included in the executable
- Executables are larger but self-contained
- No runtime dependencies
- Command: `gcc program.o -o program -static` or `gcc program.o -o program -Wl,-Bstatic -lfoo`

**Dynamic Linking** (default):
- Library code is referenced but not included
- Executables are smaller
- Libraries loaded at runtime
- Allows library updates without recompiling
- Command: `gcc program.o -o program` (default)

```bash
$ ldd program  # Shows dynamic library dependencies
    linux-vdso.so.1
    libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
    /lib64/ld-linux-x86-64.so.2
```

### Library Search Order

The linker searches for libraries in a specific order:

1. Paths specified with `-L` flags (left to right)
2. Standard system library directories (`/usr/lib`, `/lib`, etc.)
3. Paths in `LD_LIBRARY_PATH` environment variable (at runtime)

**Important**: The order of `-l` flags matters! Libraries are searched left-to-right, and a library is only used to resolve undefined symbols from libraries to its left.

```bash
# Wrong: libfoo needs symbols from libbar, but libbar is searched first
gcc program.o -o program -lfoo -lbar

# Correct: libbar is available when libfoo needs it
gcc program.o -o program -lbar -lfoo
```

We'll explore linking and relocation in depth in Chapter 6.

## 1.6 Toolchain Components and Roles

Now that we've seen the complete pipeline, let's identify the actual tools involved:

### The GCC Toolchain

When you install `gcc`, you actually get a collection of programs:

```bash
$ which gcc cc1 as ld
/usr/bin/gcc
/usr/lib/gcc/x86_64-linux-gnu/11/cc1
/usr/bin/as
/usr/bin/ld
```

| Tool | Full Name | Role | Stage |
|------|-----------|------|-------|
| `gcc`/`clang` | Compiler Driver | Orchestrates the pipeline | All |
| `cpp` | C Preprocessor | Macro expansion, includes | Preprocessing |
| `cc1` | C Compiler | Parses, optimizes, generates assembly | Compilation |
| `as` | Assembler | Assembly to machine code | Assembly |
| `ld` | Linker | Combines objects, resolves symbols | Linking |

> **Note**: `gcc` is technically a **compiler driver**—it doesn't do compilation itself. Instead, it invokes the appropriate tools (`cpp`, `cc1`, `as`, `ld`) in the correct order with the right arguments.

### The Clang Toolchain

Clang follows a similar architecture:

| Tool | Role |
|------|------|
| `clang` | Compiler driver (front-end) |
| `llvm-as` | LLVM assembler |
| `llc` | LLVM static compiler |
| `lld` | LLVM linker |

### Compiler Drivers: Why They Exist

You might wonder: if we have separate tools (`cpp`, `cc1`, `as`, `ld`), why do we typically just run `gcc`?

**Compiler drivers** exist to:
1. **Simplify**: Hide complexity from the user
2. **Standardize**: Provide a consistent interface across platforms
3. **Orchestrate**: Run tools in the correct order
4. **Configure**: Add necessary flags and include paths automatically

When you run:

```bash
gcc -O2 -Wall program.c -o program
```

The driver:
1. Determines the file type (C source)
2. Constructs the command line for `cpp`
3. Constructs the command line for `cc1` (adding `-O2` optimization)
4. Constructs the command line for `as`
5. Constructs the command line for `ld` (adding necessary libraries)
6. Runs each tool sequentially
7. Cleans up intermediate files (unless you use `-save-temps`)

### Stopping at Intermediate Stages

You can stop the compilation process at any stage:

```bash
# Stop after preprocessing (keep .i file)
gcc -E program.c -o program.i

# Stop after compilation (keep .s file)
gcc -S program.c -o program.s

# Stop after assembly (keep .o file)
gcc -c program.c -o program.o

# Keep all intermediate files
gcc -save-temps program.c -o program
# Creates: program.i, program.s, program.o, program
```

This is incredibly useful for:
- **Debugging**: Seeing what the preprocessor or compiler actually did
- **Learning**: Understanding how C code transforms to assembly
- **Optimizing**: Inspecting compiler output at different optimization levels

### Multiple Source Files

For projects with multiple source files:

```bash
# Compile all files separately (faster for incremental builds)
gcc -c main.c -o main.o
gcc -c util.c -o util.o
gcc -c data.c -o data.o
gcc main.o util.o data.o -o program

# Or let the driver do it (one command)
gcc main.c util.c data.c -o program
```

The second approach compiles each `.c` file to `.o`, then links them all.

## 1.7 A Complete Example: Tracing the Pipeline

Let's trace a complete program through all four stages:

```c
// greet.c
#include <stdio.h>

#define GREETING "Hello, World!"

int main(void) {
    printf("%s\n", GREETING);
    return 0;
}
```

### Stage 1: Preprocessing

```bash
gcc -E greet.c -o greet.i
```

`greet.i` contains the preprocessed source (over 2000 lines due to `stdio.h` expansion). The key parts:

```c
# 1 "greet.c"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "greet.c"
# 1 "/usr/include/stdio.h" 1 3 4
... [thousands of lines from stdio.h] ...
# 2 "greet.c" 2

int main(void) {
    printf("%s\n", "Hello, World!");
    return 0;
}
```

Notice:
- `#include <stdio.h>` is gone, replaced by its contents
- `GREETING` macro has been expanded to `"Hello, World!"`

### Stage 2: Compilation

```bash
gcc -S greet.i -o greet.s
```

`greet.s` contains assembly code. Simplified version:

```assembly
    .file   "greet.c"
    .intel_syntax noprefix
    .section    .rodata
.LC0:
    .string "Hello, World!"
    .text
    .globl  main
    .type   main, @function
main:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 16
    lea     rdi, [rip + .LC0]
    call    printf
    mov     eax, 0
    leave
    ret
    .size   main, .-main
```

Key observations:
- The string literal is in the `.rodata` section (read-only data)
- `printf` is called with the string address
- Return value 0 is placed in `eax`

### Stage 3: Assembly

```bash
as greet.s -o greet.o
```

`greet.o` is now a binary object file:

```bash
$ file greet.o
greet.o: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), not stripped

$ size greet.o
   text    data     bss     dec     hex filename
    135       8       0     143      8f greet.o
```

The object file contains:
- 135 bytes of code (`.text`)
- 8 bytes of data (the string in `.rodata`)
- A symbol table marking `main` as defined and `printf` as undefined
- Relocation entries for the string reference and `printf` call

### Stage 4: Linking

```bash
gcc greet.o -o greet
# Or explicitly:
ld greet.o -o greet \
   /usr/lib/x86_64-linux-gnu/crt1.o \
   /usr/lib/x86_64-linux-gnu/crti.o \
   /usr/lib/x86_64-linux-gnu/crtn.o \
   -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2
```

Now `greet` is an executable:

```bash
$ file greet
greet: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2

$ ls -l greet
-rwxr-xr-x 1 user user 16856 Nov 15 10:45 greet

$ ./greet
Hello, World!
```

## 1.8 Common Build Commands

Here's a reference for common build scenarios:

### Basic Compilation

```bash
# Compile a single source file
gcc program.c -o program

# Compile with warnings (recommended)
gcc -Wall -Wextra program.c -o program

# Compile with optimization
gcc -O2 program.c -o program

# Compile with debug information
gcc -g program.c -o program
```

### Multiple Source Files

```bash
# Compile multiple files at once
gcc main.c util.c data.c -o program

# Compile separately (faster for incremental builds)
gcc -c main.c -o main.o
gcc -c util.c -o util.o
gcc -c data.c -o data.o
gcc main.o util.o data.o -o program

# Automatic dependency tracking
gcc -MMD -c main.c -o main.o   # Creates main.d with dependencies
```

### Intermediate Inspection

```bash
# See preprocessor output
gcc -E program.c -o program.i

# See assembly output
gcc -S program.c -o program.s

# Keep all intermediate files
gcc -save-temps program.c -o program

# Generate assembly with source annotations
gcc -S -fverbose-asm -masm=intel program.c -o program.s
```

### Linking Libraries

```bash
# Link with math library
gcc program.c -o program -lm

# Link with custom library in current directory
gcc program.c -o program -L. -lmylib

# Link static library
gcc program.c -o program -l:libfoo.a

# Create a static library
ar rcs libmylib.a file1.o file2.o file3.o

# Create a shared library
gcc -shared -fPIC file1.c file2.c -o libmylib.so
```

## 1.9 Key Takeaways

1. **The C compilation pipeline has four stages**: Preprocessing, Compilation, Assembly, and Linking. Each stage transforms one file format into another.

2. **Preprocessing (.c → .i)**: Textual substitution through macro expansion, file inclusion, and conditional compilation. Creates translation units.

3. **Compilation (.i → .s)**: Parses code, builds an AST, generates intermediate representation, applies optimizations, and emits assembly language.

4. **Assembly (.s → .o)**: Converts assembly to machine code, creating relocatable object files with symbol tables and relocations.

5. **Linking (.o → executable)**: Combines object files, resolves symbols, applies relocations, and creates the final executable with proper runtime setup.

6. **Toolchain components**: `gcc`/`clang` are compiler drivers that orchestrate `cpp`, `cc1`, `as`, and `ld`. Understanding each tool helps debug build issues.

7. **Separate compilation**: Each `.c` file becomes one translation unit, compiled independently. Cross-file references are resolved during linking.

8. **You can stop at any stage**: Use `-E` (preprocessor), `-S` (compilation), `-c` (assembly), or `-save-temps` (keep everything) to inspect intermediate artifacts.

9. **Optimization levels matter**: `-O0` (fast compilation, good for debugging), `-O2` (recommended for production), `-O3` (maximum optimization), `-Os` (optimize for size).

10. **Understanding the pipeline helps**: Debug build failures, optimize performance, interpret compiler errors, and design effective build systems.

## 1.10 Looking Ahead

Now that we've seen the complete compilation pipeline, we'll examine each stage in detail:

- **Chapter 2**: Preprocessing—how macros work, include file handling, conditional compilation
- **Chapter 3**: Compilation internals—lexers, parsers, ASTs, IR, optimization
- **Chapter 4**: Assembly and object files—assembler syntax, object file structure
- **Chapter 5**: ELF format—headers, sections, segments, symbols, relocations
- **Chapter 6**: Linking and relocation—symbol resolution, static vs. dynamic linking

## Further Reading

- "The C Preprocessor" in the GCC manual
- "Using the GNU Compiler Collection (GCC)" - GCC documentation
- "LLVM: A Compilation Framework for Lifelong Program Analysis and Transformation"
- "Linkers and Loaders" by John R. Levine
