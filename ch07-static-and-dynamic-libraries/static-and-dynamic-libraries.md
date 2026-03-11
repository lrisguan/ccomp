# Chapter 7: Static and Dynamic Libraries

## Introduction

In Chapter 6, we learned how the linker combines object files into a single executable by resolving symbols and applying relocations. But what happens when you want to reuse code across multiple programs? Must every program contain a complete copy of all the code it uses?

This chapter explores **libraries**—collections of compiled object files that can be linked into multiple programs. We'll examine two fundamentally different approaches: **static libraries** (`.a` files) that are copied into the executable at link time, and **dynamic libraries** (`.so` files) that are loaded at runtime.

Understanding the difference between static and dynamic linking is crucial for:
- **Binary distribution**: Deciding whether to ship dependencies with your application
- **Security updates**: Understanding how library updates (or lack thereof) affect your programs
- **Performance**: Balancing startup time, memory usage, and execution speed
- **Cross-platform compatibility**: Ensuring your code runs across different systems

## 7.1 The Problem Libraries Solve

Imagine you're developing multiple applications that all need common functionality—say, mathematical operations, string handling, or file I/O. Without libraries, you'd have three bad options:

1. **Copy source code** into each project (maintenance nightmare)
2. **Copy object files** into each project (wastes disk space)
3. **Manually link the right object files** each time (error-prone)

Libraries solve all these problems by providing a packaged collection of object files that can be easily linked into any program.

**Example scenario**: You've written useful math functions:

```c
// math_utils.c
int add(int a, int b) { return a + b; }
int multiply(int a, int b) { return a * b; }
int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}
```

You want to use these functions in multiple programs. Let's see how both static and dynamic libraries make this possible.

## 7.2 Static Libraries (.a files)

### 7.2.1 What is a Static Library?

A **static library** is simply an archive (collection) of object files, typically with the `.a` extension. When you link against a static library, the linker **extracts** the object files containing the symbols you reference and **copies** them into your executable.

Think of a static library like a ZIP file of object files—the linker can open it, pull out what it needs, and ignore the rest.

**Key characteristics**:
- **File extension**: `.a` (archive) on Unix-like systems, `.lib` on Windows
- **Link time**: Symbols are resolved at link time (during compilation)
- **Runtime**: No external dependencies; the executable is self-contained
- **Size**: Larger binaries because all needed code is included

### 7.2.2 Creating a Static Library

Let's create a static library from our math utilities:

```bash
# Step 1: Compile source files to object files
gcc -c math_utils.c -o math_utils.o

# Step 2: Create a static library using ar (archiver)
ar rcs libmathutils.a math_utils.o
```

The `ar` command options:
- `r`: Insert (replace) files into the archive
- `c`: Create the archive if it doesn't exist
- `s`: Write an object file index into the archive

The resulting `libmathutils.a` contains the compiled code from `math_utils.o`. The `lib` prefix and `.a` extension are conventions—the linker expects libraries to follow this naming pattern.

**Multiple object files in one library**:

```bash
# Compile multiple source files
gcc -c math_utils.c -o math_utils.o
gcc -c string_utils.c -o string_utils.o
gcc -c file_utils.c -o file_utils.o

# Create a library with all of them
ar rcs libutils.a math_utils.o string_utils.o file_utils.o
```

Now `libutils.a` contains three object files that can be selectively linked.

### 7.2.3 Using a Static Library

To use a static library in your program:

```c
// main.c
#include <stdio.h>

// Forward declarations (typically in a header file)
int add(int a, int b);
int multiply(int a, int b);
int factorial(int n);

int main(void) {
    printf("5 + 3 = %d\n", add(5, 3));
    printf("5 * 3 = %d\n", multiply(5, 3));
    printf("5! = %d\n", factorial(5));
    return 0;
}
```

Compile and link with the static library:

```bash
gcc main.c -o main -L. -lmathutils
```

The linker flags:
- `-L.`: Add the current directory (`.`) to the library search path
- `-lmathutils`: Link against `libmathutils.a` (the `lib` prefix and `.a` extension are implied)

