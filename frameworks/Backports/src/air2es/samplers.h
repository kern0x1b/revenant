#ifndef REVENANT_AIR2ES_SAMPLERS_H
#define REVENANT_AIR2ES_SAMPLERS_H

#include <cstdint>
#include <string>
#include <vector>

namespace air2es {

struct SamplerRow {
    uint64_t state;
    const char *s;
    const char *t;
    const char *r;
    const char *min;
    const char *mag;
    const char *mip;
    const char *coord;
    const char *compare;
    float lodMin;
    float lodMax;
    unsigned anisotropy;
};

struct GLESSampler {
    std::string wrapS;
    std::string wrapT;
    std::string minFilter;
    std::string magFilter;
};

const std::vector<SamplerRow> &samplerTable();

bool decodeSampler(uint64_t state, const std::vector<SamplerRow> &table, GLESSampler &out, std::string &refusal);

}

#endif
