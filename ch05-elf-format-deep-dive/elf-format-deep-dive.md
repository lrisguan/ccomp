# Chapter 5: ELF Format Deep Dive

## Introduction

The **Executable and Linkable Format (ELF)** is the standard binary format on Unix-like systems. Whether you're dealing with object files, executables, shared libraries, or core dumps, they all use ELF. Understanding ELF gives you the power to analyze binaries, debug linking problems, and understand how programs are loaded.

In this chapter, we'll dissect ELF files byte by byte, exploring every header, table, and section in detail.

## 5.1 ELF Overview

### 5.1.1 What is ELF?

ELF is a flexible binary format that supports:
- **Executables**: Programs ready to run
- **Object files**: Intermediate compilation outputs
- **Shared libraries**: Dynamically loaded code (`.so` files)
- **Core dumps**: Memory snapshots for debugging

### 5.1.2 Two Views of ELF

ELF files can be viewed from two perspectives:

**Linking View** (used by linkers):
- Sections: `.text`, `.data`, `.bss`, `.symtab`, etc.
- Section header table describes all sections

**Execution View** (used by the loader):
- Segments: Groups of sections loaded into memory
- Program header table describes all segments

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ELF File Structure                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│                     ┌─────────────────┐                             │
│                     │   ELF Header    │                             │
│                     └────────┬────────┘                             │
│                              │                                      │
│           ┌──────────────────┼──────────────────┐                   │
│           │                  │                  │                   │
│           ▼                  ▼                  ▼                   │
│    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│    │  Program    │    │   Section   │    │   Section   │            │
│    │  Header     │    │   Header    │    │   Header    │            │
│    │  Table      │    │   Table     │    │   Table     │            │
│    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘            │
│           │                  │                  │                   │
│           │    Linking View  │  Execution View  │                   │
│           │                  │                  │                   │
│           ▼                  ▼                  ▼                   │
│    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│    │  Segments   │    │  Sections   │    │  Sections   │            │
│    │  (for OS)   │    │  (for link) │    │  (for debug)│            │
│    └─────────────┘    └─────────────┘    └─────────────┘            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 5.2 The ELF Header

### 5.2.1 ELF Header Structure

The ELF header sits at the very beginning of the file and contains essential identification information:

```c
// From /usr/include/elf.h
#define EI_NIDENT 16

typedef struct {
    unsigned char e_ident[EI_NIDENT];  // Identification bytes
    uint16_t e_type;                    // Object file type
    uint16_t e_machine;                 // Architecture
    uint32_t e_version;                 // Object file version
    uint64_t e_entry;                   // Entry point address
    uint64_t e_phoff;                   // Program header table offset
    uint64_t e_shoff;                   // Section header table offset
    uint32_t e_flags;                   // Processor-specific flags
    uint16_t e_ehsize;                  // ELF header size
    uint16_t e_phentsize;               // Program header table entry size
    uint16_t e_phnum;                   // Program header table entry count
    uint16_t e_shentsize;               // Section header table entry size
    uint16_t e_shnum;                   // Section header table entry count
    uint16_t e_shstrndx;                // Section name string table index
} Elf64_Ehdr;
```

### 5.2.2 The e_ident Array (Magic Bytes)

The first 16 bytes identify the file:

| Offset | Size | Name        | Description |
|--------|------|-------------|-------------|
| 0      | 4    | EI_MAG      | Magic number: 0x7f 'E' 'L' 'F' |
| 4      | 1    | EI_CLASS    | 32-bit (1) or 64-bit (2) |
| 5      | 1    | EI_DATA     | Endianness: little (1) or big (2) |
| 6      | 1    | EI_VERSION  | ELF version (always 1) |
| 7      | 1    | EI_OSABI    | OS/ABI identification |
| 8      | 1    | EI_ABIVERSION | ABI version |
| 9-15   | 7    | EI_PAD      | Padding (unused) |

**Magic Number**: The first four bytes are always `0x7f ELF` (or `7f 45 4c 46` in hex). This is how tools recognize ELF files.

