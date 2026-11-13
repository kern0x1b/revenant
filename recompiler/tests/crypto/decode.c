#include <stdint.h>
#include <stdio.h>

#include "farmdec.h"

static const char *name_of(unsigned op) {
    switch (op) {
    case A64_AESE: return "aese";
    case A64_AESD: return "aesd";
    case A64_AESMC: return "aesmc";
    case A64_AESIMC: return "aesimc";
    case A64_SHA1C: return "sha1c";
    case A64_SHA1P: return "sha1p";
    case A64_SHA1M: return "sha1m";
    case A64_SHA1H: return "sha1h";
    case A64_SHA1SU0: return "sha1su0";
    case A64_SHA1SU1: return "sha1su1";
    case A64_SHA256H: return "sha256h";
    case A64_SHA256H2: return "sha256h2";
    case A64_SHA256SU0: return "sha256su0";
    case A64_SHA256SU1: return "sha256su1";
    case A64_PMULL: return "pmull";
    default: return "other";
    }
}

int main(void) {
    unsigned word;
    while (scanf("%x", &word) == 1) {
        uint32_t binst = word;
        Inst inst;
        fad_decode(&binst, 1, &inst);
        printf("%08x %s %u %u %u %u\n", word, name_of(inst.op), inst.rd, inst.rn, inst.rm, (unsigned)fad_get_vec_arrangement(inst.flags));
    }
    return 0;
}
