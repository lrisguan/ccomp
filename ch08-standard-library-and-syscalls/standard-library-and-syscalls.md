# ch08-standard-library-and-syscalls

## Purpose
- Distinguish C standard library responsibilities from kernel system calls.

## Outline
1. C standard library vs system calls
2. glibc role and layering
3. User mode vs kernel mode
4. syscall instruction path
5. strace at a conceptual level

## Content plan
- Library wrappers and ABI compliance.
- syscall numbers, calling conventions, and return values.
- Error reporting via errno.
- Why libc adds buffering and higher-level APIs.
- Observing syscalls without oversimplifying the boundary.

## Key terms
- libc
- syscall
- user mode
- kernel mode

## Experiment
See standard-library-and-syscalls-exp/standard-library-and-syscalls-exp.md in this chapter.
