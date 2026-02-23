# Experiment: Observe syscalls from a C program

## Objective
- Use `strace` to see how libc calls translate into kernel syscalls.

## Setup requirements
- Linux or WSL.
- strace installed.

## Step-by-step commands
1. Create a program that writes to stdout:
   ```c
   #include <stdio.h>
   int main(void) { puts("hello"); return 0; }
   ```
2. Build the program:
   ```bash
   gcc -o hello hello.c
   ```
3. Trace syscalls:
   ```bash
   strace -o trace.txt ./hello
   ```
4. Inspect `trace.txt` for `write` and `exit` calls.

## Expected output explanation
- `puts` becomes one or more `write` syscalls.
- Process termination triggers `exit` or `exit_group`.

## Questions for reader
1. Which syscalls appear before `main` executes?
2. How many write calls occur and why?
3. How does buffering change the syscall pattern?
