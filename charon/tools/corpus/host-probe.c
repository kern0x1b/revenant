/* host-probe -- the measurement a backported constant's value is checked with.
 *
 * A constant's value is a fact about the release that declares it, and the only way to be sure of one
 * is to ask that release. This asks the host: it opens a framework with dlopen, looks each name up with
 * dlsym, and -- because the symbol is a `NSString *const` whose own bytes are a pointer to the
 * constant string -- walks that object with CFStringGetCString and prints what the release holds.
 *
 * The walk is the part worth being careful about. Reading the pointer with a fixed slide is how a wrong
 * address reads as another string; CFStringGetCString goes through the string's own layout and its own
 * length, and the length it reports is what the value printed is sized to, so a wrong address shows up as
 * a failed conversion rather than as a plausible wrong answer. There is deliberately no CFGetTypeID test
 * first: the isa pointer inside a constant string in a dyld shared cache is stored with the cache's own
 * fixups, so that test answers "not a CFString" for every one of them while the conversion reads the
 * same object correctly.
 *
 * The release half of a constant's provenance is a different measurement and a different tool: this one
 * does not say which iOS release first exported a name, and tools/release-split.lua is what does.
 *
 * Usage:
 *   host-probe <framework-path> <names-file> > constant-values.tsv
 *
 * <names-file> holds one symbol name per line. The TSV it prints carries the columns the ledger's
 * constant-values tables use, so a table this produces and one another band produced are the same
 * shape and diff as one. Names the framework does not export are reported as such and do not stop the
 * run: a name a framework never had is a fact about the framework, and a table with a hole in it says
 * more than a run that stopped at the hole.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* The framework the port's own HomeKit and AuthenticationServices come from, when it has no path of
 * its own on disk. The port's HomeKit is a private framework on this machine and lives in the dyld
 * shared cache, which dlopen reaches by its install path. */
static const char *const kDefaultFrameworks[] = {
    "/System/Library/PrivateFrameworks/HomeKit.framework/Versions/A/HomeKit",
    "/System/Library/Frameworks/HomeKit.framework/HomeKit",
    "/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices",
    NULL
};

/* One image's sections that hold data, and the one that holds constant strings. A `NSString *const`'s
 * own bytes are a pointer; a function's own bytes are a code address, and reading a code address as a
 * pointer is what segfaulted: the length check never runs, because the crash is on the dereference.
 * So the shape of the symbol is established from the Mach-O before anything is read through it.
 *
 * `data` is every section not marked as instructions, and `cfstring` is the `__cfstring` section,
 * which is where a constant string literal lives. Both are ranges, and both are read out of the
 * header at the image's base -- the same header getsectiondata walks, done by hand so that the tool
 * needs no Objective-C and no CoreFoundation call before it decides there is nothing to read. */
typedef struct {
    uintptr_t dataStart, dataEnd;        /* every non-instruction section, contiguous ranges kept */
    uintptr_t data[64];
    size_t dataCount;
    uintptr_t cfStringStart, cfStringEnd;
} ImageLayout;

static void note(ImageLayout *layout, const char *name, uintptr_t start, uintptr_t size, int isCode)
{
    if (!isCode && layout->dataCount < sizeof layout->data / sizeof layout->data[0]) {
        layout->data[layout->dataCount++] = start;
        layout->data[layout->dataCount++] = size;
    }
    if (name && strcmp(name, "__cfstring") == 0) {
        layout->cfStringStart = start;
        layout->cfStringEnd = start + size;
    }
}

/* The layout of the image at `base`, or a zeroed one when the header is not the one expected.
 *
 * The section addresses in a Mach-O header are the addresses the image was *linked* at, and an image
 * that came out of the dyld shared cache is loaded somewhere else: `_dyld_get_image_header` hands
 * back the header at its runtime address while the sections inside it still name their link-time
 * ones. Comparing a runtime address against them answers "not in any section" for every one -- which
 * is how the first version of these two checks turned all 255 values into "not a CFString" while the
 * walk itself was fine. The slide is the difference between where __TEXT says it is and where it
 * actually is, and every section address gets it before it is used. */
static ImageLayout layout_of_image(const struct mach_header_64 *base)
{
    ImageLayout layout;
    memset(&layout, 0, sizeof layout);
    if (!base || base->magic != MH_MAGIC_64)
        return layout;
    intptr_t slide = 0;
    int haveSlide = 0;
    const uint8_t *cursor = (const uint8_t *)(base + 1);
    for (uint32_t index = 0; index < base->ncmds; ++index) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize == 0)
            break;
        if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            if (!haveSlide && strcmp(segment->segname, "__TEXT") == 0) {
                slide = (intptr_t)base - (intptr_t)segment->vmaddr;
                haveSlide = 1;
            }
            for (uint32_t section = 0; section < segment->nsects; ++section) {
                const struct section_64 *held = (const struct section_64 *)(segment + 1) + section;
                note(&layout, held->sectname, (uintptr_t)((intptr_t)held->addr + slide), held->size,
                     (held->flags & (S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS)) != 0);
            }
        }
        cursor += command->cmdsize;
    }
    return layout;
}