**Class (32-bit vs 64-bit)**:
```
ELFCLASS32 = 1  // 32-bit architecture
ELFCLASS64 = 2  // 64-bit architecture
```

**Endianness**:
```
ELFDATA2LSB = 1  // Little endian (x86, x86-64)
ELFDATA2MSB = 2  // Big endian (some ARM, PowerPC)
```

**OS/ABI Values**:
```
ELFOSABI_NONE = 0       // No extensions (System V)
ELFOSABI_LINUX = 3      // Linux
ELFOSABI_FREEBSD = 9    // FreeBSD
```

### 5.2.3 e_type: File Type

| Value | Name           | Description |
|-------|----------------|-------------|
| 0     | ET_NONE        | No file type |
| 1     | ET_REL         | Relocatable (object file) |
| 2     | ET_EXEC        | Executable |
| 3     | ET_DYN         | Shared object (library or PIE executable) |
| 4     | ET_CORE        | Core dump |

### 5.2.4 e_machine: Architecture

| Value | Name           | Architecture |
|-------|----------------|--------------|
| 3     | EM_386         | x86 (32-bit) |
| 62    | EM_X86_64      | x86-64 |
| 40    | EM_ARM         | ARM |
| 183   | EM_AARCH64     | ARM64 |
| 20    | EM_PPC         | PowerPC |
| 21    | EM_PPC64       | PowerPC64 |
| 243   | EM_RISCV       | RISC-V |

### 5.2.5 e_entry: Entry Point

The virtual address where execution begins. For shared libraries, this is typically 0. For executables, this points to `_start` (the C runtime startup code, not `main`).

### 5.2.6 Viewing the ELF Header

```bash
# View the ELF header
readelf -h program

# Or just the identification
file program
```

Example output:
```
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              DYN (Shared object file)
  Machine:                           Advanced Micro Devices X86-64
  Version:                           0x1
  Entry point address:               0x1060
  Start of program headers:          64 (bytes into file)
  Start of section headers:          14040 (bytes into file)
  Flags:                             0x0
  Size of this header:               64 (bytes)
  Size of program headers:           56 (bytes)
  Number of program headers:         13
  Size of section headers:           64 (bytes)
  Number of section headers:         31
  Section header string table index: 30
```

## 5.3 Section Headers

### 5.3.1 Section Header Structure

Sections contain the actual code and data. The section header table is an array of section headers:

```c
typedef struct {
    uint32_t sh_name;       // Section name (index into string table)
    uint32_t sh_type;       // Section type
    uint64_t sh_flags;      // Section flags
    uint64_t sh_addr;       // Virtual address in memory
    uint64_t sh_offset;     // Offset in file
    uint64_t sh_size;       // Size in bytes
    uint32_t sh_link;       // Link to another section
    uint32_t sh_info;       // Additional info
    uint64_t sh_addralign;  // Alignment
    uint64_t sh_entsize;    // Entry size (if section holds table)
} Elf64_Shdr;
```

### 5.3.2 Common Section Types (sh_type)

| Value          | Name          | Description |
|----------------|---------------|-------------|
| SHT_NULL       | 0             | Inactive header |
| SHT_PROGBITS   | 1             | Program-defined contents (code, data) |
| SHT_SYMTAB     | 2             | Symbol table |
| SHT_STRTAB     | 3             | String table |
| SHT_RELA       | 4             | Relocation entries with addends |
| SHT_HASH       | 5             | Symbol hash table |
| SHT_DYNAMIC    | 6             | Dynamic linking info |
| SHT_NOTE       | 7             | Note section |
| SHT_NOBITS     | 8             | No space in file (BSS) |
| SHT_REL        | 9             | Relocation entries without addends |
| SHT_DYNSYM     | 11            | Dynamic symbol table |

### 5.3.3 Section Flags (sh_flags)

