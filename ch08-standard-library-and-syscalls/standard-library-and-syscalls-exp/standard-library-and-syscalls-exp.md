# Experiment: Observe syscalls from a C program

## Objective
- Use `strace` to see how libc calls translate into kernel syscalls.
- Compare libc wrappers vs. raw syscalls.
- Understand buffering and its effect on syscalls.
- Examine the cost of syscalls vs. user-space operations.

## Setup requirements
- Linux or WSL.
- strace installed.
- gcc or clang compiler.

## Step-by-step commands

### Part 1: Basic Syscall Tracing

1. Create a simple program that writes to stdout:
   ```c
   // hello.c
   #include <stdio.h>
   int main(void) {
       puts("hello");
       return 0;
   }
   ```

2. Build the program:
   ```bash
   gcc -o hello hello.c
   ```

3. Trace syscalls:
   ```bash
   strace ./hello
   ```

4. Observe:
   - `execve`: The program being loaded
   - `brk`/`mmap`: Memory allocation for libc
   - `write`: The actual output (only one!)
   - `exit_group`: Process termination

### Part 2: Compare libc vs. Raw Syscalls

5. Create a version using raw syscalls:
   ```c
   // hello_raw.c
   #include <unistd.h>
   #include <sys/syscall.h>

   int main(void) {
       const char msg[] = "hello from raw syscall\n";
       syscall(__NR_write, 1, msg, sizeof(msg) - 1);
       return 0;
   }
   ```

6. Build and trace:
   ```bash
   gcc -o hello_raw hello_raw.c
   strace ./hello_raw
   ```

7. Compare the traces:
   - Raw version makes fewer syscalls (no libc initialization overhead)
   - Both use the `write` syscall for output

### Part 3: Buffering Effects

8. Create unbuffered vs. buffered programs:
   ```c
   // unbuffered.c
   #include <stdio.h>
   int main(void) {
       setbuf(stdout, NULL);  // Disable buffering
       for (int i = 0; i < 10; i++) {
           printf("x");
       }
       return 0;
   }
   ```

   ```c
   // buffered.c
   #include <stdio.h>
   int main(void) {
       for (int i = 0; i < 10; i++) {
           printf("x");
       }
       return 0;
   }
   ```

9. Build and trace both:
   ```bash
   gcc -o unbuffered unbuffered.c
   gcc -o buffered buffered.c
   strace -e trace=write ./unbuffered 2>&1 | grep write
   strace -e trace=write ./buffered 2>&1 | grep write
   ```

10. Count write syscalls:
    - Unbuffered: 10 write syscalls (one per character)
    - Buffered: 1 write syscall (all characters batched)

### Part 4: File I/O Comparison

11. Create file write programs:
    ```c
    // file_stdio.c
    #include <stdio.h>
    int main(void) {
        FILE *f = fopen("test_stdio.txt", "w");
        if (f) {
            for (int i = 0; i < 1000; i++) {
                fprintf(f, "Line %d\n", i);
            }
            fclose(f);
        }
        return 0;
    }
   ```

    ```c
    // file_syscall.c
    #include <fcntl.h>
    #include <unistd.h>
    #include <string.h>

    int main(void) {
        int fd = open("test_syscall.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd >= 0) {
            char buffer[128];
            for (int i = 0; i < 1000; i++) {
                int len = snprintf(buffer, sizeof(buffer), "Line %d\n", i);
                write(fd, buffer, len);
            }
            close(fd);
        }
        return 0;
    }
   ```

12. Build and trace:
    ```bash
    gcc -o file_stdio file_stdio.c
    gcc -o file_syscall file_syscall.c
    strace -e trace=write,open,openat ./file_stdio 2>&1 | wc -l
    strace -e trace=write,open,openat ./file_syscall 2>&1 | wc -l
   ```

13. Compare syscall counts:
    - stdio version: Fewer syscalls (buffering)
    - syscall version: More syscalls (one write per loop iteration)

### Part 5: Memory Allocation

14. Create allocation test:
    ```c
    // malloc_test.c
    #include <stdio.h>
    #include <stdlib.h>

    int main(void) {
        // Allocate many small blocks
        for (int i = 0; i < 100; i++) {
            void *p = malloc(64);
            if (p) printf("Allocated block %d\n", i);
        }
        return 0;
    }
   ```

