# Chapter 4: Assembly and Object Files

## Introduction

After the compiler generates assembly code, the **assembler** translates that assembly into machine code and packages it into an **object file**. Object files contain binary code that isn't yet ready to run—it needs to be linked with other object files and libraries.

Understanding assembly and object files is crucial for:
- Debugging at the machine code level
- Understanding how code maps to hardware
- Analyzing performance bottlenecks
- Reverse engineering and security analysis

In this chapter, we'll explore assembly language syntax and the structure of object files.

## 4.1 Assembly Language Basics

### 4.1.1 What is Assembly Language?

Assembly language is a human-readable representation of machine code. Each assembly instruction corresponds to one or more machine instructions. Unlike C, assembly:
- Is architecture-specific (x86-64 assembly ≠ ARM assembly)
- Has a nearly 1-to-1 mapping with machine code
- Provides direct access to registers and memory
- Offers no type safety or high-level abstractions

### 4.1.2 Assembly Structure

A typical assembly file has three types of content:

```assembly
# Comments start with # (AT&T syntax)

.section .text           # Directive: tells assembler about section
.globl main              # Directive: make 'main' visible externally

main:                    # Label: marks a memory address
    pushq %rbp           # Instruction: push rbp onto stack
    movq %rsp, %rbp      # Instruction: copy rsp to rbp
    movl $42, %eax       # Instruction: load 42 into eax
    popq %rbp            # Instruction: restore rbp
    ret                  # Instruction: return from function
```

**Directives**: Commands to the assembler (not translated to machine code)
**Labels**: Named addresses for code or data locations
**Instructions**: Actual machine instructions

## 4.2 AT&T vs. Intel Syntax

There are two main assembly syntaxes, and understanding both is important:

### 4.2.1 AT&T Syntax (GCC default on Linux)

```assembly
# AT&T syntax
movl $5, %eax          # Move immediate 5 into eax
movl %eax, -4(%rbp)    # Move eax to memory at rbp-4
movl (%rdi), %eax      # Move memory at rdi into eax
addl %ecx, %eax        # Add ecx to eax (eax = eax + ecx)
```

AT&T syntax features:
- **Source first, destination second**: `mov src, dst`
- **Register prefix**: `%` before register names
- **Immediate prefix**: `$` before constants
- **Size suffix**: `b` (byte), `w` (word), `l` (long/dword), `q` (quadword)
- **Memory syntax**: `disp(base, index, scale)` → `address = base + index*scale + disp`

### 4.2.2 Intel Syntax (MASM, NASM, Windows)

```assembly
# Intel syntax
mov eax, 5             # Move immediate 5 into eax
mov dword ptr [rbp-4], eax  # Move eax to memory at rbp-4
mov eax, [rdi]         # Move memory at rdi into eax
add eax, ecx           # Add ecx to eax
```

Intel syntax features:
- **Destination first, source second**: `mov dst, src`
- **No register prefix**: `eax` not `%eax`
- **No immediate prefix**: `5` not `$5`
- **Size specifier**: `byte ptr`, `word ptr`, `dword ptr`, `qword ptr`
- **Memory syntax**: `[base + index*scale + disp]`

### 4.2.3 Switching Syntax in Tools

```bash
# objdump: Use Intel syntax
objdump -d -M intel program

# objdump: Use AT&T syntax (default)
objdump -d program

# gcc: Generate Intel syntax assembly
gcc -S -masm=intel source.c -o source.s

# gdb: Use Intel syntax
set disassembly-flavor intel
```

> **Tip**: Most Linux tools default to AT&T syntax. If you learned assembly on Windows or from tutorials, you might be more familiar with Intel syntax. Both are equivalent—it's just a matter of preference.

## 4.3 Common x86-64 Instructions

### 4.3.1 Data Movement

```assembly
# Move data
movl $10, %eax         # eax = 10 (immediate to register)
movl %eax, %ecx        # ecx = eax (register to register)
movl %eax, (%rdi)      # *rdi = eax (register to memory)
movl (%rdi), %eax      # eax = *rdi (memory to register)

# Move with zero extension
movzbw %al, %ax        # Zero-extend byte to word
movzbl %al, %eax       # Zero-extend byte to long

# Move with sign extension
movsbw %al, %ax        # Sign-extend byte to word
movsbl %al, %eax       # Sign-extend byte to long
movslq %eax, %rax      # Sign-extend long to quad

# Exchange
xchg %rax, %rbx        # Swap rax and rbx
```

