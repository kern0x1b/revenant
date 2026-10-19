/* object-constant -- the value a built object gives a `NSString *const`.
 *
 * host-probe asks the *host* what a release holds for a name. This asks a *built object* what this port
 * gives that name, which is the other half of the question: a registry row and the host can agree
 * perfectly while the source in the tree defines something else, and a check that only ever compares
 * text with the host cannot see that at all. The two questions are asked of two different artefacts and
 * both answers have to be the same as the row's.
 *
 * **The artefact has to be a linked binary, not a relocatable object.** In a `.o` the pointer a
 * `NSString *const` holds is a relocation the linker fills in, so the value is not in the file at all
 * and every name reads as unresolved. The gate's `libHomeKitBackports.dylib` is the artefact that
 * carries the values, and that is what this is pointed at.
 *
 * The walk is a Mach-O one, read straight out of the file:
 *
 *   1. the symbol table gives the address of `_NAME` within the object;
 *   2. the load commands give every section, and the symbol's address must be in a data one;
 *   3. the four bytes at that address are a pointer to a `__CFConstantString` in the same object;
 *   4. that object's layout is isa, flags, char *characters, length -- and the width of each field is
 *      the object's own: four bytes in a 32-bit object, eight in a 64-bit one. Reading a 64-bit object's
 *      constant with 32-bit offsets yields a pointer into the middle of the flags, which is a string
 *      that is not the one the source writes.
 *
 * Everything is bounds-checked against the sections it came from, and the bytes are read at each
 * section's own file offset rather than at its address: a section's address is a VM address, which in
 * a relocatable object is not the number where its bytes sit in the file.
 *
 * Usage:
 *   object-constant <object-dir-or-file> <names-file> > values.tsv
 *
 * Names it cannot resolve are reported, not skipped, and a name in the list that resolves to nothing is
 * a difference for the caller's purposes rather than a quiet pass.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

/* A nlist is 12 bytes in a 32-bit object and 16 in a 64-bit one: uint32 strx, uint8 type,
 * uint8 sect, uint16 desc, uint32 value, and uint64 value in the wide form. Spelled out
 * rather than taken from <mach-o/nlist.h>, which is not the same header on every SDK and
 * a reader of a file should not depend on one that moves. */
#define CHARON_NLIST_32 12
#define CHARON_NLIST_64 16

typedef struct {
    uint64_t address;   /* the section's VM address, which is not where its bytes are in the file */
    uint64_t offset;    /* where its bytes are, which is what a reader wants */
    uint64_t size;
    int isCode;
    char name[32];
} Section;

/* The three fields this tool needs out of a mach_header, by offset. ncmds sits after the 64-bit
 * reserved word in the wide header and straight after magic in the thin one; the symbol table's counts
 * and its string table's offset sit in that order at the end of both. Spelled out because the struct
 * that carries them is spelled differently across SDKs -- this one has no symtab member at all -- and a
 * reader of a file should not depend on a header that moves. */
static uint32_t field32(const uint8_t *at, size_t offset)
{
    uint32_t value = 0;
    memcpy(&value, at + offset, sizeof value);
    return value;
}

static void header_fields(const uint8_t *header, int is64, uint32_t *ncmds, uint32_t *nsyms, uint32_t *stroff)
{
    if (is64) {
        *ncmds = field32(header, 16);
        *nsyms = field32(header, 64);
        *stroff = field32(header, 68);
    } else {
        /* A thin mach_header is magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags --
         * so filetype sits where the wide header's ncmds does, and reading ncmds at 12 reads the file
         * type. That is what the first version did, and it found one load command in an object that
         * has six, which is how every name came back unresolved. */
        *ncmds = field32(header, 16);
        *nsyms = field32(header, 56);
        *stroff = field32(header, 60);
    }
}

typedef struct {
    uint8_t *bytes;
    size_t length;
    int is64;
    uint32_t pointerSize;
    Section *sections;
    size_t sectionCount;
} Object;

/* Where the bytes of `length` bytes at a section-relative address `at` are in the file. */
static int file_offset_of(const Object *object, const Section *section, uint64_t at, uint64_t length, uint64_t *out)
{
    if (at < section->address || at + length > section->address + section->size)
        return 0;
    *out = section->offset + (at - section->address);
    return *out + length <= object->length;
}

static int read_file(const char *path, uint8_t **out, size_t *outLength)
{
    FILE *file = fopen(path, "rb");
    if (!file)
        return 0;
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    if (length <= 0) {
        fclose(file);
        return 0;
    }
    uint8_t *bytes = malloc((size_t)length);
    if (!bytes) {
        fclose(file);
        return 0;
    }
    size_t got = fread(bytes, 1, (size_t)length, file);
    fclose(file);
    if (got != (size_t)length) {
        free(bytes);
        return 0;
    }
    *out = bytes;
    *outLength = (size_t)length;
    return 1;
}

/* A fat binary: the first architecture this host can read is taken, and the offsets in its header are
 * relative to the slice rather than to the file. */