15. Trace memory syscalls:
    ```bash
    gcc -o malloc_test malloc_test.c
    strace -e trace=brk,mmap,munmap ./malloc_test
   ```

16. Observe:
    - Initial `brk`/`mmap` to set up heap
    - Subsequent `malloc` calls don't trigger syscalls (use existing heap)
    - libc manages the heap, only asking kernel for more memory when needed

### Part 6: Examining errno

17. Create error test:
    ```c
    // errno_test.c
    #include <stdio.h>
    #include <errno.h>
    #include <string.h>

    int main(void) {
        FILE *f = fopen("/nonexistent/path/to/file", "r");
        if (f == NULL) {
            printf("Error: %s (errno=%d)\n", strerror(errno), errno);
        }
        return 0;
    }
   ```

18. Build and trace:
    ```bash
    gcc -o errno_test errno_test.c
    ./errno_test
    ```

19. Observe:
    - Program prints error message with errno code
    - errno is set by libc based on kernel error return

### Part 7: Performance Comparison

20. Create benchmark:
    ```c
    // benchmark.c
    #include <stdio.h>
    #include <unistd.h>
    #include <sys/syscall.h>
    #include <time.h>

    #define ITERATIONS 10000

    double benchmark_libc(void) {
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        for (int i = 0; i < ITERATIONS; i++) {
            printf("x");
        }
        clock_gettime(CLOCK_MONOTONIC, &end);
        return (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    }

    double benchmark_syscall(void) {
        struct timespec start, end;
        const char msg[] = "x";
        clock_gettime(CLOCK_MONOTONIC, &start);
        for (int i = 0; i < ITERATIONS; i++) {
            syscall(__NR_write, 1, msg, 1);
        }
        clock_gettime(CLOCK_MONOTONIC, &end);
        return (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    }

    int main(void) {
        printf("Benchmarking %d iterations...\n", ITERATIONS);

        // Libc version (buffered)
        double libc_time = benchmark_libc();
        printf("\nLibc printf: %.6f seconds\n", libc_time);

        // Raw syscall version
        double syscall_time = benchmark_syscall();
        printf("Raw syscall: %.6f seconds\n", syscall_time);

        printf("Speedup: %.2fx\n", syscall_time / libc_time);
        return 0;
    }
   ```

21. Build and run:
    ```bash
    gcc -o benchmark benchmark.c -lrt
    ./benchmark
   ```

22. Observe:
    - libc version is much faster (buffering reduces syscalls)
    - Raw syscall version is slow (one syscall per iteration)

### Part 8: Examining vdso

23. Check for vdso:
    ```bash
    ldd ./hello | grep vdso
    ```

24. Examine vdso content:
    ```bash
    # Look at memory mappings
    cat /proc/self/maps | grep vdso
    ```

25. The vdso provides:
    - Fast gettimeofday (no syscall needed)
    - Fast clock_gettime
    - Other "virtual" syscalls that don't need kernel mode

## Expected output explanation

### Part 1: Basic Syscall Tracing

Typical strace output:
```
execve("./hello", ["./hello"], 0x7ffc...) = 0
brk(NULL)                               = 0x55555000
brk(0x55556c000)                        = 0x55556c000
mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7ffff...
write(1, "hello\n", 6)                  = 6
exit_group(0)                           = ?
+++ exited with 0 +++
```

- `execve`: Loads the program
- `brk`/`mmap`: Sets up memory for libc
- `write`: Actual output (6 bytes = "hello\n")
- `exit_group`: Terminates the process

### Part 2: libc vs. Raw Syscalls

- Raw version has less startup overhead (no libc initialization)
- Both use the same `write` syscall for output
- libc version is more portable and convenient

### Part 3: Buffering Effects

- **Unbuffered**: 10 write syscalls (very slow!)
- **Buffered**: 1 write syscall (much faster)
- This demonstrates why libc buffering is important

### Part 4: File I/O Comparison

- **stdio version**: ~10-20 write syscalls (buffering groups writes)
- **syscall version**: 1000 write syscalls (one per iteration)
- stdio is ~50-100x faster for this workload!

### Part 5: Memory Allocation

