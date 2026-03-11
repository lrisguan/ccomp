# Chapter 6: Linking and Relocation

## Introduction

The **linker** is the final stage of the build process, combining object files and libraries into a single executable or library. It resolves symbol references, applies relocations, and produces the final binary that can be loaded and executed.

Understanding linking helps you:
- Debug "undefined symbol" and "multiple definition" errors
- Organize code across multiple files effectively
- Understand static vs. dynamic linking tradeoffs
- Optimize build times and binary sizes

In this chapter, we'll explore the complete linking process from object files to executable.

## 6.1 What is Linking?

### 6.1.1 The Linker's Role

When you compile multiple source files, each produces a separate object file. These object files are incomplete—they contain references to symbols defined in other files. The linker's job is to:

1. **Collect**: Gather all object files and libraries
2. **Resolve**: Match symbol references with definitions
3. **Relocate**: Adjust addresses based on final layout
4. **Output**: Produce a single executable or library

```
┌─────────────────────────────────────────────────────────────────────┐
│                    The Linking Process                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                           │
│  │ main.o   │  │ utils.o  │  │ math.o   │                           │
│  │          │  │          │  │          │                           │
│  │ refs:    │  │ refs:    │  │ refs:    │                           │
│  │  - utils │  │  - math  │  │  - none  │                           │
│  │  - printf│  │  - printf│  │          │                           │
│  │ defines: │  │ defines: │  │ defines: │                           │
│  │  - main  │  │  - utils │  │  - math  │                           │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                           │
│       │             │             │                                 │
│       └─────────────┼─────────────┘                                 │
│                     ▼                                               │
│            ┌───────────────┐                                        │
│            │    Linker     │                                        │
│            │     (ld)      │                                        │
│            └───────┬───────┘                                        │
│                    │                                                │
│                    ▼                                                │
│            ┌───────────────┐                                        │
│            │  Executable   │                                        │
│            │               │                                        │
│            │  - main       │                                        │
│            │  - utils      │                                        │
│            │  - math       │                                        │
│            │  - (libc.so)  │←── Dynamic linking reference           │
│            └───────────────┘                                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.1.2 Why Separate Linking?

You might wonder: why not compile everything together? Separation provides:

- **Incremental builds**: Only recompile changed files
- **Separate compilation**: Teams can work independently
- **Code reuse**: Libraries can be linked into many programs
- **Modularity**: Clear interfaces between components

## 6.2 Symbol Resolution

### 6.2.1 The Symbol Resolution Problem

Each object file has:
- **Defined symbols**: Functions and variables it provides
- **Undefined symbols**: References to external functions/variables

The linker must ensure every undefined symbol has exactly one definition.

```
Object File A:
  Defined:   main, helper_a
  Undefined: helper_b, printf

Object File B:
  Defined:   helper_b, helper_c
  Undefined: helper_a

Object File C (libc):
  Defined:   printf, scanf, malloc, ...

After resolution:
  main      → defined in A
  helper_a  → defined in A
  helper_b  → defined in B
  helper_c  → defined in B
  printf    → defined in C (libc)
```

### 6.2.2 Symbol Types and Precedence

**Strong Symbols**: Functions, initialized global variables
**Weak Symbols**: Symbols declared with `__attribute__((weak))`

Resolution rules:
1. Multiple strong symbols with same name → **error**
2. One strong symbol, multiple weak symbols → **use strong**
3. Multiple weak symbols → **arbitrary choice**

```c
// file1.c
int global_var = 10;           // Strong symbol
void foo(void) { }             // Strong symbol

// file2.c
int global_var;                // Weak symbol (tentative definition)
__attribute__((weak)) void foo(void) { }  // Weak symbol

