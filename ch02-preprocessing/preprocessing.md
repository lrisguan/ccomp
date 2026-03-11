# Chapter 2: Preprocessing

## Introduction

Before a C compiler sees your source code, it passes through the **preprocessor**—a powerful text transformation engine that manipulates your code at the character level. The preprocessor doesn't understand C syntax; it simply performs textual substitutions, file inclusions, and conditional deletions.

Understanding preprocessing is essential because:
- It's where macros, includes, and conditionals are handled
- Errors in preprocessing can produce baffling compiler errors
- The preprocessor determines what the compiler actually sees
- Many build configurations rely on preprocessor conditionals

In this chapter, we'll explore every aspect of the C preprocessor, from simple macros to complex conditional compilation, with hands-on examples you can try yourself.

## 2.1 What is the Preprocessor?

The C preprocessor (often abbreviated as CPP) is a separate program that processes your source code before the compiler proper. On most systems, it's invoked automatically by the compiler driver (like `gcc`), but you can also run it standalone:

```bash
# Run preprocessor only, output to stdout
gcc -E source.c

# Run preprocessor only, output to file
gcc -E source.c -o source.i
```

The preprocessor operates on **translation units**—essentially, what the compiler processes as a single entity. The output of the preprocessor is a single, expanded text stream that the compiler then parses.

### 2.1.1 Preprocessing as Text Transformation

The preprocessor performs three main operations:

1. **Macro expansion**: Replace defined symbols with their definitions
2. **File inclusion**: Insert the contents of other files
3. **Conditional compilation**: Include or exclude code based on conditions

All of these are pure text operations. The preprocessor doesn't know about C syntax, types, or scope. It just manipulates text.

```
┌─────────────────────────────────────────────────────────────┐
│              The Preprocessing Pipeline                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   source.c ──┐                                              │
│              │    ┌─────────────┐    ┌─────────────┐        │
│   header.h ──┼───▶│ Preprocessor│───▶│ source.i    │        │
│              │    │   (cpp)     │    │ (expanded)  │        │
│   config.h ──┘    └─────────────┘    └─────────────┘        │
│                         │                                   │
│                    Text transformations:                    │
│                    - #include → file contents               │
│                    - #define → substitutions                │
│                    - #if/#ifdef → conditional code          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 2.2 Macro Expansion

### 2.2.1 Object-Like Macros

The simplest macros are object-like—they replace a name with a token sequence:

```c
#define PI 3.14159
#define MAX_SIZE 1024
#define DEBUG 1

int main(void) {
    double area = PI * radius * radius;
    int buffer[MAX_SIZE];
    if (DEBUG) {
        printf("Debug mode enabled\n");
    }
    return 0;
}
```

After preprocessing, this becomes:

```c
int main(void) {
    double area = 3.14159 * radius * radius;
    int buffer[1024];
    if (1) {
        printf("Debug mode enabled\n");
    }
    return 0;
}
```

> **Tip**: Use UPPERCASE names for macros to distinguish them from variables. This is a convention, not a requirement, but it helps readers identify macros at a glance.

### 2.2.2 Function-Like Macros

Macros can take arguments, making them look like functions:

```c
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define SQUARE(x) ((x) * (x))
#define ABS(x) ((x) < 0 ? -(x) : (x))

int main(void) {
    int m = MAX(3, 5);          // Expands to: ((3) > (5) ? (3) : (5))
    int sq = SQUARE(4);          // Expands to: ((4) * (4))
    int av = ABS(-10);           // Expands to: ((-10) < 0 ? -(-10) : (-10))
    return 0;
}
```

> **Critical Warning**: Always parenthesize macro arguments! Without parentheses, operator precedence can cause unexpected behavior:
> ```c
> #define BAD_SQUARE(x) x * x
> int result = BAD_SQUARE(1 + 2);  // Expands to: 1 + 2 * 1 + 2 = 5, not 9!
> ```

### 2.2.3 Macro Pitfall: Multiple Evaluation

Function-like macros can evaluate arguments multiple times:

```c
#define MAX(a, b) ((a) > (b) ? (a) : (b))