| Flag           | Value   | Description |
|----------------|---------|-------------|
| SHF_WRITE      | 0x1     | Writable |
| SHF_ALLOC      | 0x2     | Occupies memory during execution |
| SHF_EXECINSTR  | 0x4     | Executable code |
| SHF_MERGE      | 0x10    | Can be merged |
| SHF_STRINGS    | 0x20    | Contains null-terminated strings |
| SHF_TLS        | 0x400   | Thread-local storage |

### 5.3.4 Standard Sections

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Common ELF Sections                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Section      Flags        Content                                  │
│  ───────      ─────        ───────                                  │
│  .text        AX           Executable code                          │
│  .rodata      A            Read-only data (const, strings)          │
│  .data        WA           Initialized writable data                │
│  .bss         WA           Uninitialized data (zero-filled)         │
│  .symtab      -            Symbol table                             │
│  .strtab      -            String table for symbol names            │
│  .shstrtab    -            Section name string table                │
│  .rela.text   -            Relocations for .text                    │
│  .rela.data   -            Relocations for .data                    │
│  .dynamic     WA           Dynamic linking information              │
│  .dynsym      A            Dynamic symbol table                     │
│  .dynstr      A            Dynamic string table                     │
│  .got         WA           Global Offset Table                      │
│  .plt         AX           Procedure Linkage Table                  │
│  .eh_frame    A            Exception handling info                  │
│  .debug_*     -            DWARF debug information                  │
│                                                                     │
│  A = SHF_ALLOC, W = SHF_WRITE, X = SHF_EXECINSTR                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.3.5 Viewing Sections

```bash
# List all sections
readelf -S program

# Or with objdump
objdump -h program

# View section contents (hex dump)
objdump -s -j .rodata program

# View specific section
readelf -x .rodata program
```

Example output:
```
Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .interp           PROGBITS         0000000000000238  00000238
       000000000000001c  0000000000000000   A       0     0     1
  [ 2] .note.ABI-tag     NOTE             0000000000000254  00000254
       0000000000000020  0000000000000000   A       0     0     4
  [13] .text             PROGBITS         0000000000001000  00001000
       00000000000001b5  0000000000000000  AX       0     0     16
  [14] .rodata           PROGBITS         0000000000002000  00002000
       0000000000000012  0000000000000000   A       0     0     4
  [23] .data             PROGBITS         0000000000004000  00003000
       0000000000000010  0000000000000000  WA       0     0     8
  [24] .bss              NOBITS           0000000000004010  00003010
       0000000000000008  0000000000000000  WA       0     0     1
```

## 5.4 Program Headers

### 5.4.1 Program Header Structure

Program headers describe **segments**—contiguous chunks of the file that the loader maps into memory:

```c
typedef struct {
    uint32_t p_type;      // Segment type
    uint32_t p_flags;     // Segment flags
    uint64_t p_offset;    // Offset in file
    uint64_t p_vaddr;     // Virtual address in memory
    uint64_t p_paddr;     // Physical address (unused)
    uint64_t p_filesz;    // Size in file
    uint64_t p_memsz;     // Size in memory
    uint64_t p_align;     // Alignment
} Elf64_Phdr;
```

### 5.4.2 Segment Types (p_type)

| Value          | Name          | Description |
|----------------|---------------|-------------|
| PT_NULL        | 0             | Inactive |
| PT_LOAD        | 1             | Loadable segment |
| PT_DYNAMIC     | 2             | Dynamic linking info |
| PT_INTERP      | 3             | Interpreter path |
| PT_NOTE        | 4             | Auxiliary info |
| PT_PHDR        | 6             | Program header table itself |
| PT_GNU_STACK   | 0x6474e551    | Stack executability |
| PT_GNU_RELRO   | 0x6474e552    | Read-only after relocation |

### 5.4.3 Segment Flags (p_flags)

| Flag     | Value  | Description |
|----------|--------|-------------|
| PF_X     | 0x1    | Executable |
| PF_W     | 0x2    | Writable |
| PF_R     | 0x4    | Readable |

### 5.4.4 Key Segments

**PT_LOAD**: The most important segment type. The loader maps these into memory:
- `.text` usually forms one LOAD segment (RX - read+execute)
- `.data` and `.bss` form another (RW - read+write)

