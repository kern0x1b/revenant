#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#if !__has_include(<CoreMedia/CMTag.h>)
#import "CharonCMTag26.h"
#endif

// CMTaggedBufferGroup, transcribed from the SDK 26.2 header the port is written against, the way
// CharonCMTag26.h does for the tag collection: the type arrived at iOS 17 and the SDK the toolchain
// resolves is 16.4, where the header does not exist. CMTaggedBufferGroupRef is a bridged Objective-C
// class, so the port's is a class too.

#if !__has_include(<CoreMedia/CMTaggedBufferGroup.h>)

typedef struct CM_BRIDGED_TYPE(id) OpaqueCMTaggedBufferGroup * CMTaggedBufferGroupRef
    CF_REFINED_FOR_SWIFT CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

// The format description for a group. Unlike the group, this is not an Objective-C class: what a caller
// gets back is the platform's own CMFormatDescription, with media subtype 'tbgr' and the group's per-entry
// tag collections travelling in its extensions dictionary under a key of the port's own. So there is no
// opaque class behind this name - it is an alias, and the alias is deliberate.
typedef CMFormatDescriptionRef CMTaggedBufferGroupFormatDescriptionRef
    CF_REFINED_FOR_SWIFT CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CF_EXPORT OSStatus CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
    CFAllocatorRef CM_NULLABLE allocator, CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTaggedBufferGroupFormatDescriptionRef CM_NULLABLE * CM_NONNULL formatDescriptionOut) CF_REFINED_FOR_SWIFT;
CF_EXPORT OSStatus CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
    CFAllocatorRef CM_NULLABLE allocator, CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CFDictionaryRef CM_NULLABLE extensions,
    CMTaggedBufferGroupFormatDescriptionRef CM_NULLABLE * CM_NONNULL formatDescriptionOut) CF_REFINED_FOR_SWIFT;
CF_EXPORT Boolean CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(
    CMTaggedBufferGroupFormatDescriptionRef CM_NONNULL desc,
    CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup) CF_REFINED_FOR_SWIFT;
CF_EXPORT OSStatus CMSampleBufferCreateForTaggedBufferGroup(
    CFAllocatorRef CM_NULLABLE allocator, CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTime sbufPTS, CMTime sbufDuration,
    CMTaggedBufferGroupFormatDescriptionRef CM_NONNULL formatDescription,
    CMSampleBufferRef CM_NULLABLE * CM_NONNULL sBufOut) CF_REFINED_FOR_SWIFT;
CF_EXPORT CMTaggedBufferGroupRef CM_NULLABLE CMSampleBufferGetTaggedBufferGroup(
    CMSampleBufferRef CM_NONNULL sbuf) CF_REFINED_FOR_SWIFT;

CF_EXPORT CFTypeID CMTaggedBufferGroupGetTypeID(void);

CF_EXPORT OSStatus CMTaggedBufferGroupCreate(CFAllocatorRef allocator, CFArrayRef tagCollections, CFArrayRef buffers,
                                             CMTaggedBufferGroupRef *taggedBufferGroupOut);
CF_EXPORT OSStatus CMTaggedBufferGroupCreateCombined(CFAllocatorRef allocator, CFArrayRef taggedBufferGroups,
                                                      CMTaggedBufferGroupRef *taggedBufferGroupOut);
CF_EXPORT CMItemCount CMTaggedBufferGroupGetCount(CMTaggedBufferGroupRef group);
CF_EXPORT CMTagCollectionRef CMTaggedBufferGroupGetTagCollectionAtIndex(CMTaggedBufferGroupRef group, CFIndex index);
CF_EXPORT CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferAtIndex(CMTaggedBufferGroupRef group, CFIndex index);
CF_EXPORT CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferForTag(CMTaggedBufferGroupRef group, CMTag tag, CFIndex *indexOut);
CF_EXPORT CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferForTagCollection(CMTaggedBufferGroupRef group,
                                                                               CMTagCollectionRef tagCollection, CFIndex *indexOut);
CF_EXPORT CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferAtIndex(CMTaggedBufferGroupRef group, CFIndex index);
CF_EXPORT CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferForTag(CMTaggedBufferGroupRef group, CMTag tag, CFIndex *indexOut);
CF_EXPORT CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferForTagCollection(CMTaggedBufferGroupRef group,
                                                                                 CMTagCollectionRef tagCollection, CFIndex *indexOut);
CF_EXPORT CMItemCount CMTaggedBufferGroupGetNumberOfMatchesForTagCollection(CMTaggedBufferGroupRef group,
                                                                             CMTagCollectionRef tagCollection);
CF_EXPORT OSStatus CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(CFAllocatorRef allocator,
                                                                                    CMTaggedBufferGroupRef taggedBufferGroup,
                                                                                    CMFormatDescriptionRef *formatDescriptionOut);
CF_EXPORT OSStatus CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(CFAllocatorRef allocator,
                                                                                                 CMTaggedBufferGroupRef taggedBufferGroup,
                                                                                                 CFDictionaryRef extensions,
                                                                                                 CMFormatDescriptionRef *formatDescriptionOut);
CF_EXPORT Boolean CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(CMFormatDescriptionRef desc,
                                                                              CMTaggedBufferGroupRef taggedBufferGroup);

typedef CF_ENUM(OSStatus, CMTaggedBufferGroupError) {
    kCMTaggedBufferGroupError_ParamErr = -15780,
    kCMTaggedBufferGroupError_InternalError = -15781,
    kCMTaggedBufferGroupError_AllocationFailed = -15782
} CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

#endif

// The group's class, named so it cannot collide with the SDK's. It holds its entries' CMTags by value
// in a malloc'd C array it owns and frees in its finaliser, because a CTag is three machine words with
// no lifetime of its own and cannot go into an NSArray as an object. The implementation is in
// CharonCMTaggedBufferGroup.m.
@interface CharonCMTaggedBufferGroup : NSObject
- (instancetype)charon_initWithCollections:(NSArray *)collections buffers:(NSArray *)buffers
    __attribute__((objc_method_family(init)));
@property (nonatomic, readonly) NSArray *charon_collections;
@property (nonatomic, readonly) NSArray *charon_buffers;
- (NSInteger)charon_count;
- (const CMTag *)charon_tags;
- (CMItemCount)charon_tagCount;
- (CMItemCount)charon_tagOffsetAtIndex:(NSInteger)index;
- (CMTagCollectionRef)charon_collectionAtIndex:(NSInteger)index;
- (CVBufferRef)charon_bufferAtIndex:(NSInteger)index;
// The entry carrying every one of the wanted tags, when there is exactly one; NULL otherwise, and
// indexOut is left as the caller passed it.
- (CVBufferRef)charon_bufferForTags:(const CMTag *)tags count:(CMItemCount)count index:(NSInteger *)index;
- (NSInteger)charon_matchesForTags:(const CMTag *)tags count:(CMItemCount)count;
@end