int x = 5;
int m = MAX(x++, 3);  // Problem: x might be incremented once or twice!
```

After expansion:
```c
int m = ((x++) > (3) ? (x++) : (3));
```

If `x` is 5, then `x++` (which returns 5) is compared to 3. Since 5 > 3 is true, the result is `x++` again—but now `x` is 6, so this returns 6. `x` ends up as 7, and `m` is 6.

**Solution**: Use inline functions when possible, or be very careful with macro arguments that have side effects:

```c
// Prefer inline functions for type safety and single evaluation
static inline int max(int a, int b) {
    return a > b ? a : b;
}
```

### 2.2.4 Multi-Line Macros

For longer macros, use backslash continuation:

```c
#define SWAP(a, b, type) do { \
    type temp = a; \
    a = b; \
    b = temp; \
} while (0)

int main(void) {
    int x = 1, y = 2;
    SWAP(x, y, int);  // x = 2, y = 1
    return 0;
}
```

> **Why the `do { ... } while (0)`?** This idiom allows the macro to be used like a statement with a semicolon, without breaking `if-else` chains:
> ```c
> if (condition)
>     SWAP(a, b, int);  // Works correctly
> else
>     do_something();
> ```

### 2.2.5 Stringification (#)

The `#` operator converts a macro argument to a string:

```c
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

#define VALUE 42

const char* s1 = STRINGIFY(VALUE);   // s1 = "VALUE"
const char* s2 = TOSTRING(VALUE);    // s2 = "42"
```

The difference: `STRINGIFY` stringifies the argument literally, while `TOSTRING` first expands the argument, then stringifies it.

### 2.2.6 Token Pasting (##)

The `##` operator concatenates tokens:

```c
#define CONCAT(a, b) a ## b
#define MAKE_VAR(name, num) int name ## _ ## num

int main(void) {
    int CONCAT(var, 1) = 10;        // Creates variable var1
    MAKE_VAR(item, 5) = 20;          // Creates variable item_5
    return 0;
}
```

This is commonly used for generating names programmatically:

```c
#define DEFINE_HANDLER(num) void handler_##num(void) { \
    printf("Handler %d called\n", num); \
}

DEFINE_HANDLER(1)  // Creates handler_1
DEFINE_HANDLER(2)  // Creates handler_2
DEFINE_HANDLER(3)  // Creates handler_3
```

### 2.2.7 Variadic Macros

Macros can accept variable numbers of arguments using `...` and `__VA_ARGS__`:

```c
#define DEBUG_PRINT(fmt, ...) \
    fprintf(stderr, "[DEBUG] " fmt "\n", __VA_ARGS__)

#define LOG(level, msg, ...) \
    printf("[%s] " msg "\n", level, __VA_ARGS__)

int main(void) {
    DEBUG_PRINT("Value: %d, Status: %s", 42, "OK");
    LOG("INFO", "User %s logged in", "alice");
    return 0;
}
```

For C99 compatibility with zero variadic arguments, use `##__VA_ARGS__` (GCC extension, now standard in C++20):

```c
#define DEBUG_PRINT(fmt, ...) \
    fprintf(stderr, "[DEBUG] " fmt "\n", ##__VA_ARGS__)

DEBUG_PRINT("Simple message");  // Works even with no extra args
```

## 2.3 File Inclusion

### 2.3.1 #include Basics

The `#include` directive inserts the contents of another file:

```c
#include <stdio.h>      // System header (angle brackets)
#include "myheader.h"   // Local header (double quotes)
```

The difference between `<...>` and `"..."` is the search path:

| Syntax        | Search Order                                          |
|---------------|------------------------------------------------------|
| `<header.h>`  | System include paths only                             |
| `"header.h"`  | Current directory first, then system include paths    |

### 2.3.2 Include Search Paths

The preprocessor searches for headers in specific directories:

```bash
# View default include paths
gcc -E -x c - -v < /dev/null 2>&1 | grep "^ "

# Add custom include paths
gcc -I/path/to/includes -I../another/path source.c
```

Common system include paths on Linux:
- `/usr/include`
- `/usr/local/include`
- `/usr/lib/gcc/x86_64-linux-gnu/11/include` (compiler-specific)

### 2.3.3 The Include Graph

With nested includes, you can build complex dependency graphs:

```
source.c
├── <stdio.h>
│   ├── <bits/libc-header-start.h>
│   ├── <features.h>
│   │   ├── <stdc-predef.h>
│   │   └── <sys/cdefs.h>
│   └── <bits/types.h>
├── "config.h"
│   └── <stdint.h>
└── "utils.h"
    └── <stdlib.h>
```