**What the linker does**:
1. Reads `main.o` and finds undefined symbols: `add`, `multiply`, `factorial`
2. Searches libraries in order for these symbols
3. Finds them in `libmathutils.a`
4. Extracts the necessary object files from the archive
5. Copies the code into the final executable
6. Resolves all relocations

The resulting `main` executable is completely self-contained—it needs no external files to run.

### 7.2.4 Static Library Internals: The Symbol Index

When we created the archive with `ar rcs`, the `s` option created a **symbol index** that makes linking much faster. Without this index, the linker would have to scan every object file in the archive to find symbols. With the index, the linker can quickly look up which object file contains each needed symbol.

Let's examine the archive structure:

```bash
# List the contents of the archive
ar t libmathutils.a

# Display the symbol table (index)
nm -s libmathutils.a

# Or use objdump to see detailed information
objdump -a libmathutils.a
```

Typical output:
```
Archive index:

add in math_utils.o
multiply in math_utils.o
factorial in math_utils.o
```

This index tells the linker exactly which object file contains each symbol.

### 7.2.5 The "Extract Only What's Needed" Rule

A crucial property of static linking: **the linker only extracts object files that contain referenced symbols**.

Example: If `libutils.a` contains `math_utils.o`, `string_utils.o`, and `file_utils.o`, and your program only calls functions from `math_utils.o`, then only that object file is included in your executable.

```c
// main2.c - only uses math functions
int main(void) {
    return add(1, 2);  // Only references 'add'
}
```

Linking this program:
```bash
gcc main2.c -o main2 -L. -lutils
```

The linker:
1. Sees reference to `add`
2. Looks up `add` in the library index
3. Finds `add` in `math_utils.o`
4. Extracts only `math_utils.o` from `libutils.a`
5. Ignores `string_utils.o` and `file_utils.o`

This selective linking keeps binary size manageable.

> **Warning**: If an object file in a static library references symbols from another object file in the same library, the linker will include both. This is why careful library organization matters—group related functions together in the same source file.

### 7.2.6 Advantages and Disadvantages of Static Libraries

**Advantages**:
1. **Self-contained executables**: No runtime dependencies; easier to distribute
2. **Predictable behavior**: You know exactly which version of library code you're using
3. **Simpler deployment**: Just copy one file
4. **Faster startup**: No dynamic linking overhead at program start
5. **Better performance**: No position-independent code overhead; more optimization opportunities

**Disadvantages**:
1. **Larger binaries**: Every program contains its own copy of library code
2. **Disk space waste**: If 10 programs use the same library, that code exists 10 times on disk
3. **Memory inefficiency**: If 10 programs using the same library run simultaneously, the library code occupies memory 10 times
4. **Security updates difficult**: To fix a bug in library code, you must recompile all programs using that library
5. **No sharing**: No way for multiple programs to share library code in memory

## 7.3 Dynamic Libraries (.so files)

### 7.3.1 What is a Dynamic Library?

A **dynamic library** (also called a **shared library** or **shared object**) is compiled code that can be loaded by multiple programs at runtime. Instead of copying library code into each executable, the operating system loads the dynamic library once and shares it among all running programs that need it.

**Key characteristics**:
- **File extension**: `.so` (shared object) on Unix-like systems, `.dll` (dynamic-link library) on Windows, `.dylib` on macOS
- **Link time**: Symbols are resolved at link time, but the library isn't included in the executable
- **Runtime**: The dynamic linker loads the library when the program starts (or on first use)
- **Size**: Smaller binaries because library code is not included

### 7.3.2 Creating a Dynamic Library

Creating a dynamic library requires special compilation options to ensure the code can be loaded at any memory address:

```bash
# Compile with Position-Independent Code (PIC) flag
gcc -fPIC -c math_utils.c -o math_utils.o

# Create a shared library
gcc -shared -o libmathutils.so math_utils.o
```

The critical flags:
- `-fPIC`: Generate **position-independent code** (PIC). This allows the code to be loaded at any memory address.
- `-shared`: Tells the linker to produce a shared library instead of an executable

**Why Position-Independent Code?**

Static libraries are linked at a fixed address known at link time. But dynamic libraries must be capable of being loaded at different addresses in different processes, because the address space layout varies depending on what other libraries are loaded.

