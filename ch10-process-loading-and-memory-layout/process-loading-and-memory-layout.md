# Chapter 10: Process Loading and Memory Layout

## Introduction

When you type `./myprogram` and press enter, what actually happens? How does a simple executable file on disk become a running process with memory, stack, and heap? This chapter explores the final piece of the compilation story: **process loading** and **memory layout**.

We've seen how source code becomes an executable file. Now we'll see how that executable file is brought to life by the operating system's loader. We'll examine:
- **The loader**: How the OS reads and maps executable files
- **Virtual memory**: How each process gets its own address space
- **Memory segments**: text, data, bss, heap, stack, and more
- **Dynamic linking**: How shared libraries are loaded at runtime
- **Memory mapping**: How `mmap` enables efficient file I/O and memory allocation

Understanding process loading is crucial for:
- **Debugging**: Understanding segmentation faults, memory errors
- **Performance**: Optimizing memory usage and allocation strategies
- **Security**: Understanding ASLR, stack protection, and memory isolation
- **Systems programming**: Writing low-level code that interacts with the OS

## 10.1 From Executable to Process

### 10.1.1 What is a Process?

A **process** is an instance of a program in execution. Unlike a program (static file on disk), a process is dynamic:

```
Program (File on Disk)          Process (Running Instance)
├── Code sections              ├── Memory regions
├── Data sections              ├── Stack
├── Metadata (headers, etc.)   ├── Heap
└── ...                        ├── Program counter
                               ├── Open files
                               └── ...
```

**Key differences**:
- **Program**: Static, passive, stored on disk
- **Process**: Dynamic, active, lives in memory

### 10.1.2 The Loading Process

When you run a program, the OS performs these steps:

```
1. User executes: ./myprogram
         │
         ▼
2. Shell calls fork() + execve()
         │
         ▼
3. Kernel's execve() handler:
   a. Read ELF header from file
   b. Verify it's a valid executable
   c. Create new memory map for process
   d. Read program headers (PHDRs)
   e. Map segments into memory (mmap)
   f. Set up stack and arguments
   g. Set up dynamic linker (if needed)
   h. Jump to entry point (_start)
         │
         ▼
4. _start (in libc/crt0):
   a. Initialize libc
   b. Run constructors (.init_array)
   c. Call main()
   │
   ▼
5. Your program runs!
   │
   ▼
6. After main() returns:
   a. Run destructors (.fini_array)
   b. Call exit()
   │
   ▼
7. Kernel cleans up process
```

Let's trace a concrete example:

```c
// hello.c
#include <stdio.h>

int main(void) {
    printf("Hello, loader!\n");
    return 0;
}
```

Compile and examine:
```bash
gcc -o hello hello.c
```

What happens when we run `./hello`?

**Step 1: Shell invokes execve**
```bash
./hello
```

The shell calls:
```c
execve("./hello", ["./hello", NULL], environ);
```

**Step 2: Kernel validates and loads**

The kernel:
1. Reads the ELF header to verify it's a valid executable
2. Reads program headers to find loadable segments
3. Maps each segment into the process's virtual address space

**Step 3: Memory layout created**

The process now has a memory layout:
```
High Addresses
     ┌─────────────────┐
     │      Stack      │  Grows downward
     ├─────────────────┤
     │       ↓         │
     │                 │
     │       ↑         │
     ├─────────────────┤
     │       Heap      │  Grows upward
     │      .bss       │  Uninitialized data
     │      .data      │  Initialized data
     │      .text      │  Code (read-only)
     └─────────────────┘
Low Addresses
```

**Step 4: _start initializes and calls main**

The entry point isn't actually `main`—it's `_start` (provided by libc/crt0):

```assembly
_start:
    ; Set up stack frame
    ; Initialize environment
    ; Initialize libc
    ; Call constructors
    call main
    ; Call exit() with main's return value
```

## 10.2 Virtual Memory

### 10.2.1 What is Virtual Memory?

**Virtual memory** gives each process the illusion of having its own private, contiguous address space. In reality, physical memory is fragmented and shared among all processes.

**Without virtual memory** (hypothetical):
- All processes share one physical address space
- Bug in one process could corrupt another's memory
- Difficult to allocate large contiguous regions

