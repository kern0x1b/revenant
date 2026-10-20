#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#if !__has_include(<CoreMedia/CMTag.h>)
#import "RevenantCMTag26.h"
#endif

#if !__has_include(<CoreMedia/CMTaggedBufferGroup.h>)

typedef struct CM_BRIDGED_TYPE(id) OpaqueCMTaggedBufferGroup * CMTaggedBufferGroupRef
    CF_REFINED_FOR_SWIFT CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

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

@interface RevenantCMTaggedBufferGroup : NSObject
- (instancetype)revenant_initWithCollections:(NSArray *)collections buffers:(NSArray *)buffers
    __attribute__((objc_method_family(init)));
@property (nonatomic, readonly) NSArray *revenant_collections;
@property (nonatomic, readonly) NSArray *revenant_buffers;
- (NSInteger)revenant_count;
- (const CMTag *)revenant_tags;
- (CMItemCount)revenant_tagCount;
- (CMItemCount)revenant_tagOffsetAtIndex:(NSInteger)index;
- (CMTagCollectionRef)revenant_collectionAtIndex:(NSInteger)index;
- (CVBufferRef)revenant_bufferAtIndex:(NSInteger)index;
- (CVBufferRef)revenant_bufferForTags:(const CMTag *)tags count:(CMItemCount)count index:(NSInteger *)index;
- (NSInteger)revenant_matchesForTags:(const CMTag *)tags count:(CMItemCount)count;
@end
