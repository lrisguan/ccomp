# Chapter 8: Standard Library and System Calls

## Introduction

Every C programmer uses functions like `printf`, `malloc`, `open`, and `read`. But where do these functions come from? Are they part of the C language, part of the operating system, or something else entirely?

This chapter explores the layered architecture that sits between your C code and the bare hardware. We'll distinguish between:
- **The C standard library (libc)**: User-space code that provides the standard C API
- **System calls**: The kernel interface that performs privileged operations
- **The boundary between user mode and kernel mode**: Where protection and privilege transitions occur

Understanding this distinction is crucial for:
- **Performance optimization**: Knowing when library functions vs. raw syscalls are appropriate
- **Debugging**: Understanding error reporting and stack traces
- **Portability**: Writing code that works across different platforms
- **Security**: Understanding privilege boundaries and potential vulnerabilities

## 8.1 The Layered Architecture

Modern Unix-like systems have a clear separation between user-space programs and the kernel:

```
┌─────────────────────────────────────────────────────────────┐
│                    Your C Program                           │
│                                                             │
│  main() {                                                   │
│      printf("Hello\n");  // ← Not a syscall!                │
│      malloc(1024);        // ← Not a syscall!               │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              C Standard Library (libc)                      │
│                                                             │
│  • Wrappers for standard C functions                        │
│  • Buffering, caching, optimization                         │
│  • POSIX API implementation                                 │
│  • Error handling (errno)                                   │
│                                                             │
│  Examples: printf(), malloc(), fopen(), strlen()            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 System Call Interface                       │
│                                                             │
│  • Well-defined entry points into kernel                    │
│  • Mode switch: user → kernel                               │
│  • Argument validation and copying                          │
│                                                             │
│  Examples: write(), brk(), mmap(), open()                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Operating System Kernel                │
│                                                             │
│  • Process management                                       │
│  • Memory management                                        │
│  • File system                                              │
│  • Device drivers                                           │
│  • Security and access control                              │
└─────────────────────────────────────────────────────────────┘
```

**Key insight**: Most C library functions are **not** system calls. They're user-space code that may or may not eventually make system calls.

## 8.2 What is a System Call?

A **system call** (syscall) is a programmatic way a program requests a service from the operating system kernel. System calls are the only legitimate way to access kernel resources.

### 8.2.1 Why System Calls Exist

User programs cannot directly access:
- **Hardware devices**: Direct hardware access would allow any program to monopolize or damage devices
- **Other processes' memory**: Without isolation, buggy or malicious programs could corrupt other programs
- **Network stack**: Raw network access requires privilege and coordination
- **File system**: File permissions and access control need kernel enforcement

The kernel provides **controlled access** to these resources through system calls.

### 8.2.2 User Mode vs. Kernel Mode

CPUs support different privilege levels (called **rings** on x86):
- **Ring 0 (Kernel Mode)**: Unrestricted access to all hardware and memory
- **Ring 3 (User Mode)**: Restricted access; certain instructions cause traps

```
┌─────────────────────────────────────────────────────────────┐
│                  Privilege Levels (x86)                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Ring 0: Kernel Mode (Most Privileged)                      │
│  ┌───────────────────────────────────────────────┐          │
│  │  • Execute any instruction                    │          │
│  │  • Access any memory address                  │          │
│  │  • Control hardware devices                   │          │
│  │  • Modify page tables                         │          │
│  └───────────────────────────────────────────────┘          │
│                    ↕ System Call                            │
│  Ring 3: User Mode (Least Privileged)                       │
│  ┌───────────────────────────────────────────────┐          │
│  │  • Limited instruction set                    │          │
│  │  • Can only access own memory                 │          │
│  │  • Cannot access hardware directly            │          │
│  │  • Must use syscalls for kernel services      │          │
│  └───────────────────────────────────────────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

System calls provide a **controlled, secure gateway** from user mode to kernel mode.

### 8.2.3 How System Calls Work

Making a system call involves:

1. **Program preparation**: Place syscall number and arguments in registers
2. **Trap instruction**: Execute special instruction (e.g., `syscall` on x86-64)
3. **CPU mode switch**: CPU switches from user mode to kernel mode
4. **Kernel execution**: Kernel validates arguments and performs the operation
5. **Result return**: Kernel places result in a register and switches back to user mode

**Example: The `write` syscall on x86-64**

```assembly
; User-space code making a raw syscall
mov rax, 1          ; Syscall number for 'write' (on x86-64 Linux)
mov rdi, 1          ; File descriptor 1 (stdout)
mov rsi, msg        ; Pointer to message
mov rdx, 13         ; Length of message
syscall             ; Invoke kernel

