#import <CoreMedia/CoreMedia.h>
#include <dlfcn.h>
#import "check.h"

OSStatus CMVideoFormatDescriptionGetH264ParameterSetAtIndex(CMFormatDescriptionRef, size_t, const uint8_t **, size_t *, size_t *, int *);

static CMFormatDescriptionRef described(NSData *record, CMVideoCodecType codec)
{
    NSDictionary *extensions = record ? @{(__bridge id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: @{@"avcC": record}} : nil;
    CMFormatDescriptionRef desc = NULL;
    CMVideoFormatDescriptionCreate(NULL, codec, 16, 16, (__bridge CFDictionaryRef)extensions, &desc);
    return desc;
}

int main(void)
{
    @autoreleasepool {
        Dl_info info;
        CHECK(dladdr((const void *)CMVideoFormatDescriptionGetH264ParameterSetAtIndex, &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libAVFoundationBackports.dylib"),
              "the function comes from the backports library");

        const uint8_t good[] = {1, 100, 0, 31, 0xFF, 0xE1, 0, 2, 0x67, 0x64, 1, 0, 2, 0x68, 0xee};
        CMFormatDescriptionRef desc = described([NSData dataWithBytes:good length:sizeof good], kCMVideoCodecType_H264);
        CHECK(desc != NULL, "a description with an avcC atom is made");

        const uint8_t *pointer = NULL;
        size_t size = 0, count = 0;
        int header = 0;
        CHECK(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(desc, 0, &pointer, &size, &count, &header) == 0, "index 0 answers");
        CHECK(pointer == NULL || (size == 2 && pointer[0] == 0x67 && pointer[1] == 0x64), "the first set is the SPS");
        CHECK(count == 2 && header == 4, "the count is 2 and the header length 4");
        CHECK(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(desc, 1, &pointer, &size, NULL, NULL) == 0 && size == 2 && pointer[0] == 0x68 && pointer[1] == 0xee,
              "index 1 is the PPS");
        CHECK(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(desc, 2, &pointer, &size, &count, &header) == -12712, "index 2 is out of range");

        CHECK(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(NULL, 0, &pointer, &size, &count, &header) == -12710, "no description answers -12710");
        CMFormatDescriptionRef other = described(nil, kCMVideoCodecType_H264);
        CHECK(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(other, 0, &pointer, &size, &count, &header) == -12710, "no avcC atom answers -12710");

        const uint8_t bad[] = {2, 100, 0, 31, 0xFF, 0xE1};
        CMFormatDescriptionRef wrong = described([NSData dataWithBytes:bad length:sizeof bad], kCMVideoCodecType_H264);
        CHECK(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(wrong, 0, &pointer, &size, &count, &header) == -12712 && header == 0 && count == 0,
              "a record of another version answers -12712 with the outputs zeroed");

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
