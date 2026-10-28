#include <sys/stat.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "metallib.h"
#include "translate.h"

using namespace air2es;

namespace {

bool readFile(const char *path, std::vector<uint8_t> &bytes)
{
    FILE *file = fopen(path, "rb");
    if (!file)
        return false;
    bytes.clear();
    uint8_t buffer[65536];
    size_t got;
    while ((got = fread(buffer, 1, sizeof buffer, file)) > 0)
        bytes.insert(bytes.end(), buffer, buffer + got);
    bool failed = ferror(file) != 0;
    return fclose(file) == 0 && !failed;
}

bool writeFile(const std::string &path, const std::string &text)
{
    FILE *file = fopen(path.c_str(), "wb");
    if (!file)
        return false;
    bool written = fwrite(text.data(), 1, text.size(), file) == text.size();
    return fclose(file) == 0 && written;
}

const char *stageName(Stage stage)
{
    switch (stage) {
    case Stage::Vertex: return "vertex";
    case Stage::Fragment: return "fragment";
    case Stage::Kernel: return "kernel";
    }
    return "unknown";
}

bool fileNameOk(const std::string &name)
{
    if (name.empty() || name == "." || name == "..")
        return false;
    for (char c : name)
        if (c == '/' || (unsigned char)c < 0x20)
            return false;
    return true;
}

int usage()
{
    fprintf(stderr, "usage: air2es METALLIB OUT.es2\n"
                    "       air2es --list METALLIB\n"
                    "       air2es --extract DIR METALLIB\n");
    return 2;
}

int list(const char *path)
{
    std::vector<uint8_t> file;
    std::vector<Entry> entries;
    std::string error;
    if (!readFile(path, file) || !splitMetallib(file, entries, error)) {
        fprintf(stderr, "%s: %s\n", path, error.c_str());
        return 1;
    }
    for (size_t index = 0; index < entries.size(); index++)
        printf("%zu %s %s offset=%llu size=%llu\n", index, entries[index].name.c_str(),
               stageName(entries[index].stage), (unsigned long long)entries[index].offset,
               (unsigned long long)entries[index].size);
    printf("%s: %zu module(s)\n", path, entries.size());
    return 0;
}

int extract(const char *directory, const char *path)
{
    std::vector<uint8_t> file;
    std::vector<Entry> entries;
    std::string error;
    if (!readFile(path, file) || !splitMetallib(file, entries, error)) {
        fprintf(stderr, "%s: %s\n", path, error.c_str());
        return 1;
    }
    for (const Entry &entry : entries) {
        if (!fileNameOk(entry.name)) {
            fprintf(stderr, "air2es: %s is not a file name\n", entry.name.c_str());
            return 1;
        }
        if (!writeFile(std::string(directory) + "/" + entry.name + ".bc",
                       std::string(entry.bitcode.begin(), entry.bitcode.end()))) {
            fprintf(stderr, "air2es: cannot write %s/%s.bc\n", directory, entry.name.c_str());
            return 1;
        }
    }
    printf("%zu module(s) written to %s\n", entries.size(), directory);
    return 0;
}

int translate(const char *path, const char *folder)
{
    std::vector<uint8_t> file;
    std::vector<Entry> entries;
    std::string error;
    if (!readFile(path, file) || !splitMetallib(file, entries, error)) {
        fprintf(stderr, "%s: %s\n", path, error.c_str());
        return 1;
    }
    if (mkdir(folder, 0755) != 0 && errno != EEXIST) {
        fprintf(stderr, "air2es: cannot create %s\n", folder);
        return 1;
    }
    std::vector<std::string> functions;
    std::vector<Refusal> refusals;
    for (const Entry &entry : entries) {
        Translation translation;
        Refusal refusal;
        if (!fileNameOk(entry.name))
            refusal.reason = "a name that is not a file name";
        else if (!translateEntry(entry, translation, refusal)) {
            refusals.push_back(Refusal{entry.name, refusal.reason});
            printf("%s: REFUSED %s: %s\n", path, entry.name.c_str(), refusal.reason.c_str());
            continue;
        }
        std::string stem = translation.name + "." + stageName(translation.stage);
        std::string source = stem + ".glsl";
        std::string reflection = stem + ".json";
        if (!writeFile(std::string(folder) + "/" + source, translation.source) ||
            !writeFile(std::string(folder) + "/" + reflection, translation.reflection)) {
            fprintf(stderr, "air2es: cannot write %s\n", stem.c_str());
            return 1;
        }
        functions.push_back("{\"name\": " + jsonQuote(translation.name) + ", \"stage\": " +
                            jsonQuote(stageName(translation.stage)) + ", \"source\": " + jsonQuote(source) +
                            ", \"reflection\": " + jsonQuote(reflection) + "}");
        printf("%s: OK %s %s\n", path, translation.name.c_str(), stageName(translation.stage));
    }
    std::string manifest = "{\"functions\": [";
    for (size_t i = 0; i < functions.size(); i++)
        manifest += (i ? ", " : "") + functions[i];
    manifest += "]}\n";
    if (!writeFile(std::string(folder) + "/library.json", manifest)) {
        fprintf(stderr, "air2es: cannot write %s/library.json\n", folder);
        return 1;
    }
    printf("%s: %zu function(s) written to %s, %zu refused\n", path, functions.size(), folder, refusals.size());
    return functions.empty() ? 1 : 0;
}

}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--list") == 0)
        return list(argv[2]);
    if (argc == 4 && strcmp(argv[1], "--extract") == 0)
        return extract(argv[2], argv[3]);
    if (argc == 3 && argv[1][0] != '-')
        return translate(argv[1], argv[2]);
    return usage();
}
