# Experiment: Inspect macro expansion

## Objective
- Observe how macros and includes are expanded in the preprocessor output.

## Setup requirements
- gcc or clang installed.
- A shell environment (Linux, WSL, or MSYS2).

## Step-by-step commands
1. Create a file with macros:
   ```c
   #define SCALE(x) ((x) * 2)
   #define FLAG 1
   #if FLAG
   int value = SCALE(3);
   #endif
   ```
2. Run the preprocessor with macro output:
   ```bash
   gcc -E -dD -o macros.i macros.c
   ```
3. Inspect `macros.i` and locate the expanded macro lines.

## Expected output explanation
- Macro definitions appear at the top when using `-dD`.
- The expansion replaces macro invocations with raw tokens.

## Questions for reader
1. How are nested macros expanded and in what order?
2. What happens if `FLAG` is set to 0?
3. Which lines come from system headers and why?
