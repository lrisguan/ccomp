# Chapter 3: Compilation Internals

## Introduction

After preprocessing, the compiler's real work begins. The compilation phase transforms your C source code—a human-readable text format—into assembly language that the machine can understand. This is the most complex stage of the build pipeline, involving lexical analysis, parsing, semantic analysis, optimization, and code generation.

Understanding compilation internals helps you:
- Write code that compilers can optimize effectively
- Debug compiler errors more efficiently
- Understand why seemingly equivalent code performs differently
- Appreciate the sophisticated machinery behind modern compilers

In this chapter, we'll trace the complete journey from preprocessed source to assembly output.

## 3.1 The Compilation Pipeline Overview

The compiler processes code through several distinct phases:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Compilation Pipeline                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
│  │  Lexical    │    │   Parsing   │    │  Semantic   │              │
│  │  Analysis   │───▶│             │───▶│  Analysis   │              │
│  │ (tokenize)  │    │ (AST build) │    │(type check) │              │
│  └─────────────┘    └─────────────┘    └─────────────┘              │
│                                                │                    │
│                                                ▼                    │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
│  │    Code     │    │ Optimization│    │     IR      │              │
│  │ Generation  │◀───│   Passes    │◀───│  Generation │              │
│  │  (assembly) │    │             │    │             │              │
│  └─────────────┘    └─────────────┘    └─────────────┘              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

Each phase builds on the previous one, creating increasingly refined representations of your code.

## 3.2 Lexical Analysis (Tokenization)

### 3.2.1 What is Lexical Analysis?

Lexical analysis (or scanning) converts the raw character stream of your source code into a sequence of **tokens**—the smallest meaningful units in the language. The lexer doesn't understand syntax; it just recognizes patterns.

Example input:
```c
int x = 42 + y;
```

Becomes tokens:
```
[KEYWORD: int] [IDENTIFIER: x] [OPERATOR: =] [INTEGER: 42] [OPERATOR: +] [IDENTIFIER: y] [SEMICOLON]
```

### 3.2.2 Token Categories

C tokens fall into several categories:

| Category      | Examples                        |
|---------------|--------------------------------|
| Keywords      | `int`, `if`, `else`, `while`, `return` |
| Identifiers   | `main`, `printf`, `count`, `x`  |
| Constants     | `42`, `3.14`, `'a'`, `"hello"` |
| Operators     | `+`, `-`, `*`, `/`, `=`, `==`, `&&` |
| Punctuation   | `;`, `,`, `(`, `)`, `{`, `}`    |
| Preprocessor  | `#include`, `#define` (handled earlier) |

### 3.2.3 How Lexers Work

Lexers use **regular expressions** and **finite automata** to recognize tokens:

```
Pattern for integer literal: [0-9]+
Pattern for identifier:      [a-zA-Z_][a-zA-Z0-9_]*
Pattern for keyword 'int':   int (but not followed by identifier chars)
```

**The Longest Match Rule**: When multiple patterns match, the lexer chooses the longest match:
- `integer` → IDENTIFIER (not `int` + `eger`)
- `while1` → IDENTIFIER (not `while` + `1`)

**The Priority Rule**: When patterns have the same length, keywords take priority over identifiers:
- `while` → KEYWORD (not IDENTIFIER)

### 3.2.4 Lexer Output

The lexer produces a token stream with location information:

```c
int x = 42 + y;
```

Token stream (simplified):
```
Token { type: KW_INT,    text: "int",  line: 1, col: 1 }
Token { type: IDENT,     text: "x",    line: 1, col: 5 }
Token { type: ASSIGN,    text: "=",    line: 1, col: 7 }
Token { type: INT_LIT,   text: "42",   line: 1, col: 9, value: 42 }
Token { type: PLUS,      text: "+",    line: 1, col: 12 }
Token { type: IDENT,     text: "y",    line: 1, col: 14 }
Token { type: SEMICOLON, text: ";",    line: 1, col: 15 }
```

