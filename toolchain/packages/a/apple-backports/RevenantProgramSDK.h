#ifndef CHARON_PROGRAM_SDK_H
#define CHARON_PROGRAM_SDK_H

#import <crt_externs.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>

static inline uint32_t charon_program_sdk_on_platform(uint32_t platform)
{
    const struct mach_header *header = (const struct mach_header *)_NSGetMachExecuteHeader();
    if (!header)
        return 0;
    const char *command = (const char *)header +
                          (header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    for (uint32_t index = 0; index < header->ncmds; index++) {
        const struct load_command *load = (const struct load_command *)command;
        if (load->cmd == LC_VERSION_MIN_IPHONEOS)
            return ((const struct version_min_command *)load)->sdk;
        if (load->cmd == LC_BUILD_VERSION) {
            const struct build_version_command *build = (const struct build_version_command *)load;
            if (platform == 0 || build->platform == platform)
                return build->sdk;
        }
        command += load->cmdsize;
    }
    return 0;
}

static inline uint32_t charon_program_sdk(void)
{
    return charon_program_sdk_on_platform(PLATFORM_IOS);
}

static inline BOOL charon_program_linked_on_or_after(double version, uint32_t platform)
{
    uint32_t sdk = charon_program_sdk_on_platform(platform);
    if (sdk == 0)
        return NO;
    return sdk >= (uint32_t)version * 0x00010000;
}

#endif
