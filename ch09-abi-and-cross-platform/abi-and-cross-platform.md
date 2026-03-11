# Chapter 9: ABI and Cross-Platform Compilation

## Introduction

We've seen how C code is compiled, linked, and executed. But what happens when you need to run your compiled binary on a different machine with a different CPU architecture or operating system? Why can't you just copy the binary and run it?

This chapter explores **ABI (Application Binary Interface)**—the set of conventions that enable binary code to work together at the machine level. Unlike API (source-level compatibility), ABI is about binary compatibility: how functions are called, how data is laid out in memory, and how the operating system expects programs to behave.

Understanding ABI is crucial for:
- **Cross-platform development**: Writing code that compiles and runs correctly on different platforms
- **Cross-compilation**: Building binaries for one architecture on another
- **Library development**: Creating libraries that work across different compilers and platforms
- **Debugging**: Understanding mysterious crashes when mixing code from different sources

## 9.1 What is an ABI?

An **Application Binary Interface (ABI)** is a contract between compiled code components that specifies:

1. **Calling convention**: How functions call each other (argument passing, return values, stack cleanup)
2. **Data representation**: Size and alignment of data types
3. **Register usage**: Which registers are preserved vs. volatile
4. **Object file format**: ELF, PE, Mach-O, etc.
5. **System call interface**: How to request kernel services
6. **Runtime behavior**: Stack layout, exception handling, initialization

**ABI vs. API**:

- **API (Application Programming Interface)**: Source-level interface
  - Defines function names, parameters, return types
  - Enables recompilation with different compilers/languages
  - Example: C header files

- **ABI (Application Binary Interface)**: Binary-level interface
  - Defines binary representation and calling conventions
  - Enables linking code compiled by different compilers
  - Example: System V AMD64 ABI

> **Key insight**: API compatibility means you can recompile the code. ABI compatibility means you can link the binaries directly without recompilation.

## 9.2 Components of an ABI

### 9.2.1 Data Type Representation

ABIs specify the size and representation of fundamental data types:

**Example: x86-64 Linux (LP64)**

| Type | Size | Alignment | Notes |
|------|------|-----------|-------|
| `char` | 1 byte | 1 | - |
| `short` | 2 bytes | 2 | - |
| `int` | 4 bytes | 4 | - |
| `long` | 8 bytes | 8 | Longs are 64-bit! |
| `long long` | 8 bytes | 8 | - |
| `void*` | 8 bytes | 8 | Pointers are 64-bit |
| `float` | 4 bytes | 4 | IEEE 754 single |
| `double` | 8 bytes | 8 | IEEE 754 double |

**Example: x86 (32-bit) Linux (ILP32)**

| Type | Size | Alignment | Notes |
|------|------|-----------|-------|
| `char` | 1 byte | 1 | - |
| `short` | 2 bytes | 2 | - |
| `int` | 4 bytes | 4 | - |
| `long` | 4 bytes | 4 | Longs are 32-bit! |
| `long long` | 8 bytes | 4 | - |
| `void*` | 4 bytes | 4 | Pointers are 32-bit |

**Naming schemes**:
- **ILP32**: int, long, pointer are 32-bit
- **LP64**: long and pointer are 64-bit (int is 32-bit)
- **LLP64**: long long and pointer are 64-bit (Windows x64)

These differences mean code that works on 32-bit systems may break on 64-bit systems!

**Problem example**:
```c
// Problematic code that assumes int == pointer
int i = (int)malloc(100);  // Truncates pointer on 64-bit!
```

### 9.2.2 Structure Layout and Alignment

ABIs specify how structures are laid out in memory, including padding for alignment.

**Example structure**:
```c
struct Example {
    char c;     // 1 byte
    int i;      // 4 bytes, requires 4-byte alignment
    short s;    // 2 bytes
    void *p;    // 8 bytes on 64-bit, requires 8-byte alignment
};
```

