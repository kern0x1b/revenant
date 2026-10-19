import sys

from capstone import CS_ARCH_ARM64, CS_MODE_ARM, Cs

from cache_reader import Cache


def annotate(cache, registers, instruction):
    operands = instruction.op_str
    if instruction.mnemonic == "adrp":
        register, immediate = [part.strip() for part in operands.split(",")]
        registers[register] = int(immediate.lstrip("#"), 16)
        return ""
    if instruction.mnemonic == "add" and "#" in operands:
        parts = [part.strip() for part in operands.split(",")]
        if len(parts) == 3 and parts[1] in registers:
            try:
                target = registers[parts[1]] + int(parts[2].lstrip("#"), 16)
            except ValueError:
                return ""
            registers[parts[0]] = target
            text = cache.printable(target)
            return "; %r" % text if text else "; 0x%x" % target
    if instruction.mnemonic == "ldr" and "[" in operands:
        parts = operands.replace("[", "").replace("]", "").split(",")
        if len(parts) >= 3 and parts[1].strip() in registers and parts[2].strip().startswith("#"):
            try:
                target = registers[parts[1].strip()] + int(parts[2].strip().lstrip("#"), 16)
                pointed = cache.pointer(target)
            except (ValueError, KeyError):
                return ""
            text = cache.printable(pointed) if pointed else None
            return "; ptr at 0x%x -> %s" % (target, repr(text) if text else hex(pointed))
    return ""


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: cache-disasm.py <dyld_shared_cache> <address> [instructions]")
    cache = Cache(sys.argv[1])
    start = int(sys.argv[2], 16)
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 400
    decoder = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
    registers = {}
    for count, instruction in enumerate(decoder.disasm(cache.read(start, limit * 4), start), 1):
        print("0x%x:\t%s\t%s\t%s" % (instruction.address, instruction.mnemonic, instruction.op_str, annotate(cache, registers, instruction)))
        if instruction.mnemonic in ("ret", "retab", "retaa", "brk") or (instruction.mnemonic == "b" and count > 3):
            break


main()
