# Experiment: Cross-compile a simple program

## Objective
- Build an AArch64 binary on an x86_64 host and inspect the output format.
- Examine calling conventions across platforms.
- Investigate data type sizes and structure layout.
- Understand endianness differences.

## Setup requirements
- Cross toolchain (for example, `aarch64-linux-gnu-gcc`).
- `file` utility available.
- `readelf`, `objdump` for binary inspection.

## Step-by-step commands

### Part 1: Basic Cross-Compilation

1. Write a simple program:
   ```c
   // hello.c
   #include <stdio.h>
   int main(void) {
       printf("Hello, cross-platform world!\n");
       return 0;
   }
   ```

2. Build for native architecture (x86-64):
   ```bash
   gcc -o hello_x86_64 hello.c
   ```

3. Cross-compile for ARM64:
   ```bash
   aarch64-linux-gnu-gcc -o hello_aarch64 hello.c
   ```

4. Inspect the binary types:
   ```bash
   file hello_x86_64 hello_aarch64
   ```

5. Try to run both:
   ```bash
   ./hello_x86_64    # Works on x86-64
   ./hello_aarch64   # Fails on x86-64: cannot execute binary file
   ```

### Part 2: Compare Assembly Output

6. Generate assembly for both architectures:
   ```bash
   gcc -S -o hello_x86_64.s hello.c
   aarch64-linux-gnu-gcc -S -o hello_aarch64.s hello.c
   ```

7. Compare the assembly:
   ```bash
   cat hello_x86_64.s
   cat hello_aarch64.s
   ```

8. Observe differences:
   - Different instruction sets (x86-64 vs. AArch64)
   - Different calling conventions
   - Different register names

### Part 3: Examine Data Type Sizes

9. Create a type size test program:
   ```c
   // typesize.c
   #include <stdio.h>

   int main(void) {
       printf("char       : %zu bytes\n", sizeof(char));
       printf("short      : %zu bytes\n", sizeof(short));
       printf("int        : %zu bytes\n", sizeof(int));
       printf("long       : %zu bytes\n", sizeof(long));
       printf("long long  : %zu bytes\n", sizeof(long long));
       printf("void*      : %zu bytes\n", sizeof(void*));
       printf("float      : %zu bytes\n", sizeof(float));
       printf("double     : %zu bytes\n", sizeof(double));

       // Check fixed-width types
       #include <stdint.h>
       printf("int32_t    : %zu bytes\n", sizeof(int32_t));
       printf("int64_t    : %zu bytes\n", sizeof(int64_t));

       return 0;
   }
   ```

10. Compile and run native:
    ```bash
    gcc -o typesize typesize.c
    ./typesize
    ```

