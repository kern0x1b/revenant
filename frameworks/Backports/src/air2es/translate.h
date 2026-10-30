#ifndef REVENANT_AIR2ES_TRANSLATE_H
#define REVENANT_AIR2ES_TRANSLATE_H

#include <string>
#include <vector>

#include "metallib.h"

namespace air2es {

struct Refusal {
    std::string name;
    std::string reason;
};

struct Translation {
    std::string name;
    Stage stage = Stage::Vertex;
    std::string source;
    std::string reflection;
};

bool translateEntry(const Entry &entry, Translation &out, Refusal &refusal);

bool dumpEntry(const Entry &entry, std::string &text, std::string &error);

struct SamplerUse {
    std::string entry;
    std::string function;
    uint64_t state = 0;
};

bool samplerStatesOf(const Entry &entry, std::vector<SamplerUse> &uses, std::string &error);

std::string jsonQuote(const std::string &text);

}

#endif