PIC achieves this through:
- **Relative addressing**: Using relative jumps and calls instead of absolute addresses
- **GOT (Global Offset Table)**: A table of pointers to external data
- **PLT (Procedure Linkage Table)**: Indirect jumps for external function calls

We'll explore GOT and PLT in detail in section 7.4.

**Creating a library from multiple source files**:

```bash
# Compile multiple source files with PIC
gcc -fPIC -c math_utils.c -o math_utils.o
gcc -fPIC -c string_utils.c -o string_utils.o
gcc -fPIC -c file_utils.c -o file_utils.o

# Create shared library
gcc -shared -o libutils.so math_utils.o string_utils.o file_utils.o
```

### 7.3.3 Using a Dynamic Library

Using a dynamic library looks similar to using a static library from the programmer's perspective:

```bash
gcc main.c -o main -L. -lmathutils
```

But the resulting executable is fundamentally different:

```bash
# Check the dynamic library dependencies
ldd main
```

Typical output:
```
    linux-vdso.so.1 (0x00007ffc12345000)
    libmathutils.so => ./libmathutils.so (0x00007f8b4a1b2000)
    libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f8b49fe0000)
    /lib64/ld-linux-x86-64.so.2 (0x00007f8b4a3b5000)
```

The `ldd` command shows which shared libraries our executable depends on. Notably:
- `libmathutils.so` is listed as a dependency
- The executable doesn't contain the library code—it just has a reference to it

When we run `./main`:
1. The operating system's **dynamic linker** (`ld-linux.so`) runs first
2. It reads the executable's list of needed shared libraries
3. It loads each required library into memory
4. It resolves all symbol references between the executable and libraries
5. Finally, it transfers control to the program's `main` function

### 7.3.4 Library Search Paths

The dynamic linker needs to find the `.so` files at runtime. It searches in this order:

1. **RPATH/RUNPATH**: Embedded in the executable (specified with `-Wl,-rpath` during compilation)
2. **LD_LIBRARY_PATH**: Environment variable (colon-separated list of directories)
3. **Trusted system directories**: `/lib`, `/usr/lib`, and others configured in `/etc/ld.so.conf`

Example with RPATH:
```bash
gcc main.c -o main -L. -lmathutils -Wl,-rpath,/path/to/libs
```

Example with LD_LIBRARY_PATH:
```bash
export LD_LIBRARY_PATH=/path/to/libs:$LD_LIBRARY_PATH
./main
```

For system-wide installation:
```bash
sudo cp libmathutils.so /usr/local/lib/
sudo ldconfig  # Update the linker cache
```

## 7.4 Dynamic Linking Internals: PLT and GOT

### 7.4.1 The Problem of Address Resolution

When a dynamically linked program calls a library function, how does it know where that function lives in memory? The address isn't known at compile time because:
1. The library might be loaded at different addresses in different runs (due to ASLR)
2. The library might be updated to a different version

The solution involves two data structures: **PLT** (Procedure Linkage Table) and **GOT** (Global Offset Table).

### 7.4.2 PLT: Procedure Linkage Table

The PLT is a table of **stubs**—small pieces of code that jump to the actual function. Each external function has an entry in the PLT.

When your code calls a library function like `printf`, it actually jumps to the PLT entry for `printf`.