**Layout on x86-64 (LP64)**:
```
Offset  Field     Size    Notes
------  -----     ----    -----
0       c         1       -
1-3     padding   3       Pad to align i to 4 bytes
4       i         4       -
8       s         2       -
10-15   padding   6       Pad to align p to 8 bytes
16      p         8       -

Total size: 24 bytes
```

**Why padding?**

CPUs access memory more efficiently when data is aligned to natural boundaries:
- 4-byte int should start at address divisible by 4
- 8-byte pointer should start at address divisible by 8

Misaligned access may:
- Work but be slower (x86-64)
- Crash with alignment fault (some ARM architectures)
- Require multiple memory accesses

**Checking structure layout**:
```bash
# Use pahole to show structure holes
pahole your_program

# Or manually with gcc
gcc -c struct_test.c
objdump -t -C struct_test.o | grep Example
```

### 9.2.3 Calling Conventions

ABIs define how functions call each other—where arguments go, where return values go, who cleans the stack.

**System V AMD64 ABI (Linux/Unix x86-64)**:

Arguments (in order):
1. RDI, RSI, RDX, RCX, R8, R9 (first 6 integer/pointer arguments)
2. XMM0-XMM7 (first 8 floating-point arguments)
3. Stack (remaining arguments)

Return value:
- Integer/pointer: RAX
- Floating-point: XMM0
- Large structs: Hidden pointer parameter

**Microsoft x64 ABI (Windows x64)**:

Arguments (in order):
1. RCX, RDX, R8, R9 (first 4 arguments)
2. Stack (remaining arguments)

Return value:
- RAX (integer/pointer)
- XMM0 (floating-point)

**Key difference**: Different registers for arguments! This is why you can't link object files between Windows and Linux.

**Example**:
```c
int add(int a, int b, int c, int d, int e, int f, int g);
```

**Linux x86-64**:
- a → RDI, b → RSI, c → RDX, d → RCX, e → R8, f → R9, g → stack

**Windows x64**:
- a → RCX, b → RDX, c → R8, d → R9, e → stack, f → stack, g → stack

### 9.2.4 Register Preservation

ABIs define which registers must be preserved across function calls:

**Caller-saved (volatile)**:
- Function can modify these; caller must save if needed
- x86-64 System V: RAX, RCX, RDX, RSI, RDI, R8-R11
- Windows x64: RAX, RCX, RDX, R8-R11

**Callee-saved (non-volatile)**:
- Function must restore these before returning
- x86-64 System V: RBX, RBP, R12-R15
- Windows x64: RBX, RBP, RDI, RSI, R12-R15

## 9.3 Architecture-Specific ABIs

### 9.3.1 x86-64 (AMD64)

**Common ABIs**:
- **System V AMD64 ABI**: Linux, BSD, macOS (with modifications)
- **Microsoft x64 ABI**: Windows

**Key features**:
- 16 general-purpose registers (RAX-R15)
- 16 SSE registers (XMM0-XMM15)
- 64-bit virtual address space
- Variable-length stacks

### 9.3.2 AArch64 (ARM64)

**Key features**:
- 31 general-purpose registers (X0-X30, plus SP)
- 32 SIMD/FP registers (V0-V31)
- 64-bit Little Endian (LE) by default
- **AArch64 Procedure Call Standard (AAPCS64)**

**Argument passing**:
- First 8 arguments: X0-X7 (or appropriate SIMD registers)
- Remaining: Stack

**Return value**: X0

**Callee-saved**: X19-X29, SP

### 9.3.3 RISC-V

**Key features**:
- 32 general-purpose registers (x0-x31)
- Clean, orthogonal design
- **RISC-V ABI** specification

**Argument passing**:
- First 8 arguments: a0-a7 (x10-x17)
- Return values: a0-a1 (x10-x11)

## 9.4 Cross-Platform Considerations

### 9.4.1 Endianness

Different architectures may use different byte ordering:

