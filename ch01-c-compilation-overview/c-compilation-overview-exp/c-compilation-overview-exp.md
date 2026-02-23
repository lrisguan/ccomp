# Experiment: Trace the full compilation pipeline

## Objective
- Produce each intermediate artifact and identify the tool responsible for it.

## Setup requirements
- gcc or clang installed.
- Linux or WSL recommended.

## Step-by-step commands
1. Create a minimal program:
   ```c
   #include <stdio.h>
   int main(void) { puts("hi"); return 0; }
   ```
2. Generate preprocessed output:
   ```bash
   gcc -E -o hello.i hello.c
   ```
3. Generate assembly:
   ```bash
   gcc -S -o hello.s hello.c
   ```
4. Assemble to object file:
   ```bash
   gcc -c -o hello.o hello.s
   ```
5. Link to executable:
   ```bash
   gcc -o hello hello.o
   ```

## Expected output explanation
- `hello.i` is expanded C after preprocessing.
- `hello.s` is target assembly.
- `hello.o` is a relocatable object file.
- `hello` is the final linked executable.

## Questions for reader
1. Which step introduces symbols that the linker resolves?
2. How large is each artifact and why does the size change?
3. Which tools can be swapped out in this pipeline?