**With virtual memory**:
- Each process has its own address space (0 to 2^64-1 on 64-bit)
- The Memory Management Unit (MMU) translates virtual → physical addresses
- Processes are isolated from each other
- Pages can be moved, swapped, or shared transparently

**Translation process**:
```
Virtual Address (seen by program)
        │
        ▼
MMU (Memory Management Unit)
        │
        ├──► Page Table Lookup
        │
        ▼
Physical Address (actual RAM location)
```

### 10.2.2 Pages and Page Tables

Memory is divided into **pages** (typically 4KB on x86-64):

```
Virtual Address (64-bit):
┌─────────────┬──────────────┬──────────┐
│ Page Number │   Offset     │          │
│  (high bits)│  (low bits)  │          │
└─────────────┴──────────────┴──────────┘
       │               │
       │               └──► Offset within page (0-4095)
       │
       └──► Index into page table
```

**Page table**: Maps virtual page numbers to physical page frames

Example:
```
Virtual Page 0  → Physical Frame 100
Virtual Page 1  → Physical Frame 205
Virtual Page 2  → (not mapped - page fault!)
Virtual Page 3  → Physical Frame 42
```

### 10.2.3 Benefits of Virtual Memory

1. **Isolation**: Processes can't access each other's memory
2. **Protection**: Pages can be marked read-only, execute-only, etc.
3. **Efficiency**: Only loaded portions of a program need to be in RAM
4. **Simplicity**: Each program can use the same address range
5. **Sharing**: Multiple processes can share the same physical page (for libraries)

## 10.3 Memory Segments

### 10.3.1 Typical Process Memory Layout

A typical process memory layout on x86-64 Linux:

```
High Addresses (0xFFFFFFFFFFFFFFFF)
     ┌─────────────────────────────┐
     │      Kernel Space           │  (Not accessible to user)
     ├─────────────────────────────┤ 0x7FFFFFFFF000
     │                             │
     │      Stack                  │  Grows downward
     │      ┌─────────────┐        │
     │      │  stack var  │        │
     │      ├─────────────┤        │
     │      │     ...     │        │
     │      └─────────────┘        │
     │                             │
     ├─────────────────────────────┤ ← RSP (stack pointer)
     │                             │
     │          ↓                  │  Free memory
     │                             │
     │          ↑                  │
     │                             │
     ├─────────────────────────────┤
     │      Memory Mapping Segment │  Libraries, mmap regions
     │      ┌─────────────┐        │
     │      │   shared lib│        │
     │      ├─────────────┤        │
     │      │     ...     │        │
     │      └─────────────┘        │
     ├─────────────────────────────┤
     │      Heap                   │  Grows upward (via brk/mmap)
     │      ┌─────────────┐        │
     │      │  malloc'd   │        │
     │      ├─────────────┤        │
     │      │     ...     │        │
     │      └─────────────┘        │
     │                             │
     ├─────────────────────────────┤ ← Program break (brk)
     │      .bss                   │  Uninitialized data
     │      (0-filled at load)     │
     ├─────────────────────────────┤
     │      .data                  │  Initialized data
     │      (global vars, etc.)    │
     ├─────────────────────────────┤
     │      .rodata                │  Read-only data (strings, etc.)
     ├─────────────────────────────┤
     │      .text                  │  Code (executable)
     │      (machine instructions) │
     └─────────────────────────────┘
Low Addresses (0x0000000000000000)
```

### 10.3.2 The .text Segment

Contains executable code (machine instructions).

**Properties**:
- **Read-only**: Code cannot modify itself
- **Executable**: CPU can fetch and execute instructions
- **Shared**: Multiple instances of the same program can share this segment

**Example**:
```c
int add(int a, int b) {
    return a + b;
}
```

Compiled to machine code in .text:
```assembly
add:
    lea eax, [rdi + rsi]  ; Return a + b
    ret
```

**Protecting .text**:
```bash
# Attempting to write to .text causes segmentation fault
```

### 10.3.3 The .data Segment

Contains **initialized** global and static variables.

