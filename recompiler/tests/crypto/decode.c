#include <stdint.h>
#include <stdio.h>

#include "farmdec.h"

static const char *name_of(const Inst *inst) {
    switch (inst->op) {
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
    case A64_SLI: return "sli";
    case A64_SRI: return "sri";
    case A64_ADDLV: return (inst->flags & SIMD_SIGNED) ? "saddlv" : "uaddlv";
    case A64_FCVT_S: return "fcvt_s";
    case A64_FCVT_D: return "fcvt_d";
    case A64_FCVT_H: return "fcvt_h";
    default: return "other";
    }
}

static unsigned shape_of(const Inst *inst) {
    switch (inst->op) {
    case A64_FCVT_S:
    case A64_FCVT_D:
    case A64_FCVT_H:
        return (unsigned)fad_get_prec(inst->flags);
    default:
        return (unsigned)fad_get_vec_arrangement(inst->flags) | ((inst->flags & SIMD_SCALAR) ? 16u : 0u);
    }
}

int main(void) {
    unsigned word;
    while (scanf("%x", &word) == 1) {
        uint32_t binst = word;
        Inst inst;
        fad_decode(&binst, 1, &inst);
        printf("%08x %s %u %u %u %u %llu\n", word, name_of(&inst), inst.rd, inst.rn, inst.rm, shape_of(&inst), (unsigned long long)inst.imm);
    }
    return 0;
}
