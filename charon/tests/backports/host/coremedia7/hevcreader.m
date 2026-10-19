#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

OSStatus CharonHostCMVideoFormatDescriptionGetHEVCParameterSetAtIndex(CMFormatDescriptionRef videoDesc, size_t parameterSetIndex,
                                                                       const uint8_t **parameterSetPointerOut, size_t *parameterSetSizeOut,
                                                                       size_t *parameterSetCountOut, int *NALUnitHeaderLengthOut);

static int failures, checks;
static uint8_t record[8192];
static size_t recordLength;

static CMFormatDescriptionRef described(const uint8_t *bytes, size_t length)
{
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
    const void *atomKeys[] = {CFSTR("hvcC")};
    const void *atomValues[] = {data};
    CFDictionaryRef atoms = CFDictionaryCreate(kCFAllocatorDefault, atomKeys, atomValues, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    const void *keys[] = {kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms};
    const void *values[] = {atoms};
    CFMutableDictionaryRef extensions = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(extensions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms, atoms);
    CMFormatDescriptionRef description = NULL;
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_HEVC, 64, 64, extensions, &description);
    CFRelease(extensions);
    CFRelease(atoms);
    CFRelease(data);
    return description;
}

static void compare(const char *label, CMFormatDescriptionRef description, size_t index, int mask)
{
    const uint8_t *mine = NULL, *theirs = NULL;
    size_t mySize = 99, myCount = 99, theirSize = 99, theirCount = 99;
    int myHeader = 99, theirHeader = 99;
    OSStatus a = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(description, index,
        (mask & 1) ? &mine : NULL, (mask & 2) ? &mySize : NULL, (mask & 4) ? &myCount : NULL, (mask & 8) ? &myHeader : NULL);
    OSStatus b = CharonHostCMVideoFormatDescriptionGetHEVCParameterSetAtIndex(description, index,
        (mask & 1) ? &theirs : NULL, (mask & 2) ? &theirSize : NULL, (mask & 4) ? &theirCount : NULL, (mask & 8) ? &theirHeader : NULL);
    checks++;
    if (a != b || mySize != theirSize || myCount != theirCount || myHeader != theirHeader || (mine == NULL) != (theirs == NULL)) {
        failures++;
        if (failures < 25)
            printf("DIFFERENT %s index %zu mask %d: %d/%zu/%zu/%d vs %d/%zu/%zu/%d\n", label, index, mask, a, mySize, myCount, myHeader, b, theirSize, theirCount, theirHeader);
        return;
    }
    if (a == 0 && (mask & 1) && mine && theirs && mySize && memcmp(mine, theirs, mySize) != 0) {
        failures++;
        if (failures < 25)
            printf("DIFFERENT %s index %zu: the bytes differ\n", label, index);
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        FILE *file = fopen(argc > 1 ? argv[1] : "hvcC.bin", "rb");
        recordLength = fread(record, 1, sizeof record, file);
        fclose(file);
        CMFormatDescriptionRef full = described(record, recordLength);
        for (size_t index = 0; index < 8; index++)
            for (int mask = 0; mask < 16; mask++)
                compare("x265 record", full, index, mask);
        if (full)
            CFRelease(full);
        for (size_t cut = 0; cut < recordLength; cut++) {
            CMFormatDescriptionRef description = described(record, cut);
            for (size_t index = 0; index < 3; index++)
                compare("truncated", description, index, 15);
            if (description)
                CFRelease(description);
        }
        for (int flip = 0; flip < 64; flip++) {
            uint8_t copy[8192];
            memcpy(copy, record, recordLength);
            copy[flip % recordLength] = (uint8_t)(copy[flip % recordLength] ^ 0xFF);
            CMFormatDescriptionRef description = described(copy, recordLength);
            compare("bit-flipped", description, 0, 15);
            compare("bit-flipped", description, 1, 15);
            if (description)
                CFRelease(description);
        }
        compare("no description", NULL, 0, 15);
        for (int flip = 0; flip < 2; flip++) {
            uint8_t copy[8192];
            memcpy(copy, record, recordLength);
            copy[flip ? 12 : 0] = (uint8_t)(copy[flip ? 12 : 0] ^ 0x55);
            CMFormatDescriptionRef description = described(copy, recordLength);
            compare("header-flipped", description, 0, 15);
            if (description)
                CFRelease(description);
        }
        {
            CMFormatDescriptionRef jpeg = NULL;
            CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_JPEG, 16, 16, NULL, &jpeg);
            compare("wrong codec", jpeg, 0, 15);
            if (jpeg)
                CFRelease(jpeg);
        }
        printf("%d checks, %d different\n", checks, failures);
    }
    return failures != 0;
}