**Example**:
```c
int global_counter = 0;        // In .data
char *message = "Hello";       // Pointer in .data, string in .rodata
static int buffer[100] = {0};  // In .data
```

**Properties**:
- **Read-write**: Variables can be modified
- **Initialized**: Contains initial values from executable
- **Fixed size**: Size known at compile time

### 10.3.4 The .bss Segment

Contains **uninitialized** global and static variables.

**"Block Started by Symbol"** - historical name, but the concept persists.

**Example**:
```c
int uninitialized_global;       // In .bss
static char buffer[1000];      // In .bss
```

**Properties**:
- **Read-write**: Variables can be modified
- **Zero-initialized**: Set to 0 at process start
- **Not stored in executable**: Only size is recorded, not data

**Why separate .bss from .data?**

Efficiency! .bss doesn't take up space in the executable file:

```
.data in file:
[initial values for 100 bytes] → 100 bytes in executable

.bss in file:
[size: 1000, zero at load] → 8 bytes in executable (just the size!)
```

The loader allocates .bss memory and zeros it at runtime.

### 10.3.5 The Heap

Dynamic memory allocation region managed by `malloc`/`free`.

**Growth direction**: Upward (toward higher addresses)

**Management**:
- libc's heap allocator (ptmalloc, jemalloc, etc.) manages this region
- Requests more memory from kernel via `brk()` or `mmap()` when needed
- Carves large regions into small allocations for your program

**Example**:
```c
int *p = malloc(sizeof(int) * 100);  // Allocates from heap
free(p);                               // Returns to heap allocator
```

**Heap growth**:
```
Initial heap:  [allocated] [free space]
                  ▲
               brk (program break)

After malloc:  [allocated] [new allocation] [free space]
                                  ▲
                               brk moved up
```

### 10.3.6 The Stack

Function call region for local variables, return addresses, saved registers.

**Growth direction**: Downward (toward lower addresses)

**Structure** (as seen in Chapter 0):
```
┌───────────────────┐
│  Return Address   │
│  Saved RBP        │ ← RBP (frame pointer)
│  Local Variables  │
│                   │
└───────────────────┘ ← RSP (stack pointer)
```

**Example**:
```c
int factorial(int n) {
    if (n <= 1) return 1;
    int result = n * factorial(n - 1);  // Recursion uses more stack
    return result;
}
```

**Stack overflow**: Exceeding stack size causes segmentation fault:
```bash
# Default stack size is usually 8MB
ulimit -s  # Show stack size
ulimit -s 16384  # Set to 16MB
```

### 10.3.7 Memory Mapping Segment

Region for memory-mapped files, shared libraries, and large allocations.

**Uses**:
- Loading shared libraries (.so files)
- Memory-mapped file I/O (`mmap`)
- Large allocations (malloc uses mmap for large requests)
- Anonymous mappings (malloc for large allocations)

**Example with mmap**:
```c
#include <sys/mman.h>

void *region = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
// Creates a new 4KB region in memory mapping segment
```

## 10.4 The Loader in Detail

### 10.4.1 Program Headers

ELF executables contain **program headers** that tell the loader how to load the file:

```bash
readelf -l hello
```

Typical output:
```
Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000400040 0x0000000000400040
                 0x00000000000001f8 0x00000000000001f8  R      0x8
  INTERP         0x0000000000000238 0x0000000000400238 0x0000000000400238
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000400000 0x0000000000400000
                 0x00000000000007ac 0x00000000000007ac  R E    0x200000
  LOAD           0x0000000000000db8 0x0000000000400db8 0x0000000000400db8
                 0x0000000000000290 0x00000000000002d0  RW     0x200000
  DYNAMIC        0x0000000000000dd8 0x0000000000400dd8 0x0000000000400dd8
                 0x00000000000001e0 0x00000000000001e0  RW     0x8
  NOTE           0x000000000000026c 0x000000000040026c 0x000000000040026c
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_EH_FRAME   0x0000000000000644 0x0000000000400644 0x0000000000400644
                 0x0000000000000034 0x0000000000000034  R      0x4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RW     0x10
  GNU_RELRO      0x0000000000000db8 0x0000000000400db8 0x0000000000400db8
                 0x0000000000000248 0x0000000000000248  R      0x1
```

