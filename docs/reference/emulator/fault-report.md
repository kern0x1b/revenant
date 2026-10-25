# The fatal-fault report: fields and symbols

What the emulator logs when a guest CPU takes a fatal exception or memory fault, and how each address in it is
named. The facts come from `emulator/src/runtime/emulator_session.cpp` (the fatal line and the fault words),
`emulator/src/kernel/kernel.cpp` (`fault_word_report`), `emulator/src/foundation/fault_dump.cpp` and
`emulator/src/foundation/cpu.cpp`. Paths are relative to the repository's `emulator/` folder.

## The fatal line

    [cpu] fatal pid=67 cpu=0 pc=0x392a2e3e lr=0xbb7d exception="ARM exception 8 at 0x392a2e3c" sp=0x2ffffc30 cpsr=0xa0000030 r0=0x1017cb20 ... r12=0xc028

* `pid`, `cpu`: the guest process and the processor slot that stopped.
* `pc`, `lr`: the raw values. They are not named on this line; see the `pc` and `lr` fault lines below.
* `fault=`, `access=`, `size=`: present only for a memory fault. `fault` is the address, `access` the numeric
  access kind, `size` the access size.
* `exception="..."`: present when the CPU raised an exception, with its kind and address.
* `sp`, `cpsr`, `r0` to `r12`: raw register values.

The fatal line and the `[fault-words]` lines are on the allowlist of the default quiet log, so they appear without
`--verbose`. The quiet log drops other bracketed lines; `--verbose` keeps every line.

## The fault words

For each register that holds a readable address, the report prints the eight words there:

    [fault-words] r0 0x1017cb20: 0x3ae41ec4 [libdispatch.dylib`__dispatch_source_vtable] 0x00000002 0x00000000 ... 0xffffffff

and, when the first of those words is itself a readable address, the four words there, as a `->` line:

    [fault-words] r0 -> 0x3ae41ec4 [libdispatch.dylib`__dispatch_source_vtable]: 0x3ae41ef0 [libdispatch.dylib`_OBJC_METACLASS_$_OS_dispatch_source] ...

* The registers are `r0` to `r12`, `sp`, `lr`, and `pc`, in that order. A register whose value is not readable has
  no lines.
* A word that cannot be read ends its line with `unmapped`.
* A value in brackets after a register, or after a word, is its label. A word with no label has none.

## How a label is named

1. The image comes from the guest's own dyld image table (`dyld_all_image_info`). The name is the last path component.
2. An address in a dyld shared cache image is named `image`symbol+0xNN`. The report finds it in three steps:
   * The cache slide is the guest load address of the first image that is in the cache, minus that image's unslid
     load address. Every image in one cache shares it.
   * The cache image is the one whose segments contain the unslid address. Its segments come from its Mach-O header.
   * The symbol is the nearest one at or below the address in the section that holds it. Stab entries and unnamed
     entries are skipped. When two symbols share an address, an exported one wins. An offset of zero prints the name
     alone, with no `+0x`.
3. An address that is in a guest image but has no symbol is named `image+0xNN`. That offset is from the image's load
   address and covers only its text. An address in no image has no label.

## Where the symbols come from

* The image's own symbol table (`LC_SYMTAB`) holds the exported names.
* The cache's local-symbol region holds the other names. The cache reader, `cache_local_symbols`, reads it with the
  image's unslid load address, and `MachOImage::add_local_symbols` merges the result into the image's symbols.
* No export-trie reader is used. The exports are in the symbol table.

## What a label does not say

* Symbols carry no size. A large offset means the section has no closer symbol. It does not prove that the address
  belongs to that symbol.
* A data word, such as a vtable, takes the nearest symbol in its own section, so the name is the section's, not the
  object's.
* The first fatal fault in a run reads the segments of every cache image once, so that report is slower.
