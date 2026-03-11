# Experiment: Exploring the C Preprocessor

## Objective

Observe preprocessing in action by examining macro expansion, file inclusion, and conditional compilation.

## Setup Requirements

- GCC or Clang compiler
- Linux or Unix-like environment
- Basic familiarity with command line

## Step-by-Step Commands

### Part 1: Basic Preprocessing

1. Create a simple source file:

```c
// demo.c
#include <stdio.h>

#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define DEBUG 1

int main(void) {
    int x = MAX(3, 5);
#ifdef DEBUG
    printf("Debug: x = %d\n", x);
#endif
    return 0;
}
```

2. Run the preprocessor only:

```bash
gcc -E demo.c -o demo.i
```

3. View the preprocessed output:

```bash
head -50 demo.i
tail -20 demo.i
```

**Expected Output**: You'll see the expanded `#include <stdio.h>` (hundreds of lines from the standard library), the macro `MAX(3, 5)` expanded to `((3) > (5) ? (3) : (5))`, and the debug printf included because `DEBUG` is defined.

### Part 2: Macro Expansion Pitfalls

1. Create a file demonstrating macro issues:

```c
// macro_pitfalls.c
#define SQUARE(x) x * x
#define SAFE_SQUARE(x) ((x) * (x))

int main(void) {
    int a = SQUARE(1 + 2);      // Problem!
    int b = SAFE_SQUARE(1 + 2); // Safe
    
    int i = 5;
    int c = SQUARE(i++);        // Double increment!
    // int d = SAFE_SQUARE(i++); // Still problematic
    
    return 0;
}
```

2. Preprocess and observe:

```bash
gcc -E macro_pitfalls.c | grep -A5 "int a"
```

**Expected Output**:
```c
int a = 1 + 2 * 1 + 2;  // = 5, not 9!
int b = ((1 + 2) * (1 + 2));  // = 9, correct
```

### Part 3: Conditional Compilation

1. Create a file with conditional compilation:

```c
// config.c
#define VERSION 3
#define PLATFORM_LINUX 1

#if VERSION < 2
    #define FEATURE_LEVEL "Basic"
#elif VERSION < 4
    #define FEATURE_LEVEL "Standard"
#else
    #define FEATURE_LEVEL "Premium"
#endif

#ifdef PLATFORM_LINUX
    #define PATH_SEPARATOR '/'
#else
    #define PATH_SEPARATOR '\\'
#endif

int main(void) {
    const char* level = FEATURE_LEVEL;
    char sep = PATH_SEPARATOR;
    return 0;
}
```

2. Preprocess with different definitions:

```bash
gcc -E config.c | grep "level\|sep"
gcc -E -DVERSION=5 config.c | grep "level\|sep"
gcc -E -UPLATFORM_LINUX config.c | grep "level\|sep"
```

### Part 4: Include Paths and Header Guards

1. Create a custom header:

```c
// myheader.h
#ifndef MYHEADER_H
#define MYHEADER_H

int my_function(int x);

#define MY_CONSTANT 42

#endif
```

2. Create a source file that includes it twice:

```c
// double_include.c
#include "myheader.h"
#include "myheader.h"  // Safe due to header guard

int main(void) {
    int x = MY_CONSTANT;
    return 0;
}
```

3. Observe the preprocessor output:

```bash
gcc -E double_include.c | grep -c "MY_CONSTANT"
```

**Expected Output**: `1` (the header guard prevents double inclusion)

4. Test include path:

```bash
mkdir -p /tmp/headers
mv myheader.h /tmp/headers/
gcc -E -I/tmp/headers double_include.c | tail -5
```

### Part 5: Stringification and Token Pasting

1. Create a file demonstrating advanced macros:

```c
// advanced_macros.c
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define CONCAT(a, b) a ## b
#define MAKE_FUNC(name) void func_##name(void) { printf(#name "\n"); }

#define VALUE 42

MAKE_FUNC(alpha)
MAKE_FUNC(beta)

int main(void) {
    const char* s1 = STRINGIFY(VALUE);
    const char* s2 = TOSTRING(VALUE);
    int CONCAT(my, var) = 10;
    func_alpha();
    func_beta();
    return 0;
}
```

2. Preprocess and examine:

```bash
gcc -E advanced_macros.c | grep -A2 "int main"
```

**Expected Output**:
```c
void func_alpha(void) { printf("alpha" "\n"); }
void func_beta(void) { printf("beta" "\n"); }

int main(void) {
    const char* s1 = "VALUE";
    const char* s2 = "42";
    int myvar = 10;
```

### Part 6: Predefined Macros

1. Create a file using predefined macros:

```c
// predefined.c
#include <stdio.h>

int main(void) {
    printf("File: %s\n", __FILE__);
    printf("Line: %d\n", __LINE__);
    printf("Function: %s\n", __func__);
    printf("Date: %s\n", __DATE__);
    printf("Time: %s\n", __TIME__);
    printf("STDC: %d\n", __STDC__);
    printf("STDC_VERSION: %ldL\n", __STDC_VERSION__);
    return 0;
}
```

2. Compile and run:

```bash
gcc predefined.c -o predefined && ./predefined
```

### Part 7: Include Dependencies

1. Generate include dependency graph:

```bash
gcc -M demo.c
gcc -MM demo.c  # System headers excluded
gcc -H demo.c 2>&1 | head -20
```

## Questions for Reader

1. **Macro Expansion**: Why does `SQUARE(1 + 2)` produce 5 instead of 9? How does proper parenthesization fix this?

2. **Side Effects**: What happens when you pass `i++` to the `MAX` macro? Why should you avoid macros with arguments that have side effects?

3. **Header Guards**: What would happen if you removed the `#ifndef` guard from `myheader.h` and included it twice? What error would you get?

4. **Conditional Compilation**: How can you use preprocessor conditionals to create a debug build vs. release build of your program?

5. **Stringification**: Why do you need two levels of macros (STRINGIFY and TOSTRING) to convert a macro's value to a string instead of its name?

6. **Real-World Application**: How might you use the X-macro pattern to generate repetitive code like switch statements or enum-to-string conversions?

## Further Exploration

- Examine how `assert.h` uses preprocessing to include file/line info
- Look at how large projects (like the Linux kernel) use conditional compilation
- Study the `-D` and `-U` flags for defining/undefining macros from the command line
- Explore `#pragma` directives and their uses
