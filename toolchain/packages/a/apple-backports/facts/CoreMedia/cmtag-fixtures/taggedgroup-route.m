#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMBlockBuffer.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

#import "CharonCMTaggedBufferGroup26.h"

int main(void)
{
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

    CMSampleBufferRef sbuf = NULL;
    CMSampleTimingInfo timing = { CMTimeMake(1,2), CMTimeMake(2,1), kCMTimeInvalid, kCMTimeInvalid, 1 };
    size_t sizes[1] = { 0 };
    CMBlockBufferRef backing = NULL;
    CMBlockBufferCreateEmpty(kCFAllocatorDefault, 0, kCMBlockBufferAssureMemoryNowFlag, &backing);
    OSStatus sb = CMSampleBufferCreate(kCFAllocatorDefault, backing, true, NULL, NULL, desc,
                                       1, 1, &timing, 1, sizes, &sbuf);
    printf("sample buffer status %d numSamples %ld isDataReady %d\n", (int)sb,
        sbuf ? (long)CMSampleBufferGetNumSamples(sbuf) : -1,
        sbuf ? (int)CMSampleBufferDataIsReady(sbuf) : -1);
    if (sbuf) {
        CMTaggedBufferGroupRef group = NULL;
        CMSetAttachment(sbuf, CFSTR("charon.group"), group, kCMAttachmentMode_ShouldNotPropagate);
        CMTaggedBufferGroupRef back = (CMTaggedBufferGroupRef)CMGetAttachment(sbuf, CFSTR("charon.group"), NULL);
        printf("attachment round trip %s\n", back == group ? "same" : "differs");
        printf("a buffer with no attachment: %s\n",
            CMGetAttachment(sbuf, CFSTR("charon.absent"), NULL) ? "non-null" : "NULL");
    }
    return 0;
}
