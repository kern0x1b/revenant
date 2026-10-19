#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>

#if !__has_include(<CoreMedia/CMTag.h>)
#import "CharonCMTag26.h"
#endif
#import <Foundation/Foundation.h>

#import <Foundation/Foundation.h>

// Nothing here is an API symbol: every name is charon_-prefixed, so the object that compiles
// CharonCMTagSupport.m exports none of it and the band machinery keeps it in every band.

// A malloc'd copy of a collection's tags, which the caller frees: the only way another object can read a
// collection's tags without calling the collection object's API, which on the 16.4 SDK is this package's.
CMTag *charon_copy_all_tags(CMTagCollectionRef collection, CMItemCount *countOut);

BOOL charon_tag_equal(CMTag left, CMTag right);
BOOL charon_tag_is_less(CMTag left, CMTag right);
BOOL charon_tag_carries(const CMTag *held, CMItemCount heldCount, const CMTag *wanted, CMItemCount wantedCount);

// The collection's storage and its sorted search, so that a collection's tags can be handed to another
// object without either of them calling the other's API. The class sits here rather than in
// CMTagCollection17.m for exactly that reason; the public C functions stay there.

@interface CharonCMTagCollection : NSObject
@property (nonatomic, readonly) NSUInteger charon_count;
- (instancetype)charon_initWithTags:(const CMTag *)tags count:(NSUInteger)count __attribute__((objc_method_family(init)));
- (BOOL)charon_contains:(CMTag)tag;
- (BOOL)charon_insert:(CMTag)tag;
- (BOOL)charon_remove:(CMTag)tag;
- (NSUInteger)charon_removeCategory:(CMTagCategory)category;
- (void)charon_removeAll;
- (NSUInteger)charon_countOfCategory:(CMTagCategory)category;
- (NSUInteger)charon_indexOfTag:(CMTag)tag;
- (const CMTag *)charon_tags;
// A malloc'd copy of the collection's tags, which the caller frees.
- (CMTag *)charon_copyAllTags:(CMItemCount *)countOut;
@end
