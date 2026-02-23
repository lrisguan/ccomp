# Experiment: Cross-compile a simple program

## Objective
- Build an AArch64 binary on an x86_64 host and inspect the output format.

## Setup requirements
- Cross toolchain (for example, `aarch64-linux-gnu-gcc`).
- `file` utility available.

## Step-by-step commands
1. Write a simple program:
   ```c
   int main(void) { return 0; }
   ```
2. Cross-compile:
   ```bash
   aarch64-linux-gnu-gcc -o hello_arm64 hello.c
   ```
3. Inspect the binary type:
   ```bash
   file hello_arm64
   ```

## Expected output explanation
- The binary is marked as AArch64 and cannot run on x86_64 without emulation.

## Questions for reader
1. What ABI does the toolchain target by default?
2. Which sysroot is used and why does it matter?
3. What changes if you build a PIE binary?
