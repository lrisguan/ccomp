# ch09-abi-and-cross-platform

## Purpose
- Explain ABI contracts and cross-platform compilation differences.

## Outline
1. What is an ABI
2. Calling conventions in x86_64 vs AArch64
3. Binary compatibility constraints
4. ELF vs PE
5. Linux vs Windows toolchains
6. Cross-compilation toolchains

## Content plan
- ABI as a stable binary interface.
- Register and stack argument passing differences.
- Structure layout, alignment, and endianness effects.
- ELF and PE loader expectations.
- Cross toolchain selection and sysroot use.

## Key terms
- ABI
- calling convention
- sysroot
- cross-compilation

## Experiment
See abi-and-cross-platform-exp/abi-and-cross-platform-exp.md in this chapter.