**PT_INTERP**: Contains the path to the dynamic linker:
```
/lib64/ld-linux-x86-64.so.2
```

**PT_DYNAMIC**: Points to the `.dynamic` section for dynamic linking.

**PT_GNU_STACK**: Controls whether the stack is executable (security feature).

**PT_GNU_RELRO**: Marks regions to become read-only after relocation (security feature).

### 5.4.5 Memory vs File Size

For `.bss` section (uninitialized data), `p_memsz > p_filesz`. The extra memory is zero-filled by the loader:

```
┌─────────────────────────────────────────────────────────────────────┐
│              PT_LOAD Segment: File vs Memory                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  File:                        Memory:                               │
│  ┌─────────────┐              ┌─────────────┐                       │
│  │   .text     │              │   .text     │  ← p_offset           │
│  │  (code)     │              │  (code)     │                       │
│  ├─────────────┤              ├─────────────┤                       │
│  │   .rodata   │              │   .rodata   │                       │
│  │  (strings)  │              │  (strings)  │                       │
│  ├─────────────┤              ├─────────────┤                       │
│  │   .data     │              │   .data     │                       │
│  │  (init var) │              │  (init var) │                       │
│  └─────────────┘              ├─────────────┤                       │
│                               │   .bss      │  ← Zero-filled        │
│  p_filesz = size in file      │  (uninit)   │     (p_memsz extra)   │
│  p_memsz = size in memory     └─────────────┘                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.4.6 Viewing Program Headers

```bash
# View program headers
readelf -l program
```

Example output:
```
Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000400040 0x0000000000400040
                 0x00000000000002d8 0x00000000000002d8  R      0x8
  INTERP         0x0000000000000318 0x0000000000400318 0x0000000000400318
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000400000 0x0000000000400000
                 0x0000000000000620 0x0000000000000620  R      0x1000
  LOAD           0x0000000000001000 0x0000000000401000 0x0000000000401000
                 0x00000000000001b5 0x00000000000001b5  R E    0x1000
  LOAD           0x0000000000002e10 0x0000000000403e10 0x0000000000403e10
                 0x0000000000000220 0x0000000000000228  RW     0x1000

 Section to Segment mapping:
  Segment Sections...
   00
   01     .interp
   02     .interp .note.ABI-tag .hash .gnu.hash .dynsym .dynstr ...
   03     .init .plt .text .fini
   04     .dynamic .got .got.plt .data .bss
```

## 5.5 Symbol Tables

### 5.5.1 Symbol Table Entry Structure

```c
typedef struct {
    uint32_t st_name;   // Symbol name (string table index)
    uint8_t  st_info;   // Type and binding
    uint8_t  st_other;  // Visibility
    uint16_t st_shndx;  // Section index
    uint64_t st_value;  // Symbol value (address)
    uint64_t st_size;   // Symbol size
} Elf64_Sym;
```

### 5.5.2 Symbol Type (st_info lower 4 bits)

| Value      | Name            | Description |
|------------|-----------------|-------------|
| STT_NOTYPE | 0               | Unspecified |
| STT_OBJECT | 1               | Data object (variable) |
| STT_FUNC   | 2               | Function |
| STT_SECTION| 3               | Section |
| STT_FILE   | 4               | Source file name |
| STT_COMMON | 5               | Common symbol |

### 5.5.3 Symbol Binding (st_info upper 4 bits)

| Value       | Name         | Description |
|-------------|--------------|-------------|
| STB_LOCAL   | 0            | Local to this file |
| STB_GLOBAL  | 1            | Visible to all files |
| STB_WEAK    | 2            | Like global, but lower precedence |

### 5.5.4 Symbol Visibility (st_other)

| Value            | Description |
|------------------|-------------|
| STV_DEFAULT      | Normal visibility |
| STV_INTERNAL     | Not visible outside |
| STV_HIDDEN       | Not visible outside this module |
| STV_PROTECTED    | Visible but not preemptible |

### 5.5.5 Section Index (st_shndx)

Special values:
- `SHN_UNDEF (0)`: Undefined symbol (external reference)
- `SHN_ABS (0xFFF1)`: Absolute symbol
- `SHN_COMMON (0xFFF2)`: Common symbol

### 5.5.6 Viewing Symbols

```bash
# View symbol table
readelf -s program
nm program