Location information is crucial for error messages and debugging.

## 3.3 Parsing and Syntax Analysis

### 3.3.1 What is Parsing?

Parsing (syntax analysis) takes the token stream and builds a **parse tree** or **Abstract Syntax Tree (AST)** according to the grammar rules of C. The parser checks whether the token sequence forms valid C syntax.

### 3.3.2 Context-Free Grammars

C's syntax is defined by a **context-free grammar (CFG)**. A grammar has:
- **Terminals**: Tokens from the lexer
- **Non-terminals**: Syntactic categories (expression, statement, declaration)
- **Production rules**: How non-terminals expand

Simplified grammar for expressions:
```
expr        → expr '+' term | expr '-' term | term
term        → term '*' factor | term '/' factor | factor
factor      → NUMBER | IDENT | '(' expr ')'
```

This grammar correctly handles operator precedence:
- `1 + 2 * 3` parses as `1 + (2 * 3)`, not `(1 + 2) * 3`

### 3.3.3 Parse Trees vs. Abstract Syntax Trees

**Parse Tree (Concrete Syntax Tree)**: Contains every grammatical element, including punctuation.

**Abstract Syntax Tree (AST)**: Eliminates syntactic sugar, focuses on structure.

For expression `x = 2 + 3 * y`:

Parse Tree (simplified):
```
        assignment_expr
           /      \
       lvalue     add_expr
          |       /      \
         'x'   mul_expr  term
                /   \      \
           term    factor  'y'
             |       |
          factor   '3'
             |
           '2'
```

AST (cleaner):
```
        =
       / \
      x   +
         / \
        2   *
           / \
          3   y
```

The AST is what the compiler uses for further processing.

### 3.3.4 AST Node Types

Different constructs produce different AST node types:

```c
// Declaration
int x = 10;

// AST:
// VarDecl {
//   type: int,
//   name: "x",
//   init: IntegerLiteral { value: 10 }
// }

// If statement
if (x > 0) {
    y = x;
}

// AST:
// IfStmt {
//   cond: BinaryOp { op: '>', left: 'x', right: IntegerLiteral(0) },
//   then: CompoundStmt { 
//     body: [ Assignment { left: 'y', right: 'x' } ]
//   },
//   else: null
// }

// Function definition
int add(int a, int b) {
    return a + b;
}

// AST:
// FunctionDecl {
//   return_type: int,
//   name: "add",
//   params: [Param{name:"a", type:int}, Param{name:"b", type:int}],
//   body: CompoundStmt {
//     body: [ ReturnStmt { expr: BinaryOp{op:'+', left:'a', right:'b'} } ]
//   }
// }
```

### 3.3.5 Error Recovery

When the parser encounters a syntax error, it tries to recover and continue:

```c
int main(void) {
    int x =    // Error: expected expression
    printf("x = %d\n", x);
    return 0;
}
```

Modern compilers use various recovery strategies:
- Skip tokens until a synchronizing token (like `;` or `}`) is found
- Insert missing tokens
- Report the error and try to provide helpful suggestions

## 3.4 Semantic Analysis

### 3.4.1 What is Semantic Analysis?

Syntax analysis ensures the code is *syntactically* valid. Semantic analysis checks whether the code is *meaningfully* valid:

- **Type checking**: Are operations applied to compatible types?
- **Symbol resolution**: Do referenced variables/functions exist?
- **Scope management**: Are variables used in the correct scope?
- **Const correctness**: Are const variables being modified?

### 3.4.2 The Symbol Table

The compiler maintains a **symbol table** mapping names to their declarations:

```c
int global_var = 10;

int add(int a, int b) {
    int result = a + b;
    return result;
}

int main(void) {
    int local_var = 5;
    global_var = add(local_var, 3);
    return 0;
}
```