- First `malloc`: Triggers `brk`/`mmap` to get memory from kernel
- Subsequent `malloc`: No syscalls! (uses existing heap)
- libc manages the heap efficiently

### Part 6: errno

- Output: "Error: No such file or directory (errno=2)"
- errno is set by libc when kernel returns error
- strerror converts errno to human-readable message

### Part 7: Performance

- libc version: ~0.001 seconds (buffered, few syscalls)
- syscall version: ~0.100 seconds (10,000 syscalls!)
- Speedup: ~100x faster with libc buffering

### Part 8: vdso

- `ldd` shows: `linux-vdso.so.1 (0x00007ffc12345000)`
- vdso is mapped into every process
- Provides fast "syscalls" that don't need kernel mode

## Questions for reader

### Basic Understanding

1. **Syscall identification**: In the strace output, which line corresponds to the `puts` call in your program? How do you know?

2. **Buffering effect**: Why does the unbuffered version make more write syscalls than the buffered version?

3. **Memory allocation**: Why don't all `malloc` calls trigger syscalls? How does libc avoid unnecessary kernel interactions?

4. **Error reporting**: How does the kernel communicate errors to user space? How does libc convert this to errno?

### Intermediate Understanding

5. **Startup overhead**: What syscalls occur before `main` executes? Why are they necessary?

6. **Performance impact**: Based on the benchmark, how much slower are syscalls compared to user-space operations?

7. **Portability**: What are the advantages of using libc wrappers instead of raw syscalls?

8. **vdso purpose**: Why does the vdso exist? What operations benefit from not needing actual syscalls?

### Advanced Understanding

9. **Buffering strategy**: When might you want to disable buffering (setbuf with NULL)? What are the trade-offs?

10. **Direct syscalls**: In what situations would you use raw syscalls instead of libc wrappers?

11. **Thread safety**: How does errno work in multithreaded programs? (Hint: is it a true global variable?)

12. **System call latency**: Estimate the cost of a syscall from your benchmark. How does this compare to a function call?

## Challenge Exercises

### Challenge 1: Count All Syscalls

Create a program and count all syscalls it makes:
```bash
strace -c ./your_program
```

Which syscalls are most common? Can you optimize your program to reduce syscall count?

### Challenge 2: Implement Simple Buffering

Implement your own buffering layer on top of `write`:
```c
// Implement a buffered writer
typedef struct {
    char buffer[4096];
    size_t pos;
} BufferedWriter;

void buffered_write(BufferedWriter *w, const char *data, size_t len);
void buffered_flush(BufferedWriter *w);
```

Compare performance with libc's buffering.

### Challenge 3: Cross-Platform Syscalls

Research how syscall numbers differ across architectures:
- x86-64 vs x86 (32-bit)
- ARM64 vs x86-64

Write a program that uses raw syscalls and make it work on two different architectures.

### Challenge 4: strace Performance Analysis

Use strace to analyze a real program's performance:
```bash
strace -T -tt ./your_program
```

- `-T`: Show time spent in each syscall
- `-tt`: Microsecond timestamps

Which syscalls take the most time? Can you optimize them?

## Summary

Through this experiment, you should understand:

1. **libc vs. kernel**: Most C library functions are user-space code that may eventually trigger syscalls, but many operations (like strlen, malloc from existing heap, etc.) don't require kernel interaction.

2. **Syscalls are expensive**: System calls cost ~500-2000 nanoseconds, much more than function calls. This is why libc buffering is so important for performance.

3. **Buffering matters**: libc's stdio buffering can reduce syscall count by orders of magnitude, dramatically improving performance for I/O operations.

4. **strace is powerful**: The strace tool reveals exactly which syscalls a program makes, invaluable for debugging and performance analysis.

5. **Error reporting**: The kernel returns error codes in registers; libc converts these to errno for easier error handling.

6. **Memory management**: malloc/free mostly manage user-space heap, only calling brk/mmap when more memory is needed from the kernel.

7. **vdso optimization**: Some operations like gettimeofday don't actually need syscalls—the vdso provides fast user-space access to kernel data.

8. **Portability**: libc wrappers hide architecture-specific syscall details, making your code portable across different platforms.

Understanding the boundary between libc and the kernel is essential for writing efficient, portable C programs and for debugging system-level issues.