; Result is now in rax
```

Let's trace what happens:

```
User Mode                          Kernel Mode
─────────────────────────────────────────────────────────────────

Program executes:
  mov rax, 1          ; Prepare syscall number
  mov rdi, 1          ; Prepare fd
  mov rsi, msg        ; Prepare buffer
  mov rdx, 13         ; Prepare length
  syscall             ; ← TRAP to kernel
                        │
                        ▼
                      Kernel takes control:
                        1. Save user registers
                        2. Verify rax is valid syscall number
                        3. Switch to kernel stack
                        4. Execute write() syscall handler:
                           - Validate fd (1 is valid stdout)
                           - Validate buffer is in user memory
                           - Copy data to kernel buffers
                           - Pass to device driver
                        5. Place result (bytes written) in rax
                        6. Restore user registers
                        7. Return to user mode
                        │
                        ▼
Program continues:
  ; rax now contains 13 (bytes written)
```

**Why not call kernel functions directly?**

There's no standard way to call kernel functions from user space because:
1. Kernel code isn't mapped into user address space (security)
2. Kernel functions expect to run with kernel privileges
3. Direct calls would bypass security checks

System calls are the **only supported interface** between user and kernel code.

## 8.3 The C Standard Library (libc)

### 8.3.1 What is libc?

**libc** is the C standard library—a collection of functions that implement the C standard library (ISO C) and POSIX APIs. On Linux, the most common implementation is **glibc** (GNU C Library).

Key responsibilities:
- **Standard C functions**: `printf`, `malloc`, `strcpy`, etc.
- **System call wrappers**: `open`, `read`, `write`, etc.
- **Buffering and caching**: Optimize performance by batching operations
- **Thread safety**: Support for multithreaded programs
- **Locale support**: Internationalization and localization

### 8.3.2 libc as a Wrapper Layer

Most libc functions are **wrappers** around system calls, adding value through buffering, error handling, and abstraction.

**Example 1: `printf`**

`printf` is **not** a system call. It's a complex user-space function:

```c
// Simplified view of what printf does
int printf(const char *format, ...) {
    va_list args;
    va_start(args, format);

    // 1. Format the string in user space
    char buffer[4096];
    int len = vsnprintf(buffer, sizeof(buffer), format, args);

    // 2. Write to stdout (which is buffered!)
    //    stdout is a FILE* with its own buffer
    return fwrite(buffer, 1, len, stdout);

    // fwrite will eventually call the write() syscall,
    // possibly after buffering many small writes
}
```

The chain looks like:
```
printf()
    → vfprintf() [format the string]
        → fwrite() [manage stdio buffer]
            → write() syscall [actual kernel I/O]
```

**Why this indirection?**

1. **Performance**: Formatting in user space avoids kernel mode switches
2. **Buffering**: Multiple `printf` calls can be combined into one `write` syscall
3. **Flexibility**: The same formatting code works for files, strings, and custom streams

**Example 2: `malloc`**

`malloc` is also **not** a system call (mostly):

```c
void *malloc(size_t size) {
    // Ask the heap allocator (brk/mmap syscalls under the hood)
    // The heap allocator manages a large memory region
    // and carves it into small pieces for your program

    // Most malloc() calls don't trigger syscalls!
    // They just carve out space from already-allocated regions
    return heap_alloc(size);
}
```

The heap allocator (`malloc` implementation) manages large memory regions obtained from the kernel via `brk` or `mmap` syscalls. Most `malloc` calls just carve out space from these regions—no syscall needed!

**Example 3: `strlen`**

`strlen` is purely user-space:

```c
size_t strlen(const char *s) {
    size_t len = 0;
    while (s[len]) len++;  // Just reads memory!
    return len;
}
```

No syscall involved—it's just reading your program's own memory.

### 8.3.3 When libc Does Make Syscalls

Some libc functions are thin wrappers around syscalls:

```c
// glibc's open() function (simplified)
int open(const char *pathname, int flags, mode_t mode) {
    // This is basically just a syscall wrapper
    return syscall(__NR_open, pathname, flags, mode);
}
```

But even "simple" wrappers add value:
- **Error handling**: Convert syscall return values to `errno`
- **Thread safety**: Handle cancellation points for pthreads
- **Cancellation checking**: Allow threads to be cancelled at safe points

## 8.4 System Call Numbers and Conventions

### 8.4.1 Syscall Numbers

Each system call has a unique number. On Linux x86-64:

```c
// From arch/x86/entry/syscalls/syscall_64.tbl
0   read
1   write
2   open
3   close
// ... hundreds more ...
```

These numbers are architecture-specific! ARM64 has different numbers than x86-64.

**Raw syscall example**:

```c
// Make a write syscall directly (bypassing libc)
#include <unistd.h>
#include <sys/syscall.h>

