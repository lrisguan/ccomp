# ch00-how-computers-execute-programs

## Purpose
- Establish the CPU and memory execution model that motivates later compilation details.

## Outline
1. CPU execution model and architectural state
2. Instruction cycle: fetch, decode, execute
3. Registers and register file roles
4. Memory model and addressing
5. Stack and function call mechanics
6. Calling conventions overview
7. Transition to ABI discussion

## Content plan
- CPU execution model: instructions update architectural state and memory.
- Instruction cycle: control flow, sequencing, and side effects.
- Registers: general purpose, PC, SP, flags, callee vs caller saved.
- Memory model: byte addressing, alignment, endianness.
- Stack mechanics: frame layout, prologue/epilogue, return address.
- Calling conventions: argument passing, return values, stack cleanup.
- ABI bridge: why a stable contract is required.

## Key terms
- instruction pointer
- stack frame
- calling convention
- ABI

## Diagrams planned
- CPU state and instruction cycle
- Stack frame layout

## Experiment
See how-computers-execute-programs-exp/how-computers-execute-programs-exp.md in this chapter.
