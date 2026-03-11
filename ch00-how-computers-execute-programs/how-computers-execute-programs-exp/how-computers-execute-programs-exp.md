# Experiment: Inspect CPU Execution and Stack Frames

## Objective

This experiment will help you understand how C programs execute at the hardware level by:
1. Examining generated assembly code to see CPU instructions
2. Observing stack frame layout and function call mechanics
3. Understanding register usage and calling conventions
4. Analyzing memory addresses and endianness

## Setup Requirements

- C compiler (gcc or clang)
- Linux or WSL is recommended for consistent assembly output
- Basic familiarity with command line tools
- Debugger (gdb) optional but helpful

## Experiment 1: Generate and Inspect Assembly Code

### Step 1: Create a Test Program

Create a file called `add.c`:

```c
int add(int a, int b) {
    int result = a + b;
    return result;
}

int main(void) {
    int sum = add(5, 3);
    return sum == 8 ? 0 : 1;
}
```

### Step 2: Generate Assembly Output

Generate assembly code with frame pointers preserved (for clarity):

```bash
gcc -S -fno-omit-frame-pointer -O0 -o add.s add.c
```

### Step 3: Examine the Assembly File

Open `add.s` in your text editor:

```bash
cat add.s
```

**What to look for:**

1. **Function prologue** in `add`:
   ```assembly
   push   rbp            # Save caller's frame pointer
   mov    rbp, rsp       # Establish new frame pointer
   ```

2. **Argument passing**:
   - On x86-64 with System V ABI: `edi` contains first argument (a), `esi` contains second (b)

3. **Return value**:
   - The sum is placed in `eax` before returning

4. **Function epilogue**:
   ```assembly
   pop    rbp            # Restore caller's frame pointer
   ret                   # Return to caller
   ```

### Step 4: Compile and Run

```bash
gcc -o add add.c
./add
echo "Exit code: $?"
```

Expected exit code: 0 (success)

## Experiment 2: Examine Stack Frame Layout

### Step 1: Create a Program with Local Variables

Create `stack_demo.c`:

```c
int demonstrate_stack(int x) {
    int local1 = x * 2;
    int local2 = x + 10;
    return local1 + local2;
}

int main(void) {
    return demonstrate_stack(5);
}
```

### Step 2: Generate Assembly

```bash
gcc -S -fno-omit-frame-pointer -O0 -o stack_demo.s stack_demo.c
cat -n stack_demo.s | grep -A 20 "demonstrate_stack"
```

**What to observe:**

1. **Stack allocation**:
   ```assembly
   sub    rsp, 16        # Allocate space for local variables
   ```

2. **Local variable access**:
   - `local1` at `[rbp-4]`
   - `local2` at `[rbp-8]`

3. **Stack frame structure**:
   ```
   Higher addresses
   ┌─────────────────┐
   │  Saved RBP      │ ← rbp points here
   ├─────────────────┤
   │  local1         │ ← rbp-4
   ├─────────────────┤
   │  local2         │ ← rbp-8
   ├─────────────────┤
   │  (padding)      │
   └─────────────────┘
   Lower addresses
   ```

## Experiment 3: Explore Endianness

### Step 1: Create Endianness Test Program

Create `endianness.c`:

```c
#include <stdio.h>

int main(void) {
    unsigned int value = 0x12345678;
    unsigned char *bytes = (unsigned char *)&value;

    printf("Value: 0x%x\n", value);
    printf("Byte 0: 0x%02x\n", bytes[0]);
    printf("Byte 1: 0x%02x\n", bytes[1]);
    printf("Byte 2: 0x%02x\n", bytes[2]);
    printf("Byte 3: 0x%02x\n", bytes[3]);

    if (bytes[0] == 0x78) {
        printf("System is: Little-endian\n");
    } else if (bytes[0] == 0x12) {
        printf("System is: Big-endian\n");
    }

    return 0;
}
```

### Step 2: Compile and Run