int main(void) {
    const char msg[] = "Hello via raw syscall!\n";

    // Direct syscall (x86-64 Linux)
    syscall(__NR_write, 1, msg, sizeof(msg) - 1);

    return 0;
}
```

Compile and run:
```bash
gcc -o raw_syscall raw_syscall.c
./raw_syscall
```

### 8.4.2 Syscall Calling Conventions

On x86-64 Linux:
- **Syscall number**: RAX register
- **Arguments**: RDI, RSI, RDX, R10, R8, R9 (in order)
- **Return value**: RAX register
- **Error indication**: Return value between -4095 and -1 (negated errno)

Note the difference from function calls:
- Function calls use RCX for 4th argument
- Syscalls use R10 for 4th argument (syscall instruction clobbers RCX)

## 8.5 Error Reporting: errno

### 8.5.1 How errno Works

When a syscall fails, the kernel returns a negative error code. libc converts this to:

1. **Return value**: -1 (for most functions)
2. **errno**: A global variable containing the error code

```c
#include <stdio.h>
#include <errno.h>
#include <string.h>

int main(void) {
    FILE *f = fopen("/nonexistent/file", "r");

    if (f == NULL) {
        // errno is set by libc based on kernel error
        printf("Error %d: %s\n", errno, strerror(errno));
    }

    return 0;
}
```

**Important**: `errno` is thread-local! Each thread has its own copy, so multithreaded programs work correctly.

### 8.5.2 Why errno Exists

Why not just return the error code directly?

1. **Historical**: Early C had limited error handling options
2. **Efficiency**: Negative return values can indicate valid data (e.g., `read` can legitimately return 0 for EOF)
3. **Detail**: errno provides more error information than just "success/failure"

**Modern alternative**: Some newer APIs use different error handling (e.g., POSIX `pthread_*` functions return error codes directly).

## 8.6 Observing Syscalls with strace

`strace` is a powerful tool that traces system calls made by a program.

### 8.6.1 Basic strace Usage

Create `simple.c`:
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    char *s = strdup("Hello");
    printf("%s\n", s);
    free(s);
    return 0;
}
```

Compile and trace:
```bash
gcc -o simple simple.c
strace ./simple
```

Typical output (abbreviated):
```
execve("./simple", ["./simple"], 0x7ffc...) = 0
brk(NULL)                               = 0x55555000
brk(0x55556c000)                        = 0x55556c000
mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7ffff...
write(1, "Hello\n", 6)                  = 6
munmap(0x7ffff..., 4096)                = 0
exit_group(0)                           = ?
+++ exited with 0 +++
```

