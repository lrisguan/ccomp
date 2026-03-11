# Experiment: Compare static and dynamic linking

## Objective
- Build both static and dynamic variants and observe runtime dependencies.
- Examine PLT and GOT structures in detail.
- Compare executable sizes, startup time, and memory usage.
- Understand library search paths and runtime linking.

## Setup requirements
- gcc or clang installed.
- ar, ldd, nm, objdump, readelf available (Linux or WSL recommended).

## Step-by-step commands

### Part 1: Create Library and Test Programs

1. Create a small library source:
   ```c
   // add.c
   int add(int a, int b) { return a + b; }

   // multiply.c
   int multiply(int a, int b) { return a * b; }
   ```

2. Build static and shared libraries:
   ```bash
   # Compile with Position-Independent Code for shared library
   gcc -c -fPIC -o add.o add.c
   gcc -c -fPIC -o multiply.o multiply.c

   # Create static library
   ar rcs libmath.a add.o multiply.o

   # Create shared library
   gcc -shared -o libmath.so add.o multiply.o
   ```

3. Create a test program:
   ```c
   // main.c
   #include <stdio.h>

   int add(int a, int b);
   int multiply(int a, int b);

   int main(void) {
       printf("5 + 3 = %d\n", add(5, 3));
       printf("5 * 3 = %d\n", multiply(5, 3));
       return 0;
   }
   ```

4. Build static and dynamic executables:
   ```bash
   # Static linking
   gcc -o demo_static main.c -L. -lmath -static

   # Dynamic linking (may need -Wl,-rpath,. to run from current dir)
   gcc -o demo_dynamic main.c -L. -lmath -Wl,-rpath,.
   ```

5. Compare binary sizes:
   ```bash
   ls -lh demo_static demo_dynamic
   ```

6. Inspect runtime dependencies:
   ```bash
   ldd demo_static
   ldd demo_dynamic
   ```

### Part 2: Examine Library Internals

7. Examine the static library archive:
   ```bash
   # List contents
   ar t libmath.a

   # Display symbol table/index
   nm -s libmath.a
   ```

8. Examine the shared library:
   ```bash
   # Check file type
   file libmath.so

   # Display dynamic symbols
   nm -D libmath.so

   # Check if it's position-independent
   readelf -h libmath.so | grep Type
   ```

### Part 3: Examine PLT and GOT

9. Create a program using standard library functions:
   ```c
   // plt_test.c
   #include <stdio.h>
   #include <stdlib.h>
   #include <string.h>

   int main(void) {
       char *s = strdup("Hello");
       printf("String: %s\n", s);
       printf("Length: %zu\n", strlen(s));
       free(s);
       return 0;
   }
   ```

10. Compile and examine PLT:
    ```bash
    gcc -o plt_test plt_test.c
    objdump -d -j .plt plt_test
    ```

11. Examine GOT:
    ```bash
    objdump -d -j .got plt_test
    objdump -d -j .got.plt plt_test
    ```

12. Examine relocation entries:
    ```bash
    readelf -r plt_test | grep JUMP
    ```

### Part 4: Library Search Paths

13. Test library search without RPATH:
    ```bash
    # Create executable without RPATH
    gcc -o demo_norpath main.c -L. -lmath

    # Move library to subdirectory
    mkdir test_libs
    mv libmath.so test_libs/

    # Try to run (should fail)
    ./demo_norpath

    # Now try with LD_LIBRARY_PATH
    LD_LIBRARY_PATH=./test_libs ./demo_norpath
    ```

14. Compare with RPATH:
    ```bash
    # Create executable with RPATH
    gcc -o demo_rpath main.c -L./test_libs -lmath -Wl,-rpath,./test_libs

    # Run without LD_LIBRARY_PATH
    ./demo_rpath

    # Verify RPATH is set
    readelf -d demo_rpath | grep RPATH
    ```

### Part 5: Symbol Visibility

15. Create library with visibility control:
    ```c
    // vis_test.c
    #include <stdio.h>

    // Internal helper - hidden
    static int helper(int x) {
        return x * 2;
    }

    // Public function - explicitly visible
    __attribute__((visibility("default")))
    int public_func(int x) {
        return helper(x);
    }

    // Another hidden function
    __attribute__((visibility("hidden")))
    int internal_func(int x) {
        return x + 10;
    }
    ```

16. Build and check visible symbols:
    ```bash
    gcc -fPIC -c vis_test.c -fvisibility=hidden
    gcc -shared -o libvis.so vis_test.o
    nm -D libvis.so
    ```

## Expected output explanation

### Part 1: Size and Dependencies

- **Binary size**: `demo_static` will be significantly larger than `demo_dynamic` because it includes the library code.
- **ldd output**:
  - `demo_static` shows only `linux-vdso` and possibly `ld-linux` (no dependency on libmath.so)
  - `demo_dynamic` shows `libmath.so` in its dependency list

### Part 2: Library Internals