// Linker chooses file1.c's definitions (strong wins)
```

### 6.2.3 Common Linker Errors

**Undefined Symbol**:
```
/usr/bin/ld: /tmp/ccXXXX.o: in function `main':
main.c:(.text+0x15): undefined reference to `missing_function'
collect2: error: ld returned 1 exit status
```
Cause: Referenced symbol not defined in any linked file or library.

**Multiple Definition**:
```
/usr/bin/ld: /tmp/ccYYYY.o:(.data+0x0): multiple definition of `global_var'
/tmp/ccXXXX.o:(.data+0x0): first defined here
collect2: error: ld returned 1 exit status
```
Cause: Symbol defined in multiple object files.

**Solutions**:
- For undefined: Add the defining file/library to link command
- For multiple: Use `static` for file-local variables, or `extern` declarations

### 6.2.4 Name Mangling and C++ Symbols

C++ mangles function names to encode type information:

```cpp
// C++ code
void foo(int x);           // Mangled: _Z3fooi
void foo(double x);        // Mangled: _Z3food
void foo(int x, int y);    // Mangled: _Z3fooii

// Using nm:
$ nm program.o
0000000000000000 T _Z3fooi
0000000000000014 T _Z3food
0000000000000028 T _Z3fooii
```

To demangle:
```bash
nm program.o | c++filt
# Output:
# 0000000000000000 T foo(int)
# 0000000000000014 T foo(double)
# 0000000000000028 T foo(int, int)
```

**extern "C"** disables name mangling for C compatibility:
```cpp
extern "C" void c_function(void);  // Mangled as just "c_function"
```

## 6.3 Relocation

### 6.3.1 What is Relocation?

Object files are compiled as if they start at address 0. The linker must adjust all addresses to reflect the final memory layout. This process is **relocation**.

```
Object file A (before linking):
  .text starts at 0x0000
  call 0x0010  (call helper)

Object file B (before linking):
  .text starts at 0x0000
  helper at 0x0010

After linking (A at 0x400000, B at 0x400100):
  A's .text at 0x400000
  B's .text at 0x400100
  helper at 0x400110
  A's call: call 0x400110
```

### 6.3.2 Relocation Types

Different relocation types specify how to compute the final value:

**Absolute Relocation**: Store the symbol's actual address
```
R_X86_64_64: Store full 64-bit address
```

**PC-Relative Relocation**: Store the offset from current instruction
```
R_X86_64_PC32: Store (symbol_address - current_address)
R_X86_64_PLT32: Store (PLT_entry - current_address)
```

**GOT-Relative**: Store offset to GOT entry
```
R_X86_64_GOTPCREL: Store (GOT_entry - current_address)
```

### 6.3.3 Relocation Process

For each relocation entry in object files:

1. Find the target symbol's final address
2. Compute the relocation value based on type
3. Write the value to the specified offset in the output

```
Object file has:
  Offset: 0x0a
  Type: R_X86_64_PLT32
  Symbol: printf

Linker knows:
  printf's PLT entry is at 0x401020
  This code will be at 0x401100

Computation:
  Offset 0x0a in output is 0x401100 + 0x0a = 0x40110a
  Relocation value = PLT_entry - PC_after_instruction
                   = 0x401020 - 0x40110f = 0xFFFFFEF1 (as signed 32-bit)

Write 0xFFFFFEF1 at offset 0x0a in the output file
```

### 6.3.4 Viewing Relocations

```bash
# In object files (before linking)
readelf -r object.o

# In final executable (fewer, for dynamic linking)
readelf -r executable
```

## 6.4 The Linking Process in Detail

### 6.4.1 Linker Input Processing

The linker processes inputs in order:

```bash
gcc main.o utils.o -lm -o program
```

Order matters for static libraries:
```
1. Process main.o: collect undefined symbols (utils functions)
2. Process utils.o: provides utils functions, may add undefined symbols
3. Process -lm (libm.a): only extract needed objects
```

**Critical rule**: Static libraries should come after files that use them:
```bash
# Wrong: linker hasn't seen the undefined symbols yet
gcc -lm main.o -o program   # May fail to find math functions

# Correct: main.o's undefined symbols trigger libm extraction
gcc main.o -lm -o program
```

### 6.4.2 Section Merging

The linker combines sections from all inputs:

