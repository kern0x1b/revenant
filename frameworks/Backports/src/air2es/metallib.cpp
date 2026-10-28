#include "metallib.h"

#include <cstring>

namespace air2es {

namespace {

const uint8_t kMetallibMagic[4] = {'M', 'T', 'L', 'B'};
const uint8_t kWrapperMagic[4] = {0xde, 0xc0, 0x17, 0x0b};
const uint8_t kBitcodeMagic[4] = {'B', 'C', 0xc0, 0xde};

const uint64_t kHeaderMetadataOffset = 0x18;
const uint64_t kHeaderBitcodeOffset = 0x48;
const uint64_t kMetadataPrologue = 8;

struct Function {
    std::string name;
    Stage stage = Stage::Vertex;
    uint64_t regionSize = 0;
    bool named = false;
    bool staged = false;
    bool sized = false;
};

bool readLittleEndian(const std::vector<uint8_t> &bytes, uint64_t at, unsigned width, uint64_t &value)
{
    if (at > bytes.size() || width > bytes.size() - at)
        return false;
    value = 0;
    for (unsigned i = 0; i < width; i++)
        value |= (uint64_t)bytes[at + i] << (8 * i);
    return true;
}

bool bytesAt(const std::vector<uint8_t> &bytes, uint64_t at, const uint8_t *expected, size_t count)
{
    return at <= bytes.size() && count <= bytes.size() - at && memcmp(&bytes[at], expected, count) == 0;
}

bool readFunctions(const std::vector<uint8_t> &file, std::vector<Function> &functions, std::string &error)
{
    uint64_t metadataAt = 0, count = 0;
    if (!readLittleEndian(file, kHeaderMetadataOffset, 8, metadataAt) ||
        !readLittleEndian(file, metadataAt, 4, count)) {
        error = "the header does not reach the public metadata";
        return false;
    }
    uint64_t at = metadataAt + kMetadataPrologue;
    Function current;
    while (functions.size() < count) {
        if (file.size() < at || file.size() - at < 4) {
            error = "the public metadata ends before its function records";
            return false;
        }
        std::string tag(file.begin() + at, file.begin() + at + 4);
        at += 4;
        if (tag == "ENDT") {
            uint64_t ignored = 0;
            if (!readLittleEndian(file, at, 4, ignored)) {
                error = "the public metadata ends inside an ENDT record";
                return false;
            }
            at += 4;
            if (!current.named || !current.staged || !current.sized) {
                error = "a function record lacks its name, type or region size";
                return false;
            }
            functions.push_back(current);
            current = Function();
            continue;
        }
        uint64_t length = 0;
        if (!readLittleEndian(file, at, 2, length) || length > file.size() - (at + 2)) {
            error = "a public metadata record " + tag + " runs past the end of the file";
            return false;
        }
        const uint64_t dataAt = at + 2;
        at = dataAt + length;
        if (tag == "NAME") {
            current.name.assign((const char *)file.data() + dataAt, length);
            while (!current.name.empty() && current.name.back() == '\0')
                current.name.pop_back();
            current.named = true;
        } else if (tag == "TYPE" && length == 1 && file[dataAt] <= (uint32_t)Stage::Kernel) {
            current.stage = (Stage)file[dataAt];
            current.staged = true;
        } else if (tag == "MDSZ" && length == 8) {
            readLittleEndian(file, dataAt, 8, current.regionSize);
            current.sized = true;
        }
    }
    return true;
}

}

bool splitMetallib(const std::vector<uint8_t> &file, std::vector<Entry> &entries, std::string &error)
{
    entries.clear();
    if (!bytesAt(file, 0, kMetallibMagic, 4)) {
        error = "not a metallib: no MTLB magic";
        return false;
    }
    uint64_t bitcodeAt = 0;
    if (!readLittleEndian(file, kHeaderBitcodeOffset, 8, bitcodeAt)) {
        error = "the header does not reach the bitcode section";
        return false;
    }
    std::vector<Function> functions;
    if (!readFunctions(file, functions, error))
        return false;
    uint64_t regionAt = bitcodeAt;
    for (const Function &function : functions) {
        uint64_t wrapperOffset = 0, wrapperSize = 0;
        if (!bytesAt(file, regionAt, kWrapperMagic, 4) ||
            !readLittleEndian(file, regionAt + 8, 4, wrapperOffset) ||
            !readLittleEndian(file, regionAt + 12, 4, wrapperSize)) {
            error = function.name + ": its module region has no bitcode wrapper";
            return false;
        }
        if (function.regionSize > file.size() - regionAt) {
            error = function.name + ": its module region runs past the end of the file";
            return false;
        }
        if (wrapperOffset + wrapperSize > function.regionSize) {
            error = function.name + ": its bitcode does not fit in its module region";
            return false;
        }
        uint64_t at = regionAt + wrapperOffset;
        if (!bytesAt(file, at, kBitcodeMagic, 4)) {
            error = function.name + ": its bitcode does not begin with BC C0 DE";
            return false;
        }
        Entry entry;
        entry.name = function.name;
        entry.stage = function.stage;
        entry.offset = at;
        entry.size = wrapperSize;
        entry.bitcode.assign(file.begin() + at, file.begin() + at + wrapperSize);
        entries.push_back(entry);
        regionAt += function.regionSize;
    }
    if (regionAt != file.size()) {
        error = "the module regions end at " + std::to_string(regionAt) + ", not at the end of the file";
        return false;
    }
    return true;
}

}
