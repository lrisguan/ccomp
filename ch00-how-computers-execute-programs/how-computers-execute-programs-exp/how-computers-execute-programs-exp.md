# Experiment: Inspect stack frames in generated assembly

## Objective
- Observe how a simple function call maps to stack usage and return control flow.

## Setup requirements
- C compiler (gcc or clang).
- Linux or WSL is recommended for consistent assembly output.

## Step-by-step commands
1. Create a small program:
   ```c
   int add(int a, int b) { return a + b; }
   int main(void) { return add(1, 2); }
   ```
2. Generate assembly with frame pointers:
   ```bash
   gcc -S -fno-omit-frame-pointer -O0 -o demo.s demo.c
   ```
3. Open `demo.s` and locate the function prologue and epilogue.

## Expected output explanation
- The prologue sets up a stack frame and preserves the old frame pointer.
- The epilogue restores the frame pointer and returns to the caller.

## Questions for reader
1. Which register holds the frame pointer on your target architecture?
2. How are arguments passed into `add` in the assembly output?
3. Where is the return value placed?