### 4.3.2 Arithmetic Operations

```assembly
# Addition and subtraction
addl $5, %eax          # eax = eax + 5
subl $3, %eax          # eax = eax - 3
incl %eax              # eax = eax + 1
decl %eax              # eax = eax - 1

# Multiplication
imull %ecx             # edx:eax = eax * ecx (signed)
mull %ecx              # edx:eax = eax * ecx (unsigned)

# Division
idivl %ecx             # eax = edx:eax / ecx, edx = remainder (signed)
divl %ecx              # eax = edx:eax / ecx, edx = remainder (unsigned)

# Negation
negl %eax              # eax = -eax
```

### 4.3.3 Bitwise Operations

```assembly
andl $0xFF, %eax       # eax = eax & 0xFF
orl $0x80, %eax        # eax = eax | 0x80
xorl %eax, %eax        # eax = 0 (common idiom to zero a register)
notl %eax              # eax = ~eax

# Shifts
shll $2, %eax          # eax = eax << 2 (logical left shift)
shrl $2, %eax          # eax = (unsigned)eax >> 2 (logical right shift)
sarl $2, %eax          # eax = (signed)eax >> 2 (arithmetic right shift)

# Rotate
roll $4, %eax          # Rotate left by 4 bits
rorl $4, %eax          # Rotate right by 4 bits
```

### 4.3.4 Comparison and Testing

```assembly
cmpl %ecx, %eax        # Compare eax with ecx (sets flags)
testl %eax, %eax       # Test if eax is zero (sets flags)
testl %eax, %ecx       # Test if any bits are set (eax & ecx)
```

### 4.3.5 Control Flow

```assembly
# Unconditional jump
jmp label              # Jump to label

# Conditional jumps (after cmp or test)
je label               # Jump if equal (ZF=1)
jne label              # Jump if not equal (ZF=0)
jg label               # Jump if greater (signed)
jge label              # Jump if greater or equal (signed)
jl label               # Jump if less (signed)
jle label              # Jump if less or equal (signed)
ja label               # Jump if above (unsigned)
jb label               # Jump if below (unsigned)
jz label               # Jump if zero (same as je)
jnz label              # Jump if not zero (same as jne)

# Function calls
call function          # Push return address, jump to function
ret                    # Pop return address, jump to it

# Loop instructions (less common now)
loop label             # Decrement ecx, jump if not zero
```

### 4.3.6 Stack Operations

```assembly
pushq %rax             # Push rax onto stack, decrement rsp
popq %rax              # Pop from stack into rax, increment rsp

# Enter/leave for function prologue/epilogue
enter $16, $0          # Push rbp, mov rsp to rbp, subtract 16 from rsp
leave                  # mov rbp to rsp, pop rbp
```

### 4.3.7 Addressing Modes

x86-64 supports complex addressing modes:

```assembly
# Immediate addressing
movl $42, %eax         # eax = 42

# Register addressing
movl %eax, %ecx        # ecx = eax

# Direct addressing
movl var, %eax         # eax = var (var is a label)

# Register indirect
movl (%rax), %ecx      # ecx = *rax

# Base + displacement
movl -4(%rbp), %eax    # eax = *(rbp - 4)
movl 8(%rdi), %eax     # eax = *(rdi + 8)

# Base + index + scale + displacement
# Address = base + index * scale + displacement
movl 0(%rdi, %rsi, 4), %eax  # eax = *(rdi + rsi * 4)
movl -8(%rbp, %rcx, 2), %eax # eax = *(rbp + rcx * 2 - 8)
```

Scale can be 1, 2, 4, or 8. This is perfect for array access:
```c
// C: arr[i]  where arr is int*
// Assembly: (%rdi, %rsi, 4) where rdi=arr, rsi=i
```

## 4.4 Assembly Directives

### 4.4.1 Section Directives

```assembly
.section .text         # Code section
.section .data         # Initialized data section
.section .bss          # Uninitialized data section
.section .rodata       # Read-only data section
.section .eh_frame     # Exception handling information
```

### 4.4.2 Data Definition Directives

