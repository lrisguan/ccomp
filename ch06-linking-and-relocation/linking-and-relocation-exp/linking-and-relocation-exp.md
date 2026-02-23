# Experiment: Demonstrate symbol collision and weak overrides

## Objective
- Observe how strong and weak symbols are resolved at link time.

## Setup requirements
- gcc or clang installed.
- nm for symbol inspection.

## Step-by-step commands
1. Create two translation units:
   ```c
   // a.c
   __attribute__((weak)) int value(void) { return 1; }
   ```
   ```c
   // b.c
   int value(void) { return 2; }
   int main(void) { return value(); }
   ```
2. Compile and link:
   ```bash
   gcc -c a.c b.c
   gcc -o demo a.o b.o
   ```
3. Inspect symbols:
   ```bash
   nm -C demo | grep value
   ```

## Expected output explanation
- The strong definition in `b.c` overrides the weak definition in `a.c`.
- The resulting executable contains a single `value` symbol.

## Questions for reader
1. What happens if the strong definition is removed?
2. How does the linker report multiple strong definitions?
3. How do weak symbols affect library design?