To see the include graph:

```bash
# Show included files
gcc -E source.c -H

# Output example:
# . /usr/include/stdio.h
# .. /usr/include/bits/libc-header-start.h
# .. /usr/include/features.h
```

### 2.3.4 Include Guards and #pragma once

Without protection, a header included twice causes errors:

```c
// header.h
struct Point { int x, y; };

// source.c
#include "header.h"
#include "header.h"  // Error: redefinition of 'struct Point'!
```

**Solution 1: Include Guards (Traditional)**

```c
#ifndef HEADER_H
#define HEADER_H

struct Point { int x, y; };

#endif /* HEADER_H */
```

The first inclusion defines `HEADER_H`. Subsequent inclusions see the guard and skip the content.

**Solution 2: #pragma once (Modern)**

```c
#pragma once

struct Point { int x, y; };
```

`#pragma once` tells the preprocessor to include this file at most once per compilation unit. It's simpler and often faster, but technically non-standard (though supported by all major compilers).

> **Recommendation**: Use `#pragma once` for new code. It's cleaner and less error-prone. Use include guards if you need strict C standard compliance.

## 2.4 Conditional Compilation

Conditional compilation lets you include or exclude code based on conditions evaluated during preprocessing.

### 2.4.1 #if, #elif, #else, #endif

```c
#define VERSION 3

#if VERSION == 1
    #define FEATURE_NAME "Basic"
#elif VERSION == 2
    #define FEATURE_NAME "Standard"
#elif VERSION == 3
    #define FEATURE_NAME "Premium"
#else
    #define FEATURE_NAME "Unknown"
#endif
```

### 2.4.2 #ifdef and #ifndef

Test whether a macro is defined:

```c
#ifdef DEBUG
    printf("Debug mode enabled\n");
#endif

#ifndef BUFFER_SIZE
    #define BUFFER_SIZE 1024  // Default value
#endif
```

These are equivalent to:

```c
#if defined(DEBUG)
#if !defined(BUFFER_SIZE)
```

### 2.4.3 defined() Operator

The `defined()` operator checks if a macro exists:

```c
#if defined(DEBUG) && defined(VERBOSE)
    #define LOG_LEVEL 3
#elif defined(DEBUG)
    #define LOG_LEVEL 2
#else
    #define LOG_LEVEL 1
#endif
```

### 2.4.4 Common Use Cases

**Platform Detection:**

```c
#ifdef _WIN32
    #define PATH_SEPARATOR '\\'
    #include <windows.h>
#elif defined(__linux__)
    #define PATH_SEPARATOR '/'
    #include <unistd.h>
#elif defined(__APPLE__)
    #define PATH_SEPARATOR '/'
    #include <mach-o/dyld.h>
#endif
```

**Debug vs. Release:**

```c
#ifdef NDEBUG
    #define ASSERT(cond) ((void)0)
#else
    #define ASSERT(cond) \
        do { \
            if (!(cond)) { \
                fprintf(stderr, "Assertion failed: %s, %s:%d\n", \
                        #cond, __FILE__, __LINE__); \
                abort(); \
            } \
        } while (0)
#endif
```

**Feature Flags:**

```c
// Compile with: gcc -DUSE_OPENCL source.c
#ifdef USE_OPENCL
    void compute(void) { /* OpenCL implementation */ }
#elif defined(USE_CUDA)
    void compute(void) { /* CUDA implementation */ }
#else
    void compute(void) { /* CPU fallback */ }
#endif
```

**Header Inclusion Control:**

```c
// Disable assert.h assertions
#define NDEBUG
#include <assert.h>
```

## 2.5 Predefined Macros

The C standard and compilers provide predefined macros:

### 2.5.1 Standard Predefined Macros

| Macro           | Description                          | Example Value            |
|-----------------|--------------------------------------|--------------------------|
| `__FILE__`      | Current source file name             | `"source.c"`             |
| `__LINE__`      | Current line number                  | `42`                     |
| `__func__`      | Current function name (C99)          | `"main"`                 |
| `__DATE__`      | Compilation date                     | `"Mar 11 2026"`          |
| `__TIME__`      | Compilation time                     | `"16:30:00"`             |
| `__STDC__`      | 1 if compiler conforms to C standard | `1`                      |
| `__STDC_VERSION__` | C standard version (as long)      | `201710L` (C17)          |