**PLT structure**:
```
┌─────────────────────────────────────────────────────────────┐
│                    Procedure Linkage Table                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PLT[0]: PLT resolver entry (special entry)                 │
│  ┌──────────────────────────────────────┐                   │
│  │  Jump to dynamic linker              │                   │
│  │  (uses GOT[0] and GOT[1])            │                   │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  PLT[1]: printf entry                                       │
│  ┌──────────────────────────────────────┐                   │
│  │  *Jump to address in GOT[printf]*    │ ← First call      │
│  │  Push relocation offset              │   goes to GOT     │
│  │  Jump to PLT resolver (PLT[0])       │                   │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  PLT[2]: scanf entry                                        │
│  ┌──────────────────────────────────────┐                   │
│  │  Jump to address in GOT[scanf]       │                   │
│  │  Push relocation offset              │                   │
│  │  Jump to PLT resolver (PLT[0])       │                   │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  PLT[3]: malloc entry ...                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 7.4.3 GOT: Global Offset Table

The GOT is a table of **addresses**—pointers to the actual locations of external symbols. Each PLT entry has a corresponding GOT entry.

**GOT structure**:
```
┌─────────────────────────────────────────────────────────────┐
│                     Global Offset Table                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  GOT[0]: Address of link map structure (special entry)      │
│  ┌──────────────────────────────────────┐                   │
│  │  Pointer to runtime linker data      │                   │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  GOT[1]: Linker's identity (special entry)                  │
│  ┌──────────────────────────────────────┐                   │
│  │  Pointer to dynamic linker           │                   │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  GOT[2]: Address of printf (initially points back to PLT)   │
│  ┌──────────────────────────────────────┐                   │
│  │  [Before resolution]: &PLT[1] + 6    │ ← Loop back       │
│  │  [After resolution]: &printf in libc │   to resolver     │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  GOT[3]: Address of scanf                                   │
│  ┌──────────────────────────────────────┐                   │
│  │  [Before resolution]: &PLT[2] + 6    │                   │
│  │  [After resolution]: &scanf in libc  │                   │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  GOT[4]: Address of malloc ...                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 7.4.4 Lazy Binding: The First Call

Modern systems use **lazy binding** to optimize startup time. Library functions aren't resolved until they're actually called. Here's what happens on the first call to `printf`:

1. **Your code** calls `printf`
2. **Actually calls** `PLT[printf]` (the PLT entry)
3. **PLT entry** jumps to the address in `GOT[printf]`
4. **Initially**, `GOT[printf]` points back to the PLT resolver (specifically, `PLT[0]`)
5. **PLT resolver** runs and:
   - Identifies which symbol needs resolution (`printf`)
   - Asks the dynamic linker to find the real address of `printf` in libc
   - Writes that address into `GOT[printf]`
   - Jumps to the real `printf`
6. **Future calls** to `printf` jump directly from PLT to the real address via GOT (no resolver needed)

This is called **lazy binding** because resolution happens "lazily"—only when needed.

Let's visualize the process:

```
First call to printf:

Your code
    │
    v
PLT[printf]: "Jump to *GOT[printf]"
    │
    v
GOT[printf]: "Go to PLT resolver" (initially)
    │
    v
PLT resolver: "I need to find printf"
    │
    v
Dynamic linker: "printf is at 0x7f8b4a2b3120"
    │
    v
GOT[printf] updated to: 0x7f8b4a2b3120
    │
    v
Jump to printf at 0x7f8b4a2b3120

Subsequent calls:

Your code -> PLT[printf] -> GOT[printf] -> printf (direct!)
```

### 7.4.5 Observing PLT and GOT

You can examine the PLT and GOT using various tools:

```bash
# Compile a program that uses library functions
gcc -o demo demo.c -L. -lmathutils

# Examine the PLT
objdump -d -j .plt demo

# Examine the GOT
objdump -d -j .got demo
objdump -d -j .got.plt demo

# See relocation entries (what will be resolved)
readelf -r demo
```

## 7.5 Static vs Dynamic Libraries: Tradeoffs

### 7.5.1 Binary Size Comparison

Let's compare executable sizes with actual numbers:

**Static linking**:
```bash
gcc -o main_static main.c libmathutils.a
ls -lh main_static
# Output: -rwxr-xr-x 1 user user 872K Jan 10 10:00 main_static
```

**Dynamic linking**:
```bash
gcc -o main_dynamic main.c -lmathutils
ls -lh main_dynamic
# Output: -rwxr-xr-x 1 user user 16K Jan 10 10:00 main_dynamic
```

The dynamically linked executable is **much smaller** because it doesn't contain the library code.

### 7.5.2 Startup Time Comparison

**Static linking**: Faster startup (no dynamic linking overhead)

**Dynamic linking**: Slower startup due to:
1. Loading and parsing the executable
2. Loading required shared libraries
3. Resolving symbols (at least for non-lazy-bound functions)

However, this difference is usually imperceptible for small programs.

### 7.5.3 Memory Usage When Running Multiple Programs

This is where dynamic libraries really shine:

**Scenario**: 10 programs using the same library