static int within_data(const ImageLayout *layout, const void *address)
{
    uintptr_t value = (uintptr_t)address;
    for (size_t index = 0; index + 1 < layout->dataCount; index += 2) {
        if (value >= layout->data[index] && value < layout->data[index] + layout->data[index + 1])
            return 1;
    }
    return 0;
}

static int within_cfstring(const ImageLayout *layout, const void *address)
{
    uintptr_t value = (uintptr_t)address;
    return value >= layout->cfStringStart && value < layout->cfStringEnd;
}

/* Whether the symbol's own bytes are a pointer into some loaded image's constant strings. A constant
 * string's address is in the framework that declares it, and every image is asked, because a
 * framework's literals can land in a different image once the dyld has fixed them up. */
static int points_at_a_constant_string(const void *pointer)
{
    uint32_t count = _dyld_image_count();
    for (uint32_t index = 0; index < count; ++index) {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(index);
        if (!header)
            continue;
        ImageLayout layout = layout_of_image(header);
        if (layout.cfStringEnd > layout.cfStringStart && within_cfstring(&layout, pointer))
            return 1;
    }
    return 0;
}

/* The value of a `NSString *const`. The cast goes through void * because a data symbol's bytes are a
 * pointer whatever the declaration says, and the length is read from the object rather than assumed. */
static const char *value_of(void *symbol, size_t *outLength)
{
    /* Two questions before anything is read through the symbol: is the symbol's own address in a
     * non-instruction section, and does the pointer stored there land in some image's __cfstring? A
     * name the framework exports that is not a string -- CFStringGetCString, objc_msgSend -- answers
     * no to the first, and answers no to the second without being dereferenced, which is the whole
     * point: the counter that says "not a CFString" has to be reachable. */
    Dl_info info;
    if (dladdr(symbol, &info) && info.dli_fbase) {
        ImageLayout own = layout_of_image((const struct mach_header_64 *)info.dli_fbase);
        if (!within_data(&own, symbol))
            return NULL;
    }
    void *pointer = *(void *const *)symbol;
    if (!pointer || !points_at_a_constant_string(pointer))
        return NULL;
    CFStringRef string = (CFStringRef)pointer;
    /* The size comes from the string's own length, and the conversion is one call. CFStringGetCString
     * is not a two-call form: asked with a null buffer it fails, which is how this tool first reported
     * all 255 values as "not a CFString" while the same walk in Objective-C read every one of them. */
    CFIndex length = CFStringGetLength(string);
    char *buffer = malloc((size_t)length + 1);
    if (!buffer)
        return NULL;
    if (!CFStringGetCString(string, buffer, (CFIndex)length + 1, kCFStringEncodingUTF8)) {
        free(buffer);
        return NULL;
    }
    if (outLength)
        *outLength = (size_t)length;
    return buffer;
}

int main(int argc, char **argv)
{
    const char *framework = NULL;
    const char *names = NULL;
    if (argc == 3) {
        framework = argv[1];
        names = argv[2];
    } else if (argc == 2) {
        names = argv[1];
    } else {
        fprintf(stderr, "usage: %s [framework-path] <names-file>\n", argv[0]);
        return 2;
    }

    void *handle = NULL;
    if (framework) {
        handle = dlopen(framework, RTLD_LAZY);
        if (!handle) {
            fprintf(stderr, "%s: %s\n", framework, dlerror());
            return 1;
        }
    } else {
        for (int index = 0; kDefaultFrameworks[index] && !handle; ++index) {
            handle = dlopen(kDefaultFrameworks[index], RTLD_LAZY);
            if (handle)
                framework = kDefaultFrameworks[index];
        }
        if (!handle) {
            fprintf(stderr, "none of the default frameworks opened: %s\n", dlerror());
            return 1;
        }
    }

    FILE *in = strcmp(names, "-") == 0 ? stdin : fopen(names, "r");
    if (!in) {
        fprintf(stderr, "%s: %s\n", names, strerror(errno));
        return 1;
    }

    printf("api\tintroduced\tc-type\tvalue\thow-measured\tsource-binary\tos-build\n");
    char line[4096];
    int asked = 0, missing = 0, notAString = 0;
    while (fgets(line, sizeof line, in)) {
        size_t length = strlen(line);
        while (length && (line[length - 1] == '\n' || line[length - 1] == '\r'))
            line[--length] = 0;
        if (!length || line[0] == '#')
            continue;
        ++asked;
        dlerror();
        void *symbol = dlsym(handle, line);
        if (!symbol) {
            ++missing;
            printf("%s\t-\t-\t-\t%s does not export it\t%s\thost\n", line, framework, framework);
            continue;
        }
        size_t valueLength = 0;
        const char *value = value_of(symbol, &valueLength);
        if (!value) {
            ++notAString;
            printf("%s\t-\t-\t-\texported, and the value is not a CFString\t%s\thost\n", line, framework);
            continue;
        }
        printf("%s\t-\tNSString *const\t%s\t"
               "dlopen + dlsym on the host, decoded through CFStringGetCString as UTF-8\t%s\thost\n",
               line, value, framework);
        free((void *)value);
    }
    if (in != stdin)
        fclose(in);
    fprintf(stderr, "asked %d, %d not exported, %d not a CFString\n", asked, missing, notAString);
    return missing || notAString ? 1 : 0;
}