Symbol table (simplified):
```
Global Scope:
  global_var → { type: int, storage: extern, location: .data }
  add        → { type: int(int,int), storage: extern, params: [a, b] }
  main       → { type: int(void), storage: extern }

add function scope:
  a         → { type: int, storage: param, location: rdi }
  b         → { type: int, storage: param, location: rsi }
  result    → { type: int, storage: auto, location: stack:-4 }

main function scope:
  local_var → { type: int, storage: auto, location: stack:-4 }
```

### 3.4.3 Type Checking

The compiler checks type compatibility for every operation:

```c
int x = 10;
float f = 3.14;
char* s = "hello";

int* p = x;       // Error: cannot convert int to int*
int* q = s;       // Error: cannot convert char* to int* (without cast)
int y = f;        // Warning: implicit conversion from float to int
void* v = p;      // OK: any pointer converts to void*
```

**Implicit Conversions**: The compiler automatically performs certain conversions:
- Integer promotion: `char` → `int`, `short` → `int`
- Arithmetic conversion: `int` + `float` → `float`
- Pointer decay: array name → pointer to first element

### 3.4.4 Scope and Visibility

The compiler tracks which symbols are visible at each point:

```c
int x = 1;           // Global x

void foo(void) {
    int x = 2;       // Local x shadows global
    {
        int x = 3;   // Inner x shadows outer
        printf("%d\n", x);  // Prints 3
    }
    printf("%d\n", x);      // Prints 2
}
```

The symbol table handles shadowing by maintaining a stack of scopes.

## 3.5 Intermediate Representation (IR)

### 3.5.1 Why IR?

Directly translating AST to assembly is impractical because:
- The AST is too high-level for optimization
- Different target architectures have different instruction sets
- Optimization is easier on a simpler, more regular form

The solution is an **Intermediate Representation (IR)** that:
- Is architecture-independent (mostly)
- Is simpler than the AST
- Supports various optimizations
- Can be easily translated to assembly

### 3.5.2 Three-Address Code (TAC)

A simple IR form is **three-address code**, where each instruction has at most three operands:

```c
// Source
int result = (a + b) * (c - d);

// Three-address code
t1 = a + b
t2 = c - d
t3 = t1 * t2
result = t3
```

Each instruction is simple: `dest = op1 operator op2` or `dest = operator op1`.

### 3.5.3 SSA Form (Static Single Assignment)

**Static Single Assignment (SSA)** is a modern IR form where each variable is assigned exactly once:

```c
// Original code
int x = 1;
x = x + 2;
x = x * 3;

// SSA form
x1 = 1
x2 = x1 + 2
x3 = x2 * 3
```

SSA makes many optimizations simpler because:
- Each use refers to exactly one definition
- Def-use chains are explicit
- Data flow analysis is easier

**φ (Phi) Functions**: At control flow merge points, SSA uses phi functions:

```c
// Original
if (condition) {
    x = 1;
} else {
    x = 2;
}
y = x;  // Which x?

// SSA form
if (condition) {
    x1 = 1;
} else {
    x2 = 2;
}
x3 = φ(x1, x2);  // Selects x1 or x2 based on which path was taken
y = x3;
```

### 3.5.4 LLVM IR Example

LLVM is a popular compiler infrastructure with its own well-defined IR:

```c
// Source
int add(int a, int b) {
    return a + b;
}

// LLVM IR
define i32 @add(i32 %a, i32 %b) {
entry:
    %result = add i32 %a, %b
    ret i32 %result
}
```

```c
// Source with control flow
int max(int a, int b) {
    if (a > b)
        return a;
    else
        return b;
}

// LLVM IR
define i32 @max(i32 %a, i32 %b) {
entry:
    %cmp = icmp sgt i32 %a, %b
    br i1 %cmp, label %return_a, label %return_b

return_a:
    ret i32 %a

return_b:
    ret i32 %b
}
```

### 3.5.5 GCC's GIMPLE and RTL

GCC uses two IRs:

**GIMPLE**: High-level IR similar to three-address code:
```c
// Original
x = a + b * c;

// GIMPLE
D.1234 = b * c;
x = a + D.1234;
```

**RTL (Register Transfer Language)**: Low-level IR closer to machine code:
```
(insn 6 5 7 (set (reg:SI 85)
        (plus:SI (reg:SI 84)
            (reg:SI 83))) "test.c":3 -1
     (nil))
```

## 3.6 Optimization Passes

### 3.6.1 Why Optimize?

C compilers perform optimizations to:
- Generate faster code
- Reduce code size
- Use registers efficiently
- Eliminate redundant computations

Modern compilers have hundreds of optimization passes.

### 3.6.2 Optimization Levels

| Level | Description                                   | Key Optimizations |
|-------|-----------------------------------------------|-------------------|
| -O0   | No optimization (default)                     | None              |
| -O1   | Basic optimizations                           | Dead code elimination, basic block reordering |
| -O2   | Standard optimizations                        | Inlining, loop optimizations, common subexpression elimination |
| -O3   | Aggressive optimizations                      | Vectorization, function inlining (aggressive), loop unrolling |
| -Os   | Optimize for size                            | Disables size-increasing optimizations |
| -Ofast| Maximum performance (non-standard)           | -O3 + fast math + non-IEEE compliance |

### 3.6.3 Common Optimizations

**Constant Folding**: Evaluate constant expressions at compile time:
```c
// Source
int x = 2 + 3 * 4;

// Optimized (evaluated at compile time)
int x = 14;
```

**Constant Propagation**: Substitute known constant values:
```c
// Source
int a = 5;
int b = a + 10;

// Optimized
int a = 5;
int b = 15;
```

**Dead Code Elimination**: Remove code that has no effect:
```c
// Source
int x = 10;
x = 20;  // First assignment is dead
return x;

// Optimized
int x = 20;
return x;
```

**Common Subexpression Elimination (CSE)**: Compute repeated expressions once:
```c
// Source
int a = b * c + d;
int e = b * c + f;

// Optimized
int temp = b * c;
int a = temp + d;
int e = temp + f;
```

**Loop Invariant Code Motion**: Move computations out of loops:
```c
// Source
for (int i = 0; i < n; i++) {
    x = a * b + i;  // a * b is invariant
}

// Optimized
int temp = a * b;
for (int i = 0; i < n; i++) {
    x = temp + i;
}
```

**Loop Unrolling**: Replicate loop body to reduce branch overhead:
```c
// Source
for (int i = 0; i < 4; i++) {
    a[i] = b[i];
}

// Optimized
a[0] = b[0];
a[1] = b[1];
a[2] = b[2];
a[3] = b[3];
```

**Strength Reduction**: Replace expensive operations with cheaper ones:
```c
// Source
int x = a * 2;    // Multiplication
int y = a * 16;   // Multiplication
int z = a % 8;    // Modulo

// Optimized
int x = a << 1;   // Bit shift
int y = a << 4;   // Bit shift
int z = a & 7;    // Bitwise AND
```

**Function Inlining**: Replace function call with the function body:
```c
// Source
static int square(int x) { return x * x; }
int result = square(5);

// Optimized
int result = 5 * 5;
```

**Vectorization (SIMD)**: Use vector instructions for parallel operations:
```c
// Source
for (int i = 0; i < 100; i++) {
    a[i] = b[i] + c[i];
}

// Optimized (using AVX)
for (int i = 0; i < 100; i += 8) {
    __m256i vb = _mm256_loadu_si256((__m256i*)&b[i]);
    __m256i vc = _mm256_loadu_si256((__m256i*)&c[i]);
    __m256i va = _mm256_add_epi32(vb, vc);
    _mm256_storeu_si256((__m256i*)&a[i], va);
}
```

### 3.6.4 Optimization Example

Let's trace a complete optimization sequence:

```c
// Original source
int sum_array(int* arr, int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += arr[i];
    }
    return sum;
}
```

After parsing (AST-like):
```
Function(sum_array):
  params: arr, n
  local: sum, i
  body:
    sum = 0
    i = 0
    while (i < n):
      sum = sum + arr[i]
      i = i + 1
    return sum
```

After IR generation (simplified):
```
sum_1 = 0
i_1 = 0
goto check

check:
  t1 = i_1 < n
  if t1 goto body else goto end

body:
  t2 = arr + i_1 * 4
  t3 = *t2
  sum_2 = sum_1 + t3
  i_2 = i_1 + 1
  goto check

end:
  return sum_1
```

After SSA conversion:
```
sum_1 = 0
i_1 = 0
goto check

check:
  i_2 = φ(i_1, i_4)    // From entry or loop
  sum_2 = φ(sum_1, sum_3)
  t1 = i_2 < n
  if t1 goto body else goto end

body:
  t2 = arr + i_2 * 4
  t3 = *t2
  sum_3 = sum_2 + t3
  i_4 = i_2 + 1
  goto check

end:
  return sum_2
```

After optimizations:
```
check:
  i_2 = φ(0, i_4)      // Constant propagation: i_1 = 0
  sum_2 = φ(0, sum_3)  // Constant propagation: sum_1 = 0
  t1 = i_2 < n
  if t1 goto body else goto end

body:
  t2 = arr + i_2 << 2  // Strength reduction: *4 → <<2
  t3 = *t2
  sum_3 = sum_2 + t3
  i_4 = i_2 + 1
  goto check

end:
  return sum_2
```

## 3.7 Code Generation

### 3.7.1 Instruction Selection

The code generator selects machine instructions to implement each IR operation:

```
IR: t3 = t1 + t2

x86-64:  add eax, ecx      ; Add ecx to eax
ARM:     add r0, r1, r2    ; r0 = r1 + r2
RISC-V:  add a0, a1, a2    ; a0 = a1 + a2
```

### 3.7.2 Register Allocation

The **register allocator** maps IR temporaries to physical registers. Since registers are limited, values may need to be **spilled** to memory.

```
IR temporaries: t1, t2, t3, t4, t5, t6
Available registers: eax, ecx, edx (3 registers)

Allocation:
  t1 → eax
  t2 → ecx
  t3 → edx
  t4 → [stack - 4]   (spilled)
  t5 → eax (t1 dead, can reuse)
  t6 → ecx (t2 dead, can reuse)
```

**Register Allocation Algorithms**:
- **Linear scan**: Fast but suboptimal
- **Graph coloring**: Classic algorithm, optimal for many cases
- **Iterated register coalescing**: Used in many production compilers

### 3.7.3 Instruction Scheduling

The scheduler reorders instructions to:
- Avoid pipeline stalls
- Hide memory latency
- Maximize instruction-level parallelism

```
// Original order
load r1, [arr]      // Cache miss, stalls
add r2, r1, r3      // Waits for r1
store [result], r2

// Scheduled (reordered)
load r1, [arr]      // Start load early
... other independent instructions ...
add r2, r1, r3
store [result], r2
```

### 3.7.4 Complete Code Generation Example

Source:
```c
int square(int x) {
    return x * x;
}
```

IR:
```
define i32 @square(i32 %x) {
  %result = mul i32 %x, %x
  ret i32 %result
}
```

x86-64 Assembly:
```assembly
square:
    mov eax, edi        ; Move argument to eax (result register)
    imul eax, eax       ; eax = eax * eax
    ret                 ; Return (eax contains result)
```

ARM64 Assembly:
```assembly
square:
    mul w0, w0, w0      ; w0 = w0 * w0
    ret                 ; Return (w0 contains result)
```

## 3.8 Compiler Flags for Optimization

### 3.8.1 -O0 (No Optimization)