**Little-endian** (x86, x86-64, ARM, RISC-V):
- Least significant byte at lowest address
- `0x12345678` stored as `78 56 34 12`

**Big-endian** (some older architectures, network protocols):
- Most significant byte at lowest address
- `0x12345678` stored as `12 34 56 78`

**Problem**: Binary data files may not be portable across architectures!

**Solution**: Use explicit byte ordering functions:
```c
// Host to network byte order (big-endian)
uint32_t net_value = htonl(host_value);

// Network to host byte order
uint32_t host_value = ntohl(net_value);
```

### 9.4.2 Data Type Differences

**Problem**: `long` size varies

| Platform | sizeof(long) | sizeof(void*) |
|----------|--------------|---------------|
| Windows 32-bit | 4 | 4 |
| Windows 64-bit | 4 | 8 |
| Linux 32-bit | 4 | 4 |
| Linux 64-bit | 8 | 8 |

**Portable code**:
```c
// Bad: assumes long == pointer
printf("%lx\n", (long)ptr);

// Good: use standard types
#include <inttypes.h>
printf("0x%" PRIxPTR "\n", (uintptr_t)ptr);

// Or:
printf("%p\n", (void*)ptr);
```

**Fixed-width types**:
```c
#include <stdint.h>

int32_t i32;   // Exactly 32 bits, everywhere
uint64_t u64;  // Exactly 64 bits, everywhere
```

### 9.4.3 Structure Packing

Different compilers/platforms may pad structures differently!

**Solution**: Use explicit packing when needed:
```c
// Ensure specific layout
#pragma pack(push, 1)
struct Packed {
    char c;
    int i;
    short s;
};
#pragma pack(pop)

// Or use compiler-specific attributes
struct Packed {
    char c;
    int i;
    short s;
} __attribute__((packed));  // GCC/Clang
```

**Warning**: Packed structures may be slower to access and can cause alignment faults on some architectures!

## 9.5 Cross-Compilation

### 9.5.1 What is Cross-Compilation?

**Native compilation**: Build binaries for the same architecture/host
- x86-64 Linux → x86-64 Linux binary

**Cross-compilation**: Build binaries for a different architecture/host
- x86-64 Linux → ARM64 Linux binary
- x86-64 macOS → x86-64 Linux binary

### 9.5.2 Cross-Compilation Toolchains

A cross-compilation toolchain includes:
- **Cross-compiler**: gcc that generates code for target architecture
- **Cross-assembler**: as for target
- **Cross-linker**: ld for target
- **Sysroot**: Target system's headers and libraries

**Naming convention**: `{host}-{target}-{tool}`

Examples:
- `x86_64-linux-gnu-gcc`: Native compiler for x86-64 Linux
- `aarch64-linux-gnu-gcc`: Cross-compiler for ARM64 Linux (from x86-64 host)
- `x86_64-w64-mingw32-gcc`: Cross-compiler for Windows (from Linux host)

### 9.5.3 Installing Cross-Compilers

**Ubuntu/Debian**:
```bash
# ARM64 cross-compiler
sudo apt-get install gcc-aarch64-linux-gnu

# Windows cross-compiler
sudo apt-get install gcc-mingw-w64-x86-64

# Check installation
aarch64-linux-gnu-gcc --version
x86_64-w64-mingw32-gcc --version
```

**macOS**:
```bash
# Install cross-compilers via Homebrew
brew install aarch64-elf-gcc
brew install x86_64-elf-gcc
```

### 9.5.4 Cross-Compiling a Program

**Simple cross-compilation**:
```bash
# Compile for ARM64 instead of x86-64
aarch64-linux-gnu-gcc -o hello_arm64 hello.c

# Check the output file
file hello_arm64
# Output: ELF 64-bit LSB executable, ARM aarch64...

# It won't run on x86-64!
./hello_arm64
# bash: ./hello_arm64: cannot execute binary file

# But it works on ARM64 systems
scp hello_arm64 user@arm64-machine:~
```

