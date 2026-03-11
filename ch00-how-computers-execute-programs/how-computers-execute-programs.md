# Chapter 0: How Computers Execute Programs

## Introduction

Before diving into the intricacies of C compilation, we need to understand what happens *after* compilation—when your program actually runs on a physical processor. This chapter establishes the fundamental execution model of modern computers: how CPUs execute instructions, how memory is organized, and how function calls work at the hardware level.

Why start here? Because understanding the target execution model explains *why* compilers make the decisions they do. Every optimization, every register allocation, and every function call convention exists to serve the underlying hardware architecture.

## 0.1 The CPU Execution Model

### 0.1.1 What is a CPU?

A Central Processing Unit (CPU) is a state machine that repeatedly fetches, decodes, and executes instructions. At its core, a CPU has:

1. **Registers**: Fast storage locations within the CPU
2. **Arithmetic Logic Unit (ALU)**: Performs mathematical and logical operations
3. **Control Unit**: Orchestrates the instruction cycle
4. **Buses**: Connect the CPU to memory and other components

The CPU maintains a piece of architectural state that gets updated with each instruction execution. Think of this state as the CPU's "working memory"—everything it needs to know about the current program's execution.

### 0.1.2 The Instruction Cycle

The CPU operates through a continuous loop called the **instruction cycle** (also known as the fetch-decode-execute cycle):

```
┌─────────────────────────────────────────────────────────────┐
│                    Instruction Cycle                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐   │
│  │  FETCH  │ -> │ DECODE  │ -> │ EXECUTE │ -> │  WRITE  │   │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘   │
│       │                              │                      │
│       └──────────────────────────────┘                      │
│              Update Program Counter                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Let's break down each stage:

#### Fetch
The CPU reads the next instruction from memory at the address stored in the **Program Counter (PC)** register (also called the Instruction Pointer or IP). After fetching, the PC is incremented to point to the next instruction.

#### Decode
The CPU interprets the fetched bits to determine:
- What operation to perform (add, subtract, jump, etc.)
- Which registers to use
- What memory addresses to access (if any)

#### Execute
The CPU actually performs the operation:
- Arithmetic calculations in the ALU
- Memory reads or writes
- Conditional checks that affect control flow

#### Writeback (optional)
Many instructions write results back to registers or memory, updating the architectural state.

### 0.1.3 Architectural State

The **architectural state** is the set of all registers and flags that define the current execution context:

```
┌─────────────────────────────────────────────────────────────┐
│                   Architectural State                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  General Purpose Registers:                                 │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐            │
│  │ RAX │ │ RBX │ │ RCX │ │ RDX │ │ RSI │ │ RDI │  ...       │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘            │
│                                                             │
│  Special Registers:                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │     RIP     │ │     RSP     │ │     RBP     │            │
│  │ (Instr Ptr) │ │ (Stack Ptr) │ │(Frame Ptr)  │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
│                                                             │
│  Status Flags:                                              │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐            │
│  │  CF │ │  ZF │ │  SF │ │  OF │ │  PF │ │  AF │            │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

This state is crucial because:
- **Function calls** preserve parts of this state
- **Context switches** save and restore this state
- **Debuggers** inspect this state to show program behavior

## 0.2 Registers: The CPU's Working Memory

Registers are the fastest storage available in a computer. They're built directly into the CPU hardware and can be accessed in a single clock cycle. Modern CPUs have two main categories of registers:

### 0.2.1 General-Purpose Registers (GPRs)

Despite the name, these registers aren't truly "general purpose"—conventions and hardware features give each register specific roles.

On x86-64 (the architecture used by most modern desktop and server computers):

| Register | Name                | Special Use                            |
|----------|---------------------|----------------------------------------|
| RAX      | Accumulator         | Return values for functions            |
| RBX      | Base                | Callee-saved register                  |
| RCX      | Counter             | Used for loops and string operations   |
| RDX      | Data                | Used for multiplication/division       |
| RSI      | Source Index        | Source for string operations           |
| RDI      | Destination Index   | Destination for string operations      |
| RSP      | Stack Pointer       | Points to top of stack                 |
| RBP      | Base Pointer        | Points to current stack frame          |
| R8-R15   | Extended registers  | Additional general-purpose registers   |

