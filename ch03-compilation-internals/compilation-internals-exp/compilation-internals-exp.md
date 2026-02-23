# Experiment: Compare optimization levels

## Objective
- Observe how optimization levels change the generated assembly.

## Setup requirements
- gcc or clang installed.
- Linux or WSL recommended.

## Step-by-step commands
1. Create a small loop-based program:
   ```c
   int sum(int *a, int n) {
     int s = 0;
     for (int i = 0; i < n; i++) s += a[i];
     return s;
   }
   ```
2. Generate assembly at O0:
   ```bash
   gcc -S -O0 -o sum_O0.s sum.c
   ```
3. Generate assembly at O2:
   ```bash
   gcc -S -O2 -o sum_O2.s sum.c
   ```
4. Compare the two outputs.

## Expected output explanation
- O0 keeps a straightforward translation with many loads and stores.
- O2 may unroll, vectorize, or keep values in registers longer.

## Questions for reader
1. Which instructions disappear at O2 and why?
2. How does register allocation differ between the outputs?
3. What optimizations would be risky for debugging?
