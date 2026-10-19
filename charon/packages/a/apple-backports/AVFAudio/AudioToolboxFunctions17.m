#import <AudioToolbox/AudioToolbox.h>
#import <stdlib.h>
#import <string.h>
#import "CharonAudioToolboxDeclarations.h"

// AudioToolbox functions of iOS 17, which the release this port runs on does not export. The release has the 32-bit size and
// the whole chunk (AudioFileGetUserDataSize, AudioFileGetUserData); these two are built on them, and the host's answers for the
// same inputs are measured by tests/backports/host/audiotoolbox-functions (facts/AVFAudio/AudioToolboxFunctions.md).

// AudioFileGetUserDataSize64: the release's size, as 64 bits. A chunk the release cannot size is the release's own status: the
// host's answer for a missing chunk and for an index past the last chunk is kAudioFileInvalidChunkError, and the release reports
// the same for those.
OSStatus AudioFileGetUserDataSize64(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt64 *outUserDataSize)
{
    UInt32 size = 0;
    OSStatus status = AudioFileGetUserDataSize(inAudioFile, inUserDataID, inIndex, &size);
    if (status == noErr && outUserDataSize != NULL) {
        *outUserDataSize = size;
    }
    return status;
}

// AudioFileGetUserDataAtOffset: up to *ioUserDataSize bytes of the chunk, from inOffset, and no more than the chunk has after it.
// The host's answers, measured on a 10-byte chunk, in the order the host checks them: an offset below 0 gives
// kAudioFilePositionError (-40); a size of 0 gives kAudioFileBadPropertySizeError ('!siz'); an offset at or past the end (10
// and 12) gives -40. Every failure leaves the size as it was. Otherwise the bytes from the offset are copied, up to the size asked
// and the bytes left (offsets 0, 2, 6 and 8, with sizes 4 and 32). A missing chunk gives the release's status.
// The release can only read the whole chunk, so the bytes are read in full and the part asked for is copied out.
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