```bash
gcc -o endianness endianness.c
./endianness
```

**Expected output on x86-64:**
```
Value: 0x12345678
Byte 0: 0x78
Byte 1: 0x56
Byte 2: 0x34
Byte 3: 0x12
System is: Little-endian
```

**Analysis:**
- The least significant byte (0x78) is stored at the lowest memory address
- This is characteristic of little-endian architecture

## Experiment 4: Trace Register Usage with GDB (Optional)

### Step 1: Create a Debuggable Program

Create `registers.c`:

```c
int multiply(int a, int b) {
    return a * b;
}

int main(void) {
    int result = multiply(7, 6);
    return result == 42 ? 0 : 1;
}
```

### Step 2: Compile with Debug Symbols

```bash
gcc -g -o registers registers.c
```

### Step 3: Debug with GDB

```bash
gdb ./registers
```

In GDB, run these commands:

```
(gdb) break main
(gdb) break multiply
(gdb) run
(gdb) info registers rdi rsi rdx rcx r8 r9  # Check argument registers
(gdb) step
(gdb) info registers rax rbx rcx rdx        # Check result register
(gdb) continue
(gdb) quit
```

**What to observe:**
- Before calling `multiply`: arguments in `rdi` (7) and `rsi` (6)
- After `multiply` returns: result (42) in `eax`
- The calling convention in action!

## Experiment 5: Observe Stack Growth

### Step 1: Create Recursive Function

Create `recursion.c`:

```c
#include <stdio.h>

int recursive_depth(int depth) {
    int local = depth * 10;
    if (depth <= 0) {
        return local;
    }
    return local + recursive_depth(depth - 1);
}

int main(void) {
    int result = recursive_depth(5);
    printf("Result: %d\n", result);
    return 0;
}
```

### Step 2: Generate Assembly

```bash
gcc -S -fno-omit-frame-pointer -O0 -o recursion.s recursion.c
cat recursion.s | grep -A 5 "recursive_depth:"
```

**What to observe:**
1. Each recursive call creates a new stack frame
2. The `call` instruction pushes the return address
3. The `push rbp` instruction saves the previous frame pointer
4. Stack grows downward (toward lower addresses)

### Step 3: Visualize Stack Layout

```
Call: recursive_depth(5)
┌─────────────────────────┐
│ recursive_depth(0)      │ ← Stack top (lowest address)
│ - local = 0             │
│ - saved RBP             │
│ - return address        │
├─────────────────────────┤
│ recursive_depth(1)      │
│ - local = 10            │
│ - saved RBP             │
│ - return address        │
├─────────────────────────┤
│ recursive_depth(2)      │
│ - local = 20            │
│ - saved RBP             │
│ - return address        │
├─────────────────────────┤
│ ...                     │
├─────────────────────────┤
│ recursive_depth(5)      │ ← Stack bottom (highest address)
│ - local = 50            │
│ - saved RBP             │
│ - return address        │
└─────────────────────────┘
```

## Experiment 6: Compare Optimized vs. Unoptimized Code

### Step 1: Create Optimization Test

Create `optimization.c`:

```c
int calculate(int a, int b, int c) {
    int temp1 = a + b;
    int temp2 = temp1 * c;
    int temp3 = temp2 - a;
    return temp3;
}

int main(void) {
    return calculate(5, 3, 2);
}
```

### Step 2: Generate Unoptimized Assembly

```bash
gcc -S -O0 -fno-omit-frame-pointer -o opt_unopt.s optimization.c
wc -l opt_unopt.s
```

### Step 3: Generate Optimized Assembly

```bash
gcc -S -O2 -o opt_opt.s optimization.c
wc -l opt_opt.s
```

### Step 4: Compare

```bash
diff -y opt_unopt.s opt_opt.s | head -30
```

**What to observe:**
- Unoptimized code: More instructions, explicit stack operations
- Optimized code: Fewer instructions, more register usage, possibly inlined
- The optimizer removes unnecessary temporaries
- Register allocation is more efficient