**Key program headers**:
- **PHDR**: Program header table itself
- **INTERP**: Specifies dynamic linker (ld-linux.so)
- **LOAD**: Loadable segment (code or data)
- **DYNAMIC**: Dynamic linking information
- **GNU_STACK**: Stack permissions (executable? non-executable?)

### 10.4.2 The Dynamic Linker

For dynamically linked executables, the **dynamic linker** (`ld-linux.so`) performs final setup:

**What it does**:
1. Load required shared libraries (libc.so, etc.)
2. Resolve symbol references (PLT/GOT, as seen in Chapter 7)
3. Run relocations
4. Call shared library initializers
5. Transfer control to the program

**Inspecting dynamic dependencies**:
```bash
ldd hello
```

Output:
```
    linux-vdso.so.1 (0x00007ffc12345000)
    libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f8b4a1b2000)
    /lib64/ld-linux-x86-64.so.2 (0x00007f8b4a3b5000)
```

### 10.4.3 ASLR: Address Space Layout Randomization

Modern systems use **ASLR** to randomize memory locations for security:

**Without ASLR** (old systems):
```
Stack always at 0x7ffffff00000
Heap always starts at 0x02000000
Libraries always loaded at same addresses
→ Predictable = easier to exploit!
```

**With ASLR** (modern systems):
```
Stack at random location each run
Heap starts at random location
Libraries loaded at random addresses
→ Unpredictable = harder to exploit!
```

**Checking ASLR status**:
```bash
cat /proc/sys/kernel/randomize_va_space
# 0 = disabled, 1 = conservative, 2 = full
```

**Effect on debugging**:
Addresses change each run, making debugging harder. Disable for debugging (careful!):
```bash
sudo bash -c 'echo 0 > /proc/sys/kernel/randomize_va_space'
```

## 10.5 Examining Process Memory

### 10.5.1 /proc/pid/maps

The `/proc` filesystem provides detailed information about process memory:

```c
// memory_test.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int global = 42;
int uninitialized;

int main(void) {
    int stack_var;
    int *heap_var = malloc(sizeof(int));

    printf("PID: %d\n", getpid());
    printf("&global        = %p\n", &global);
    printf("&uninitialized = %p\n", &uninitialized);
    printf("&stack_var     = %p\n", &stack_var);
    printf("heap_var       = %p\n", heap_var);

    printf("Press Enter to continue...");
    getchar();

    free(heap_var);
    return 0;
}
```

Compile and run:
```bash
gcc -o memory_test memory_test.c
./memory_test
```

While program waits, in another terminal:
```bash
cat /proc/$(pgrep memory_test)/maps
```

Typical output:
```
00400000-00401000 r-xp 00000000 08:01 123456    /path/to/memory_test
00600000-00601000 r--p 00000000 08:01 123456    /path/to/memory_test
00601000-00602000 rw-p 00001000 08:01 123456    /path/to/memory_test
...
7fff12345000-7fff12346000 rw-p 00000000 00:00 0          [stack]
...
```

**Format**:
```
address-range    perms offset  dev   inode   pathname
```

- **r-xp**: Read-execute (code)
- **rw-p**: Read-write (data/heap)
- **r--p**: Read-only (read-only data)
- **---p**: No permissions (guard pages)

### 10.5.2 Using pmap

The `pmap` tool provides a more readable view:

```bash
pmap $(pgrep memory_test)
```

Shows:
- Address ranges
- Size of each region
- Permissions
- Mapping type (anonymous, file-backed, etc.)

## 10.6 Memory Allocation Strategies

### 10.6.1 Stack Allocation

**Fast**: Just adjust stack pointer
**Limited**: Stack size is limited (usually ~8MB)
**Automatic**: Freed when function returns

```c
int function(void) {
    int buffer[1000];  // Stack allocation
    // buffer automatically freed on return
}
```

**Use when**:
- Small, short-lived allocations
- Size known at compile time
- Simple cleanup needed

### 10.6.2 Heap Allocation

**Slower**: Must interact with heap allocator
**Flexible**: Can allocate large, variable-sized regions
**Manual**: Must explicitly free