```assembly
.data

# Define bytes
byte_val: .byte 42          # One byte initialized to 42
bytes: .byte 1, 2, 3, 4, 5  # Multiple bytes

# Define words (2 bytes)
word_val: .word 1000        # 2-byte value

# Define longs (4 bytes)
long_val: .long 100000      # 4-byte value
longs: .long 10, 20, 30     # Array of longs

# Define quads (8 bytes)
quad_val: .quad 0x123456789ABCDEF0  # 8-byte value
ptr: .quad string_label     # Pointer to string

# Define strings
string_label: .asciz "Hello, World!\n"  # Null-terminated string
string2: .ascii "No null terminator"    # String without null

# Reserve space (BSS section)
.bss
buffer: .skip 1024          # Reserve 1024 bytes (zero-initialized)
counter: .comm counter, 4   # Common symbol, 4 bytes
```

### 4.4.3 Symbol Directives

```assembly
.globl main             # Make 'main' visible to linker
.extern printf          # Declare external symbol (often implicit)
.local helper           # Keep 'helper' local to this file
.hidden internal_func   # Hide from dynamic linker
.weak weak_symbol       # Declare weak symbol
```

### 4.4.4 Alignment Directives

```assembly
.align 4                # Align to 2^4 = 16 bytes
.align 8                # Align to 2^8 = 256 bytes
.balign 16              # Align to 16 bytes (absolute value)
.p2align 4              # Align to 2^4 = 16 bytes (power of 2)
```

Alignment is important for:
- Performance (aligned access is faster)
- Correctness (some architectures require alignment for certain operations)
- SIMD instructions (often require 16 or 32-byte alignment)

### 4.4.5 Function Directives

```assembly
.text
.globl my_function
.type my_function, @function  # Declare as function symbol
my_function:
    # ... function code ...
    ret
.size my_function, .-my_function  # Size = current address - start
```

## 4.5 The Assembler

### 4.5.1 The Assembling Process

The assembler (`as` on Linux) translates assembly to object files:

```
┌─────────────────────────────────────────────────────────────┐
│                    Assembling Process                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   source.s ──▶ [ Assembler ] ──▶ source.o                   │
│                     │                                       │
│                     ▼                                       │
│               ┌─────────────┐                               │
│               │ Parse       │                               │
│               │ Assembly    │                               │
│               └─────┬───────┘                               │
│                     ▼                                       │
│               ┌─────────────┐                               │
│               │ Generate    │                               │
│               │ Machine     │                               │
│               │ Code        │                               │
│               └─────┬───────┘                               │
│                     ▼                                       │
│               ┌─────────────┐                               │
│               │ Create      │                               │
│               │ Object File │                               │
│               └─────────────┘                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.5.2 Using the Assembler

```bash
# Assemble source.s to source.o
as source.s -o source.o

# Or using gcc (which calls as)
gcc -c source.s -o source.o

# Generate assembly from C
gcc -S source.c -o source.s

# Assemble with debugging info
as --gdwarf-2 source.s -o source.o
```

### 4.5.3 What the Assembler Does

1. **Parse instructions**: Convert mnemonics to opcodes
2. **Calculate offsets**: Determine label addresses
3. **Handle relocations**: Mark locations that need linker fixes
4. **Create sections**: Organize code and data into sections
5. **Build symbol table**: Record all defined and referenced symbols

## 4.6 Object File Structure

### 4.6.1 What is an Object File?

An object file (`.o` on Unix, `.obj` on Windows) contains:
- **Machine code**: Binary instructions
- **Data**: Initialized and uninitialized variables
- **Symbol table**: Names and locations of functions and variables
- **Relocation entries**: Locations that need fixing during linking
- **Debug information**: Source line mappings (if compiled with `-g`)

### 4.6.2 Object File Format

On Linux, object files use the **ELF** (Executable and Linkable Format) format. We'll cover ELF in detail in Chapter 5, but here's the basic structure:

```
┌─────────────────────────────────────────┐
│              ELF Header                 │
│  Magic number, architecture, entry pt   │
├─────────────────────────────────────────┤
│           Program Headers               │
│  (for segments - usually not in .o)     │
├─────────────────────────────────────────┤
│              .text section              │
│  Executable code                        │
├─────────────────────────────────────────┤
│              .rodata section            │
│  Read-only data (strings, constants)    │
├─────────────────────────────────────────┤
│              .data section              │
│  Initialized read-write data            │
├─────────────────────────────────────────┤
│              .bss section               │
│  Uninitialized data (size only)         │
├─────────────────────────────────────────┤
│            .symtab section              │
│  Symbol table                           │
├─────────────────────────────────────────┤
│            .strtab section              │
│  String table for symbol names          │
├─────────────────────────────────────────┤
│           .rela.text section            │
│  Relocation entries for .text           │
├─────────────────────────────────────────┤
│           Section Headers               │
│  Describes all sections                 │
└─────────────────────────────────────────┘
```

### 4.6.3 Examining Object Files

```bash
# View all sections
objdump -h source.o