**Static linking**:
```
Process 1: [code] [library copy] [stack] [heap]  = 10 MB
Process 2: [code] [library copy] [stack] [heap]  = 10 MB
...
Process 10: [code] [library copy] [stack] [heap] = 10 MB
────────────────────────────────────────────────────
Total memory: 100 MB (library loaded 10 times)
```

**Dynamic linking**:
```
Process 1:  [code] [stack] [heap]  = 6 MB
Process 2:  [code] [stack] [heap]  = 6 MB
...
Process 10: [code] [stack] [heap]  = 6 MB
[Shared library in memory once]    = 4 MB
────────────────────────────────────────────
Total memory: 64 MB (library loaded once)
```

The dynamically linked version uses **36% less memory** in this example!

### 7.5.4 Security and Updates

**Static linking**:
- Library bugs require recompiling all affected programs
- No risk of library incompatibility (you ship the exact version you tested with)
- Example: If `libssl` has a security flaw, you must rebuild every program linked against it

**Dynamic linking**:
- Update the library file once, all programs benefit
- Risk of library version incompatibility
- Example: Update `libssl.so` once, all programs using it are fixed

### 7.5.5 Portability and Distribution

**Static linking**:
- Easier to distribute single binary
- Works even if target system lacks required libraries
- Popular in embedded systems, containers, and application distribution (e.g., static Go binaries)

**Dynamic linking**:
- Must ensure library is present on target system
- Or ship libraries alongside executable
- Common in package manager systems (APT, RPM, etc.)

## 7.6 Versioning and Symbol Visibility

### 7.6.1 The Versioning Problem

When you update a dynamic library, you must ensure existing programs don't break. This is the **ABI compatibility problem**:

**Safe changes** (backward compatible):
- Adding new functions
- Fixing bugs without changing behavior
- Adding new global symbols

**Unsafe changes** (breaking):
- Removing functions
- Changing function signatures
- Changing data structure layouts
- Changing the size or layout of global variables

### 7.6.2 Symbol Versioning in ELF

ELF shared libraries support **symbol versioning** to allow multiple versions of a function to coexist:

```
libfoo.so.1
├── foo@GLIBC_2.2.5    (old version)
├── foo@GLIBC_2.17     (newer, optimized version)
└── bar@GLIBC_2.2.5
```

Programs compiled against older versions continue to use the old version, while newly compiled programs use the new version.

Example from glibc:
```bash
# View symbol versions in libc
nm -D /lib/x86_64-linux-gnu/libc.so.6 | grep " memcpy"
```

Output:
```
000000000008c810 T memcpy@@GLIBC_2.2.5
```

The `@@` indicates this is the **default** version.

### 7.6.3 Controlling Symbol Visibility

Not all functions in a library should be visible to users. Use **visibility attributes** to control the public interface:

```c
// Internal functions - hidden from users
static int internal_helper(int x) {
    return x * 2;
}

// Public API - visible to users
__attribute__((visibility("default")))
int public_function(int x) {
    return internal_helper(x);
}
```

Compile with:
```bash
gcc -fPIC -c mylib.c -fvisibility=hidden
gcc -shared -o libmylib.so mylib.o
```

The `-fvisibility=hidden` flag makes all symbols hidden by default, requiring explicit `__attribute__((visibility("default")))` for public API functions.

