# Experiment: Linking and Relocation

## Objective

Explore the linking process by creating object files, libraries, and observing how symbols are resolved and relocations applied.

## Setup Requirements

- GCC compiler
- binutils (ar, nm, objdump, readelf)
- Linux environment

## Step-by-Step Commands

### Part 1: Basic Linking

1. Create multiple source files:

```c
// main.c
#include <stdio.h>

extern int add(int a, int b);
extern int global_value;

int main(void) {
    printf("Result: %d\n", add(global_value, 10));
    return 0;
}
```

```c
// math_ops.c
int add(int a, int b) {
    return a + b;
}

int subtract(int a, int b) {
    return a - b;
}
```

```c
// data.c
int global_value = 42;
```

2. Compile separately and link:

```bash
gcc -c main.c -o main.o
gcc -c math_ops.c -o math_ops.o
gcc -c data.c -o data.o
gcc main.o math_ops.o data.o -o program
./program
```

3. Observe symbol resolution:

```bash
echo "=== main.o symbols ===" && nm main.o
echo "=== math_ops.o symbols ===" && nm math_ops.o
echo "=== data.o symbols ===" && nm data.o
echo "=== program symbols ===" && nm program | grep -E "add|global|main"
```

### Part 2: Understanding Relocations

1. Examine relocations in object files:

```bash
readelf -r main.o
objdump -r main.o
```

2. View the code with relocation markers:

```bash
objdump -d main.o
```

3. After linking, verify relocations are resolved:

```bash
readelf -r program
objdump -d program | grep -A5 "<main>"
```

### Part 3: Static Library Creation

1. Create a static library:

```bash
ar rcs libmath.a math_ops.o
ar -t libmath.a
nm libmath.a
```

2. Link with the static library:

```bash
gcc main.c -L. -lmath data.o -o program_static
./program_static
```

3. Verify the library is embedded:

```bash
nm program_static | grep add
```

### Part 4: Library Linking Order

1. Demonstrate ordering issue:

```bash
# This may fail with static libraries
gcc -L. -lmath main.c data.o -o program_order 2>&1 || echo "Failed as expected"
```

2. Correct ordering:

```bash
gcc main.c data.o -L. -lmath -o program_correct
./program_correct
```

### Part 5: Symbol Visibility

1. Create files with conflicting symbols:

```c
// conflict1.c
int shared_var = 10;
void print_var(void) {
    printf("conflict1: %d\n", shared_var);
}
```

```c
// conflict2.c
int shared_var = 20;  // Multiple definition!
void print_var2(void) {
    printf("conflict2: %d\n", shared_var);
}
```

2. Try to link:

```bash
gcc -c conflict1.c -o conflict1.o
gcc -c conflict2.c -o conflict2.o
gcc conflict1.o conflict2.o -o conflict 2>&1 || echo "Multiple definition error"
```

3. Fix with static:

```c
// fixed1.c
static int file_local_var = 10;  // File-local
```

```c
// fixed2.c
static int file_local_var = 20;  // Different symbol, OK
```

```bash
gcc -c fixed1.c -o fixed1.o
gcc -c fixed2.c -o fixed2.o
gcc fixed1.o fixed2.o -o fixed  # Works!
```

### Part 6: Weak Symbols

1. Create files with weak/strong symbols:

```c
// weak.c
#include <stdio.h>

__attribute__((weak)) void my_handler(void) {
    printf("Default handler\n");
}

void run_handler(void) {
    if (my_handler) {
        my_handler();
    }
}
```

```c
// strong.c
#include <stdio.h>

void my_handler(void) {
    printf("Custom handler\n");
}
```

2. Link and observe:

```bash
gcc -c weak.c -o weak.o
gcc -c strong.c -o strong.o

# Without override
gcc weak.o -o weak_only
./weak_only

# With override
gcc weak.o strong.o -o weak_strong
./weak_strong
```

### Part 7: Shared Library Creation

1. Create a shared library:

```c
// shared_math.c
int shared_add(int a, int b) {
    return a + b;
}

int shared_mul(int a, int b) {
    return a * b;
}
```

```bash
gcc -fPIC -c shared_math.c -o shared_math.o
gcc -shared shared_math.o -o libsharedmath.so
```

2. Link against shared library:

```c
// use_shared.c
#include <stdio.h>

int shared_add(int, int);

int main(void) {
    printf("Result: %d\n", shared_add(5, 3));
    return 0;
}
```

```bash
gcc use_shared.c -L. -lsharedmath -o use_shared
LD_LIBRARY_PATH=. ./use_shared
```

3. Check dependencies:

```bash
ldd use_shared
readelf -d use_shared | grep NEEDED
```

### Part 8: Dynamic Loading at Runtime

1. Use dlopen for runtime loading:

```c
// dynamic_load.c
#include <stdio.h>
#include <dlfcn.h>

int main(void) {
    void* handle = dlopen("./libsharedmath.so", RTLD_NOW);
    if (!handle) {
        fprintf(stderr, "Error: %s\n", dlerror());
        return 1;
    }

    int (*add_func)(int, int) = dlsym(handle, "shared_add");
    char* error = dlerror();
    if (error) {
        fprintf(stderr, "Error: %s\n", error);
        return 1;
    }

    printf("Dynamic result: %d\n", add_func(10, 20));
    dlclose(handle);
    return 0;
}
```

```bash
gcc dynamic_load.c -ldl -o dynamic_load
LD_LIBRARY_PATH=. ./dynamic_load
```

### Part 9: Link-Time Optimization (LTO)

1. Create test file:

```c
// lto_test.c
static int helper(int x) {
    return x * x;
}

int compute(int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += helper(i);
    }
    return sum;
}
```

2. Compare without and with LTO:

```bash
# Without LTO
gcc -O2 lto_test.c -c -o lto_no.o
nm lto_no.o | grep helper

# With LTO
gcc -O2 -flto lto_test.c -c -o lto_yes.o
nm lto_yes.o | grep helper || echo "helper optimized away"
```

### Part 10: Linker Script Basics

1. View default linker script:

```bash
ld --verbose | head -100 > default.ld
```

2. Create custom script:

```ld
/* custom.ld */
ENTRY(main)

SECTIONS
{
    . = 0x10000;
    .text : { *(.text) }
    
    . = 0x20000;
    .data : { *(.data) }
    .bss : { *(.bss) }
}
```

3. Use custom script:

```bash
gcc -c main.c -o main.o
ld -T custom.ld main.o math_ops.o data.o -o custom_program
readelf -S custom_program | grep -E "\.text|\.data"
```

## Questions for Reader

1. **Symbol Resolution**: How did the linker find the `add` function and `global_value` variable? What would happen if they were missing?

2. **Relocation**: Look at the relocation entries for `main.o`. What types of relocations are used? Why are there no relocations in the final executable?

3. **Library Order**: Why does the order of static libraries on the command line matter? How is this different from shared libraries?

4. **Weak Symbols**: When both weak and strong definitions exist, which one is used? How can you check this with nm?

5. **PIC**: What does position-independent code mean? Why is it required for shared libraries?

6. **LTO**: How does link-time optimization allow for better optimization than separate compilation?

## Further Exploration

- Explore `-Wl,--as-needed` flag
- Study symbol versioning in shared libraries
- Create a plugin system using dlopen
- Explore `-Wl,--gc-sections` for dead code elimination
- Study the GNU hash table for symbol lookup