### 2.5.2 Compiler-Specific Macros

**GCC:**
```c
#ifdef __GNUC__
    #define GCC_VERSION (__GNUC__ * 10000 + __GNUC_MINOR__ * 100 + __GNUC_PATCHLEVEL__)
    #if GCC_VERSION >= 90100
        // GCC 9.1+ specific code
    #endif
#endif
```

**Clang:**
```c
#ifdef __clang__
    #define CLANG_VERSION (__clang_major__ * 10000 + __clang_minor__ * 100 + __clang_patchlevel__)
#endif
```

**MSVC:**
```c
#ifdef _MSC_VER
    #if _MSC_VER >= 1920
        // Visual Studio 2019+
    #endif
#endif
```

### 2.5.3 Platform Detection Macros

```c
// Architecture
#if defined(__x86_64__) || defined(_M_X64)
    #define ARCH_X64
#elif defined(__i386__) || defined(_M_IX86)
    #define ARCH_X86
#elif defined(__arm__) || defined(_M_ARM)
    #define ARCH_ARM
#elif defined(__aarch64__)
    #define ARCH_ARM64
#endif

// Operating System
#if defined(_WIN32) || defined(_WIN64)
    #define OS_WINDOWS
#elif defined(__linux__)
    #define OS_LINUX
#elif defined(__APPLE__)
    #define OS_MACOS
#elif defined(__FreeBSD__)
    #define OS_FREEBSD
#endif
```

### 2.5.4 Practical Example: Debug Logging

```c
#define LOG_DEBUG(fmt, ...) \
    fprintf(stderr, "[%s:%d] " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__)

#define LOG_FUNC_ENTRY() \
    fprintf(stderr, "Entering %s() at %s:%d\n", __func__, __FILE__, __LINE__)

void process_data(int value) {
    LOG_FUNC_ENTRY();
    LOG_DEBUG("Processing value: %d", value);
    // ... processing code ...
}

int main(void) {
    process_data(42);
    return 0;
}
```

Output:
```
Entering process_data() at source.c:10
[source.c:11] Processing value: 42
```

## 2.6 #define vs. enum vs. const

When should you use macros versus other constants?

### 2.6.1 Macros

```c
#define MAX_ITEMS 100
#define VERSION "1.0.0"
```

**Pros:**
- Works in preprocessor conditionals
- No memory allocation (text substitution)
- Can be undefined and redefined

**Cons:**
- No type checking
- Not visible in debugger
- Can cause unexpected substitutions

### 2.6.2 enum

```c
enum {
    MAX_ITEMS = 100,
    BUFFER_SIZE = 1024
};

// Typed enums (C23 or earlier with compiler support)
typedef enum Status {
    STATUS_OK = 0,
    STATUS_ERROR = 1,
    STATUS_PENDING = 2
} Status;
```

**Pros:**
- Type-safe (with typed enums)
- Visible in debugger
- Scoped (with `enum class` in C++)

**Cons:**
- Integer values only
- Cannot be used in preprocessor conditionals

### 2.6.3 const

```c
const int max_items = 100;
const char* const version = "1.0.0";
```

**Pros:**
- Type-safe
- Scoped properly
- Visible in debugger
- Can take address

**Cons:**
- Cannot be used in preprocessor conditionals
- May occupy memory (though compilers often optimize)
- Cannot be used for array sizes in C89 (VLA in C99)

### 2.6.4 Recommendation

```c
// For preprocessor conditionals
#define FEATURE_ENABLED 1
#define PLATFORM_LINUX 1

// For integer constants
enum { MAX_ITEMS = 100, BUFFER_SIZE = 1024 };

// For typed constants
static const char* const APP_NAME = "MyApp";
static const double PI = 3.141592653589793;
```

## 2.7 Translation Units

A **translation unit** is the result of preprocessing a single source file with all its included headers. This is what the compiler proper processes.

### 2.7.1 Translation Unit Boundaries

Each `.c` file is a separate translation unit:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     main.c      │     │    utils.c      │     │    config.c     │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Translation     │     │ Translation     │     │ Translation     │
│ Unit 1          │     │ Unit 2          │     │ Unit 3          │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    main.o       │     │    utils.o      │     │    config.o     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                       ┌─────────────────┐
                       │   Executable    │
                       └─────────────────┘
