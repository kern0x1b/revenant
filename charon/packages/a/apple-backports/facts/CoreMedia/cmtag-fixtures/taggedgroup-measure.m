// What the host does for CMTag's group format description and the two sample-buffer functions, over the
// chain the 464/0 fixture already builds: a subset chain of three entries - {video}, {video,track},
// {video,track,gone} - and three pixel buffers.
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTaggedBufferGroup.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#include <stdio.h>

static CMTagCollectionRef collection(CMTag *tags, CFIndex count)
{
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreate(kCFAllocatorDefault, tags, count, &out);
    if (status) { printf("collection create failed %d\n", status); return NULL; }
    return out;
}

int main(void)
{
    CMTag video = kCMTagMediaTypeVideo;
    CMTag track = CMTagMakeWithSInt64Value(kCMTagCategory_TrackID, 7);
    CMTag gone  = CMTagMakeWithSInt64Value(kCMTagCategory_MediaSubType, 0x676F6E65);

    CMTag e0[1] = { video };
    CMTag e1[2] = { video, track };
    CMTag e2[3] = { video, track, gone };
    CMTagCollectionRef chain[3] = { collection(e0,1), collection(e1,2), collection(e2,3) };
    printf("chain counts: %ld %ld %ld\n",
        (long)CMTagCollectionGetCount(chain[0]), (long)CMTagCollectionGetCount(chain[1]),
        (long)CMTagCollectionGetCount(chain[2]));

    CFMutableArrayRef tags = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
    CFMutableArrayRef bufs = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
    CVPixelBufferRef made[3];
    for (CFIndex i = 0; i < 3; i++) {
        CFArrayAppendValue(tags, chain[i]);
        CVPixelBufferCreate(kCFAllocatorDefault, 8, 8, kCVPixelFormatType_32BGRA, NULL, &made[i]);
        CFArrayAppendValue(bufs, made[i]);
    }
    CMTaggedBufferGroupRef group = NULL;
    OSStatus created = CMTaggedBufferGroupCreate(kCFAllocatorDefault, tags, bufs, &group);
    printf("group create %d count %ld\n", created, (long)CMTaggedBufferGroupGetCount(group));

    // 1. the plain create
    CMTaggedBufferGroupFormatDescriptionRef desc = NULL;
    OSStatus made1 = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
        kCFAllocatorDefault, group, &desc);
    printf("\ncreate: status %d out %s\n", made1, desc ? "non-null" : "NULL");
    if (desc) {
        // what is it, and is it opaque? Compare its type against ones this file can name, and ask the
        // format-description entry points whether they recognise it.
        CFTypeID type = CFGetTypeID(desc);
        printf("  its CFTypeID %lu; is a CMFormatDescription %d, is a CFDictionary %d, is a CFData %d\n",
            (unsigned long)type,
            (int)(type == CMFormatDescriptionGetTypeID()),
            (int)(type == CFDictionaryGetTypeID()),
            (int)(type == CFDataGetTypeID()));
        FourCharCode sub = CMFormatDescriptionGetMediaSubType(desc);
        printf("  CMFormatDescriptionGetMediaSubType on it answers %u\n", (unsigned)sub);
    }

    // 2. Matches: the group it came from, a different group, and NULL
    if (desc) {
        printf("\nmatches: same group %d\n",
            (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(desc, group));
        CMTaggedBufferGroupRef other = NULL;
        CFMutableArrayRef otherTags = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
        CFMutableArrayRef otherBufs = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
        CFArrayAppendValue(otherTags, chain[0]); CFArrayAppendValue(otherTags, chain[1]);
        CFArrayAppendValue(otherBufs, made[0]);   CFArrayAppendValue(otherBufs, made[1]);
        CMTaggedBufferGroupCreate(kCFAllocatorDefault, otherTags, otherBufs, &other);
        printf("matches: two entries %d\n",
            (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(desc, other));
        // a group of the same shape but different buffers
        CFMutableArrayRef sameShape = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
        CFMutableArrayRef sameShapeBufs = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
        CVPixelBufferRef other3[3];
        for (CFIndex i = 0; i < 3; i++) {
            CFArrayAppendValue(sameShape, chain[i]);
            CVPixelBufferCreate(kCFAllocatorDefault, 8, 8, kCVPixelFormatType_32BGRA, NULL, &other3[i]);
            CFArrayAppendValue(sameShapeBufs, other3[i]);
        }
        CMTaggedBufferGroupRef twin = NULL;
        CMTaggedBufferGroupCreate(kCFAllocatorDefault, sameShape, sameShapeBufs, &twin);
        printf("matches: same shape, different buffers %d\n",
            (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(desc, twin));
        printf("matches: NULL group %d\n",
            (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(desc, NULL));
        // the control: three entries of the SAME SIZES but different tags. If Matches only counted,
        // this would answer 1.
        CMTag f0[1] = { gone };
        CMTag f1[2] = { gone, track };
        CMTag f2[3] = { gone, track, video };
        CMTagCollectionRef shaped[3] = { collection(f0,1), collection(f1,2), collection(f2,3) };
        CFMutableArrayRef st = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
        CFMutableArrayRef sb = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
        for (CFIndex i = 0; i < 3; i++) { CFArrayAppendValue(st, shaped[i]); CFArrayAppendValue(sb, made[i]); }
        CMTaggedBufferGroupRef sameSizes = NULL;
        CMTaggedBufferGroupCreate(kCFAllocatorDefault, st, sb, &sameSizes);
        printf("matches: same entry sizes, different tags %d\n",
            (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(desc, sameSizes));
        // and the out-parameter for a NULL group
        CMTaggedBufferGroupFormatDescriptionRef fromNull = (void *)0x1;
        OSStatus nullStatus = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
            kCFAllocatorDefault, NULL, &fromNull);
        printf("create from a NULL group: status %d out %s\n", nullStatus,
            fromNull == NULL ? "set to NULL" : (fromNull == (void *)0x1 ? "left alone" : "non-null"));
        if (fromNull && fromNull != (void *)0x1) {
            // is it a real object? ask before touching it, then release it under ASan: a host that
            // writes a pointer it does not own would say so here rather than in a crash later.
            CFTypeID t = CFGetTypeID(fromNull);
            printf("  and it is a CFTypeID %lu, a CMFormatDescription %d, subtype %u\n", (unsigned long)t,
                (int)(t == CMFormatDescriptionGetTypeID()),
                (unsigned)CMFormatDescriptionGetMediaSubType(fromNull));
            printf("  and it matches the real group %d, matches NULL %d\n",
                (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(fromNull, group),
                (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(fromNull, NULL));
            CFRelease(fromNull);
            printf("  released without an ASan report\n");
        }
    }

    // 3. the 26.0 one, with and without extensions
    CMTaggedBufferGroupFormatDescriptionRef withExt = NULL;
    OSStatus made2 = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
        kCFAllocatorDefault, group, NULL, &withExt);
    printf("\nwithExtensions NULL dict: status %d out %s matches %d\n", made2,
        withExt ? "non-null" : "NULL",
        withExt ? (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(withExt, group) : -1);
    const void *ekeys[] = { CFSTR("a") };
    const void *evals[] = { CFSTR("b") };
    CFDictionaryRef ext = CFDictionaryCreate(NULL, ekeys, evals, 1, &kCFTypeDictionaryKeyCallBacks,
                                             &kCFTypeDictionaryValueCallBacks);
    CMTaggedBufferGroupFormatDescriptionRef withExt2 = NULL;
    OSStatus made3 = CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
        kCFAllocatorDefault, group, ext, &withExt2);
    printf("withExtensions one key: status %d out %s matches %d\n", made3,
        withExt2 ? "non-null" : "NULL",
        withExt2 ? (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(withExt2, group) : -1);

    // 4. the sample buffer round trip
    if (desc) {
        CMSampleBufferRef sbuf = NULL;
        OSStatus sb = CMSampleBufferCreateForTaggedBufferGroup(
            kCFAllocatorDefault, group, CMTimeMake(1, 2), CMTimeMake(2, 1), desc, &sbuf);
        printf("\nsample buffer: status %d out %s\n", sb, sbuf ? "non-null" : "NULL");
        if (sbuf) {
            CMTaggedBufferGroupRef back = CMSampleBufferGetTaggedBufferGroup(sbuf);
            printf("  GetTaggedBufferGroup %s  same pointer %d  count %ld  matchesDesc %d\n",
                back ? "non-null" : "NULL", back == group,
                back ? (long)CMTaggedBufferGroupGetCount(back) : -1,
                back ? (int)CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(desc, back) : -1);
            printf("  numSamples %ld isDataReady %d pts %lld/%d dur %lld/%d\n",
                (long)CMSampleBufferGetNumSamples(sbuf), (int)CMSampleBufferDataIsReady(sbuf),
                (long long)CMSampleBufferGetPresentationTimeStamp(sbuf).value,
                (int)CMSampleBufferGetPresentationTimeStamp(sbuf).timescale,
                (long long)CMSampleBufferGetDuration(sbuf).value,
                (int)CMSampleBufferGetDuration(sbuf).timescale);
            CFIndex idx = -1;
            // video is in all three collections, so the unique-match rule the group already implements
            // says NULL; 'gone' is only in the third, so it is the tag that answers.
            printf("  through the group, video (in all three) %s\n",
                CMTaggedBufferGroupGetCVPixelBufferForTag(back, kCMTagMediaTypeVideo, &idx) ? "non-null" : "NULL");
            idx = -1;
            CVPixelBufferRef pv = CMTaggedBufferGroupGetCVPixelBufferForTag(back, gone, &idx);
            printf("  through the group, gone (only the third) %s index %ld is-made[2] %d\n",
                pv ? "non-null" : "NULL", (long)idx, pv == made[2]);
            idx = -1;
            printf("  the same lookup straight on the group is-made[2] %d\n",
                (int)(CMTaggedBufferGroupGetCVPixelBufferForTag(group, gone, &idx) == made[2]));
        }
    }
    // 5. a sample buffer that did not come from a group
    {
        CMSampleBufferRef plain = NULL;
        CVPixelBufferRef one = NULL;
        CVPixelBufferCreate(kCFAllocatorDefault, 8, 8, kCVPixelFormatType_32BGRA, NULL, &one);
        CMVideoFormatDescriptionRef vfd = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, one, &vfd);
        CMSampleTimingInfo timing = { CMTimeMake(0,1), CMTimeMake(1,1), kCMTimeInvalid, kCMTimeInvalid, 1 };
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, one, true, NULL, NULL, vfd, &timing, &plain);
        if (plain) {
            printf("\nplain image sample buffer: GetTaggedBufferGroup %s\n",
                CMSampleBufferGetTaggedBufferGroup(plain) ? "non-null" : "NULL");
            CFRelease(plain);
        } else {
            printf("\nplain image sample buffer: could not create one\n");
        }
    }
    return 0;
}