```
Input A:        Input B:        Output:
.text (100)     .text (200)     .text (300)
.rodata (50)    .rodata (30)    .rodata (80)
.data (20)      .data (40)      .data (60)
.bss (10)       .bss (15)       .bss (25)
```

Sections are merged by name and type, maintaining alignment requirements.

### 6.4.3 Address Assignment

The linker assigns virtual addresses to all sections:

```
Default layout (simplified):
0x400000: .text (code)
0x600000: .rodata (read-only data)
0x800000: .data (initialized data)
0x800XXX: .bss (uninitialized data)
```

The actual layout is determined by:
- Linker script (default or custom)
- Section alignment requirements
- Memory protection constraints

### 6.4.4 Symbol Table Construction

The linker builds the final symbol table:

1. Collect all global symbols from inputs
2. Resolve conflicts (strong vs. weak)
3. Assign final addresses
4. Write symbol table to output

```bash
# View final symbol table
nm program
readelf -s program
```

## 6.5 Static Linking

### 6.5.1 What is Static Linking?

Static linking embeds library code directly into the executable:

```bash
# Create a static library
ar rcs libmylib.a file1.o file2.o file3.o

# Link statically with the library
gcc main.o -L. -lmylib -o program

# Or link completely static
gcc -static main.o -o program
```

### 6.5.2 Static Library Format

Static libraries (`.a` files) are **archives** containing multiple object files:

```
libmylib.a:
├── file1.o
├── file2.o
└── file3.o

# View contents
ar -t libmylib.a
ar -x libmylib.a   # Extract all .o files
```

### 6.5.3 Selective Linking

The linker only extracts objects that satisfy undefined symbols:

```
libmylib.a:
├── string_utils.o (defines: str_lower, str_upper)
├── math_utils.o   (defines: add, subtract)
└── file_utils.o   (defines: read_file, write_file)

main.o references: str_lower, add

Linker extracts: string_utils.o, math_utils.o
Ignores: file_utils.o (no referenced symbols)
```

This prevents unnecessary code bloat.

### 6.5.4 Pros and Cons of Static Linking

**Advantages**:
- Self-contained executable (no external dependencies)
- Predictable behavior (library version is fixed)
- No runtime linking overhead

**Disadvantages**:
- Larger executables
- Memory inefficiency (each program has its own copy)
- Updates require recompilation
- Security updates harder to deploy

## 6.6 Dynamic Linking

### 6.6.1 What is Dynamic Linking?

Dynamic linking defers library resolution to runtime:

```bash
# Create a shared library
gcc -shared -fPIC -o libmylib.so file1.c file2.c

# Link against shared library
gcc main.c -L. -lmylib -o program

# At runtime
LD_LIBRARY_PATH=. ./program
```

### 6.6.2 Position-Independent Code (PIC)

Shared libraries must be position-independent—they can load at any address:

```bash
# Compile with -fPIC
gcc -fPIC -c file.c -o file.o

# Create shared library
gcc -shared file.o -o libfile.so
```

PIC uses relative addressing and the GOT:

```assembly
# Non-PIC: absolute address
mov 0x400000, %eax    # Hard-coded address

# PIC: relative addressing through GOT
mov var@GOTPCREL(%rip), %rax  # Get address from GOT
mov (%rax), %eax              # Dereference
```

### 6.6.3 The Dynamic Linker

The dynamic linker (`ld.so`) runs when the program starts:

1. Read the program's dynamic section
2. Find needed libraries (DT_NEEDED entries)
3. Load libraries into memory
4. Resolve symbols (lazily or eagerly)
5. Update GOT entries

```bash
# View dynamic dependencies
ldd program

# Trace dynamic linking
LD_DEBUG=libs ./program
LD_DEBUG=symbols ./program
LD_DEBUG=all ./program 2>&1 | less
```

### 6.6.4 Lazy vs. Eager Binding

**Lazy Binding** (default): Resolve symbols on first use
- Faster startup
- Unused symbols never resolved
- Implemented via PLT

