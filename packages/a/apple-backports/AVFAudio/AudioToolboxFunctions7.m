#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>
#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <string.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

// AudioToolbox functions of iOS 7, which the release this port runs on does not export. Each is written from the
// host's answer for the same input (tests/backports/host/audiotoolbox-functions measures every case below against the
// host's own symbol, and facts/AVFAudio/AudioToolboxFunctions.md has the figures).

// AudioComponentGetLastActiveTime. The host answers 0 for a component nobody has used yet, and still answers 0
// after the component is instantiated and initialized, which is every case measured. This port keeps no record of
// use, so the answer is the one the host gives, for every component.
CFAbsoluteTime AudioComponentGetLastActiveTime(AudioComponent comp)
{
    return 0;
}

// AudioOutputUnitGetHostIcon. The icon is the host application's, the application that hosts the unit out of process.
// The host answers nil for a unit it has in this process (the generic output, instantiated), and this port hosts every
// unit in its own process, so there is no host application icon to return: nil, for every unit. The function's return type
// is UIImage, which only iOS has, so this definition is compiled for iOS only; the host test prints the host's answer for the
// record and does not compile this definition (facts/AVFAudio/AudioToolboxFunctions.md).
#if TARGET_OS_IPHONE
UIImage *AudioOutputUnitGetHostIcon(AudioUnit au, float desiredPointSize)
{
    return nil;
}

// AudioComponentGetIcon. The host answers nil for NULL, and for the generic output it answers an image of 32 by 32 points
// whatever size is asked (measured on the macOS host for 0, 16, 32, 64 and 128). The host's image is the component's own
// artwork, which this port does not carry, so the image returned is blank at the host's size. The iOS host's answer for a
// size is not measured. The function is deprecated from iOS 14 (AudioComponentCopyIcon replaces it).
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

// AudioOutputUnitPublish. The host answers noErr for every input measured: a NULL description, a NULL name, a NULL unit,
// version 0 and version 1, and a description it has not seen before. Within this process the host does not make the
// published description findable (AudioComponentFindNext answers NULL for it after the call). What the host does for other
// processes, which may find a published component, is not reproduced: this port hosts every unit in its own process, so
// there is no other process for a publication to reach.
OSStatus AudioOutputUnitPublish(const AudioComponentDescription *inDesc, CFStringRef inName, UInt32 inVersion,
                                AudioUnit inOutputUnit)
{
    return noErr;
}

// The sound banks. A DLS bank is a RIFF form 'DLS ' whose 'INFO' list holds the bank's name (its INAM chunk) and whose 'lins'
// list holds one 'ins ' list per instrument. An instrument's 'insh' chunk is three little-endian words (its region count, its
// bank word and its program), and its own 'INFO' list holds its name. The host reads the same chunks, and answers the same
// entries for gs_instruments.dls (all 235 match, measured). The host also reads a DLS bank whose name ends in .sf2 by its
// content, and this port does too. A SoundFont bank ('sfbk') is not read: no SF2 file was on the machine the host was
// measured on, so the port answers the status for an unreadable bank.

static uint32_t CharonLittleWord(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

// The next chunk in [*offset, end): its id, and the range of its data. The offset moves past the chunk and its pad byte. A
// chunk whose data runs past end is not returned, so a truncated bank yields the chunks that are whole.
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

// The text of the INAM chunk in an INFO list, up to its NUL; nil when the list has none.
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

// The entries of a 'lins' list: one dictionary per 'ins ' list, with the host's four keys. LSB is the second byte of the bank
// word, MSB is 120 for a drum bank (the word's top bit) and 121 otherwise (the host's value for every melodic bank measured),
// and program is the instrument's number. The name is the instrument's INAM, or empty when it has none (not measured).
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

// Reads a DLS bank from its bytes: its name into *name (when name is not NULL, nil if the bank has none), and its instruments
// into instruments (when that is not NULL). NO when the bytes are not a DLS bank.
static BOOL CharonParseBank(NSData *data, NSString **name, NSMutableArray *instruments)
{
    const uint8_t *bytes = data.bytes;
    size_t length = data.length;
    if (length < 12 || memcmp(bytes, "RIFF", 4) != 0 || memcmp(bytes + 8, "DLS ", 4) != 0) {
        return NO;
    }
    // The RIFF size counts the bytes after its own eight; a file shorter than that is read to its end.
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

// CopyNameFromSoundBank. The host answers the bank's name, the INAM of its INFO list, for a DLS bank, with the trailing spaces
// the file has (gs_instruments.dls: "QuickTime Music Synthesizer  ", status 0, measured). For a file that is missing, a
// directory, or not a bank, the host answers kAudioUnitErr_InvalidFile (-10871) and the URL's last path component, for the
// missing file and the directory (measured). The host traps on an empty and a text file and hangs on a truncated bank, so
// those answers are not measured; the port answers -10871 with the component for them too.
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

// The status of a missing file (fnfErr, -43; the iOS SDK's MacTypes.h does not declare the name).
#define CharonFileNotFoundStatus ((OSStatus)-43)

// CopyInstrumentInfoFromSoundBank. The host answers one dictionary per instrument of a DLS bank (its keys LSB, MSB, program and
// name), in the bank's order: 235 for gs_instruments.dls, every one equal to the port's (measured). A missing file is fnfErr
// (-43), and a directory or a file that is not a bank is kAudioUnitErr_InvalidFile (-10871), all measured.
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
