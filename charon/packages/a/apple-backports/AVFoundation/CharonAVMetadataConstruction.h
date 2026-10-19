// The port's own construction of the metadata classes.
//
// **Why this exists.** The 26.2 headers give no public initializer for any of these: a metadata group
// and a metadata item filter are handed out by an asset's reader, which needs media, and
// `+[AVMetadataItemFilter metadataItemFilterWithIdentifiers:]` is not on this build at all - the
// member it replaced is `allowList`. The port carries the classes, so it carries the way to make them,
// and this is that way. The classes are plain data: a list of identifiers, a list of items, a time
// range, two dates. Nothing here touches a capture device, a media library or an asset.
//
// **Why the methods are named the way they are.** A method may only assign `self` when it is in the
// `init` method family, and clang decides that from the attribute and not from the spelling: a
// selector called `charon_initWithItems:timeRange:` is not in the family, and writing
// `self = [super init]` in it is rejected. `objc_method_family(init)` puts it in the family under a
// name the port owns, so nothing collides with the header's.
//
// The factory forms are not in the init family and therefore do not need the attribute; they are
// written the way the tree's other `charon_` factories are (CharonWebKit.h, CharonHomeKitConstruction.h).
#ifndef CHARON_AVMETADATA_CONSTRUCTION_H
#define CHARON_AVMETADATA_CONSTRUCTION_H

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

// The filter's 7.0 spelling and the current one, over ONE stored list, so that a filter built through
// either answers identically through both. Measured on the host: `-identifiers` and
// `+metadataItemFilterWithIdentifiers:` are absent from this build and `-allowList` is present, so a
// port that carried only one of the two would be callable by one generation of application and not
// the other.
@interface AVMetadataItemFilter (CharonAVMetadataConstruction)
+ (instancetype)charon_metadataItemFilterWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers;
- (instancetype)charon_initWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
    __attribute__((objc_method_family(init)));
// The 7.0 spellings, declared HERE because the 26.2 headers no longer declare them: an application
// written for 7.0 calls -identifiers, and the port is the only thing on the release that can answer
// it. Without this declaration the SDK's own header is all a caller has, and it does not have it.
// AVMetadataItemFilter is the RELEASE's class - the first held rung that exports it is 7.0, so below that the port
// defines the class and from 7.0 up the release's answers - see AVMetadataItemFilter.m.
@property (nonatomic, readonly, copy) NSArray<AVMetadataIdentifier> *identifiers;
@property (nonatomic, readonly, copy) NSArray<AVMetadataIdentifier> *allowList;
@end

// A group is a list of items over a time range, which is what the header's `-initWithItems:timeRange:`
// takes. The port's own name so that it cannot be mistaken for the header's, which it does not collide
// with: this build does not implement the header's initializer either.
@interface AVMetadataGroup (CharonAVMetadataConstruction)
- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

// AVTimedMetadataGroup is the RELEASE's class (the 4.3 cache exports it), so this is a category on it
// and the initializer is attached, not ivar'd. The keys are the file's own addresses so no other
// associated key in the port can collide with them.
extern const void *CharonAVMetadataTimedItemsKey;
extern const void *CharonAVMetadataTimedRangeKey;

@interface AVTimedMetadataGroup (CharonAVMetadataConstruction)
- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

// A date range group is a list of items between two dates, and answers the time range those dates
// describe. The end date is nullable in the header and nil here means "still going", which answers
// an INVALID end time rather than a zero one.
@interface AVDateRangeMetadataGroup (CharonAVMetadataConstruction)
- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
    __attribute__((objc_method_family(init)));
@end

// The value request's 9.0 spelling, the one the corpus row is. The current header keeps
// -respondWithValue: and -respondWithError: and has dropped the specifier, so the port carries both
// generations over one request.
@interface AVMetadataItemValueRequest (CharonAVMetadataConstruction)
- (instancetype)charon_initWithSpecifier:(id)specifier
    __attribute__((objc_method_family(init)));
@end

// A body object is a detection's measurements. The port has no detector, so nothing here produces
// one in the field; the initializer is the port's own so that its own code and its own tests can make
// one and hold the values to the answers, and the defaults after a plain -init are the answers Apple
// documents for a detection that did not happen: no body, no object, no face, no angle.
@interface AVMetadataBodyObject (CharonAVMetadataConstruction)
- (instancetype)charon_initWithBodyID:(NSInteger)bodyID
                             objectID:(NSInteger)objectID
                               faceID:(NSInteger)faceID
                            rollAngle:(CGFloat)rollAngle
                             yawAngle:(CGFloat)yawAngle
    __attribute__((objc_method_family(init)));
@end

#define CHARON_AVMETADATA_BODY_CONSTRUCTION(cls) \
    @interface cls (CharonAVMetadataConstruction) \
    - (instancetype)charon_initWithObjectID:(NSInteger)objectID \
                                     faceID:(NSInteger)faceID \
                                  rollAngle:(CGFloat)rollAngle \
                                   yawAngle:(CGFloat)yawAngle \
    __attribute__((objc_method_family(init))); \
    @end

CHARON_AVMETADATA_BODY_CONSTRUCTION(AVMetadataCatBodyObject)
CHARON_AVMETADATA_BODY_CONSTRUCTION(AVMetadataDogBodyObject)
CHARON_AVMETADATA_BODY_CONSTRUCTION(AVMetadataHumanBodyObject)

#undef CHARON_AVMETADATA_BODY_CONSTRUCTION

// A salient object is the base's shape without a body, so it takes the same measurements minus the
// body id.
@interface AVMetadataSalientObject (CharonAVMetadataConstruction)
- (instancetype)charon_initWithObjectID:(NSInteger)objectID
                                 faceID:(NSInteger)faceID
                              rollAngle:(CGFloat)rollAngle
                               yawAngle:(CGFloat)yawAngle
    __attribute__((objc_method_family(init)));
@end

#endif