- **Static library (`ar t`)**: Shows `add.o` and `multiply.o` in the archive
- **Symbol index (`nm -s`)**: Shows which object file contains each symbol, enabling fast lookup during linking
- **Shared library (`file`)**: Identified as "ELF 64-bit LSB shared object"
- **Dynamic symbols (`nm -D`)**: Shows only exported symbols (add and multiply)

### Part 3: PLT and GOT

- **PLT disassembly**: Shows stub code for each external function (printf, strdup, strlen, free)
- **GOT disassembly**: Shows data section containing addresses (initially 0 or pointing to PLT resolver)
- **Relocations**: JUMP_SLOT relocations indicate which symbols need runtime resolution

### Part 4: Search Paths

- **Without RPATH**: Program fails if library isn't in standard system paths
- **With LD_LIBRARY_PATH**: Program runs by using environment variable to find library
- **With RPATH**: Program runs without environment variables because search path is embedded in executable

### Part 5: Symbol Visibility

- **With visibility control**: Only `public_func` appears in `nm -D` output
- **Helper functions**: Not exported, preventing users from calling them directly

## Questions for reader

### Basic Understanding

1. **Library size**: Why is `demo_static` larger than `demo_dynamic`? Where is the library code in each case?

2. **Runtime dependencies**: Why does `ldd demo_static` show no dependency on `libmath.a`, but `ldd demo_dynamic` shows `libmath.so`?

3. **PIC requirement**: What happens if you try to create a shared library without `-fPIC`? Why is this required for shared libraries but not static libraries?

4. **Archive structure**: What does the symbol index in a static library do? Why is it important for linking speed?

### Intermediate Understanding

5. **PLT purpose**: Why can't programs directly call library functions? What role does the PLT play in dynamic linking?

6. **GOT contents**: What does the GOT contain? When does it get populated with actual addresses?

7. **Lazy binding**: What is lazy binding? When does it happen? Why is it beneficial for program startup time?

8. **RPATH vs LD_LIBRARY_PATH**: What are the advantages and disadvantages of each method for specifying library search paths?

### Advanced Understanding

9. **Selective linking**: If a static library contains multiple object files but you only use functions from one of them, does the linker include all object files or just the needed one?

10. **Symbol versioning**: How does symbol versioning (e.g., `memcpy@@GLIBC_2.2.5`) help maintain backward compatibility when libraries are updated?

11. **Memory efficiency**: In what scenarios does dynamic linking provide significant memory savings? When would static linking be more appropriate?

12. **Visibility control**: Why would you want to hide certain symbols in a library? What are the security and API stability benefits?

## Challenge Exercises

### Challenge 1: Build a Complete Library

Create a library with:
- At least 3 source files with different functionality (math, string, file operations)
- A header file declaring public functions
- Hidden internal helper functions using `-fvisibility=hidden`

Then:
- Build both static and shared versions
- Create test programs that use functions from all three modules
- Verify selective linking works (test program using only math functions shouldn't pull in string/file object files from static library)

### Challenge 2: Measure Memory Usage

Create multiple instances of static and dynamic executables and measure memory usage:

```bash
# Run multiple instances in background
./demo_static &
./demo_static &
./demo_static &
./demo_dynamic &
./demo_dynamic &
./demo_dynamic &

# Check memory usage
ps aux | grep demo_
```

Compare total memory usage. Can you observe the memory sharing benefit of dynamic libraries?

### Challenge 3: Dynamic Loading with dlopen

Use runtime dynamic loading:

```c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>

int main(void) {
    void *handle = dlopen("./libmath.so", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "Error: %s\n", dlerror());
        return 1;
    }

    // Clear any existing error
    dlerror();

    // Find the add function
    int (*add_func)(int, int) = dlsym(handle, "add");
    char *error = dlerror();
    if (error != NULL)  {
        fprintf(stderr, "Error: %s\n", error);
        return 1;
    }

    printf("5 + 3 = %d\n", add_func(5, 3));

    dlclose(handle);
    return 0;
}
```

Compile with: `gcc dynamic_load.c -o dynamic_load -ldl`

### Challenge 4: Investigate Symbol Resolution

Use `LD_DEBUG` to trace symbol resolution:

```bash
LD_DEBUG=symbols,bindings ./demo_dynamic 2>&1 | less
```

Observe:
- When symbols are resolved
- Which library provides each symbol
- The order of library search

## Summary

Through this experiment, you should understand:

1. **Static libraries** are archives of object files that are copied into executables at link time, producing self-contained but larger binaries.

2. **Dynamic libraries** are loaded at runtime by the dynamic linker, producing smaller binaries and enabling code sharing between processes.

3. **Position-independent code (PIC)** allows shared libraries to be loaded at any memory address, essential for dynamic linking.

4. **PLT and GOT** are data structures that enable runtime symbol resolution through indirection, with lazy binding deferring resolution until first use.

5. **Library search paths** (RPATH, LD_LIBRARY_PATH, system paths) control where the dynamic linker looks for shared libraries.

6. **Symbol visibility** controls which functions are exported from a library, enforcing API boundaries and improving load times.

These concepts form the foundation of how C programs are linked and executed on modern Unix-like systems.