# View dynamic symbols only
readelf --dyn-syms program

# Sort by size (find large symbols)
nm -S --size-sort program
```

Example output:
```
Symbol table '.symtab' contains 67 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
     1: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crt1.o
    42: 0000000000001060    47 FUNC    GLOBAL DEFAULT   14 main
    43: 0000000000001090    23 FUNC    GLOBAL DEFAULT   14 add
    44: 0000000000004010     4 OBJECT  GLOBAL DEFAULT   24 global_var
    45: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND printf
```

## 5.6 Relocations

### 5.6.1 Relocation Entry Structure

```c
// Relocation without addend
typedef struct {
    uint64_t r_offset;   // Where to apply relocation
    uint64_t r_info;     // Symbol index and type
} Elf64_Rel;

// Relocation with addend
typedef struct {
    uint64_t r_offset;   // Where to apply relocation
    uint64_t r_info;     // Symbol index and type
    int64_t  r_addend;   // Constant addend
} Elf64_Rela;
```

### 5.6.2 Decoding r_info

```c
#define ELF64_R_SYM(i)  ((i) >> 32)          // Symbol index
#define ELF64_R_TYPE(i) ((i) & 0xffffffff)   // Relocation type
```

### 5.6.3 Common x86-64 Relocation Types

| Name               | Value | Description |
|--------------------|-------|-------------|
| R_X86_64_64        | 1     | 64-bit absolute |
| R_X86_64_PC32      | 2     | 32-bit PC-relative |
| R_X86_64_GOT32     | 3     | 32-bit GOT offset |
| R_X86_64_PLT32     | 4     | 32-bit PLT-relative |
| R_X86_64_32        | 10    | 32-bit absolute (truncated) |
| R_X86_64_32S       | 11    | 32-bit signed absolute |
| R_X86_64_GOTPCREL  | 9     | GOT + PC-relative |
| R_X86_64_REX_GOTPCRELX | 42 | Optimized GOT access |

### 5.6.4 Viewing Relocations

```bash
# View relocations
readelf -r object.o
objdump -r object.o
```

Example output:
```
Relocation section '.rela.text' at offset 0x230 contains 3 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
00000000000a  000500000004 R_X86_64_PLT32    0000000000000000 printf - 4
000000000014  000600000002 R_X86_64_PC32     0000000000000000 global_var - 4
00000000001e  000700000009 R_X86_64_GOTPCREL 0000000000000000 external - 4
```

## 5.7 Dynamic Linking Structures

### 5.7.1 The .dynamic Section

The `.dynamic` section contains an array of entries for the dynamic linker:

```c
typedef struct {
    int64_t  d_tag;   // Type
    union {
        uint64_t d_val;  // Integer value
        uint64_t d_ptr;  // Address value
    } d_un;
} Elf64_Dyn;
```

Common tags:

| Tag            | Description |
|----------------|-------------|
| DT_NEEDED      | Name of needed library |
| DT_STRTAB      | Address of string table |
| DT_SYMTAB      | Address of symbol table |
| DT_STRSZ       | Size of string table |
| DT_SONAME      | Shared object name |
| DT_RPATH       | Library search path (deprecated) |
| DT_RUNPATH     | Library search path |
| DT_INIT        | Address of init function |
| DT_FINI        | Address of fini function |
| DT_GNU_HASH    | GNU hash table address |

### 5.7.2 Global Offset Table (GOT)

The GOT contains addresses of external symbols, filled in by the dynamic linker:

```
.got.plt section:
┌──────────────────┐
│ GOT[0]: .dynamic │  ← Points to dynamic section
├──────────────────┤
│ GOT[1]: link_map │  ← Dynamic linker data
├──────────────────┤
│ GOT[2]: resolver │  ← Dynamic resolver function
├──────────────────┤
│ GOT[3]: printf   │  ← Initially points to PLT stub
├──────────────────┤         Updated to actual address
│ GOT[4]: scanf    │         on first call
├──────────────────┤
│ ...              │
└──────────────────┘
```

### 5.7.3 Procedure Linkage Table (PLT)

The PLT contains stubs for calling external functions:

```assembly
# PLT entry for printf
printf@plt:
    jmp *GOT[3](%rip)    # Jump through GOT entry
    push $3              # Push symbol index
    jmp resolver         # Jump to dynamic resolver

