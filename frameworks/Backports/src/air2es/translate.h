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
    Stage stage;
    std::string source;
    std::string reflection;
};

bool translateEntry(const Entry &entry, Translation &out, Refusal &refusal);

}

#endif