> **Historical Note**: The "R" prefix denotes 64-bit registers in x86-64. Originally, these were 16-bit registers (AX, BX, etc.), then extended to 32-bit (EAX, EBX), and finally to 64-bit (RAX, RBX). You can still access the lower portions of these registers: RAX contains EAX, which contains AX, which contains AH (high byte) and AL (low byte).

### 0.2.2 Special-Purpose Registers

Some registers have dedicated functions:

**Program Counter (RIP on x86-64)**
- Holds the memory address of the *next* instruction to execute
- Automatically updated after most instructions
- Can be explicitly modified by jump, call, and return instructions

**Stack Pointer (RSP on x86-64)**
- Points to the top of the stack (specifically, the lowest address in the current stack frame)
- Grows downward (toward lower addresses) on most architectures
- Crucial for function calls and local variable storage

**Flags Register (RFLAGS)**
- Contains individual bits (flags) set by arithmetic operations
- Key flags include:
  - **ZF (Zero Flag)**: Set if the result was zero
  - **SF (Sign Flag)**: Set if the result was negative (in two's complement)
  - **CF (Carry Flag)**: Set if an operation overflowed its destination
  - **OF (Overflow Flag)**: Set if signed overflow occurred

These flags enable conditional branching (like `if` statements and loops).

### 0.2.3 Caller-Saved vs. Callee-Saved Registers

One of the most important conventions in modern programming is the division of registers into **caller-saved** and **callee-saved** registers. This convention makes function calls efficient.

**Caller-saved registers** (also called volatile registers):
- Can be overwritten by a called function
- If the caller needs to preserve a value, it must save it before calling
- On x86-64: RAX, RCX, RDX, RSI, RDI, R8-R11

**Callee-saved registers** (also called non-volatile registers):
- Must be preserved by functions that modify them
- If a function wants to use these registers, it must save the original value and restore it before returning
- On x86-64: RBX, RBP, R12-R15

> **Why this matters**: This convention is part of the **calling convention** or **ABI** (Application Binary Interface). When a C compiler generates code, it knows which registers it can use freely and which it must preserve. Chapter 9 covers ABIs in detail.

## 0.3 The Memory Model

### 0.3.1 Memory as a Giant Byte Array

From the CPU's perspective, memory is a contiguous array of bytes, each with a unique address. On a 64-bit system, addresses range from 0 to 2^64-1 (though in practice, only about 48 bits are used currently).

```
Address  Contents
┌─────────────────────────────────────────────┐
│ 0x0000...0000  │ ?                          │
│ 0x0000...0001  │ ?                          │
│ 0x0000...0002  │ ?                          │
│ 0x0000...0003  │ ?                          │
│     ...        │                            │
│ 0x7FFF...0000  │ (often stack start)        │
│     ...        │                            │
└─────────────────────────────────────────────┘
```

**Key properties:**

1. **Byte-addressability**: Each byte has a unique address
2. **Word size**: The CPU typically accesses memory in chunks (e.g., 4 bytes at a time on a 32-bit system, 8 bytes on 64-bit)
3. **Alignment**: Accessing multi-byte values from addresses that are multiples of their size is faster (and sometimes required)

### 0.3.2 Endianness

When a multi-byte value is stored in memory, there's a choice: which byte goes at the lowest address? This is called **endianness**.

**Little-endian** (used by x86 and x86-64):
- The least significant byte is stored at the lowest address
- Example: 0x12345678 stored as `78 56 34 12`

```
Address:   0x1000  0x1001  0x1002  0x1003
Content:    0x78    0x56    0x34    0x12
                              ↑
                          Least significant byte
```

**Big-endian** (used by some network protocols and older architectures):
- The most significant byte is stored at the lowest address
- Example: 0x12345678 stored as `12 34 56 78`

> **Practical Impact**: Endianness matters when:
> - Reading binary files created on different architectures
> - Implementing network protocols (network byte order is big-endian)
> - Debugging memory dumps

### 0.3.3 Virtual Memory

Modern operating systems use **virtual memory**, which gives each process the illusion of having its own private address space. The CPU's Memory Management Unit (MMU) translates virtual addresses to physical addresses transparently.

**Benefits:**
- **Isolation**: Processes can't access each other's memory
- **Protection**: Pages can be marked read-only or execute-only
- **Efficiency**: Only loaded portions of a program need to be in physical memory
- **Simplicity**: Each program can use the same address range (e.g., stack always starting at a high address)

We'll explore virtual memory in depth in Chapter 10.

## 0.4 The Stack and Function Calls

### 0.4.1 What is the Stack?

The **stack** is a region of memory used for:
- Function call frames
- Local variables
- Return addresses
- Temporary storage

The stack grows **downward** (toward lower addresses), and the stack pointer (RSP) always points to the *lowest* used address (the "top" of the stack).

```
     High Addresses
      ┌───────────┐
      │           │  ↑
      │  Stack    │  │ Grows downward
      │           │  │ (toward lower addresses)
      │   ...     │  │
      │           │  ↓
      └───────────┘
     Low Addresses
```

### 0.4.2 Stack Frames

Each function call creates a **stack frame** (also called an activation record). The frame contains:

```
┌────────────────────────────────────────────────────────┐
│                 Stack Frame Structure                  │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Previous Frame    ┌───────────────────────────────┐   │
│                    │ Saved RBP (old frame pointer) │   │ ← RBP points here
│  Current Frame     ├───────────────────────────────┤   │
│                    │ Local Variables               │   │
│                    │                               │   │
│                    ├───────────────────────────────┤   │
│                    │ Saved Registers (if needed)   │   │
│                    ├───────────────────────────────┤   │
│                    │ Return Address                │   │
│                    ├───────────────────────────────┤   │
│                    │ Arguments (if stack-passed)   │   │ ← RSP points here
│                    └───────────────────────────────┘   │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**The frame pointer (RBP)** serves as a stable reference point within a function's stack frame. While some optimizations omit the frame pointer (using RSP as a general-purpose register instead), it's extremely useful for debugging.

### 0.4.3 Function Prologue and Epilogue

Every function has a standard structure:

**Prologue** (executed when entering the function):
```assembly
push rbp           ; Save caller's frame pointer
mov rbp, rsp       ; Establish new frame pointer
sub rsp, N         ; Allocate space for local variables (N bytes)
```

**Epilogue** (executed when exiting the function):
```assembly
mov rsp, rbp       ; Deallocate local variables (restore stack pointer)
pop rbp            ; Restore caller's frame pointer
ret                ; Return to caller (uses saved return address)
```

Let's trace what happens with this C code:

```c
int add(int a, int b) {
    int result = a + b;
    return result;
}

int main(void) {
    return add(5, 3);
}
```

When `main` calls `add`:

1. **Before call**: Arguments are prepared (in registers or on stack)
2. **Call instruction**: The `call` instruction pushes the **return address** onto the stack and jumps to `add`
3. **Prologue in `add`**: Sets up the new stack frame
4. **Function body**: Executes the addition
5. **Epilogue in `add`**: Tears down the stack frame
6. **Return**: The `ret` instruction pops the return address and resumes execution in `main`

### 0.4.4 Detailed Stack Growth Example

Let's visualize the complete stack behavior:

```
State before calling add(5, 3):
┌─────────────────────────────────┐
│ ... previous frames ...         │
├─────────────────────────────────┤
│ main's stack frame              │
│ - local variables               │
│ - saved RBP                     │ ← RBP (main's frame pointer)
│ - return address to OS/runtime  │
│ - arguments to main             │ ← RSP
└─────────────────────────────────┘

State after call to add (before prologue):
┌─────────────────────────────────┐
│ ... previous frames ...         │
├─────────────────────────────────┤
│ main's stack frame              │
│ - local variables               │
│ - saved RBP                     │ ← RBP (main's frame pointer)
│ - return address to OS/runtime  │
│ - arguments to main             │
├─────────────────────────────────┤
│ add's stack frame (incomplete)  │
│ - return address (back to main) │ ← RSP
└─────────────────────────────────┘

State after add's prologue:
┌─────────────────────────────────┐
│ ... previous frames ...         │
├─────────────────────────────────┤
│ main's stack frame              │
│ - local variables               │
│ - saved RBP                     │ ← old RBP value
│ - return address to OS/runtime  │
│ - arguments to main             │
├─────────────────────────────────┤
│ add's stack frame               │
│ - saved RBP (main's RBP)        │ ← RBP (add's frame pointer)
│ - return address (back to main) │
│ - arguments (5, 3)              │ ← RSP
└─────────────────────────────────┘

State after allocating local variables:
┌─────────────────────────────────┐
│ ... previous frames ...         │
├─────────────────────────────────┤
│ main's stack frame              │
│ - local variables               │
│ - saved RBP                     │
│ - return address to OS/runtime  │
│ - arguments to main             │
├─────────────────────────────────┤
│ add's stack frame               │
│ - saved RBP                     │ ← RBP
│ - return address                │
│ - arguments (5, 3)              │
│ - local var: result (4 bytes)   │ ← RSP
└─────────────────────────────────┘
```

## 0.5 Calling Conventions

### 0.5.1 What is a Calling Convention?

A **calling convention** is a set of rules that defines how functions call each other. It specifies:

1. **Argument passing**: Where to put function arguments (registers vs. stack)
2. **Return values**: Where to place return values
3. **Stack cleanup**: Who cleans up arguments from the stack (caller or callee)
4. **Register preservation**: Which registers must be preserved across calls
5. **Name mangling** (in some languages): How to encode function names with type information

> **Critical Insight**: Without calling conventions, code compiled by different compilers couldn't work together. The calling convention is the **contract** that allows separate compilation to work.

### 0.5.2 The System V AMD64 ABI (Linux/Unix)

The most common calling convention for x86-64 on Unix-like systems is the **System V AMD64 ABI**. Here's how it works:

**Argument Passing:**
- First 6 integer/pointer arguments: RDI, RSI, RDX, RCX, R8, R9 (in order)
- First 8 floating-point arguments: XMM0-XMM7
- Additional arguments: Passed on the stack

**Return Values:**
- Integer/pointer returns: RAX
- Floating-point returns: XMM0
- Large structs: Hidden pointer parameter (address where to store result)

**Register Preservation:**
- Callee-saved: RBX, RBP, R12-R15
- Caller-saved: RAX, RCX, RDX, RSI, RDI, R8-R11

**Stack Alignment:**
- The stack must be 16-byte aligned before any `call` instruction

Let's see an example:

```c
long compute(long a, long b, long c, long d, long e, long f, long g) {
    return a + b + c + d + e + f + g;
}

int main(void) {
    return (int)compute(1, 2, 3, 4, 5, 6, 7);
}
```

The arguments would be passed as follows:
- `a` (1) → RDI
- `b` (2) → RSI
- `c` (3) → RDX
- `d` (4) → RCX
- `e` (5) → R8
- `f` (6) → R9
- `g` (7) → On the stack

### 0.5.3 The Microsoft x64 Calling Convention (Windows)

Windows uses a different calling convention:

**Argument Passing:**
- First 4 arguments: RCX, RDX, R8, R9 (in order)
- Additional arguments: Passed on the stack
- For floating-point: XMM0-XMM3 for first 4 arguments

**Key Differences from System V:**
- Different registers for arguments
- Stack space is always allocated for register arguments (shadow space)
- Different register preservation rules

> **Practical Note**: This is why you can't always link object files between Windows and Linux, even on the same architecture. The calling conventions are incompatible.

## 0.6 Control Flow and Branch Prediction

### 0.6.1 Conditional Jumps

The CPU executes instructions sequentially, but conditional jumps (branches) allow programs to make decisions. Conditional jumps depend on the flags register:

```assembly
cmp rax, rbx      ; Compare RAX and RBX (sets flags)
je  target        ; Jump if equal (ZF == 1)
jne target        ; Jump if not equal (ZF == 0)
jg  target        ; Jump if greater (signed comparison)
jl  target        ; Jump if less (signed comparison)
ja  target        ; Jump if above (unsigned comparison)
jb  target        ; Jump if below (unsigned comparison)
```

Modern CPUs use **branch prediction** to guess which way a branch will go and speculatively execute those instructions. Correct predictions improve performance; mispredictions cause the pipeline to be flushed.

### 0.6.2 Loops

Loops are implemented using conditional jumps:

```c
for (int i = 0; i < 10; i++) {
    // loop body
}
```

Might compile to:

```assembly
    xor eax, eax          ; i = 0
.loop:
    cmp eax, 10           ; compare i with 10
    jge .end              ; if i >= 10, exit loop
    ; loop body here
    inc eax               ; i++
    jmp .loop             ; repeat
.end:
```

## 0.7 Putting It All Together: A Complete Example

Let's trace through a complete program execution to see all these concepts in action:

```c
int multiply_by_two(int x) {
    return x * 2;
}

int add_and_multiply(int a, int b) {
    int sum = a + b;
    return multiply_by_two(sum);
}

int main(void) {
    int result = add_and_multiply(5, 7);
    return result == 24 ? 0 : 1;
}
```

Here's what happens when this program runs:

1. **Program startup**: The OS loader sets up the initial stack and calls `main`

2. **In `main`**:
   - Arguments to `add_and_multiply` are prepared: RDI = 5, RSI = 7
   - The `call` instruction pushes the return address onto the stack
   - Execution jumps to `add_and_multiply`

3. **In `add_and_multiply`**:
   - Prologue: Saves RBP, sets up new frame
   - Adds RDI and RSI: `lea eax, [rdi + rsi]` (result in EAX)
   - Prepares argument to `multiply_by_two`: EDI = EAX (the sum)
   - The `call` instruction pushes return address, jumps to `multiply_by_two`

4. **In `multiply_by_two`**:
   - Prologue: Saves RBP, sets up new frame
   - Multiplies by 2: `lea eax, [rdi + rdi]` (efficient way to multiply by 2)
   - Epilogue: Restores RBP
   - Return: Pops return address, returns to `add_and_multiply`

5. **Back in `add_and_multiply`**:
   - The return value (24) is now in EAX
   - Epilogue: Restores RBP
   - Return: Returns to `main`

6. **Back in `main`**:
   - Compares EAX (24) with 24: `cmp eax, 24`
   - Sets flags accordingly (ZF will be set because they're equal)
   - Conditional move: `sete al` (AL = 1 if equal, 0 if not)
   - Zero-extends: `movzx eax, al`
   - Returns this value as the program's exit status

## 0.8 Common Pitfalls

### Pitfall 1: Stack Overflow

Each function call consumes stack space. Deep recursion or large local arrays can exhaust the stack:

```c
// Dangerous: Recursion with no base case
void infinite_recursion(void) {
    char buffer[1024];  // Each call uses 1KB+ of stack
    infinite_recursion();
}
```

When the stack is exhausted, the program crashes with a **segmentation fault**.

### Pitfall 2: Misaligned Accesses

Accessing multi-byte values from misaligned addresses can hurt performance or cause crashes:

```c
// Potentially slow or crashing on some architectures
void misaligned_access(void* p) {
    int* ip = (int*)((char*)p + 1);  // Misaligned!
    *ip = 42;  // May be slow or crash
}
```

### Pitfall 3: Register Starvation

When a function needs more registers than available, the compiler must spill some to memory (the stack), which hurts performance:

```c
// Uses many variables - may cause register spills
int complex_calc(int a, int b, int c, int d, int e,
                 int f, int g, int h, int i, int j) {
    int t1 = a + b;
    int t2 = c * d;
    int t3 = e - f;
    int t4 = g / h;
    int t5 = i << 2;
    return t1 + t2 + t3 + t4 + t5;
}
```

## 0.9 Key Takeaways

1. **The CPU is a state machine**: It fetches, decodes, and executes instructions in a continuous loop, updating architectural state with each instruction.

2. **Registers are fast but limited**: General-purpose registers provide the fastest storage, but there are only a handful. Callee-saved vs. caller-saved conventions enable efficient function calls.

3. **Memory is byte-addressable**: Each byte has a unique address, and multi-byte values are stored according to the system's endianness (little-endian on x86-64).

4. **The stack enables function calls**: Each function call creates a stack frame containing local variables, saved registers, and return addresses. The stack grows downward, managed by the stack pointer (RSP) and frame pointer (RBP).

5. **Calling conventions are contracts**: They define how functions call each other—argument passing, return values, stack cleanup, and register preservation. The System V AMD64 ABI is the standard on Linux/Unix x86-64 systems.

6. **Control flow uses jumps and flags**: Conditional jumps depend on status flags set by comparison and arithmetic operations, enabling `if` statements and loops.

7. **Understanding execution explains compilation**: The hardware execution model drives compiler decisions. Every optimization targets some aspect of the underlying architecture.

## 0.10 Looking Ahead

Now that we understand how programs execute at the hardware level, we can explore how C source code gets transformed into machine instructions. In Chapter 1, we'll examine the complete compilation pipeline—from source code to executable program.

## Further Reading

- Intel 64 and IA-32 Architectures Software Developer's Manual (Volume 1: Basic Architecture)
- AMD64 Architecture Programmer's Manual (Volume 1: Application Programming)
- "Computer Systems: A Programmer's Perspective" by Bryant and O'Hallaron
- "Computer Architecture: A Quantitative Approach" by Hennessy and Patterson
