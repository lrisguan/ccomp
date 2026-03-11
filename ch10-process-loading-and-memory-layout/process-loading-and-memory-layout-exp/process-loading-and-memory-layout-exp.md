# Experiment: Process Loading and Memory Layout

## Objective

Explore how programs are loaded into memory, understand virtual memory layout, and observe the runtime memory organization of processes.

## Setup Requirements

- Linux environment
- Standard tools (cat, dd, hexdump)
- GCC compiler
- /proc filesystem access

## Step-by-Step Commands

### Part 1: Examining Process Memory Maps

1. Create a program that displays its memory map:

```c
// show_maps.c
#include <stdio.h>
#include <stdlib.h>

int global_init = 42;
int global_uninit;
static int static_var = 100;
const int const_var = 200;

void print_maps(void) {
    char buf[256];
    FILE* f = fopen("/proc/self/maps", "r");
    if (!f) { perror("fopen"); return; }
    
    printf("\n=== Memory Map ===\n");
    while (fgets(buf, sizeof(buf), f)) {
        printf("%s", buf);
    }
    fclose(f);
}

int main(int argc, char** argv) {
    int local_var = 10;
    int* heap_var = malloc(100);
    
    printf("Code (main):    %p\n", (void*)main);
    printf("Global init:    %p\n", (void*)&global_init);
    printf("Global uninit:  %p\n", (void*)&global_uninit);
    printf("Static:         %p\n", (void*)&static_var);
    printf("Const:          %p\n", (void*)&const_var);
    printf("Local (stack):  %p\n", (void*)&local_var);
    printf("Heap (malloc):  %p\n", (void*)heap_var);
    
    print_maps();
    
    free(heap_var);
    return 0;
}
```

2. Compile and run:

```bash
gcc show_maps.c -o show_maps
./show_maps
```

### Part 2: Understanding Memory Regions

1. Analyze the memory map output:

```bash
./show_maps | grep -E "heap|stack|^\[heap\]|^\[stack\]"
```

2. Identify different regions:

```bash
# Code (text) - readable and executable
./show_maps | grep "r-x" | head -3

# Data - readable and writable
./show_maps | grep "rw-" | head -5

# Read-only data
./show_maps | grep "r--" | head -3
```

### Part 3: Stack Exploration

1. Create a program to explore stack layout:

```c
// stack_layout.c
#include <stdio.h>

void func3(void) {
    int local3 = 30;
    printf("func3: local3 at %p\n", (void*)&local3);
}

void func2(void) {
    int local2 = 20;
    printf("func2: local2 at %p\n", (void*)&local2);
    func3();
}

void func1(void) {
    int local1 = 10;
    printf("func1: local1 at %p\n", (void*)&local1);
    func2();
}

int main(void) {
    printf("Stack grows downward:\n");
    func1();
    return 0;
}
```

```bash
gcc stack_layout.c -o stack_layout
./stack_layout
```

### Part 4: Heap Exploration

1. Observe heap allocation:

```c
// heap_explore.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void print_heap_break(const char* label) {
    printf("%s: program break at %p\n", label, sbrk(0));
}

int main(void) {
    print_heap_break("Initial");
    
    void* p1 = malloc(1000);
    print_heap_break("After 1KB");
    printf("p1 = %p\n", p1);
    
    void* p2 = malloc(1000000);
    print_heap_break("After 1MB");
    printf("p2 = %p\n", p2);
    
    void* p3 = malloc(10000000);
    print_heap_break("After 10MB");
    printf("p3 = %p\n", p3);
    
    free(p1);
    free(p2);
    free(p3);
    print_heap_break("After free");
    
    return 0;
}
```

```bash
gcc heap_explore.c -o heap_explore
./heap_explore
```

### Part 5: Memory Protection

1. Test memory protection:

```c
// mem_protect.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

int main(void) {
    // Allocate read-only memory
    void* ro_mem = mmap(NULL, 4096, PROT_READ, 
                        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (ro_mem == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    
    printf("Read-only memory at %p\n", ro_mem);
    
    // This should work
    int value = *(int*)ro_mem;
    printf("Read value: %d\n", value);
    
    // This should crash - uncomment to test
    // printf("Attempting to write...\n");
    // memset(ro_mem, 0, 4096);
    
    // Allocate read-write memory
    void* rw_mem = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    printf("Read-write memory at %p\n", rw_mem);
    memset(rw_mem, 'A', 4096);  // This works
    
    // Allocate executable memory
    void* exec_mem = mmap(NULL, 4096, PROT_READ | PROT_WRITE | PROT_EXEC,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    printf("Executable memory at %p\n", exec_mem);
    
    // Write some x86-64 code: return 42
    unsigned char code[] = {
        0xb8, 0x2a, 0x00, 0x00, 0x00,  // mov eax, 42
        0xc3                            // ret
    };
    memcpy(exec_mem, code, sizeof(code));
    
    // Call the code
    int (*func)(void) = exec_mem;
    int result = func();
    printf("JIT result: %d\n", result);
    
    munmap(ro_mem, 4096);
    munmap(rw_mem, 4096);
    munmap(exec_mem, 4096);
    
    return 0;
}
```