# View symbol table
nm source.o

# View detailed symbol info
readelf -s source.o

# Disassemble code sections
objdump -d source.o

# View all content
readelf -a source.o

# View section contents (hex dump)
objdump -s source.o
```

## 4.7 Symbols and Symbol Tables

### 4.7.1 What are Symbols?

Symbols are named locations in the object file. They include:
- **Defined functions**: Functions implemented in this file
- **Defined variables**: Global and static variables
- **Referenced symbols**: External functions and variables used

### 4.7.2 Symbol Types

```bash
$ nm source.o

# Output format: address type name
0000000000000000 T main           # T = text (code) section, global
0000000000000000 t helper         # t = text section, local
0000000000000010 D global_var     # D = data section, initialized
0000000000000000 B bss_var        # B = BSS section, uninitialized
0000000000000000 C common_var     # C = common symbol
                 U printf         # U = undefined (external)
0000000000000000 r const_val      # r = read-only data
```

Common symbol types:

| Type | Meaning |
|------|---------|
| T/t  | Text (code) section |
| D/d  | Data section (initialized) |
| B/b  | BSS section (uninitialized) |
| R/r  | Read-only data section |
| U    | Undefined (external reference) |
| C    | Common symbol (uninitialized, may be merged) |
| W    | Weak symbol |
| S/s  | Small data section |
| A    | Absolute symbol |

Uppercase = global/external, lowercase = local

### 4.7.3 Symbol Binding

- **Global (STB_GLOBAL)**: Visible to other object files
- **Local (STB_LOCAL)**: Visible only within this object file
- **Weak (STB_WEAK)**: Like global, but can be overridden

```c
// Source file demonstrating symbol bindings
int global_var = 10;           // Global (STB_GLOBAL)
static int local_var = 20;     // Local (STB_LOCAL)
extern int external_var;       // Undefined (referenced)

void public_func(void) { }     // Global
static void private_func(void) { }  // Local
```

## 4.8 Relocations

### 4.8.1 What are Relocations?

Relocations are "fix-ups" that the linker must perform. When the assembler encounters a reference to an external symbol or a location that's not yet known, it creates a relocation entry.

```assembly
# Assembly with external reference
call printf            # Assembler doesn't know where printf is

# Object file contains:
# - Partial instruction encoding
# - Relocation entry: "fix this location with printf's address"
```

### 4.8.2 Relocation Types

Different architectures have different relocation types. Common x86-64 relocations:

| Relocation | Description |
|------------|-------------|
| R_X86_64_64 | 64-bit absolute address |
| R_X86_64_PC32 | 32-bit PC-relative |
| R_X86_64_PLT32 | 32-bit PC-relative to PLT (for function calls) |
| R_X86_64_32 | 32-bit absolute (truncated) |
| R_X86_64_32S | 32-bit signed absolute |

### 4.8.3 Viewing Relocations

```bash
# View relocations
objdump -r source.o

# Or with readelf
readelf -r source.o
```

Example output:
```
RELOCATION RECORDS FOR [.text]:
OFFSET           TYPE              VALUE
0000000000000005 R_X86_64_PC32     .rodata-0x0000000000000004
000000000000000a R_X86_64_PLT32    printf-0x0000000000000004
0000000000000013 R_X86_64_PLT32    external_var-0x0000000000000004
```

### 4.8.4 Relocation Example

Consider this code:

```c
extern int external_var;

int get_value(void) {
    return external_var;
}
```

Assembly output:
```assembly
get_value:
    movl external_var(%rip), %eax    # Load external_var
    ret
```

Before linking, `external_var` is unknown. The object file contains:

```
Offset  Bytes                    Meaning
0x00    8b 05 00 00 00 00        movl 0(%rip), %eax
        ^^^^^^^^^^^
        This 00 00 00 00 is a placeholder
        Relocation at offset 0x02: R_X86_64_PC32 external_var

0x06    c3                       ret
```

After linking, if `external_var` is at address `0x4040`:
```
Offset  Bytes                    Meaning
0x00    8b 05 36 40 00 00        movl 0x4036(%rip), %eax
        ^^^^^^^^^^^^^
        The linker filled in the relative offset
        (0x4040 - 0x06 - 0x02 = 0x4036)

