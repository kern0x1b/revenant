#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>

#if !__has_include(<CoreMedia/CMTag.h>)
#import "CharonCMTag26.h"
#endif
#import <Foundation/Foundation.h>

#import <Foundation/Foundation.h>

CMTag *charon_copy_all_tags(CMTagCollectionRef collection, CMItemCount *countOut);

BOOL charon_tag_equal(CMTag left, CMTag right);
BOOL charon_tag_is_less(CMTag left, CMTag right);
BOOL charon_tag_carries(const CMTag *held, CMItemCount heldCount, const CMTag *wanted, CMItemCount wantedCount);

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
- (CMTag *)charon_copyAllTags:(CMItemCount *)countOut;
@end