**Specifying sysroot**:
```bash
# Use specific sysroot for target libraries
aarch64-linux-gnu-gcc --sysroot=/path/to/sysroot \
    -o hello_arm64 hello.c
```

## 9.6 ELF vs. PE vs. Mach-O

Different operating systems use different executable file formats:

### 9.6.1 ELF (Executable and Linkable Format)

**Used by**: Linux, most Unix-like systems, many embedded systems

**Structure**:
- **ELF header**: File type, architecture, entry point
- **Program headers**: Describe segments for runtime loader
- **Sections**: Code, data, symbols, etc.
- **Section headers**: Describe sections for linker

**File type**: `ELF 64-bit LSB executable, x86-64, version 1 (SYSV)`

### 9.6.2 PE (Portable Executable)

**Used by**: Windows

**Structure**:
- **DOS header**: Legacy DOS support
- **PE header**: File format information
- **Optional header**: Entry point, subsystem, etc.
- **Section headers**: Code, data, resources
- **Sections**: .text, .data, .rdata, etc.

**File type**: `PE32+ executable (console) x86-64, for MS Windows`

### 9.6.3 Mach-O

**Used by**: macOS, iOS

**Structure**:
- **Mach header**: File type, architecture, flags
- **Load commands**: Describe segments, dynamic linker info, etc.
- **Segments**: __TEXT, __DATA, __LINKEDIT, etc.
- **Sections**: within segments

**File type**: `Mach-O 64-bit executable x86_64`

## 9.7 Platform-Specific Challenges

### 9.7.1 Dynamic Library Naming

**Linux**: `libname.so`
- Example: `libc.so.6`, `libpthread.so.0`

**Windows**: `name.dll`
- Example: `msvcrt.dll`, `kernel32.dll`

**macOS**: `libname.dylib`
- Example: `libSystem.dylib`, `libc.dylib`

### 9.7.2 System Call Differences

Even on the same architecture, different operating systems have different system call interfaces:

**Linux x86-64**:
- write syscall: number 1
- Arguments: RDI (fd), RSI (buf), RDX (count)

**Windows x64**:
- Uses different system call numbers
- Different calling convention for syscalls
- Most code uses Win32 API (user-space DLLs) instead of direct syscalls

**Result**: You can't run Linux binaries on Windows (without emulation like WSL) and vice versa.

### 9.7.3 C Library Differences

**Linux**: Typically glibc
- ISO C + POSIX + Linux extensions

**macOS**: libSystem (includes libc)
- ISO C + POSIX + macOS-specific APIs
- Different function availability in some cases

**Windows**: msvcrt.dll or Universal CRT
- ISO C (mostly)
- Win32 API for system functionality
- Limited POSIX support via Cygwin/MSYS2

## 9.8 Practical Cross-Platform Development

### 9.8.1 Portable Data Types

Always use fixed-width types for binary data:

```c
#include <stdint.h>

struct BinaryFormat {
    uint32_t magic;      // Always 32 bits
    uint16_t version;     // Always 16 bits
    uint8_t flags;        // Always 8 bits
};
```

### 9.8.2 Pointer-Integer Conversion

Use proper types for pointer-integer conversion:

```c
// Bad: assumes size matches
int i = (int)ptr;

// Good: use standard types
intptr_t i = (intptr_t)ptr;
uintptr_t u = (uintptr_t)ptr;
```

### 9.8.3 Structure Alignment

Be explicit about structure layout when binary compatibility matters:

```c
// For network protocols or file formats
#pragma pack(push, 1)
struct NetworkPacket {
    uint8_t type;
    uint16_t length;
    uint32_t data;
};
#pragma pack(pop)
```

### 9.8.4 Conditional Compilation

Use preprocessor directives for platform-specific code:

```c
#if defined(__linux__)
    // Linux-specific code
    #include <unistd.h>
#elif defined(_WIN32)
    // Windows-specific code
    #include <windows.h>
#elif defined(__APPLE__)
    // macOS-specific code
    #include <sys/types.h>
#endif
```

