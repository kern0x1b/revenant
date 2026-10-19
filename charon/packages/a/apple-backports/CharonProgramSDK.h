#ifndef CHARON_PROGRAM_SDK_H
#define CHARON_PROGRAM_SDK_H

// The two public headers the read below needs: the mach-o load commands and the two symbols that name the
// main image (the modern one is in dyld.h, the older _NSGetMachExecuteHeader in crt_externs.h). The importing
// source does not have to have carried them - the caller in UIKit did, this header does it for everyone.
#import <crt_externs.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>

// The SDK the PROGRAM was linked against, read out of the main executable's own load command.
//
// A few of the properties this package carries are documented with a condition on the app: the header
// gives true as the default where the app is linked against iOS 26 or later (AVCaptureSession.h:685,
// AVCaptureOutputBase.h:129) - and the condition is a property of the APPLICATION, not of this port: a band
// links against the SDK its package line names (16.4 for every band this repository builds), which is written
// into the binary as the load command's sdk field. So it is READ, never assumed, and this is the one place in
// the package that reads it.
//
// It was a file-static in UIKit/UIViewController+AutomaticPresentation.m, which is not reusable: a static in one
// object cannot be called from another, and sharing it across libraries would mean an exported symbol, which
// this package's registry does not allow (a library exports only the names an SDK header declares). Hence a
// header of static inline functions, the arrangement CharonValueStore.h and CharonSayOnce.h already use and
// for the same reason: two libraries that include this each get their own copy and neither needs a symbol from
// the other. UIViewController+AutomaticPresentation.m includes it and no longer keeps a copy of its own.
//
// The walk below is the ONE walk. There were two - this one and an iOS-only copy of it beside it, with a
// comment claiming they were the same answer - and the coordinator's finding of 2026-10-03 was that a comment
// saying so is not a thing: the two were compared command for command and are now one function and a call.
//
// It returns the sdk field as the packed version the load command stores (0x00100400 for 16.4, and
// 0x010d0000 for 13.0), or 0 where the main image records none - which is the value the UIKit caller's own rule
// was written against. <platform> is PLATFORM_IOS for the question an iOS program asks - which
// charon_program_sdk() below is exactly this call with that argument - or 0 for "whatever platform this image was
// linked for", which is what a host-side check of the same rule needs: the field is the SDK the program was
// BUILT against and the question is the same one whichever platform it was built for, so a check that ran only
// where the platform is iOS could not answer it off-device at all.
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

/// The read narrowed to iOS, which is what the UIKit caller's rule asks and what this header's name says.
static inline uint32_t charon_program_sdk(void)
{
    return charon_program_sdk_on_platform(PLATFORM_IOS);
}

/// The question the headers ask, in the form they ask it: is the program linked against SDK <version> or later?
/// <version> is given the way the headers write it, "26.0", and compared as the two integers it is. NO where
/// the main image records no SDK at all, which is the case charon_program_sdk() was written against.
static inline BOOL charon_program_linked_on_or_after(double version, uint32_t platform)
{
    uint32_t sdk = charon_program_sdk_on_platform(platform);
    if (sdk == 0)
        return NO;
    return sdk >= (uint32_t)version * 0x00010000;
}

#endif
