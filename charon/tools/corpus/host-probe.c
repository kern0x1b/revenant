#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *const kDefaultFrameworks[] = {
    "/System/Library/PrivateFrameworks/HomeKit.framework/Versions/A/HomeKit",
    "/System/Library/Frameworks/HomeKit.framework/HomeKit",
    "/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices",
    NULL
};

typedef struct {
    uintptr_t dataStart, dataEnd;
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

static const char *value_of(void *symbol, size_t *outLength)
{
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
