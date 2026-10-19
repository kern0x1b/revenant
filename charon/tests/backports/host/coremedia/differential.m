#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

OSStatus CharonHostCMVideoFormatDescriptionGetH264ParameterSetAtIndex(CMFormatDescriptionRef, size_t, const uint8_t **, size_t *, size_t *, int *);

static int failures, checks;

static NSString *answer(BOOL host, CMFormatDescriptionRef desc, size_t index, int mask)
{
    const uint8_t *pointer = (const uint8_t *)0x1;
    size_t size = 99, count = 99;
    int length = 99;
    OSStatus (*function)(CMFormatDescriptionRef, size_t, const uint8_t **, size_t *, size_t *, int *) = host ? CharonHostCMVideoFormatDescriptionGetH264ParameterSetAtIndex : CMVideoFormatDescriptionGetH264ParameterSetAtIndex;
    OSStatus status = function(desc, index, (mask & 1) ? &pointer : NULL, (mask & 2) ? &size : NULL, (mask & 4) ? &count : NULL, (mask & 8) ? &length : NULL);
    NSData *content = pointer > (const uint8_t *)1 && (mask & 2) ? [NSData dataWithBytes:pointer length:size] : nil;
    return [NSString stringWithFormat:@"%d %d %zu %zu %d %@", (int)status, pointer == NULL, size, count, length, content];
}

static void compare(const char *name, CMFormatDescriptionRef desc)
{
    for (size_t index = 0; index < 6; index++)
        for (int mask = 0; mask < 16; mask++) {
            NSString *a = answer(NO, desc, index, mask), *b = answer(YES, desc, index, mask);
            checks++;
            if (![a isEqualToString:b]) {
                failures++;
                printf("DIFFERENT %s index %zu mask %d:\n  system %s\n  port   %s\n", name, index, mask, a.UTF8String, b.UTF8String);
            }
        }
}

static CMFormatDescriptionRef made(NSArray<NSData *> *sets, int header)
{
    const uint8_t *pointers[8];
    size_t sizes[8];
    for (NSUInteger i = 0; i < sets.count; i++) {
        pointers[i] = sets[i].bytes;
        sizes[i] = sets[i].length;
    }
    CMFormatDescriptionRef desc = NULL;
    CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, sets.count, pointers, sizes, header, &desc);
    return desc;
}

static CMFormatDescriptionRef withRecord(NSData *record, CMVideoCodecType codec)
{
    NSDictionary *extensions = record ? @{(__bridge id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: @{@"avcC": record}} : nil;
    CMFormatDescriptionRef desc = NULL;
    CMVideoFormatDescriptionCreate(NULL, codec, 16, 16, (__bridge CFDictionaryRef)extensions, &desc);
    return desc;
}

int main(void)
{
    @autoreleasepool {
        static const uint8_t sps1[] = {0x67, 0x64, 0x00, 0x1f, 0xac, 0xd9, 0x40, 0x50, 0x05, 0xbb, 0x01, 0x10, 0x00, 0x00, 0x03, 0x00, 0x10, 0x00, 0x00, 0x03, 0x03, 0xc0, 0xf1, 0x83, 0x19, 0x60};
        static const uint8_t pps1[] = {0x68, 0xeb, 0xec, 0xb2, 0x2c};
        NSData *sps = [NSData dataWithBytes:sps1 length:sizeof sps1], *pps = [NSData dataWithBytes:pps1 length:sizeof pps1];
        for (int header = 1; header <= 4; header++) {
            if (header == 3)
                continue;
            char name[64];
            snprintf(name, sizeof name, "one of each, header %d", header);
            compare(name, made(@[sps, pps], header));
            snprintf(name, sizeof name, "two of each, header %d", header);
            compare(name, made(@[sps, sps, pps, pps], header));
            snprintf(name, sizeof name, "three sets, header %d", header);
            compare(name, made(@[sps, pps, pps], header));
        }
        compare("no description", NULL);
        CMFormatDescriptionRef audio = NULL;
        AudioStreamBasicDescription asbd = {44100, kAudioFormatLinearPCM, 12, 4, 1, 4, 2, 16, 0};
        CMAudioFormatDescriptionCreate(NULL, &asbd, 0, NULL, 0, NULL, NULL, &audio);
        compare("audio", audio);
        compare("another codec", withRecord(nil, kCMVideoCodecType_JPEG));
        compare("H.264 with no atoms", withRecord(nil, kCMVideoCodecType_H264));
        const uint8_t good[] = {1, 100, 0, 31, 0xFF, 0xE1, 0, 2, 0x67, 0x64, 1, 0, 2, 0x68, 0xee};
        compare("hand made record", withRecord([NSData dataWithBytes:good length:sizeof good], kCMVideoCodecType_H264));
        for (size_t cut = 0; cut < sizeof good; cut++) {
            char name[64];
            snprintf(name, sizeof name, "record cut to %zu bytes", cut);
            compare(name, withRecord([NSData dataWithBytes:good length:cut], kCMVideoCodecType_H264));
        }
        uint8_t version[sizeof good];
        memcpy(version, good, sizeof good);
        version[0] = 2;
        compare("record of version 2", withRecord([NSData dataWithBytes:version length:sizeof version], kCMVideoCodecType_H264));
        const uint8_t noSets[] = {1, 100, 0, 31, 0xFF, 0xE0, 0};
        compare("record with no sets", withRecord([NSData dataWithBytes:noSets length:sizeof noSets], kCMVideoCodecType_H264));
        const uint8_t longer[] = {1, 100, 0, 31, 0xFF, 0xE1, 0, 2, 0x67, 0x64, 1, 0, 2, 0x68, 0xee, 9, 9, 9};
        compare("record with trailing bytes", withRecord([NSData dataWithBytes:longer length:sizeof longer], kCMVideoCodecType_H264));
        printf("%d checks, %d different\n", checks, failures);
    }
    return failures != 0;
}