**Common predefined macros**:
- `__linux__`: Linux
- `_WIN32`: Windows (32 or 64 bit)
- `_WIN64`: Windows 64-bit specifically
- `__APPLE__`: macOS/iOS
- `__GNUC__`: GCC/Clang
- `__SIZEOF_POINTER__`: Size of pointer

## 9.9 ABI Compatibility Examples

### 9.9.1 C++ Name Mangling

C++ uses name mangling to encode type information into function names. Different compilers may use different mangling schemes!

**Example function**:
```cpp
namespace foo {
    void bar(int);
}
```

**Mangled name (Itanium C++ ABI used by GCC/Clang)**:
```
_ZN3foo3barEi
```

**Problem**: You can't link C++ code compiled with GCC and code compiled with MSVC on Windows without special handling!

**Solution**: Use `extern "C"` for ABI-compatible interfaces:
```cpp
extern "C" {
    void c_compatible_function(int arg);
}
```

### 9.9.2 Symbol Versioning (ELF)

Libraries can provide multiple versions of a function for ABI compatibility:

```bash
# View symbol versions
nm -D /lib/x86_64-linux-gnu/libc.so.6 | grep memcpy
```

Output:
```
000000000008c810 T memcpy@@GLIBC_2.2.5
```

Programs compiled against older glibc versions continue to work with newer glibc because it maintains the old ABI.

### 9.9.3 C++ ABI Compatibility

C++ adds ABI complexity beyond C:

- **Object layout**: Vtables, inheritance
- **Exception handling**: Throwing across shared library boundaries
- **RTTI**: type_info objects
- **Name mangling**: Symbol encoding

**Result**: Mixing C++ libraries from different compilers is generally problematic!

## 9.10 Key Takeaways

1. **ABI is binary-level contract**: Unlike API (source-level), ABI defines how binaries interact—data layout, calling conventions, register usage.

2. **Data types vary by platform**: `long`, `void*`, and even `int` may have different sizes. Use fixed-width types (`int32_t`) for binary data.

3. **Structure layout matters**: Padding and alignment vary. Use `#pragma pack` only when necessary—packed structures may be slower.

4. **Calling conventions differ**: x86-64 System V (Linux) uses different argument registers than Microsoft x64 (Windows), preventing binary compatibility.

5. **Endianness affects data**: Little-endian and big-endian systems store multi-byte values differently. Use `htonl`/`ntohl` for network data.

6. **Cross-compilation requires toolchains**: Build binaries for different architectures using cross-compilers like `aarch64-linux-gnu-gcc`.

7. **Executable formats differ**: ELF (Linux), PE (Windows), and Mach-O (macOS) are incompatible at the binary level.

8. **C++ ABI is more complex**: Name mangling, exception handling, and object layout vary between compilers. Use `extern "C"` for stable interfaces.

9. **Sysroot provides target libraries**: Cross-compilation requires target system headers and libraries in a sysroot directory.

10. **Test on target platforms**: The only sure way to verify cross-platform compatibility is to test on each target architecture and OS.

## 9.11 Looking Ahead

In Chapter 10, we'll explore **process loading and memory layout**—how the operating system loads executables into memory and sets up the runtime environment. We'll examine virtual memory, memory segments, and the dynamic linker's role in program startup.

## Further Reading

- **System V AMD64 ABI** - https://gitlab.com/x86-psABIs/x86-64-ABI
- **Microsoft x64 Calling Convention** - MSDN Documentation
- **ARM Architecture Procedure Call Standard** - ARM Documentation
- **RISC-V ABI** - RISC-V Specification
- **ELF Specification** - Tool Interface Standard (TIS)
- "Linkers and Loaders" by John R. Levine - Chapter 7 covers ABI issues
- `man 2 syscall` - System call conventions
- `man 3 gcc` - GCC cross-compilation options
