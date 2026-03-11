# Experiment: Assembly and Object Files

## Objective

Explore assembly language and object file structure through hands-on exercises.

## Setup Requirements

- GCC assembler and linker
- binutils (objdump, readelf, nm)
- Linux environment

## Step-by-Step Commands

### Part 1: Generating and Viewing Assembly

1. Create a simple C program:

```c
// hello.c
#include <stdio.h>

int global_var = 42;
static int static_var = 10;

int add(int a, int b) {
    return a + b;
}

int main(void) {
    int local = add(global_var, static_var);
    printf("Result: %d\n", local);
    return 0;
}
```

2. Generate assembly with C intermixing:

```bash
gcc -S -fverbose-asm -g hello.c -o hello.s
```

3. View the assembly:

```bash
less hello.s
```

4. Compare AT&T vs Intel syntax:

```bash
gcc -S hello.c -o hello_att.s
gcc -S -masm=intel hello.c -o hello_intel.s
diff hello_att.s hello_intel.s | head -30
```

### Part 2: Assembling by Hand

1. Create assembly directly:

```assembly
# hand_coded.s
.section .data
message: .asciz "Hello from assembly!\n"

.section .text
.globl _start
_start:
    # write(1, message, 22)
    movq $1, %rax        # syscall: write
    movq $1, %rdi        # fd: stdout
    leaq message(%rip), %rsi  # buf: message
    movq $22, %rdx       # count: length
    syscall

    # exit(0)
    movq $60, %rax       # syscall: exit
    xorq %rdi, %rdi      # status: 0
    syscall
```

2. Assemble and link:

```bash
as hand_coded.s -o hand_coded.o
ld hand_coded.o -o hand_coded
./hand_coded
```

### Part 3: Object File Examination

1. Compile to object file:

```bash
gcc -c hello.c -o hello.o
```

2. View sections:

```bash
objdump -h hello.o
readelf -S hello.o
```

3. View symbol table:

```bash
nm hello.o
nm -C hello.o  # Demangle C++ names
readelf -s hello.o
```

4. Disassemble the object file:

```bash
objdump -d hello.o
```

5. View all content:

```bash
objdump -x hello.o
readelf -a hello.o
```

### Part 4: Understanding Symbols

1. Create a file with various symbol types:

```c
// symbols.c
int global_init = 10;        // .data, global
int global_uninit;           // .bss, global
static int static_init = 20; // .data, local
static int static_uninit;    // .bss, local
const int const_var = 30;    // .rodata, local

void public_func(void) { }   // .text, global
static void private_func(void) { }  // .text, local

extern int external_var;     // undefined
```

2. Compile and examine symbols:

```bash
gcc -c symbols.c -o symbols.o
nm symbols.o
```

**Expected Output**:
```
0000000000000000 T public_func
0000000000000000 D global_init
0000000000000004 C global_uninit
0000000000000000 d static_init
0000000000000004 b static_uninit
0000000000000000 r const_var
000000000000000a t private_func
                 U external_var
```

### Part 5: Relocations

1. Create a file with external references:

```c
// relocs.c
extern int external_var;
extern void external_func(void);

int get_external(void) {
    return external_var;
}

void call_external(void) {
    external_func();
}
```

2. View relocations:

```bash
gcc -c relocs.c -o relocs.o
readelf -r relocs.o
objdump -r relocs.o
```

3. Examine the code with relocation placeholders:

```bash
objdump -d relocs.o
```

### Part 6: Section Contents

1. View data sections:

```bash
objdump -s -j .data hello.o
objdump -s -j .rodata hello.o
readelf -x .rodata hello.o
```

2. View string table:

```bash
readelf -p .strtab hello.o
readelf -p .shstrtab hello.o
```

### Part 7: Building a Static Library

1. Create multiple source files:

```c
// lib_src/math_ops.c
int add(int a, int b) { return a + b; }
int subtract(int a, int b) { return a - b; }

// lib_src/str_ops.c
int str_len(const char* s) {
    int len = 0;
    while (s[len]) len++;
    return len;
}
```

2. Compile and create static library:

```bash
gcc -c lib_src/math_ops.c -o math_ops.o
gcc -c lib_src/str_ops.c -o str_ops.o
ar rcs libmylib.a math_ops.o str_ops.o
```

3. View library contents:

```bash
ar -t libmylib.a
nm libmylib.a
```

4. Use the library:

```c
// use_lib.c
#include <stdio.h>

int add(int, int);
int str_len(const char*);

int main(void) {
    printf("add(3,4) = %d\n", add(3, 4));
    printf("len = %d\n", str_len("hello"));
    return 0;
}
```

```bash
gcc use_lib.c -L. -lmylib -o use_lib
./use_lib
```

### Part 8: Debug Information

1. Compile with debug info:

```bash
gcc -g hello.c -o hello_debug
```

2. View debug sections:

```bash
readelf -S hello_debug | grep debug
readelf --debug-dump=info hello_debug | head -50
```

3. Strip debug info:

```bash
cp hello_debug hello_stripped
strip hello_stripped
ls -l hello_debug hello_stripped
```

4. Compare symbol tables:

```bash
nm hello_debug | wc -l
nm hello_stripped | wc -l
```

## Questions for Reader

1. **AT&T vs Intel**: What are the key differences between AT&T and Intel assembly syntax? Which do you find more readable?

2. **Symbol Types**: What do the letters T, D, B, U mean in nm output? How can you tell if a symbol is global or local?

3. **Relocations**: Why does the object file contain relocation entries for `external_var` and `external_func`? What will the linker do with these?

4. **Sections**: Why is `const_var` placed in `.rodata` instead of `.data`? What's the practical implication?

5. **Static Library**: When you linked against `libmylib.a`, did the linker include both object files from the archive? How can you verify this?

6. **Stripping**: How much smaller did the executable become after stripping? What information was removed? Can you still debug a stripped binary?

## Further Exploration

- Write assembly functions that call C functions and vice versa
- Explore the `-fno-stack-protector` and `-fno-pie` flags
- Use `objcopy` to extract or modify specific sections
- Study position-independent code (PIC) with `-fPIC`
- Create and use custom linker scripts
