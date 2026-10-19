#import <AudioToolbox/AudioToolbox.h>
#import <stdlib.h>
#import <string.h>
#import "CharonAudioToolboxDeclarations.h"

OSStatus AudioFileGetUserDataSize64(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt64 *outUserDataSize)
{
    UInt32 size = 0;
    OSStatus status = AudioFileGetUserDataSize(inAudioFile, inUserDataID, inIndex, &size);
    if (status == noErr && outUserDataSize != NULL) {
        *outUserDataSize = size;
    }
    return status;
}

OSStatus AudioFileGetUserDataAtOffset(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, SInt64 inOffset,
                                      UInt32 *ioUserDataSize, void *outUserData)
{
    UInt32 size = 0;
    OSStatus status = AudioFileGetUserDataSize(inAudioFile, inUserDataID, inIndex, &size);
    if (status != noErr) {
        return status;
    }
    if (inOffset < 0) {
        return kAudioFilePositionError;
    }
    if (ioUserDataSize == NULL || *ioUserDataSize == 0) {
        return kAudioFileBadPropertySizeError;
    }
    if (inOffset >= (SInt64)size) {
        return kAudioFilePositionError;
    }
    UInt32 wanted = *ioUserDataSize;
    UInt32 available = size - (UInt32)inOffset;
    UInt32 count = wanted < available ? wanted : available;
    uint8_t *chunk = malloc(size > 0 ? size : 1);
    if (chunk == NULL) {
        return kAudioFileUnspecifiedError;
    }
    UInt32 readSize = size;
    status = AudioFileGetUserData(inAudioFile, inUserDataID, inIndex, &readSize, chunk);
    if (status == noErr) {
        memcpy(outUserData, chunk + inOffset, count);
        *ioUserDataSize = count;
    }
    free(chunk);
    return status;
}
