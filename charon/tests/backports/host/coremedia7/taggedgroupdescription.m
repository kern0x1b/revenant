#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#import <CoreMedia/CMTagCollection.h>
#import <CoreMedia/CMTaggedBufferGroup.h>
#import <CoreMedia/CMBlockBuffer.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <string.h>

// The five CMTaggedBufferGroup format-description and sample-buffer functions, against the host.
//
// The chain is the one facts/CoreMedia/cmtag-fixtures/taggedgroup-measure.m measured: a subset chain of
// three entries - {video}, {video,track}, {video,track,gone} - over three pixel buffers. It is built
// twice, once from the host's own collections and once from the port's, and every case is asked of both,
// because Matches reads a representation only its own side wrote: the port's reads the key the port
// writes, so a description made by one and matched by the other is not a case, it is a type error.
//
// Every expected answer below was taken from the host first, in taggedgroup-answers.txt, commit 2fbdb758c.
// Nothing here is an expectation invented at the port.

static void *port = NULL;
static long checks = 0, different = 0;

static void same(const char *what, NSString *hostAnswer, NSString *portAnswer)
{
    checks++;
    if (![hostAnswer isEqualToString:portAnswer]) {
        different++;
        printf("  DIFFERENT %-52s host %s  port %s\n", what,
               [hostAnswer UTF8String], [portAnswer UTF8String]);
    }
}

