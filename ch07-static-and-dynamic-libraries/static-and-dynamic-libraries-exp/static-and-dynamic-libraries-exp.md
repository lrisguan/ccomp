# Experiment: Compare static and dynamic linking

## Objective
- Build both static and dynamic variants and observe runtime dependencies.

## Setup requirements
- gcc or clang installed.
- ar, ldd available (Linux or WSL recommended).

## Step-by-step commands
1. Create a small library source:
   ```c
   int add(int a, int b) { return a + b; }
   ```
2. Build static and shared libraries:
   ```bash
   gcc -c -fPIC -o add.o add.c
   ar rcs libadd.a add.o
   gcc -shared -o libadd.so add.o
   ```
3. Build static and dynamic executables:
   ```bash
   gcc -o demo_static main.c -L. -ladd -static
   gcc -o demo_dynamic main.c -L. -ladd -Wl,-rpath,'$ORIGIN'
   ```
4. Inspect runtime dependencies:
   ```bash
   ldd demo_dynamic
   ```

## Expected output explanation
- The static binary embeds library code and has no `libadd.so` dependency.
- The dynamic binary records a dependency that the loader resolves at runtime.

## Questions for reader
1. Why might static linking fail on some systems?
2. How does `rpath` affect loader behavior?
3. What changes in binary size between the two builds?
