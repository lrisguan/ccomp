# Experiment: Exploring Compilation Internals

## Objective

Observe the compiler's transformation from source code to assembly, including intermediate representations and optimization effects.

## Setup Requirements

- GCC compiler
- LLVM/Clang (optional, for LLVM IR)
- Linux environment

## Step-by-Step Commands

### Part 1: Generating Assembly Output

1. Create a simple C file:

```c
// simple.c
int add(int a, int b) {
    return a + b;
}

int main(void) {
    int result = add(3, 5);
    return result;
}
```

2. Generate assembly without optimization:

```bash
gcc -S -O0 simple.c -o simple_O0.s
```

3. Generate assembly with optimization:

```bash
gcc -S -O2 simple.c -o simple_O2.s
gcc -S -O3 simple.c -o simple_O3.s
```

4. Compare the outputs:

```bash
diff simple_O0.s simple_O2.s
```

**Expected Observations**:
- `-O0`: Full function prologue/epilogue, stack operations
- `-O2`: Inlined `add`, minimal code, direct return

### Part 2: Viewing GCC Intermediate Representations

1. Create a more complex function:

```c
// compute.c
int compute(int n) {
    int sum = 0;
    for (int i = 1; i <= n; i++) {
        sum += i * i;
    }
    return sum;
}
```

2. Dump GIMPLE representation:

```bash
gcc -fdump-tree-gimple compute.c -c -o compute.o
cat compute.c.003t.gimple
```

3. View all optimization passes:

```bash
gcc -fdump-tree-all -O2 compute.c -c -o compute.o
ls -la compute.c.*.tree
```

4. Examine specific passes:

```bash
# Before optimization
cat compute.c.001t.tu

# After SSA conversion
cat compute.c.004t.ssa

# After optimization
cat compute.c.228t.optimized
```

### Part 3: Viewing LLVM IR

1. Install clang if needed:

```bash
sudo apt install clang  # Debian/Ubuntu
```

2. Generate LLVM IR:

```bash
clang -S -emit-llvm compute.c -o compute.ll
```

3. View the IR:

```bash
cat compute.ll
```

4. Generate optimized IR:

```bash
clang -S -emit-llvm -O2 compute.c -o compute_O2.ll
diff compute.ll compute_O2.ll
```

5. Use opt for optimization passes:

```bash
opt -S -mem2reg compute.ll -o compute_mem2reg.ll
```

### Part 4: Optimization Effects

1. Create test code:

```c
// opt_test.c
int dead_code(int x) {
    int a = 10;
    int b = 20;
    int c = a + b;  // Dead: never used
    return x * 2;
}

int constant_fold(void) {
    int x = 2 + 3 * 4;
    return x;
}

int loop_optimize(int* arr, int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += arr[i];
    }
    return sum;
}
```

2. Generate assembly at different optimization levels:

```bash
gcc -S -O0 opt_test.c -o opt_O0.s
gcc -S -O2 opt_test.c -o opt_O2.s
gcc -S -O3 opt_test.c -o opt_O3.s
```

3. Compare dead code elimination:

```bash
grep -A20 "dead_code:" opt_O0.s
grep -A10 "dead_code:" opt_O2.s
```

4. Compare constant folding:

```bash
grep -A5 "constant_fold:" opt_O0.s
grep -A5 "constant_fold:" opt_O2.s
```

### Part 5: Inlining Analysis

1. Create test file:

```c
// inline_test.c
static int square(int x) {
    return x * x;
}

int calculate(int n) {
    return square(n) + square(n + 1);
}
```

2. Examine without inlining:

```bash
gcc -S -O0 -fno-inline inline_test.c -o inline_no.s
grep "square" inline_no.s
```

3. Examine with inlining:

```bash
gcc -S -O2 inline_test.c -o inline_yes.s
grep "square" inline_yes.s || echo "Function inlined!"
```

### Part 6: Vectorization

1. Create vectorizable code:

```c
// vector.c
void add_arrays(float* a, float* b, float* c, int n) {
    for (int i = 0; i < n; i++) {
        c[i] = a[i] + b[i];
    }
}
```

2. Compile with vectorization info:

```bash
gcc -O3 -fopt-info-vec vector.c -c -o vector.o
```

3. Examine assembly for SIMD instructions:

```bash
gcc -S -O3 vector.c -o vector.s
grep -E "(xmm|ymm|zmm)" vector.s
```

### Part 7: Debug Symbols and Source Mapping

1. Compile with debug info:

```bash
gcc -g compute.c -o compute_debug
```

2. View debug info:

```bash
readelf --debug-dump=info compute_debug | head -50
```

3. Use addr2line:

```bash
addr2line -e compute_debug 0xXXXX  # Use actual address from objdump
objdump -d compute_debug | head -20
```

### Part 8: Function Size Analysis

1. Create a program with multiple functions:

```c
// sizes.c
int tiny(void) { return 42; }

int small(int x) { return x * 2; }

int medium(int x, int y) {
    int result = 0;
    for (int i = 0; i < 10; i++) {
        result += x + y * i;
    }
    return result;
}
```

2. Compile and analyze:

```bash
gcc -O2 sizes.c -c -o sizes.o
nm -S --size-sort sizes.o
```

## Questions for Reader

1. **Optimization Levels**: What differences do you observe between `-O0` and `-O2` for the `add` function? Why does the optimized version look so different?

2. **SSA Form**: In the SSA dump, look for φ (phi) functions. Where do they appear and what do they represent?

3. **Dead Code**: How much code was eliminated from `dead_code` at `-O2`? What happened to the unused variables?

4. **Loop Optimization**: Compare the loop in `loop_optimize` at different optimization levels. What transformations do you see?

5. **Vectorization**: What SIMD instructions did GCC generate for the array addition? How many elements are processed per iteration?

6. **Inlining Tradeoffs**: What are the advantages and disadvantages of function inlining? When might you want to prevent inlining?

## Further Exploration

- Explore GCC's `-fverbose-asm` flag for annotated assembly
- Use `-fopt-info` to see what optimizations the compiler applies
- Compare GCC and Clang optimization strategies
- Study the `-march=native` flag for CPU-specific optimizations
- Explore Link-Time Optimization (LTO) with `-flto`
