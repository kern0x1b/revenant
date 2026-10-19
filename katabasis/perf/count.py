import struct, subprocess, sys
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_ARM, UC_HOOK_BLOCK, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.arm_const import *
from capstone import Cs, CS_ARCH_ARM, CS_MODE_ARM, CS_MODE_THUMB

binary = sys.argv[1]
guest = sys.argv[2]
data = open(binary, 'rb').read()
magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags = struct.unpack_from('<7I', data, 0)
assert magic == 0xfeedface
segments, symtab = [], None
offset = 28
for _ in range(ncmds):
    cmd, size = struct.unpack_from('<2I', data, offset)
    if cmd == 1:
        name = data[offset + 8:offset + 24].rstrip(b'\0').decode()
        vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<4I', data, offset + 24)
        segments.append((name, vmaddr, vmsize, fileoff, filesize))
    elif cmd == 2:
        symtab = struct.unpack_from('<4I', data, offset + 8)
    offset += size
symbols = {}
symoff, nsyms, stroff, strsize = symtab
for i in range(nsyms):
    strx, ntype, nsect, ndesc, value = struct.unpack_from('<IBBHI', data, symoff + i * 12)
    name = data[stroff + strx:data.index(b'\0', stroff + strx)].decode()
    if ntype & 0x0e == 0x0e:
        symbols[name] = value | (1 if ndesc & 0x8 else 0)

guest_symbols = {}
for line in subprocess.run(['nm', '-gU', guest], capture_output=True, text=True).stdout.splitlines():
    value, kind, name = line.split()
    guest_symbols[name] = int(value, 16) + 0x10000000

PAGE = 0x1000
def page_align(v): return (v + PAGE - 1) & ~(PAGE - 1)

def machine():
    uc = Uc(UC_ARCH_ARM, UC_MODE_ARM)
    uc.ctl_set_cpu_model(UC_CPU_ARM_CORTEX_A9)
    uc.reg_write(UC_ARM_REG_C1_C0_2, uc.reg_read(UC_ARM_REG_C1_C0_2) | (0xf << 20))
    uc.reg_write(UC_ARM_REG_FPEXC, 0x40000000)
    for name, vmaddr, vmsize, fileoff, filesize in segments:
        if vmsize == 0 or name == '__PAGEZERO':
            continue
        uc.mem_map(vmaddr & ~(PAGE - 1), page_align(vmaddr + vmsize) - (vmaddr & ~(PAGE - 1)))
        if filesize and name != '__LINKEDIT':
            uc.mem_write(vmaddr, data[fileoff:fileoff + filesize])
    uc.mem_map(0x40000000, 0x08000000)
    uc.mem_map(0x50000000, 0x00200000)
    uc.mem_map(0x51000000, 0x00800000)
    uc.mem_map(0x60000000, 0x00001000)
    uc.mem_write(0x60000000, b'\xfe\xff\xff\xea')
    return uc

cs_arm, cs_thumb = Cs(CS_ARCH_ARM, CS_MODE_ARM), Cs(CS_ARCH_ARM, CS_MODE_THUMB)
block_cache = {}

def run(uc, pc, args, stack_args=()):
    counters = {'insn': 0, 'read': 0, 'write': 0}
    def on_block(uc, address, size, _):
        thumb = uc.reg_read(UC_ARM_REG_CPSR) & 0x20
        key = (address, size, thumb)
        n = block_cache.get(key)
        if n is None:
            code = bytes(uc.mem_read(address, size))
            n = sum(1 for _ in (cs_thumb if thumb else cs_arm).disasm_lite(code, address))
            block_cache[key] = n
        counters['insn'] += n
    def on_read(uc, access, address, size, value, _):
        counters['read'] += 1
    def on_write(uc, access, address, size, value, _):
        counters['write'] += 1
    hooks = [uc.hook_add(UC_HOOK_BLOCK, on_block), uc.hook_add(UC_HOOK_MEM_READ, on_read), uc.hook_add(UC_HOOK_MEM_WRITE, on_write)]
    sp = 0x50200000 - 0x100
    for i, value in enumerate(stack_args):
        uc.mem_write(sp + 4 * i, struct.pack('<I', value))
    regs = [UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3]
    for reg, value in zip(regs, args):
        uc.reg_write(reg, value)
    uc.reg_write(UC_ARM_REG_SP, sp)
    uc.reg_write(UC_ARM_REG_LR, 0x60000000)
    start = pc & ~1
    if pc & 1:
        start |= 1
    uc.emu_start(start, 0x60000000, count=400000000)
    for h in hooks:
        uc.hook_del(h)
    result = uc.reg_read(UC_ARM_REG_R0) | uc.reg_read(UC_ARM_REG_R1) << 32
    return result, counters

kernels = [('crc32', 1 << 16), ('sha256', 1 << 16), ('fnv64', 1 << 16), ('sort', 20000), ('list', 20000), ('geometry', 20000), ('matrix', 60), ('text', 1 << 16)]
print('%-9s %12s %12s %12s %7s %7s %10s %10s %6s' % ('kernel', 'native insn', 'wide insn', 'xlate insn', 'wide/n', 'xl/n', 'n mem', 'x mem', 'same'))
for index, (name, size) in enumerate(kernels):
    uc = machine()
    native_value, native = run(uc, symbols['_native_run'], [index, 0x40000000, size])
    uc = machine()
    wide_value, wide = run(uc, symbols['_native_wide_run'], [index, 0x40000000, size])
    uc = machine()
    xlate_value, xlate = run(uc, symbols['_xlate_run'], [guest_symbols['_k_' + name], 0x40000000, size, 0x51000000], [0x51800000])
    print('%-9s %12d %12d %12d %7.2f %7.2f %10d %10d %6s' % (name, native['insn'], wide['insn'], xlate['insn'], wide['insn'] / native['insn'], xlate['insn'] / native['insn'],
          native['read'] + native['write'], xlate['read'] + xlate['write'], native_value == xlate_value == wide_value))
