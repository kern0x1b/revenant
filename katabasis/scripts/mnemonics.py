import collections, sys
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM
cs = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
counts = collections.Counter()
total = 0
for path in sys.argv[1:]:
    for line in open(path):
        address, word = line.split()
        code = int(word, 16).to_bytes(4, 'little')
        insn = next(cs.disasm(code, int(address, 16)), None)
        counts[(insn.mnemonic + ' ' + insn.op_str.split(',')[0][:2]) if insn else '<data>'] += 1
        total += 1
for mnemonic, count in counts.most_common(40):
    print('%6d %s' % (count, mnemonic))
print('total', total)