**What to observe**:
- `brk`/`mmap`: Memory allocation for heap
- `write`: The actual I/O syscall (only one, despite printf!)
- No syscall for `strlen`-like operations (they're pure user-space)

### 8.6.2 strace for Debugging

strace is invaluable for:
- **Finding file access problems**: "Which config file did it try to open?"
- **Performance analysis**: "Why is this program slow? Too many small reads?"
- **Understanding behavior**: "What syscalls does this program actually make?"

Example: Find why a program can't open a file:
```bash
strace -e trace=open,openat my_program 2>&1 | grep -i "no such file"
```

## 8.7 Library vs. Syscall Performance

### 8.7.1 The Cost of Syscalls

System calls are expensive compared to function calls:

```
Function call: ~1-5 nanoseconds
System call: ~500-2000 nanoseconds
```

The overhead comes from:
1. **Mode switch**: User → kernel → user transition
2. **Validation**: Kernel must validate all arguments
3. **Scheduling**: Other processes might run while in kernel
4. **Cache effects**: Kernel code uses different cache lines

**Example**: Writing many small strings

```c
// Approach 1: Naive - many small syscalls
for (int i = 0; i < 1000; i++) {
    write(1, "x", 1);  // Syscall each time!
}

// Approach 2: Better - libc buffering
for (int i = 0; i < 1000; i++) {
    printf("x");  // Buffered! One syscall at the end.
}
```

The second approach is **much faster** because libc buffers the output and makes a single `write` syscall.

### 8.7.2 libc Buffering

libc performs buffering at several levels:

**Stdio buffering (`FILE*` streams)**:
```c
// Unbuffered (slow)
setbuf(stdout, NULL);
for (int i = 0; i < 1000; i++) {
    printf("x");  // Syscall each iteration!
}

// Fully buffered (fast)
setvbuf(stdout, NULL, _IOFBF, BUFSIZ);
for (int i = 0; i < 1000; i++) {
    printf("x");  // Buffered until:
                 // - Buffer is full
                 // - fflush() is called
                 // - Program exits
}
```

**Default buffering behavior**:
- **stdin**: Line-buffered (when interactive) or fully buffered
- **stdout**: Line-buffered (when connected to terminal) or fully buffered
- **stderr**: Always unbuffered (ensure error messages appear)

### 8.7.3 When to Use Syscalls Directly

**Use syscalls directly when**:
- You need functionality not exposed by libc
- You need to avoid libc's buffering (e.g., for `O_DIRECT` I/O)
- You're implementing a library yourself
- You need very specific control over behavior

**Use libc wrappers when**:
- You want standard C/POSIX behavior
- You want buffering and optimization for free
- You want portable code across Unix-like systems

## 8.8 Common System Calls

Let's examine some commonly-used syscalls:

### 8.8.1 File I/O Syscalls

```c
// Open a file (returns file descriptor)
int fd = open("file.txt", O_RDONLY);

// Read from file descriptor
ssize_t n = read(fd, buffer, sizeof(buffer));

// Write to file descriptor
ssize_t written = write(fd, data, size);

// Close file descriptor
close(fd);
```

**libc equivalents**:
```c
// fopen returns FILE* (which wraps a file descriptor)
FILE *f = fopen("file.txt", "r");

// fread/fwrite use buffering internally
size_t n = fread(buffer, 1, sizeof(buffer), f);
fwrite(data, 1, size, f);

// fclose closes the FILE* and underlying fd
fclose(f);
```

### 8.8.2 Memory Management Syscalls

```c
// Adjust program break (old-school memory allocation)
void *brk(void *addr);
int brk(void *addr);

// Map memory into address space (modern approach)
void *mmap(void *addr, size_t length, int prot, int flags,
           int fd, off_t offset);

// Unmap memory
int munmap(void *addr, size_t length);
```

**libc uses these internally** for `malloc`, `free`, etc.

### 8.8.3 Process Management Syscalls

```c
// Create new process (fork)
pid_t fork(void);

// Replace process image (exec)
int execve(const char *pathname, char *const argv[], char *const envp[]);

// Wait for process state change
pid_t waitpid(pid_t pid, int *wstatus, int options);

// Exit current process
void _exit(int status);
```

## 8.9 The libc Implementation: glibc

### 8.9.1 What is glibc?

**glibc** (GNU C Library) is the standard C library on Linux. It provides:
- ISO C standard library
- POSIX API (mostly)
- Linux-specific extensions
- Thread support (NPTL: Native POSIX Thread Library)
- Internationalization (locale, iconv)

### 8.9.2 glibc Architecture

```
glibc
├── Standard C library
│   ├── stdio (printf, scanf, fopen, ...)
│   ├── stdlib (malloc, free, atoi, ...)
│   ├── string (strlen, strcpy, memcpy, ...)
│   └── ...
├── POSIX API
│   ├── pthread (threads, mutexes, condition variables)
│   ├── sockets (network I/O)
│   ├── sys/stat (file status)
│   └── ...
├── Syscall wrappers
│   ├──unistd (read, write, fork, exec, ...)
│   ├── sys/mman (mmap, munmap, ...)
│   └── ...
└── Linux-specific extensions
    ├── epoll (event notification)
    ├── inotify (file system monitoring)
    └── ...
```

### 8.9.3 Finding glibc on Your System

```bash
# Find the library file
ldd /bin/ls | grep libc

# Typically: /lib/x86_64-linux-gnu/libc.so.6

# Check glibc version
ldd --version

# Or:
/lib/x86_64-linux-gnu/libc.so.6
```

## 8.10 Direct Syscall vs. libc Wrapper Examples

### 8.10.1 File Operations

**Using libc wrapper**:
```c
#include <stdio.h>

int main(void) {
    FILE *f = fopen("hello.txt", "w");
    if (f) {
        fprintf(f, "Hello, world!\n");
        fclose(f);
    }
    return 0;
}
```

**Using raw syscalls**:
```c
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

int main(void) {
    int fd = open("hello.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        const char msg[] = "Hello, world!\n";
        write(fd, msg, sizeof(msg) - 1);
        close(fd);
    }
    return 0;
}
```

**Key differences**:
- libc version uses `FILE*` abstraction and buffering
- syscall version uses file descriptors (integers)
- libc version is more portable (same code works on Windows with different libc)

### 8.10.2 Time Measurement

**Using libc wrapper**:
```c
#include <time.h>

int main(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return 0;
}
```

**Using raw syscall**:
```c
#include <unistd.h>
#include <sys/syscall.h>
#include <time.h>

int main(void) {
    struct timespec ts;
    syscall(__NR_clock_gettime, CLOCK_REALTIME, &ts);
    return 0;
}
```

Note: `clock_gettime` is both a libc function AND a syscall wrapper. Some functions are thin wrappers!

## 8.11 The VDSO: Virtual Dynamically-linked Shared Object

There's a special "shared library" that's not really a file: **vdso** (virtual dynamic shared object).

```bash
ldd /bin/ls | grep vdso
```

Output:
```
    linux-vdso.so.1 (0x00007ffc12345000)
```

**What is vdso?**

The vdso is a memory region mapped by the kernel into every process. It contains code that runs in user space but is provided by the kernel.

**Purpose**: Accelerate certain "syscalls" that don't actually need kernel mode

Example: `gettimeofday`

**Old approach** (expensive):
```
user space → syscall → kernel → copy time to user → return to user space
```

**New approach** (fast):
```
user space → read data from vdso (no syscall!)
```

The kernel maps a page of memory into each process that contains:
- The current time
- A function to read it efficiently
- Other frequently-needed data

Programs can call `gettimeofday` without entering the kernel!

## 8.12 Key Takeaways

1. **libc is not the kernel**: The C standard library runs in user space and provides wrappers around system calls, adding buffering, error handling, and abstraction.

2. **System calls are the kernel interface**: Syscalls are the only legitimate way for user programs to access kernel resources like files, network, and process creation.

3. **Most C functions are not syscalls**: Functions like `printf`, `malloc`, and `strlen` run entirely in user space. Only some operations trigger actual syscalls.

4. **Syscalls are expensive**: Mode switches between user and kernel mode cost ~500-2000 nanoseconds, much more than function calls. libc buffering amortizes this cost.

5. **Error reporting via errno**: When syscalls fail, libc sets the global `errno` variable (thread-local) to indicate the specific error.

6. **strace reveals syscalls**: The `strace` tool shows exactly which syscalls a program makes, invaluable for debugging and performance analysis.

7. **Raw syscalls are architecture-specific**: Syscall numbers and calling conventions vary by architecture. libc provides portability by hiding these details.

8. **The vdso accelerates "syscalls"**: Some operations like `gettimeofday` don't actually need kernel mode—the vdso provides data in user space.

9. **Buffering happens in libc**: Functions like `printf` buffer output to reduce the number of `write` syscalls, dramatically improving performance.

10. **Use libc unless you have a reason not to**: For most programs, libc wrappers provide the right combination of portability, performance, and convenience.

## 8.13 Looking Ahead

In Chapter 9, we'll explore **ABIs (Application Binary Interfaces)** and cross-platform compilation. We'll see how calling conventions, data structure layout, and system call differences affect binary compatibility across architectures and operating systems.

## Further Reading

- `man 2 syscalls` - Overview of Linux system calls
- `man 3 errno` - Error reporting in libc
- `man 1 strace` - System call tracer
- `man 7 vdso` - Virtual dynamic shared object
- Linux Kernel Documentation - `Documentation/process/coding-style.rst`
- "The Linux Programming Interface" by Michael Kerrisk - Comprehensive guide to Linux system programming
- glibc source code - Available at https://sourceware.org/git/glibc.git