Benefits:
- Smaller symbol tables (faster linking)
- Enforced API boundaries (can't accidentally use internal functions)
- Better optimization (compiler can inline hidden functions)

## 7.7 Common Linking Problems and Solutions

### 7.7.1 Undefined Reference

**Problem**:
```
undefined reference to `add'
```

**Causes**:
- Library not specified on link line
- Library specified in wrong order
- Library doesn't actually contain the symbol

**Solution**:
```bash
# Put libraries AFTER the object files that need them
gcc main.o -o main -L. -lmathutils  # Correct
gcc -L. -lmathutils main.o -o main  # Wrong on some systems!
```

The linker processes files left-to-right and only keeps symbols it has seen. If `-lmathutils` comes before `main.o`, the linker hasn't seen `main.o`'s undefined symbols yet, so it doesn't extract anything from the library.

### 7.7.2 Multiple Definition

**Problem**:
```
multiple definition of 'add'
```

**Causes**:
- Two object files define the same symbol
- Both static and dynamic libraries define the same symbol

**Solution**:
- Ensure each symbol is defined in only one place
- Use `-Wl,--allow-multiple-definition` (not recommended) as last resort
- Check for accidentally linking the same library twice

### 7.7.3 Library Not Found at Runtime

**Problem**:
```
error while loading shared libraries: libmathutils.so: cannot open shared object file
```

**Causes**:
- Library not in standard search paths
- LD_LIBRARY_PATH not set
- RPATH not set correctly

**Solutions**:
```bash
# Option 1: Use LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/path/to/libs:$LD_LIBRARY_PATH

# Option 2: Use RPATH during compilation
gcc main.c -o main -L/path/to/libs -lmathutils -Wl,-rpath,/path/to/libs

# Option 3: Install to system directory
sudo cp libmathutils.so /usr/local/lib/
sudo ldconfig
```

### 7.7.4 Wrong Library Version

**Problem**: Program works on one system but fails on another.

**Cause**: Different library versions (ABI incompatibility)

**Solution**: Use static linking or ensure consistent library versions across systems.

## 7.8 Practical Decision Guide: Static or Dynamic?

When should you use static linking? When should you use dynamic linking?

### Use Static Linking When:
- Distributing to systems with unknown library availability
- Building embedded systems with limited external dependencies
- Creating containers or appliances that need to be self-contained
- Maximum performance is critical (no PLT/GOT indirection)
- You need to guarantee exact library versions

### Use Dynamic Linking When:
- Multiple programs on the system use the same library (save memory)
- Security updates need to be applied without recompilation
- You're building for a standard Linux distribution environment
- You want smaller binary sizes
- You're building a library for others to use

### Hybrid Approach:
Some programs use a mix—static linking for certain dependencies and dynamic for others:

```bash
# Link statically against libfoo, dynamically against everything else
gcc main.c -o main -l:libfoo.a -lbar -lbaz
```

The `-l:` syntax tells the linker to use a specific file rather than searching for `libfoo.so` or `libfoo.a`.

## 7.9 Key Takeaways

1. **Static libraries (.a) are archives of object files**: The linker extracts only the object files containing referenced symbols and copies them into the executable. This produces self-contained but larger binaries.

2. **Dynamic libraries (.so) are loaded at runtime**: The executable contains references to shared libraries, which are loaded by the dynamic linker when the program starts. This produces smaller binaries and allows code sharing.

3. **Position-independent code (PIC) enables dynamic libraries**: The `-fPIC` flag generates code that can execute correctly regardless of its memory address, essential for shared libraries.

4. **PLT and GOT enable dynamic symbol resolution**: The Procedure Linkage Table contains stub code for external functions, while the Global Offset Table contains their actual addresses. Lazy binding defers resolution until first call for efficiency.

5. **Static linking: larger binaries, faster startup, simpler deployment**: Best for embedded systems, containers, and when library availability is uncertain.

6. **Dynamic linking: smaller binaries, memory efficient, easier updates**: Best for standard desktop/server environments where multiple programs share libraries.

7. **Symbol order matters in static linking**: On Unix-like systems, place libraries AFTER the object files that reference them on the link line.

8. **Versioning maintains ABI compatibility**: Symbol versioning allows libraries to evolve without breaking existing programs, with multiple versions of functions coexisting.

9. **Visibility control enforces API boundaries**: Use `-fvisibility=hidden` and `__attribute__((visibility("default")))` to explicitly define the public API of a library.

10. **Choose the right linking strategy for your use case**: Consider deployment environment, update requirements, memory constraints, and performance needs when deciding between static and dynamic linking.

## 7.10 Looking Ahead

In Chapter 8, we'll explore the **C standard library** and its relationship to the operating system. We'll distinguish between library functions (user-space code) and **system calls** (kernel boundary crossings), understanding how the standard library wraps raw system calls to provide the familiar C API we use every day.

## Further Reading

- "Linkers and Loaders" by John R. Levine - Comprehensive treatment of linking and loading
- "Program Library HOWTO" by David A. Wheeler - Practical guide to creating and using libraries
- ELF specification: Tool Interface Standard (TIS) Executable and Linking Format (ELF)
- `man ld.so` - The dynamic linker/ loader manual
- `man ld` - The linker manual