# First call: GOT[3] points here (PLT+6)
# Resolver finds printf, updates GOT[3], jumps to printf
# Subsequent calls: jmp *GOT[3] goes directly to printf
```

### 5.7.4 Viewing Dynamic Info

```bash
# View dynamic section
readelf -d program

# View needed libraries
ldd program

# View PLT/GOT
objdump -d -j .plt program
objdump -s -j .got.plt program
```

## 5.8 Practical ELF Analysis

### 5.8.1 Identifying File Types

```bash
file program
# Output: program: ELF 64-bit LSB shared object, x86-64, ...
```

### 5.8.2 Finding Entry Point

```bash
readelf -h program | grep Entry
# Output: Entry point address: 0x1060
```

### 5.8.3 Finding String Constants

```bash
strings program
strings -t x program   # With hex offset
```

### 5.8.4 Checking Security Features

```bash
# Check for stack executable (NX bit)
readelf -l program | grep GNU_STACK
# Output: GNU_STACK    0x0000000000000000 ... RW  (good: not executable)

# Check for RELRO
readelf -l program | grep GNU_RELRO
# Output: GNU_RELRO    0x0000000000003e10 ... R   (good: read-only after init)

# Check for PIE (position-independent)
file program | grep shared
readelf -h program | grep Type
# Output: Type: DYN (Shared object file) = PIE enabled
```

### 5.8.5 Analyzing Stripped Binaries

```bash
# Check if stripped
file program
# Output: ELF 64-bit LSB executable, stripped

# Strip symbols
strip program

# Still view sections
readelf -S program

# View dynamic symbols (still present after strip)
readelf --dyn-syms program
```

## 5.9 ELF Tools Summary

| Tool        | Purpose |
|-------------|---------|
| `readelf`   | Comprehensive ELF analysis |
| `objdump`   | Disassembly and section viewing |
| `nm`        | Symbol table viewing |
| `strings`   | Extract string constants |
| `strip`     | Remove symbols |
| `ldd`       | Show library dependencies |
| `file`      | Quick file type identification |
| `objcopy`   | Copy/transform object files |

## 5.10 Key Takeaways

1. **ELF has two views**: Linking view (sections) for linkers, execution view (segments) for loaders.

2. **The ELF header is the roadmap**: It points to the program header table and section header table.

3. **Sections contain code and data**: `.text` for code, `.data` for initialized data, `.bss` for uninitialized data.

4. **Program headers describe memory mapping**: PT_LOAD segments are loaded into memory by the loader.

5. **Symbols name locations**: The symbol table maps names to addresses and contains binding/type information.

6. **Relocations enable linking**: They tell the linker where to fill in final addresses.

7. **Dynamic structures enable runtime linking**: GOT, PLT, and .dynamic work together for shared library support.

8. **Tools are your friends**: `readelf`, `objdump`, and `nm` reveal everything about ELF files.

## 5.11 Looking Ahead

Now that we understand the ELF format, we can explore how the linker uses this information to combine object files into executables. In Chapter 6, we'll cover symbol resolution, relocation application, and the complete linking process.

## Further Reading

- "Linkers and Loaders" by John Levine
- "Learning Linux Binary Analysis" by Ryan O'Neill
- "Practical Binary Analysis" by Dennis Andriesse
- ELF Specification: https://refspecs.linuxfoundation.org/elf/elf.pdf
- man pages: readelf(1), objdump(1), elf(5)