```bash
gcc mem_protect.c -o mem_protect
./mem_protect
```

### Part 6: ASLR (Address Space Layout Randomization)

1. Check if ASLR is enabled:

```bash
cat /proc/sys/kernel/randomize_va_space
# 0 = disabled, 1 = partial, 2 = full
```

2. Run the same program multiple times:

```bash
./show_maps | grep "main\|stack\|heap" | head -3
./show_maps | grep "main\|stack\|heap" | head -3
./show_maps | grep "main\|stack\|heap" | head -3
```

Notice the addresses change between runs (if ASLR is enabled).

3. Disable ASLR temporarily (requires root):

```bash
# Disable ASLR
sudo sh -c 'echo 0 > /proc/sys/kernel/randomize_va_space'
./show_maps | grep main
./show_maps | grep main

# Re-enable ASLR
sudo sh -c 'echo 2 > /proc/sys/kernel/randomize_va_space'
```

### Part 7: Process Memory Statistics

1. View detailed memory info:

```bash
# Get PID
./show_maps &
PID=$!

# Memory statistics
cat /proc/$PID/status | grep -E "^Vm|^RSS"

# Memory map with details
cat /proc/$PID/maps | head -10

# Clean up
kill $PID 2>/dev/null
```

2. Use pmap for detailed analysis:

```bash
./show_maps &
PID=$!
pmap -x $PID
pmap -X $PID | head -20
kill $PID 2>/dev/null
```

### Part 8: Environment and Arguments

1. Explore where environment and arguments are stored:

```c
// env_explore.c
#include <stdio.h>
#include <stdlib.h>

extern char** environ;

int main(int argc, char** argv, char** envp) {
    printf("argc at %p\n", (void*)&argc);
    printf("argv at %p\n", (void*)&argv);
    printf("argv[0] at %p\n", (void*)argv[0]);
    printf("envp at %p\n", (void*)&envp);
    printf("environ at %p\n", (void*)&environ);
    printf("First env var at %p\n", (void*)envp[0]);
    
    // Are they on the stack?
    int local;
    printf("Local var at %p\n", (void*)&local);
    
    return 0;
}
```

```bash
gcc env_explore.c -o env_explore
./env_explore
```

### Part 9: Loading Process with strace

1. Trace program loading:

```bash
strace -e trace=openat,mmap,execve ./show_maps 2>&1 | head -30
```

2. Observe the interpreter:

```bash
readelf -l show_maps | grep interpreter
```

3. Trace the dynamic linker:

```bash
strace -f ./show_maps 2>&1 | grep -E "open.*\.so|mmap" | head -20
```

### Part 10: Segment Permissions

1. Create a program to check segment permissions:

```c
// seg_perms.c
#include <stdio.h>

int global_data = 42;
const int global_rodata = 100;
char global_bss[100];

void code_function(void) {
    printf("This is code\n");
}

int main(void) {
    printf("=== Segment Permissions ===\n");
    printf("Code (rx):   %p\n", (void*)code_function);
    printf("Data (rw):   %p\n", (void*)&global_data);
    printf("Rodata (r):  %p\n", (void*)&global_rodata);
    printf("BSS (rw):    %p\n", (void*)global_bss);
    
    // Check actual permissions in /proc/self/maps
    char cmd[256];
    snprintf(cmd, sizeof(cmd), 
             "grep '%p' /proc/self/maps", 
             (void*)code_function);
    printf("\nCode segment:\n");
    system(cmd);
    
    return 0;
}
```

```bash
gcc seg_perms.c -o seg_perms
./seg_perms
```

## Questions for Reader

1. **Memory Layout**: In what order do the different memory regions appear? Why is the text segment at a lower address than the data segment?

2. **Stack Growth**: When you call nested functions, do the local variable addresses increase or decrease? Why?

3. **ASLR**: Why does ASLR improve security? What types of attacks does it help prevent?

4. **Memory Protection**: What happens when you try to write to read-only memory? What signal is generated?

5. **Heap vs Stack**: What are the key differences between heap and stack allocation? When would you use each?

6. **Segment Permissions**: Why does the code segment need execute permission but not write permission? What security risk would write permission create?

## Further Exploration

- Use `valgrind` to detect memory errors
- Explore `/proc/[pid]/smaps` for detailed memory statistics
- Study the `mlock` and `mprotect` system calls
- Investigate memory-mapped I/O with `mmap`
- Learn about virtual memory areas (VMAs) in the kernel