**Eager Binding**: Resolve all symbols at startup
```bash
LD_BIND_NOW=1 ./program
```
- Slower startup
- All symbols guaranteed to exist
- More predictable behavior

### 6.6.5 Symbol Interposition

Dynamic linking allows symbol interposition—overriding library functions:

```c
// intercept.c
#define _GNU_SOURCE
#include <stdio.h>
#include <dlfcn.h>

int printf(const char *format, ...) {
    // Get original printf
    static int (*real_printf)(const char*, ...) = NULL;
    if (!real_printf) {
        real_printf = dlsym(RTLD_NEXT, "printf");
    }

    // Add prefix
    real_printf("[INTERCEPTED] ");
    
    // Call original with remaining args
    va_list args;
    va_start(args, format);
    int ret = vprintf(format, args);
    va_end(args);
    return ret;
}
```

```bash
# Compile interceptor
gcc -shared -fPIC intercept.c -o intercept.so -ldl

# Use it
LD_PRELOAD=./intercept.so ./program
```

### 6.6.6 Pros and Cons of Dynamic Linking

**Advantages**:
- Smaller executables
- Memory efficiency (shared code pages)
- Easy updates (replace library file)
- Runtime plugin support

**Disadvantages**:
- Runtime overhead
- Dependency management ("DLL hell")
- Security concerns (LD_PRELOAD attacks)
- Version compatibility issues

## 6.7 Linker Scripts

### 6.7.1 What is a Linker Script?

Linker scripts control exactly how sections are laid out:

```ld
/* Simple linker script */
ENTRY(main)

SECTIONS
{
    . = 0x400000;          /* Start address */
    
    .text : {
        *(.text)           /* All .text sections */
    }
    
    . = 0x600000;
    
    .rodata : {
        *(.rodata)
    }
    
    . = 0x800000;
    
    .data : {
        *(.data)
    }
    
    .bss : {
        *(.bss)
    }
}
```

### 6.7.2 Using Linker Scripts

```bash
# Use custom linker script
ld -T custom.ld object.o -o program

# Or with gcc
gcc -T custom.ld object.o -o program
```

### 6.7.3 View Default Linker Script

```bash
# See the default script
ld --verbose

# For gcc's default
gcc -Wl,--verbose 2>&1 | grep -A1000 "^======="
```

### 6.7.4 Common Linker Script Features

```
ENTRY(symbol)           # Set entry point

SECTIONS {
    . = address;        # Set current location counter
    
    .section : {
        *(.section*)    # Wildcard matching
        file.o(.text)   # Specific file
    }
    
    . = ALIGN(4096);    # Align to page boundary
    
    PROVIDE(symbol = .); # Define symbol at current address
}

MEMORY {
    RAM (rwx) : ORIGIN = 0, LENGTH = 1M
    FLASH (rx) : ORIGIN = 1M, LENGTH = 1M
}
```

## 6.8 Common Linker Flags

### 6.8.1 Library Search Paths

```bash
# Add library search path
gcc -L/path/to/libs program.c -lmylib

# Add runtime library path
gcc -Wl,-rpath,/path/to/libs program.c -lmylib

# Add both compile-time and runtime paths
gcc -L/path/to/libs -Wl,-rpath,/path/to/libs program.c -lmylib
```

### 6.8.2 Symbol Control

```bash
# Export only specific symbols
gcc -Wl,--version-script,exports.map program.c

# exports.map:
# {
#     global: public_function;
#     local: *;
# };

# Strip all symbols
gcc -s program.c -o program

# Keep debug info
gcc -g program.c -o program
```

### 6.8.3 Optimization Flags

```bash
# Remove unused sections
gcc -ffunction-sections -fdata-sections -Wl,--gc-sections

# Link-time optimization (LTO)
gcc -flto program.c

# Dead code elimination
gcc -Wl,--as-needed  # Only link needed libraries
```

### 6.8.4 Security Flags