- Fastest compilation
- Best debugging experience
- Variables stay in memory as declared
- No optimization surprises

Use for: Development, debugging

### 3.8.2 -O1 (Basic Optimization)

- Reasonable compilation time
- Basic optimizations enabled
- Still debuggable (mostly)
- Good balance for development

Optimizations enabled: dead code elimination, basic block reordering, simple inlining

### 3.8.3 -O2 (Standard Optimization)

- Slower compilation
- Most beneficial optimizations
- Generally safe
- Industry standard for release builds

Optimizations enabled: all from -O1, plus inlining, loop optimizations, common subexpression elimination, instruction scheduling

### 3.8.4 -O3 (Aggressive Optimization)

- Slowest compilation
- May increase code size
- May not be faster than -O2
- Some risky optimizations

Optimizations enabled: all from -O2, plus aggressive inlining, loop unrolling, vectorization

### 3.8.5 -Os (Optimize for Size)

- Minimizes code size
- Good for embedded systems
- May be faster due to better cache utilization
- Disables size-increasing optimizations

### 3.8.6 -Ofast (Maximum Performance)

- Disables strict standards compliance
- Enables fast math optimizations
- May change numerical results
- Use with caution

Example of fast math behavior:
```c
// Source
double x = a * b + c;

// -O2: Standard IEEE 754
// -Ofast: May reorder to (a * b) + c → a * (b + c/a) if faster
```

## 3.9 Viewing Compiler Output

### 3.9.1 View Intermediate Representations

```bash
# GCC: View GIMPLE
gcc -fdump-tree-gimple source.c

# GCC: View all passes
gcc -fdump-tree-all source.c

# Clang/LLVM: View LLVM IR
clang -S -emit-llvm source.c -o source.ll

# Clang/LLVM: View IR with optimization
clang -S -emit-llvm -O2 source.c -o source.ll
```

### 3.9.2 View Assembly Output

```bash
# Generate assembly file
gcc -S source.c -o source.s

# With comments and C source intermixed
gcc -S -fverbose-asm source.c -o source.s

# With source line annotations
gcc -g -S source.c -o source.s
```

### 3.9.3 View Optimization Decisions

```bash
# GCC: Show vectorization info
gcc -O3 -fopt-info-vec source.c

# GCC: Show all optimization decisions
gcc -O3 -fopt-info-all source.c

# Clang: Show optimization remarks
clang -Rpass=inline source.c
clang -Rpass-missed=inline source.c
```

## 3.10 Key Takeaways

1. **Compilation is multi-stage**: Lexical analysis → parsing → semantic analysis → IR generation → optimization → code generation.

2. **AST captures structure**: The Abstract Syntax Tree represents your code's syntactic structure without syntactic sugar.

3. **IR enables optimization**: Intermediate representations like SSA make optimizations easier and architecture-independent.

4. **SSA is crucial**: Static Single Assignment form, where each variable is assigned once, simplifies many analyses.

5. **Optimization levels trade off compile time vs. performance**: -O0 for debugging, -O2 for production, -O3 for maximum performance.

6. **Register allocation is critical**: Limited registers must be carefully allocated; spilling to memory hurts performance.

7. **Modern compilers are sophisticated**: Hundreds of optimization passes work together to generate efficient code.

8. **Understanding compilation helps write better code**: Knowing how compilers think helps you write code they can optimize effectively.

## 3.11 Looking Ahead

Now that we've seen how the compiler generates assembly code, we'll examine that assembly output in detail. In Chapter 4, we'll explore assembly language, object file structure, and how assembly is translated into machine code.

## Further Reading

- "Engineering a Compiler" by Cooper and Torczon
- "Modern Compiler Implementation in C" by Appel
- LLVM Language Reference Manual: https://llvm.org/docs/LangRef.html
- GCC Internals: https://gcc.gnu.org/onlinedocs/gccint/
- "Advanced Compiler Design and Implementation" by Muchnick