#define BIND(name) __typeof__(&name) port_##name = (__typeof__(&name))dlsym(port, #name); \
    if (!port_##name) { printf("missing %s in the port image\n", #name); return 1; }

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        port = dlopen(argc > 1 ? argv[1] : "libCharonCMTag.dylib", RTLD_LOCAL | RTLD_FIRST);
        if (!port) {
            printf("dlopen failed: %s\n", dlerror());
            return 1;
        }
        BIND(CMTagCollectionCreate)
        BIND(CMTaggedBufferGroupCreate)
        BIND(CMTaggedBufferGroupGetCount)
        BIND(CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup)
        BIND(CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions)
        BIND(CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup)
        BIND(CMSampleBufferCreateForTaggedBufferGroup)
        BIND(CMSampleBufferGetTaggedBufferGroup)

        CMTag video = kCMTagMediaTypeVideo;
        CMTag track = CMTagMakeWithSInt64Value(kCMTagCategory_TrackID, 7);
        CMTag gone = CMTagMakeWithSInt64Value(kCMTagCategory_MediaSubType, 0x676F6E65);
        CMTag e0[1] = { video }, e1[2] = { video, track }, e2[3] = { video, track, gone };
        CMTag f0[1] = { gone }, f1[2] = { gone, track }, f2[3] = { gone, track, video };

        // The three pixel buffers, made once and shared, so "the same tags over different buffers" and
        // "the same buffers over the same tags" are two different groups and not one alias of the other.
        CVPixelBufferRef made[6];
        for (CFIndex i = 0; i < 6; i++)
            CVPixelBufferCreate(kCFAllocatorDefault, 8, 8, kCVPixelFormatType_32BGRA, NULL, &made[i]);

        // the host's family
        CMTagCollectionRef hc[3], hsame[3], hshaped[3];
        CMTagCollectionCreate(kCFAllocatorDefault, e0, 1, &hc[0]);
        CMTagCollectionCreate(kCFAllocatorDefault, e1, 2, &hc[1]);
        CMTagCollectionCreate(kCFAllocatorDefault, e2, 3, &hc[2]);
        CMTagCollectionCreate(kCFAllocatorDefault, e0, 1, &hsame[0]);
        CMTagCollectionCreate(kCFAllocatorDefault, e1, 2, &hsame[1]);
        CMTagCollectionCreate(kCFAllocatorDefault, e2, 3, &hsame[2]);
        CMTagCollectionCreate(kCFAllocatorDefault, f0, 1, &hshaped[0]);
        CMTagCollectionCreate(kCFAllocatorDefault, f1, 2, &hshaped[1]);
        CMTagCollectionCreate(kCFAllocatorDefault, f2, 3, &hshaped[2]);
        // the port's family
        CMTagCollectionRef pc[3], psame[3], pshaped[3];
        port_CMTagCollectionCreate(kCFAllocatorDefault, e0, 1, &pc[0]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, e1, 2, &pc[1]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, e2, 3, &pc[2]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, e0, 1, &psame[0]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, e1, 2, &psame[1]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, e2, 3, &psame[2]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, f0, 1, &pshaped[0]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, f1, 2, &pshaped[1]);
        port_CMTagCollectionCreate(kCFAllocatorDefault, f2, 3, &pshaped[2]);

        CMTaggedBufferGroupRef hostGroups[4], portGroups[4];
        #define GROUP(into, create, cols, bufs) \
            { CFMutableArrayRef t = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks); \
              CFMutableArrayRef b = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks); \
              for (CFIndex i = 0; i < 3; i++) { CFArrayAppendValue(t, (cols)[i]); \
                  CFArrayAppendValue(b, (bufs)[i]); } \
              create(kCFAllocatorDefault, t, b, &(into)[0]); \
              CFRelease(t); CFRelease(b); } \
            { CFMutableArrayRef t = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks); \
              CFMutableArrayRef b = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks); \
              CFArrayAppendValue(t, (cols)[0]); CFArrayAppendValue(t, (cols)[1]); \
              CFArrayAppendValue(b, (bufs)[0]); CFArrayAppendValue(b, (bufs)[1]); \
              create(kCFAllocatorDefault, t, b, &(into)[1]); \
              CFRelease(t); CFRelease(b); } \
            { CFMutableArrayRef t = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks); \
              CFMutableArrayRef b = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks); \
              for (CFIndex i = 0; i < 3; i++) { CFArrayAppendValue(t, (hsameAlt)[i]); \
                  CFArrayAppendValue(b, (bufs)[i + 3]); } \
              create(kCFAllocatorDefault, t, b, &(into)[2]); \
              CFRelease(t); CFRelease(b); } \
            { CFMutableArrayRef t = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks); \
              CFMutableArrayRef b = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks); \
              for (CFIndex i = 0; i < 3; i++) { CFArrayAppendValue(t, (hshapedAlt)[i]); \
                  CFArrayAppendValue(b, (bufs)[i]); } \
              create(kCFAllocatorDefault, t, b, &(into)[3]); \
              CFRelease(t); CFRelease(b); }
        #define hsameAlt hsame
        #define hshapedAlt hshaped
        GROUP(hostGroups, CMTaggedBufferGroupCreate, hc, made)
        #undef hsameAlt
        #undef hshapedAlt
        #define hsameAlt psame
        #define hshapedAlt pshaped
        GROUP(portGroups, port_CMTaggedBufferGroupCreate, pc, made)

        // 1. the description, and what it is
        CMTaggedBufferGroupFormatDescriptionRef hDesc = NULL, pDesc = NULL;
        OSStatus hMade = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
            kCFAllocatorDefault, hostGroups[0], &hDesc);
        OSStatus pMade = port_CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
            kCFAllocatorDefault, portGroups[0], &pDesc);
        same("create status", [NSString stringWithFormat:@"%d", (int)hMade],
                                 [NSString stringWithFormat:@"%d", (int)pMade]);
        same("create out non-null", hDesc ? @"non-null" : @"NULL", pDesc ? @"non-null" : @"NULL");
        same("it is a CMFormatDescription",
             (hDesc && CFGetTypeID(hDesc) == CMFormatDescriptionGetTypeID()) ? @"yes" : @"no",
             (pDesc && CFGetTypeID(pDesc) == CMFormatDescriptionGetTypeID()) ? @"yes" : @"no");
        same("media subtype",
             hDesc ? [NSString stringWithFormat:@"%u", (unsigned)CMFormatDescriptionGetMediaSubType(hDesc)] : @"no description",
             pDesc ? [NSString stringWithFormat:@"%u", (unsigned)CMFormatDescriptionGetMediaSubType(pDesc)] : @"no description");
        same("the group it describes has entries",
             [NSString stringWithFormat:@"%ld", hostGroups[0] ? (long)CMTaggedBufferGroupGetCount(hostGroups[0]) : -1L],
             [NSString stringWithFormat:@"%ld", portGroups[0] ? (long)port_CMTaggedBufferGroupGetCount(portGroups[0]) : -1L]);

        // 2. Matches, over the four groups and NULL
        #define MATCHES(label, hostGroup, portGroup) \
            same(label, \
                 [NSString stringWithFormat:@"%d", (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(hDesc, hostGroup)], \
                 [NSString stringWithFormat:@"%d", (int)port_CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(pDesc, portGroup)])
        MATCHES("matches the group it came from", hostGroups[0], portGroups[0]);
        MATCHES("matches a two-entry group", hostGroups[1], portGroups[1]);
        MATCHES("matches same tags over different buffers", hostGroups[2], portGroups[2]);
        MATCHES("matches same entry sizes over different tags", hostGroups[3], portGroups[3]);
        MATCHES("matches NULL", NULL, NULL);

        // 3. the description a NULL group gives: real, and matching nothing
        CMTaggedBufferGroupFormatDescriptionRef hFromNull = NULL, pFromNull = NULL;
        OSStatus hNull = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
            kCFAllocatorDefault, NULL, &hFromNull);
        OSStatus pNull = port_CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
            kCFAllocatorDefault, NULL, &pFromNull);
        same("NULL group create status", [NSString stringWithFormat:@"%d", (int)hNull],
                                             [NSString stringWithFormat:@"%d", (int)pNull]);
        same("NULL group gives a real description", hFromNull ? @"non-null" : @"NULL",
                                                     pFromNull ? @"non-null" : @"NULL");
        same("NULL group's description matches the real group",
             [NSString stringWithFormat:@"%d", (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(hFromNull, hostGroups[0])],
             [NSString stringWithFormat:@"%d", (int)port_CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(pFromNull, portGroups[0])]);
        same("NULL group's description matches NULL",
             [NSString stringWithFormat:@"%d", (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(hFromNull, NULL)],
             [NSString stringWithFormat:@"%d", (int)port_CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(pFromNull, NULL)]);

        // 4. WithExtensions, with nothing and with a dictionary
        const void *eKeys[] = { CFSTR("charon.test") };
        const void *eVals[] = { CFSTR("value") };
        CFDictionaryRef ext = CFDictionaryCreate(NULL, eKeys, eVals, 1, &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
        CMTaggedBufferGroupFormatDescriptionRef hExt = NULL, pExt = NULL, hNoExt = NULL, pNoExt = NULL;
        OSStatus hE = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
            kCFAllocatorDefault, hostGroups[0], ext, &hExt);
        OSStatus pE = port_CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
            kCFAllocatorDefault, portGroups[0], ext, &pExt);
        OSStatus hN = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
            kCFAllocatorDefault, hostGroups[0], NULL, &hNoExt);
        OSStatus pN = port_CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
            kCFAllocatorDefault, portGroups[0], NULL, &pNoExt);
        same("withExtensions with a dictionary: status", [NSString stringWithFormat:@"%d", (int)hE],
                                                         [NSString stringWithFormat:@"%d", (int)pE]);
        same("withExtensions with a dictionary: out", hExt ? @"non-null" : @"NULL",
                                                      pExt ? @"non-null" : @"NULL");
        same("withExtensions with a dictionary: matches",
             [NSString stringWithFormat:@"%d", (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(hExt, hostGroups[0])],
             [NSString stringWithFormat:@"%d", (int)port_CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(pExt, portGroups[0])]);
        same("withExtensions with NULL: status", [NSString stringWithFormat:@"%d", (int)hN],
                                                 [NSString stringWithFormat:@"%d", (int)pN]);
        same("withExtensions with NULL: matches",
             [NSString stringWithFormat:@"%d", (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(hNoExt, hostGroups[0])],
             [NSString stringWithFormat:@"%d", (int)port_CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(pNoExt, portGroups[0])]);

        // 5. the sample buffer round trip
        CMSampleBufferRef hSbuf = NULL, pSbuf = NULL;
        OSStatus hSB = CMSampleBufferCreateForTaggedBufferGroup(
            kCFAllocatorDefault, hostGroups[0], CMTimeMake(1, 2), CMTimeMake(2, 1), hDesc, &hSbuf);
        OSStatus pSB = port_CMSampleBufferCreateForTaggedBufferGroup(
            kCFAllocatorDefault, portGroups[0], CMTimeMake(1, 2), CMTimeMake(2, 1), pDesc, &pSbuf);
        same("sample buffer create status", [NSString stringWithFormat:@"%d", (int)hSB],
                                               [NSString stringWithFormat:@"%d", (int)pSB]);
        same("sample buffer out", hSbuf ? @"non-null" : @"NULL", pSbuf ? @"non-null" : @"NULL");
        same("the buffer hands the same group back",
             CMSampleBufferGetTaggedBufferGroup(hSbuf) == hostGroups[0] ? @"same pointer" : @"different",
             port_CMSampleBufferGetTaggedBufferGroup(pSbuf) == portGroups[0] ? @"same pointer" : @"different");
        same("numSamples", [NSString stringWithFormat:@"%ld", (long)CMSampleBufferGetNumSamples(hSbuf)],
                               [NSString stringWithFormat:@"%ld", (long)CMSampleBufferGetNumSamples(pSbuf)]);
        same("is data ready", CMSampleBufferDataIsReady(hSbuf) ? @"yes" : @"no",
                                   CMSampleBufferDataIsReady(pSbuf) ? @"yes" : @"no");
        CMTime hPTS = CMSampleBufferGetPresentationTimeStamp(hSbuf), pPTS = CMSampleBufferGetPresentationTimeStamp(pSbuf);
        CMTime hDur = CMSampleBufferGetDuration(hSbuf), pDur = CMSampleBufferGetDuration(pSbuf);
        same("presentation timestamp", [NSString stringWithFormat:@"%lld/%d", (long long)hPTS.value, (int)hPTS.timescale],
                                          [NSString stringWithFormat:@"%lld/%d", (long long)pPTS.value, (int)pPTS.timescale]);
        same("duration", [NSString stringWithFormat:@"%lld/%d", (long long)hDur.value, (int)hDur.timescale],
                          [NSString stringWithFormat:@"%lld/%d", (long long)pDur.value, (int)pDur.timescale]);

        // 6. a sample buffer that did not come from a group
        CMVideoFormatDescriptionRef vfd = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, made[0], &vfd);
        CMSampleTimingInfo timing = { CMTimeMake(0, 1), CMTimeMake(1, 1), kCMTimeInvalid, kCMTimeInvalid, 1 };
        CMSampleBufferRef plain = NULL;
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, made[0], true, NULL, NULL, vfd, &timing, &plain);
        same("a plain image sample buffer", plain ? @"created" : @"not created", @"created");
        same("a plain buffer answers NULL for the group",
             CMSampleBufferGetTaggedBufferGroup(plain) ? @"non-null" : @"NULL",
             port_CMSampleBufferGetTaggedBufferGroup(plain) ? @"non-null" : @"NULL");

        printf("%ld checks, %ld different\n", checks, different);
        return different ? 1 : 0;
    }
}