```bash
# Enable RELRO (read-only relocations)
gcc -Wl,-z,relro program.c

# Full RELRO (eager binding + read-only GOT)
gcc -Wl,-z,relro,-z,now program.c

# Non-executable stack
gcc -Wl,-z,noexecstack program.c
```

## 6.9 Linker Errors and Solutions

### 6.9.1 Undefined Reference

```
undefined reference to `symbol_name'
```

**Causes**:
- Forgot to link a library
- Misspelled symbol name
- Symbol is static in another file
- C++ name mangling mismatch

**Solutions**:
```bash
# Add missing library
gcc program.c -lmissinglib

# For C++ code, use extern "C"
extern "C" void c_function();

# Check if symbol exists
nm library.a | grep symbol_name
```

### 6.9.2 Multiple Definition

```
multiple definition of `symbol_name'
```

**Causes**:
- Symbol defined in multiple files
- Header defines variable (not just declares)

**Solutions**:
```c
// In header: declare only
extern int global_var;

// In one source file: define
int global_var = 10;

// Or use static for file-local
static int file_local_var = 10;
```

### 6.9.3 Cannot Find Library

```
cannot find -lmylib
```

**Solutions**:
```bash
# Add library path
gcc -L/path/to/lib program.c -lmylib

# Check library exists
find /usr -name "libmylib*"

# Check ldconfig cache
ldconfig -p | grep mylib
```

### 6.9.4 Library Not Found at Runtime

```
error while loading shared libraries: libmylib.so: cannot open shared object file
```

**Solutions**:
```bash
# Temporary: set LD_LIBRARY_PATH
LD_LIBRARY_PATH=/path/to/lib ./program

# Permanent: add to ldconfig
echo "/path/to/lib" | sudo tee /etc/ld.so.conf.d/mylib.conf
sudo ldconfig

# Or embed path in executable
gcc -Wl,-rpath,/path/to/lib program.c -lmylib
```

## 6.10 Build Systems and Linking

### 6.10.1 Make

```makefile
# Makefile
CC = gcc
CFLAGS = -Wall -g
LDFLAGS = -L./lib -lmylib

SRCS = main.c utils.c
OBJS = $(SRCS:.c=.o)
PROGRAM = myprogram

$(PROGRAM): $(OBJS)
    $(CC) $(OBJS) $(LDFLAGS) -o $(PROGRAM)

%.o: %.c
    $(CC) $(CFLAGS) -c $< -o $@

clean:
    rm -f $(OBJS) $(PROGRAM)
```

### 6.10.2 CMake

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.10)
project(MyProject)

add_executable(myprogram main.c utils.c)

# Link library
target_link_libraries(mylib mylib)

# Add library path
link_directories(./lib)

# Add compile options
target_compile_options(myprogram PRIVATE -Wall -g)
```

## 6.11 Key Takeaways

1. **Linkers combine object files**: They resolve symbols and apply relocations.

2. **Symbol resolution matches references to definitions**: Strong symbols override weak ones; duplicates cause errors.

3. **Relocation adjusts addresses**: Object files start at 0; linker computes final addresses.

4. **Static linking embeds libraries**: Self-contained but larger; updates require recompilation.

5. **Dynamic linking defers to runtime**: Smaller, updatable, but with runtime overhead.

6. **Order matters for static libraries**: Libraries should come after files that use them.

7. **Linker scripts control layout**: They specify section addresses and ordering.

8. **Many linker flags optimize and secure**: LTO, garbage collection, RELRO, etc.

## 6.12 Looking Ahead

With linking complete, we have an executable ready to run. But where do the standard library functions come from? In Chapter 7, we'll explore static and dynamic libraries in depth, learning how to create, use, and manage them.

## Further Reading

- "Linkers and Loaders" by John Levine (the definitive reference)
- "Beginner's Guide to Linkers" by Ian Lance Taylor
- GNU ld documentation: https://sourceware.org/binutils/docs/ld/
- System V ABI: https://refspecs.linuxbase.org/elf/gabi4+/contents.html
- man pages: ld(1), objdump(1), readelf(1), dlopen(3)