static const uint8_t *slice_of(const uint8_t *bytes, size_t length, size_t *sliceLength)
{
    uint32_t magic = 0;
    memcpy(&magic, bytes, sizeof magic);
    if (length < sizeof(struct fat_header) || (magic != FAT_MAGIC && magic != FAT_CIGAM))
        return NULL;
    const struct fat_header *fat = (const struct fat_header *)bytes;
    const struct fat_arch *arch = (const struct fat_arch *)(fat + 1);
    for (uint32_t index = 0; index < fat->nfat_arch; ++index) {
        if (arch[index].offset + arch[index].size > length)
            continue;
        *sliceLength = arch[index].size;
        return bytes + arch[index].offset;
    }
    return NULL;
}

static int open_object(const char *path, Object *object)
{
    memset(object, 0, sizeof *object);
    if (!read_file(path, &object->bytes, &object->length))
        return 0;
    const uint8_t *start = object->bytes;
    size_t length = object->length;
    const uint8_t *slice = slice_of(object->bytes, length, &length);
    if (slice) {
        start = slice;
        object->length = length;
    }
    if (length < sizeof(struct mach_header_64))
        return 0;
    uint32_t magic;
    memcpy(&magic, start, sizeof magic);
    if (magic == MH_MAGIC_64) {
        object->is64 = 1;
        object->pointerSize = 8;
    } else if (magic == MH_CIGAM_64) {
        object->is64 = 1;
        object->pointerSize = 8;
    } else if (magic == MH_MAGIC) {
        object->is64 = 0;
        object->pointerSize = 4;
    } else {
        return 0;
    }

    uint32_t ncmds = 0, nsyms = 0, stroff = 0;
    header_fields(start, object->is64, &ncmds, &nsyms, &stroff);
    const uint8_t *cursor = start + (object->is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));

    /* Count the sections first, so the table is sized once. */
    size_t count = 0;
    cursor = start + (object->is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    for (uint32_t index = 0; index < ncmds; ++index) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize == 0)
            break;
        if (command->cmd == LC_SEGMENT || command->cmd == LC_SEGMENT_64) {
            const struct segment_command *thin = (const struct segment_command *)command;
            count += thin->nsects;
        }
        cursor += command->cmdsize;
    }
    object->sections = calloc(count ? count : 1, sizeof(Section));
    object->sectionCount = 0;
    if (!object->sections)
        return 0;

    cursor = start + (object->is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    for (uint32_t index = 0; index < ncmds; ++index) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize == 0)
            break;
        if (command->cmd == LC_SEGMENT) {
            const struct segment_command *segment = (const struct segment_command *)command;
            const uint8_t *base = (const uint8_t *)(segment + 1);
            for (uint32_t part = 0; part < segment->nsects; ++part) {
                const struct section *held = (const struct section *)base + part;
                Section *slot = &object->sections[object->sectionCount++];
                slot->address = held->addr;
                slot->offset = held->offset;
                slot->size = held->size;
                slot->isCode = (held->flags & (S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS)) != 0;
                memcpy(slot->name, held->sectname, sizeof slot->name - 1);
            }
        } else if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            const uint8_t *base = (const uint8_t *)(segment + 1);
            for (uint32_t part = 0; part < segment->nsects; ++part) {
                const struct section_64 *held = (const struct section_64 *)base + part;
                Section *slot = &object->sections[object->sectionCount++];
                slot->address = held->addr;
                slot->offset = held->offset;
                slot->size = held->size;
                slot->isCode = (held->flags & (S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS)) != 0;
                memcpy(slot->name, held->sectname, sizeof slot->name - 1);
            }
        }
        cursor += command->cmdsize;
    }

    (void)nsyms;
    (void)stroff;
    return 1;
}

static const Section *section_holding(const Object *object, uint64_t address, int wantCode)
{
    for (size_t index = 0; index < object->sectionCount; ++index) {
        const Section *section = &object->sections[index];
        if (section->isCode == wantCode && address >= section->address && address < section->address + section->size)
            return section;
    }
    return NULL;
}

/* The value a `NSString *const` in this object carries, or NULL. */
static const char *value_in(const Object *object, uint64_t symbolAddress)
{
    const Section *holding = section_holding(object, symbolAddress, 0);
    if (!holding)
        return NULL;
    uint64_t at;
    if (!file_offset_of(object, holding, symbolAddress, object->pointerSize, &at))
        return NULL;
    uint64_t pointer = 0;
    memcpy(&pointer, object->bytes + at, object->pointerSize);
    if (!pointer)
        return NULL;
    const Section *constant = section_holding(object, pointer, 0);
    if (!constant)
        return NULL;
    /* isa, flags, characters, length -- with the object's own field width. */
    uint64_t charactersAt = 0, lengthAt = 0;
    if (!file_offset_of(object, constant, pointer + object->pointerSize * 2, object->pointerSize, &charactersAt) ||
        !file_offset_of(object, constant, pointer + object->pointerSize * 3, object->pointerSize, &lengthAt))
        return NULL;
    uint64_t characters = 0, length = 0;
    memcpy(&characters, object->bytes + charactersAt, object->pointerSize);
    memcpy(&length, object->bytes + lengthAt, object->pointerSize);
    if (!characters || !length || length > 4096)
        return NULL;
    const Section *text = section_holding(object, characters, 0);
    uint64_t textAt = 0;
    if (!text || !file_offset_of(object, text, characters, (uint64_t)length, &textAt))
        return NULL;
    char *value = calloc((size_t)length + 1, 1);
    if (!value)
        return NULL;
    memcpy(value, object->bytes + textAt, (size_t)length);
    return value;
}

