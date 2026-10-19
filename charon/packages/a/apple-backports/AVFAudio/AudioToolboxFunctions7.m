#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>
#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <string.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

CFAbsoluteTime AudioComponentGetLastActiveTime(AudioComponent comp)
{
    return 0;
}

#if TARGET_OS_IPHONE
UIImage *AudioOutputUnitGetHostIcon(AudioUnit au, float desiredPointSize)
{
    return nil;
}

static UIImage *CharonBlankComponentIcon(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(32, 32), NO, 1);
    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return icon;
}

UIImage *AudioComponentGetIcon(AudioComponent comp, float desiredPointSize)
{
    if (comp == NULL) {
        return nil;
    }
    return CharonBlankComponentIcon();
}
#endif

OSStatus AudioOutputUnitPublish(const AudioComponentDescription *inDesc, CFStringRef inName, UInt32 inVersion,
                                AudioUnit inOutputUnit)
{
    return noErr;
}

static uint32_t CharonLittleWord(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static BOOL CharonNextChunk(const uint8_t *bytes, size_t *offset, size_t end, char id[5], size_t *dataBegin, size_t *dataEnd)
{
    if (*offset > end || end - *offset < 8) {
        return NO;
    }
    memcpy(id, bytes + *offset, 4);
    id[4] = 0;
    size_t size = CharonLittleWord(bytes + *offset + 4);
    *dataBegin = *offset + 8;
    if (size > end - *dataBegin) {
        return NO;
    }
    *dataEnd = *dataBegin + size;
    *offset = *dataEnd + (size & 1);
    return YES;
}

static NSString *CharonNameInInfo(const uint8_t *bytes, size_t begin, size_t end)
{
    size_t offset = begin;
    char id[5];
    size_t dataBegin, dataEnd;
    while (CharonNextChunk(bytes, &offset, end, id, &dataBegin, &dataEnd)) {
        if (strcmp(id, "INAM") == 0) {
            size_t length = 0;
            while (dataBegin + length < dataEnd && bytes[dataBegin + length] != 0) {
                length++;
            }
            return [[NSString alloc] initWithBytes:bytes + dataBegin length:length encoding:NSISOLatin1StringEncoding];
        }
    }
    return nil;
}

static void CharonParseInstruments(const uint8_t *bytes, size_t begin, size_t end, NSMutableArray *instruments)
{
    size_t offset = begin;
    char id[5];
    size_t listBegin, listEnd;
    while (CharonNextChunk(bytes, &offset, end, id, &listBegin, &listEnd)) {
        if (strcmp(id, "LIST") != 0 || listEnd - listBegin < 4 || memcmp(bytes + listBegin, "ins ", 4) != 0) {
            continue;
        }
        uint32_t bank = 0;
        uint32_t program = 0;
        NSString *instrumentName = @"";
        size_t childOffset = listBegin + 4;
        size_t childBegin, childEnd;
        while (CharonNextChunk(bytes, &childOffset, listEnd, id, &childBegin, &childEnd)) {
            if (strcmp(id, "insh") == 0 && childEnd - childBegin >= 12) {
                bank = CharonLittleWord(bytes + childBegin + 4);
                program = CharonLittleWord(bytes + childBegin + 8);
            } else if (strcmp(id, "LIST") == 0 && childEnd - childBegin >= 4 && memcmp(bytes + childBegin, "INFO", 4) == 0) {
                NSString *found = CharonNameInInfo(bytes, childBegin + 4, childEnd);
                if (found != nil) {
                    instrumentName = found;
                }
            }
        }
        [instruments addObject:@{
            @"LSB": @((bank >> 8) & 0x7f),
            @"MSB": @((bank >> 31) ? 120 : 121),
            @"program": @(program),
            @"name": instrumentName,
        }];
    }
}

static BOOL CharonParseBank(NSData *data, NSString **name, NSMutableArray *instruments)
{
    const uint8_t *bytes = data.bytes;
    size_t length = data.length;
    if (length < 12 || memcmp(bytes, "RIFF", 4) != 0 || memcmp(bytes + 8, "DLS ", 4) != 0) {
        return NO;
    }
    size_t end = length;
    size_t riffEnd = CharonLittleWord(bytes + 4) + 8;
    if (riffEnd < length) {
        end = riffEnd;
    }
    size_t offset = 12;
    char id[5];
    size_t listBegin, listEnd;
    while (CharonNextChunk(bytes, &offset, end, id, &listBegin, &listEnd)) {
        if (strcmp(id, "LIST") != 0 || listEnd - listBegin < 4) {
            continue;
        }
        if (memcmp(bytes + listBegin, "INFO", 4) == 0 && name != NULL) {
            *name = CharonNameInInfo(bytes, listBegin + 4, listEnd);
        } else if (memcmp(bytes + listBegin, "lins", 4) == 0 && instruments != nil) {
            CharonParseInstruments(bytes, listBegin + 4, listEnd, instruments);
        }
    }
    return YES;
}

OSStatus CopyNameFromSoundBank(CFURLRef inURL, CFStringRef __nullable *outName)
{
    NSURL *url = (__bridge NSURL *)inURL;
    if (url == nil) {
        *outName = NULL;
        return kAudio_ParamError;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:NULL];
    NSString *name = nil;
    if (data != nil && CharonParseBank(data, &name, NULL) && name != nil) {
        *outName = (__bridge_retained CFStringRef)name;
        return noErr;
    }
    *outName = (__bridge_retained CFStringRef)[url lastPathComponent];
    return kAudioUnitErr_InvalidFile;
}

#define CharonFileNotFoundStatus ((OSStatus)-43)

OSStatus CopyInstrumentInfoFromSoundBank(CFURLRef inURL, CFArrayRef __nullable *outInstrumentInfo)
{
    NSURL *url = (__bridge NSURL *)inURL;
    if (url == nil) {
        *outInstrumentInfo = NULL;
        return kAudio_ParamError;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:NULL];
    if (data == nil) {
        *outInstrumentInfo = NULL;
        return [url checkResourceIsReachableAndReturnError:NULL] ? kAudioUnitErr_InvalidFile : CharonFileNotFoundStatus;
    }
    NSMutableArray *instruments = [NSMutableArray array];
    if (!CharonParseBank(data, NULL, instruments)) {
        *outInstrumentInfo = NULL;
        return kAudioUnitErr_InvalidFile;
    }
    *outInstrumentInfo = (__bridge_retained CFArrayRef)instruments;
    return noErr;
}