## Experiment 7: Examine Calling Convention with Many Arguments

### Step 1: Create Multi-Argument Function

Create `many_args.c`:

```c
long many_arguments(long a, long b, long c, long d,
                    long e, long f, long g, long h) {
    return a + b + c + d + e + f + g + h;
}

int main(void) {
    return (int)many_arguments(1, 2, 3, 4, 5, 6, 7, 8);
}
```

### Step 2: Generate Assembly

```bash
gcc -S -O0 -fno-omit-frame-pointer -o many_args.s many_args.c
cat -n many_args.s | grep -A 30 "many_arguments:"
```

**What to observe (System V AMD64 ABI):**

Arguments 1-6: Passed in registers
- `a` (1) → `rdi`
- `b` (2) → `rsi`
- `c` (3) → `rdx`
- `d` (4) → `rcx`
- `e` (5) → `r8`
- `f` (6) → `r9`

Arguments 7-8: Passed on the stack
- `g` (7) → `[rsp+8]`
- `h` (8) → `[rsp+16]`

This demonstrates the hybrid argument passing strategy!

## Questions for Reader

### Basic Understanding

1. **Register Identification**: Which register holds the return value for integer functions on x86-64?

2. **Stack Growth**: Does the stack grow toward higher or lower addresses? How can you tell from the assembly?

3. **Frame Pointer**: What is the purpose of `rbp`? Why do some optimized code omit it?

4. **Argument Passing**: In the System V AMD64 ABI, where are the first 6 integer arguments passed?

### Intermediate Understanding

5. **Prologue/Epilogue**: Explain the purpose of each instruction in the function prologue and epilogue.

6. **Endianness Impact**: If you write an `int` value to a file and read it on a machine with different endianness, what happens?

7. **Register Preservation**: What's the difference between caller-saved and callee-saved registers?

8. **Stack Alignment**: Why is 16-byte stack alignment important on x86-64?

### Advanced Understanding

9. **Optimization Impact**: How does optimization level (-O0 vs -O2) affect the generated assembly? What transformations do you see?

10. **Debugging Role**: Why are frame pointers useful for debugging, even though they consume an extra register?

11. **ABI Compatibility**: Why can't you always link object files compiled for Windows and Linux together?

12. **Performance**: In the many-arguments example, why do you think the first 6 arguments are passed in registers but the rest go on the stack?

## Challenge Exercises

### Challenge 1: Stack Overflow

Create a program that causes a stack overflow. Observe the error message. Then modify it to use heap allocation instead and compare the behavior.

```c
// Template to start
void infinite_recursion(void) {
    char buffer[1024];
    // What happens if you call recursively?
    infinite_recursion();
}
```

### Challenge 2: ABI Investigation

Research and implement the same simple function for two different ABIs (e.g., System V AMD64 vs. Microsoft x64). Compare the assembly output and document the differences.

### Challenge 3: Custom Calling Convention

Implement a function call using inline assembly that uses a non-standard calling convention. Document why this might be useful or dangerous.

```c
// Template: Call a function with arguments in unusual registers
void my_function(int a, int b, int c);

int main(void) {
    int result;
    // Use inline assembly to call my_function
    // with arguments in r10, r11, r12 instead
    // of rdi, rsi, rdx
    return 0;
}
```

## Summary

Through these experiments, you should now understand:

1. **CPU Execution Model**: How the fetch-decode-execute cycle works
2. **Register Usage**: How registers are used for arguments, return values, and temporary storage
3. **Stack Mechanics**: How stack frames are created and destroyed
4. **Calling Conventions**: The rules that govern function calls
5. **Memory Organization**: How data is stored in memory (endianness)
6. **Optimization Impact**: How compilers transform code for efficiency

These fundamentals are crucial for understanding how C code gets compiled and executed, which we'll explore in depth throughout the rest of this book.