/* The address of `_name` in this object, or 0. */
static uint64_t symbol_address(const Object *object, const char *name)
{
    char wanted[512];
    snprintf(wanted, sizeof wanted, "_%s", name);
    uint32_t magic;
    memcpy(&magic, object->bytes, sizeof magic);
    int is64 = object->is64;
    const uint8_t *base = object->bytes;
    uint32_t ncmds = 0, nsyms = 0, stroff = 0;
    header_fields(base, is64, &ncmds, &nsyms, &stroff);
    const uint8_t *cursor = base + (is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    for (uint32_t index = 0; index < ncmds; ++index) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize == 0)
            break;
        if (command->cmd == LC_SYMTAB) {
            const struct symtab_command *symtab = (const struct symtab_command *)command;
            const uint8_t *symbols = base + symtab->symoff;
            const char *strings = (const char *)(base + symtab->stroff);
            for (uint32_t part = 0; part < symtab->nsyms; ++part) {
                const uint8_t *entry = symbols + (size_t)part * (is64 ? CHARON_NLIST_64 : CHARON_NLIST_32);
                uint32_t strx;
                uint64_t value;
                /* A nlist is strx, type, sect, desc, value -- four one-byte-or-less fields between
                 * the name index and the value, so the value is at offset 8 in both the thin and the
                 * wide form and the difference is its width. Reading it at 4 in the thin form lands
                 * inside the type/sect/desc fields, which is why every name resolved to nothing. */
                memcpy(&strx, entry, 4);
                if (is64)
                    memcpy(&value, entry + 8, 8);
                else
                    memcpy(&value, entry + 8, 4);
                if (strcmp(strings + strx, wanted) == 0)
                    return value;
            }
        }
        cursor += command->cmdsize;
    }
    (void)nsyms;
    (void)stroff;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s <object-dir-or-file> <names-file>\n", argv[0]);
        return 2;
    }
    FILE *names = strcmp(argv[2], "-") == 0 ? stdin : fopen(argv[2], "r");
    if (!names) {
        fprintf(stderr, "%s: cannot read\n", argv[2]);
        return 1;
    }

    printf("api\tintroduced\tc-type\tvalue\thow-measured\tsource-binary\tos-build\n");
    char line[4096];
    int asked = 0, resolved = 0, notAString = 0;
    while (fgets(line, sizeof line, names)) {
        size_t length = strlen(line);
        while (length && (line[length - 1] == '\n' || line[length - 1] == '\r'))
            line[--length] = 0;
        if (!length || line[0] == '#')
            continue;
        ++asked;
        /* A directory is searched for the object that defines the name; a file is the one object. */
        char path[4096];
        Object object;
        int opened = 0;
        if (strstr(argv[1], ".o") || strstr(argv[1], ".dylib")) {
            snprintf(path, sizeof path, "%s", argv[1]);
            opened = open_object(path, &object);
        } else {
            /* The object whose name says which file it came from, plus every other object in the
             * directory, because a name can be defined by a file this tool has not been told about. */
            snprintf(path, sizeof path, "%s/%s.o", argv[1], line);
            opened = open_object(path, &object);
            if (!opened) {
                snprintf(path, sizeof path, "%s", argv[1]);
                opened = open_object(path, &object);
            }
        }
        if (!opened) {
            printf("%s\t-\t-\t-\tno object could be opened\t%s\t-\n", line, path);
            continue;
        }
        uint64_t address = symbol_address(&object, line);
        if (!address) {
            printf("%s\t-\t-\t-\texported by no object read here\t%s\t-\n", line, path);
            continue;
        }
        const char *value = value_in(&object, address);
        if (!value) {
            ++notAString;
            printf("%s\t-\t-\t-\tthe symbol is there and the value is not a constant string\t%s\t-\n", line, path);
        } else {
            ++resolved;
            printf("%s\t-\tNSString *const\t%s\t"
                   "read out of the built object with tools/corpus/object-constant.c: the symbol's own pointer, "
                   "then the __CFConstantString's characters and length at the object's own field width\t%s\t-\n",
                   line, value, path);
            free((void *)value);
        }
        free(object.sections);
        free(object.bytes);
    }
    if (names != stdin)
        fclose(names);
    fprintf(stderr, "asked %d, %d resolved, %d not a constant string\n", asked, resolved, notAString);
    return resolved == asked ? 0 : 1;
}
