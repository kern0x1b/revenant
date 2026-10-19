// Both routes the coordinator named, compiled for armv7-apple-ios6.0 against the 16.4 SDK. The question
// this answers is not "does it compile" but "what do these two calls need from the port's own types".
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMBlockBuffer.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

// the port's own header, not a hand-typed copy of it: CM_BRIDGED_TYPE is Apple's (CMBase.h), and typing
// it by hand dropped the objc_bridge, which is what made an earlier version of this fail to compile.
#import "CharonCMTaggedBufferGroup26.h"

int main(void)
{
    // (1) the description: a real platform CMFormatDescription carrying the payload in extensions
    const void *keys[] = { CFSTR("charon.entries") };
    CFMutableArrayRef entries = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    const void *vals[] = { entries };
    CFDictionaryRef payload = CFDictionaryCreate(NULL, keys, vals, 1, &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
    CMFormatDescriptionRef desc = NULL;
    OSStatus made = CMFormatDescriptionCreate(kCFAllocatorDefault, kCMMediaType_Video, 'tbgr', payload, &desc);
    printf("description status %d type is a CMFormatDescription %d subtype %u\n", (int)made,
        (int)(desc && CFGetTypeID(desc) == CMFormatDescriptionGetTypeID()),
        desc ? (unsigned)CMFormatDescriptionGetMediaSubType(desc) : 0u);

    // (2) the sample buffer: a real one, with the group attached as an attachment
    CMSampleBufferRef sbuf = NULL;
    CMSampleTimingInfo timing = { CMTimeMake(1,2), CMTimeMake(2,1), kCMTimeInvalid, kCMTimeInvalid, 1 };
    size_t sizes[1] = { 0 };
    CMBlockBufferRef backing = NULL;
    // 16.4 spells this CMBlockBufferCreateEmpty; there is no CMBlockBufferCreate
    CMBlockBufferCreateEmpty(kCFAllocatorDefault, 0, kCMBlockBufferAssureMemoryNowFlag, &backing);
    OSStatus sb = CMSampleBufferCreate(kCFAllocatorDefault, backing, true, NULL, NULL, desc,
                                       1, 1, &timing, 1, sizes, &sbuf);
    printf("sample buffer status %d numSamples %ld isDataReady %d\n", (int)sb,
        sbuf ? (long)CMSampleBufferGetNumSamples(sbuf) : -1,
        sbuf ? (int)CMSampleBufferDataIsReady(sbuf) : -1);
    if (sbuf) {
        // the group as the port has it: a pointer to a struct that is really an ObjC object
        CMTaggedBufferGroupRef group = NULL;
        // no cast: the port's CMTaggedBufferGroupRef is CM_BRIDGED_TYPE(id), so CMSetAttachment takes it
        CMSetAttachment(sbuf, CFSTR("charon.group"), group, kCMAttachmentMode_ShouldNotPropagate);
        CMTaggedBufferGroupRef back = (CMTaggedBufferGroupRef)CMGetAttachment(sbuf, CFSTR("charon.group"), NULL);
        printf("attachment round trip %s\n", back == group ? "same" : "differs");
        printf("a buffer with no attachment: %s\n",
            CMGetAttachment(sbuf, CFSTR("charon.absent"), NULL) ? "non-null" : "NULL");
    }
    return 0;
}