```c
int *buffer = malloc(1000 * sizeof(int));
// ...
free(buffer);
```

**Use when**:
- Large allocations needed
- Size determined at runtime
- Data must outlive the function

### 10.6.3 Memory Mapping

**Most flexible**: Can map files, create shared regions
**Page-granularity**: Allocations in page-sized chunks (4KB)
**Direct control**: Fine-grained control over permissions

```c
void *region = mmap(NULL, size, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
// ...
munmap(region, size);
```

**Use when**:
- Very large allocations (>128KB, typically)
- Memory-mapped I/O
- Shared memory between processes
- Specific alignment or permission requirements

## 10.7 Common Memory Errors

### 10.7.1 Segmentation Fault

Caused by accessing invalid memory:

```c
int *p = NULL;
*p = 42;  // Segfault: dereferencing NULL pointer

int arr[10];
arr[100] = 5;  // Segfault: out of bounds

char *s = "hello";
s[0] = 'H';  // Segfault: writing to read-only memory (.rodata)
```

**Debugging with gdb**:
```bash
gcc -g program.c -o program
gdb ./program
(gdb) run
... segfault ...
(gdb) backtrace
(gdb) print variable_name
```

### 10.7.2 Memory Leaks

Allocating memory without freeing it:

```c
void leaky_function(void) {
    int *p = malloc(sizeof(int) * 100);
    // Forgot to free(p)!
}
```

**Detection with valgrind**:
```bash
gcc -g leaky.c -o leaky
valgrind --leak-check=full ./leaky
```

### 10.7.3 Use-After-Free

Using memory after it's been freed:

```c
int *p = malloc(sizeof(int));
free(p);
*p = 42;  // Undefined behavior! May crash or corrupt data.
```

**Detection**: Use tools like AddressSanitizer:
```bash
gcc -fsanitize=address -g use_after_free.c -o uaf
./uaf
```

## 10.8 Key Takeaways

1. **Loading transforms executables into processes**: The OS loader reads the ELF file, maps segments into memory, and transfers control to the entry point.

2. **Virtual memory isolates processes**: Each process has its own address space, translated to physical memory by the MMU via page tables.

3. **Memory is organized into segments**: .text (code), .rodata (read-only data), .data (initialized data), .bss (uninitialized data), heap, and stack.

4. **The stack grows downward, heap grows upward**: Local variables and function frames are on the stack; dynamic allocations are on the heap.

5. **The loader uses program headers**: ELF program headers specify which segments to load, their permissions, and their virtual addresses.

6. **Dynamic linking happens at load time**: The dynamic linker loads shared libraries, resolves symbols, and performs relocations before your code runs.

7. **ASLR randomizes memory layout**: For security, ASLR randomizes stack, heap, and library locations to make exploitation harder.

8. **/proc/pid/maps reveals memory layout**: You can inspect a running process's memory layout through the /proc filesystem.

9. **Different allocation strategies**: Stack (fast, automatic), heap (flexible, manual), and mmap (direct control) each have different trade-offs.

10. **Memory errors cause crashes**: Segmentation faults, memory leaks, and use-after-free are common errors debuggable with tools like gdb, valgrind, and AddressSanitizer.

## 10.9 Looking Ahead

This completes our journey from C source code to running process! We've seen:
- **Chapter 1-2**: Compilation pipeline and preprocessing
- **Chapter 3-4**: Compilation internals and object files
- **Chapter 5-6**: ELF format and linking
- **Chapter 7-8**: Static/dynamic libraries and system calls
- **Chapter 9**: ABI and cross-platform compilation
- **Chapter 10**: Process loading and memory layout

You now understand the complete path from source code to executing process, with deep knowledge of each step along the way.

## Further Reading

- `man 2 execve` - Execute program
- `man 2 mmap` - Memory mapping
- `man 5 proc` - /proc filesystem
- `man 8 ld.so` - Dynamic linker
- "Understanding the Linux Kernel" by Daniel P. Bovet and Marco Cesati
- "Linux Kernel Development" by Robert Love
- "The C Programming Language" (K&R) - Appendix on memory layout
