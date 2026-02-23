# ch03-compilation-internals

## Purpose
- Detail how source code becomes optimized machine-oriented assembly.

## Outline
1. Lexical analysis
2. Parsing and grammar
3. AST construction
4. Intermediate representation (IR)
5. Optimization passes
6. Code generation
7. Optimization flags (-O0, -O1, -O2, -O3)

## Content plan
- Tokenization and error reporting.
- Parser output and syntax trees.
- AST vs IR roles and transformations.
- Optimization pipeline: local, global, SSA-based.
- Code generation: instruction selection, register allocation.
- Mapping high-level constructs to assembly idioms.
- Flag effects on debugability and performance.

## Key terms
- AST
- IR
- SSA
- register allocation

## Experiment
See compilation-internals-exp/compilation-internals-exp.md in this chapter.