0x06    c3                       ret
```

## 4.9 Practical Example: From C to Object File

Let's trace the complete process:

### 4.9.1 Source Code

```c
// example.c
#include <stdio.h>

int global_var = 42;
static int local_var = 10;

int add(int a, int b) {
    return a + b;
}

static int multiply(int a, int b) {
    return a * b;
}

int main(int argc, char** argv) {
    int sum = add(global_var, local_var);
    printf("Sum: %d\n", sum);
    return 0;
}
```

### 4.9.2 Generate Assembly

```bash
gcc -S -O0 -fno-stack-protector example.c -o example.s
```

Key parts of the assembly:
```assembly
    .data
    .globl global_var
    .align 4
global_var:
    .long 42
local_var:
    .long 10

    .text
    .globl add
add:
    pushq %rbp
    movq %rsp, %rbp
    movl %edi, -4(%rbp)
    movl %esi, -8(%rbp)
    movl -4(%rbp), %eax
    addl -8(%rbp), %eax
    popq %rbp
    ret

multiply:                    # Note: not .globl
    # ... similar ...

    .globl main
main:
    # ... calls add, references global_var, local_var, printf ...
```

### 4.9.3 Examine Object File

```bash
gcc -c example.c -o example.o
nm example.o
```

Output:
```
0000000000000000 T add           # Global function
0000000000000000 D global_var    # Global variable
                 U printf        # External reference
0000000000000000 T main          # Global function
0000000000000014 t multiply      # Local function (lowercase t)
0000000000000004 d local_var     # Local variable (lowercase d)
```

### 4.9.4 View Relocations

```bash
objdump -r example.o
```

Output:
```
RELOCATION RECORDS FOR [.text]:
OFFSET           TYPE              VALUE
000000000000001e R_X86_64_PC32     global_var-0x0000000000000004
0000000000000024 R_X86_64_PC32     local_var-0x0000000000000004
0000000000000044 R_X86_64_PLT32    printf-0x0000000000000004
```

## 4.10 Debug Information

### 4.10.1 Compiling with Debug Info

```bash
# Include debug symbols
gcc -g source.c -o program

# Debug info level
gcc -g1 source.c        # Minimal
gcc -g2 source.c        # Default
gcc -g3 source.c        # Maximum (includes macros)

# Debug format
gcc -gdwarf-4 source.c  # DWARF version 4
gcc -gsplit-dwarf       # Separate .dwo file
```

### 4.10.2 DWARF Debug Format

Modern Unix systems use DWARF for debug information:

```
.debug_info     # Core debug information
.debug_abbrev   # Abbreviation tables
.debug_line     # Line number info
.debug_str      # String table
.debug_ranges   # Address ranges
.debug_loc      # Location lists
```

### 4.10.3 Viewing Debug Info

```bash
# View debug sections
readelf --debug-dump=info program

# View line info
readelf --debug-dump=line program

# Use addr2line
addr2line -e program 0x401126  # What source line is at this address?

# Use objdump with source
objdump -S program  # Interleave source with assembly
```

## 4.11 Key Takeaways

1. **Assembly is architecture-specific**: x86-64 assembly won't work on ARM, and vice versa.

2. **Two syntax styles**: AT&T (Linux default) and Intel (Windows, NASM). Learn to read both.

3. **Instructions, directives, and labels**: These are the three building blocks of assembly files.

4. **Object files are intermediate products**: They contain machine code but need linking before execution.

5. **Symbols name locations**: The symbol table maps names to addresses within the object file.

6. **Relocations mark fix-ups**: The linker fills in addresses that the assembler couldn't determine.

7. **Debug info maps machine to source**: DWARF format connects binary addresses to source lines.

8. **Tools for inspection**: `objdump`, `readelf`, `nm`, and `addr2line` are essential for analyzing object files.

## 4.12 Looking Ahead

Now that we understand object files, we'll dive deeper into the ELF format in Chapter 5. We'll examine every field in the ELF header, section headers, and program headers, giving you complete mastery over binary file analysis.

## Further Reading

- "Linkers and Loaders" by John Levine
- "Practical Binary Analysis" by Andriesse
- Intel 64 and IA-32 Architectures Software Developer's Manual
- System V AMD64 ABI (for calling conventions and relocation types)
- "ELF Format" documentation (Chapter 5 covers this in detail)