```

### 2.7.2 Static Variables and Translation Units

Variables and functions with `static` linkage are private to their translation unit:

```c
// utils.c
static int internal_counter = 0;  // Only visible in utils.c

static void internal_helper(void) {  // Only visible in utils.c
    internal_counter++;
}

void public_function(void) {
    internal_helper();
}

// main.c
extern int internal_counter;  // Error! Not accessible
```

### 2.7.3 One Definition Rule (ODR)

Each translation unit can have at most one definition of each external symbol. Violations cause linker errors:

```c
// header.h
int global_var = 42;  // WRONG! Multiple definitions if included in multiple .c files

// Correct approach:
// header.h
extern int global_var;  // Declaration only

// source.c
int global_var = 42;  // Definition in one place
```

## 2.8 Common Preprocessor Idioms

### 2.8.1 Include Guard with #pragma once

```c
#ifndef MYHEADER_H
#define MYHEADER_H
#pragma once

// Header contents

#endif /* MYHEADER_H */
```

This provides both compatibility and optimization.

### 2.8.2 Compile-Time Assertions

```c
// C11 _Static_assert
_Static_assert(sizeof(int) == 4, "int must be 4 bytes");
static_assert(sizeof(void*) == 8, "64-bit platform required");

// Pre-C11 hack
#define STATIC_ASSERT(cond, msg) \
    typedef char static_assert_##msg[(cond) ? 1 : -1]

STATIC_ASSERT(sizeof(int) == 4, int_must_be_4_bytes);
```

### 2.8.3 X-Macro Pattern

Generate repetitive code from a data table:

```c
// Define the list
#define ITEM_LIST \
    X(ITEM_A, 1) \
    X(ITEM_B, 2) \
    X(ITEM_C, 3)

// Generate enum
typedef enum {
    #define X(name, value) name = value,
    ITEM_LIST
    #undef X
} Items;

// Generate string array
const char* item_names[] = {
    #define X(name, value) #name,
    ITEM_LIST
    #undef X
};

// Generate handler functions
#define X(name, value) void handle_##name(void);
ITEM_LIST
#undef X

// Expands to:
// typedef enum { ITEM_A = 1, ITEM_B = 2, ITEM_C = 3 } Items;
// const char* item_names[] = { "ITEM_A", "ITEM_B", "ITEM_C" };
// void handle_ITEM_A(void);
// void handle_ITEM_B(void);
// void handle_ITEM_C(void);
```

### 2.8.4 Counting Arguments

```c
#define VA_NARGS_IMPL(_1, _2, _3, _4, N, ...) N
#define VA_NARGS(...) VA_NARGS_IMPL(__VA_ARGS__, 4, 3, 2, 1)

VA_NARGS(a)        // 1
VA_NARGS(a, b)     // 2
VA_NARGS(a, b, c)  // 3
```

## 2.9 Key Takeaways

1. **Preprocessing is text-only**: The preprocessor doesn't understand C syntax; it performs pure text substitutions.

2. **Parenthesize macro arguments**: Without parentheses, operator precedence can cause unexpected results.

3. **Beware of multiple evaluation**: Function-like macros can evaluate arguments multiple times, causing side effects.

4. **Use `#pragma once` for headers**: It's simpler and less error-prone than traditional include guards.

5. **Conditional compilation is powerful**: Use it for platform detection, debug builds, and feature flags.

6. **Predefined macros are useful**: `__FILE__`, `__LINE__`, and `__func__` enable powerful debugging macros.

7. **Understand translation units**: Each `.c` file is a separate translation unit, and static symbols are private to their unit.

8. **Prefer alternatives when appropriate**: Use `enum` or `const` instead of macros for values that don't need preprocessor conditions.

## 2.10 Looking Ahead

Now that we understand how preprocessing transforms source code into translation units, we're ready to explore what happens next: compilation. In Chapter 3, we'll examine how the compiler parses C code, builds intermediate representations, performs optimizations, and generates assembly code.

## Further Reading

- "The C Programming Language" (K&R) - Chapter 4
- C17 Standard (ISO/IEC 9899:2018) - Section 6.10 (Preprocessing directives)
- GCC Preprocessor Documentation: https://gcc.gnu.org/onlinedocs/cpp/
- "Modern C" by Jens Gustedt - Chapter 5 (Preprocessing)
