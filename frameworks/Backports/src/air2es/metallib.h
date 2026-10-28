#ifndef REVENANT_AIR2ES_METALLIB_H
#define REVENANT_AIR2ES_METALLIB_H

#include <cstdint>
#include <string>
#include <vector>

namespace air2es {

enum class Stage : uint32_t {
    Vertex = 0,
    Fragment = 1,
    Kernel = 2,
};

struct Entry {
    std::string name;
    Stage stage;
    uint64_t offset;
    uint64_t size;
    std::vector<uint8_t> bitcode;
};

bool splitMetallib(const std::vector<uint8_t> &file, std::vector<Entry> &entries, std::string &error);

}

#endif