11. Cross-compile and inspect (can't run directly):
    ```bash
    aarch64-linux-gnu-gcc -o typesize_aarch64 typesize.c
    readelf -a typesize_aarch64 | grep -A 20 "Section Headers"
    ```

12. Note: Both x86-64 and AArch64 use LP64, so type sizes are the same!

### Part 4: Structure Layout Comparison

13. Create a structure test:
    ```c
    // struct_test.c
    #include <stdio.h>
    #include <stddef.h>
    #include <stdint.h>

    struct Example {
        char c;
        int i;
        short s;
        void *p;
    };

    int main(void) {
        printf("Offset of c: %zu\n", offsetof(struct Example, c));
        printf("Offset of i: %zu\n", offsetof(struct Example, i));
        printf("Offset of s: %zu\n", offsetof(struct Example, s));
        printf("Offset of p: %zu\n", offsetof(struct Example, p));
        printf("Total size: %zu\n", sizeof(struct Example));
        return 0;
    }
   ```

14. Compile and compare:
    ```bash
    gcc -o struct_x86_64 struct_test.c && ./struct_x86_64
    aarch64-linux-gnu-gcc -o struct_aarch64 struct_test.c
    # Can't run directly, but structure layout should be identical
    ```

15. Verify structure layout is the same (both use LP64 ABI).

### Part 5: Calling Convention Comparison

16. Create a function call test:
    ```c
    // callconv.c
    int add_many(int a, int b, int c, int d, int e, int f, int g, int h) {
       return a + b + c + d + e + f + g + h;
   }

    int main(void) {
       return add_many(1, 2, 3, 4, 5, 6, 7, 8);
   }
   ```

17. Generate assembly:
    ```bash
    gcc -S -O0 -fno-asynchronous-unwind-tables -o call_x86_64.s callconv.c
    aarch64-linux-gnu-gcc -S -O0 -o call_aarch64.s callconv.c
    ```

18. Examine how arguments are passed:
    ```bash
    cat call_x86_64.s | grep -A 20 "add_many"
    cat call_aarch64.s | grep -A 20 "add_many"
    ```

**x86-64 System V ABI**:
- Arguments 1-6: RDI, RSI, RDX, RCX, R8, R9
- Arguments 7-8: Stack

**AArch64 ABI**:
- Arguments 1-8: X0, X1, X2, X3, X4, X5, X6, X7
- No stack arguments needed for this example!

### Part 6: Endianness Investigation

19. Create endianness test:
    ```c
    // endian.c
    #include <stdio.h>
    #include <stdint.h>

    int main(void) {
       uint32_t value = 0x12345678;
       uint8_t *bytes = (uint8_t *)&value;

       printf("uint32_t value: 0x%08x\n", value);
       printf("Byte 0: 0x%02x @ %p\n", bytes[0], &bytes[0]);
       printf("Byte 1: 0x%02x @ %p\n", bytes[1], &bytes[1]);
       printf("Byte 2: 0x%02x @ %p\n", bytes[2], &bytes[2]);
       printf("Byte 3: 0x%02x @ %p\n", bytes[3], &bytes[3]);

       if (bytes[0] == 0x78) {
           printf("System is: Little-endian\n");
       } else if (bytes[0] == 0x12) {
           printf("System is: Big-endian\n");
       }

       return 0;
    }
   ```

20. Compile and run:
    ```bash
    gcc -o endian endian.c && ./endian
    ```

21. Cross-compile for big-endian target (if toolchain supports):
    ```bash
    # Some ARM toolchains support big-endian
    # aarch64_be-linux-gnu-gcc -o endian_be endian.c
    ```

**Note**: Most modern systems use little-endian!

### Part 7: Object File Format Comparison

22. Examine ELF headers:
    ```bash
    readelf -h hello_x86_64
    readelf -h hello_aarch64
    ```

23. Compare machine type:
    - x86_64: Machine: 62 (Advanced Micro Devices X86-64)
    - aarch64: Machine: 183 (AArch64)

24. Examine program headers:
    ```bash
    readelf -l hello_x86_64
    readelf -l hello_aarch64
    ```

25. Observe: Both use ELF format, but with different machine types!

### Part 8: Cross-Compiling for Windows (optional)

26. If you have MinGW installed:
    ```bash
    # Install on Ubuntu/Debian
    sudo apt-get install gcc-mingw-w64-x86-64

    # Cross-compile for Windows
    x86_64-w64-mingw32-gcc -o hello.exe hello.c
    ```

27. Inspect the Windows executable:
    ```bash
    file hello.exe
    # Output: PE32+ executable (console) x86-64, for MS Windows
    ```

28. Note the file format: PE (not ELF)!

## Expected output explanation

### Part 1: Basic Cross-Compilation

**file output**:
```
hello_x86_64:  ELF 64-bit LSB executable, x86-64, version 1 (SYSV)...
hello_aarch64: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV)...
```

- Both use ELF format
- Different machine types: x86-64 vs. AArch64
- Cannot run ARM64 binary on x86-64 host

### Part 2: Assembly Comparison

**x86-64 assembly**:
```assembly
mov eax, 1   ; Move return value
ret          ; Return
```

**AArch64 assembly**:
```assembly
mov w0, #1   ; Move return value to w0 (return register)
ret          ; Return
```

Different:
- Instruction mnemonics
- Register names (rax vs. w0/x0)
- Instruction encoding

### Part 3: Data Type Sizes

Both x86-64 and AArch64 use **LP64**:
```
char       : 1 bytes
short      : 2 bytes
int        : 4 bytes
long       : 8 bytes
long long  : 8 bytes
void*      : 8 bytes
```

This is why many programs are portable at the source level!

### Part 4: Structure Layout

Same layout on both (LP64 ABI):
```
Offset of c: 0
Offset of i: 4   (padded by 3 bytes)
Offset of s: 8
Offset of p: 16  (padded by 6 bytes)
Total size: 24
```

### Part 5: Calling Conventions

**x86-64 System V**:
- Arguments in RDI, RSI, RDX, RCX, R8, R9, [stack], [stack]
- Return in RAX

**AArch64**:
- Arguments in X0, X1, X2, X3, X4, X5, X6, X7
- Return in X0

Different registers, but same conceptual approach!

### Part 6: Endianness

**Little-endian output**:
```
uint32_t value: 0x12345678
Byte 0: 0x78 @ lowest address
Byte 1: 0x56
Byte 2: 0x34
Byte 3: 0x12 @ highest address
System is: Little-endian
```

Most modern systems (x86-64, ARM64, RISC-V) use little-endian!

### Part 7: ELF Headers

**Key differences**:
- Machine: 62 (x86-64) vs. 183 (ARM aarch64)
- Entry point: Different addresses
- Flags: Architecture-specific

**Key similarities**:
- Both use ELF format
- Both have .text, .data, .bss sections
- Both use program headers for loading

## Questions for reader

### Basic Understanding

1. **Binary compatibility**: Why can't you run an AArch64 binary on an x86-64 machine without emulation?

2. **ABI naming**: What does "LP64" mean? How is it different from "ILP32"?

3. **File formats**: What's the difference between ELF and PE? Why can't Linux run Windows executables directly?

4. **Cross-compilation**: What is a cross-compiler? Why do you need one for embedded development?

### Intermediate Understanding

5. **Type sizes**: Why does `long` have different sizes on different platforms? How does this affect portability?

6. **Structure padding**: Why does the compiler insert padding in structures? Is the padding the same across all platforms?

7. **Calling conventions**: How do argument registers differ between x86-64 System V and AArch64? Why does this matter?

8. **Endianness**: What happens when you read a binary file created on a big-endian system on a little-endian system?

### Advanced Understanding

9. **ABI stability**: What breaks ABI compatibility between library versions? How do systems maintain backward compatibility?

10. **Sysroot purpose**: What is a sysroot in cross-compilation? Why is it necessary?

11. **Register allocation**: How do different ABIs decide which registers are caller-saved vs. callee-saved?

12. **C++ ABI complexity**: Why is C++ ABI compatibility more complex than C ABI compatibility? What about name mangling, exceptions, and RTTI?

## Challenge Exercises

### Challenge 1: Portable Structure

Create a structure that has the same binary layout on both ILP32 and LP64 systems:

```c
struct Portable {
    // Your design here
};
```

Use fixed-width types and ensure consistent padding.

### Challenge 2: Cross-Platform Build System

Create a Makefile that builds for multiple architectures:

```makefile
# Build for x86-64, ARM64, and maybe Windows
all: hello_x86_64 hello_aarch64 hello.exe

hello_x86_64: hello.c
    # Your commands

hello_aarch64: hello.c
    # Your commands

hello.exe: hello.c
    # Your commands
```

### Challenge 3: Investigate Name Mangling

Compare C++ name mangling between GCC and Clang:

```cpp
// test.cpp
namespace foo {
    void bar(int);
}
```

Compile with both and compare symbols:
```bash
g++ -c test.cpp -o test_gcc.o
clang++ -c test.cpp -o test_clang.o
nm test_gcc.o
nm test_clang.o
```

Are the mangled names the same? Why or why not?

### Challenge 4: Endianness Conversion

Implement functions to convert between host and network byte order:

```c
uint32_t host_to_network(uint32_t host);
uint32_t network_to_host(uint32_t network);
```

Test on both little-endian and big-endian systems (if available).

## Summary

Through this experiment, you should understand:

1. **ABI defines binary compatibility**: Different architectures have different ABIs (calling conventions, data layout, etc.), requiring separate compilation.

2. **Cross-compilation enables building for other targets**: Cross-compilers generate code for different architectures while running on the host.

3. **Data types vary by platform**: `long` and pointers have different sizes on ILP32 vs. LP64 systems. Use fixed-width types for portable binary data.

4. **Structure layout requires careful consideration**: Padding and alignment vary, affecting binary compatibility of data structures.

5. **Calling conventions differ**: x86-64 System V and AArch64 use different registers for arguments, preventing binary compatibility.

6. **File formats differ**: Linux (ELF), Windows (PE), and macOS (Mach-O) use incompatible executable formats.

7. **Endianness affects multi-byte data**: Little-endian and big-endian systems store bytes in different orders, requiring explicit conversion for portable data.

8. **Assembly reveals ABI details**: Examining generated assembly shows how the compiler implements calling conventions and data access.

Understanding ABI is crucial for cross-platform development, library design, and debugging mysterious crashes when mixing code from different sources.
