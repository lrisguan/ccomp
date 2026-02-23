# Experiment: Inspect process memory maps

## Objective
- Observe the runtime memory layout of a process.

## Setup requirements
- Linux or WSL.
- pmap or /proc available.

## Step-by-step commands
1. Build a simple program:
   ```bash
   gcc -o hello hello.c
   ```
2. Run the program in the background and capture its PID:
   ```bash
   ./hello & echo $!
   ```
3. Inspect memory maps:
   ```bash
   cat /proc/<PID>/maps
   ```

## Expected output explanation
- You will see mappings for text, data, heap, stack, and shared libraries.
- Permissions reveal which regions are executable or writable.

## Questions for reader
1. Which mappings correspond to the main executable?
2. Where is the heap located relative to the stack?
3. How does ASLR change the addresses between runs?
