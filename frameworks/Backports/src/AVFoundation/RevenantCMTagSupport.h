#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>

#if !__has_include(<CoreMedia/CMTag.h>)
#import "RevenantCMTag26.h"
#endif
#import <Foundation/Foundation.h>

#import <Foundation/Foundation.h>

CMTag *revenant_copy_all_tags(CMTagCollectionRef collection, CMItemCount *countOut);

BOOL revenant_tag_equal(CMTag left, CMTag right);
BOOL revenant_tag_is_less(CMTag left, CMTag right);
BOOL revenant_tag_carries(const CMTag *held, CMItemCount heldCount, const CMTag *wanted, CMItemCount wantedCount);

@interface RevenantCMTagCollection : NSObject
@property (nonatomic, readonly) NSUInteger revenant_count;
- (instancetype)revenant_initWithTags:(const CMTag *)tags count:(NSUInteger)count __attribute__((objc_method_family(init)));
- (BOOL)revenant_contains:(CMTag)tag;
- (BOOL)revenant_insert:(CMTag)tag;
- (BOOL)revenant_remove:(CMTag)tag;
- (NSUInteger)revenant_removeCategory:(CMTagCategory)category;
- (void)revenant_removeAll;
- (NSUInteger)revenant_countOfCategory:(CMTagCategory)category;
- (NSUInteger)revenant_indexOfTag:(CMTag)tag;
- (const CMTag *)revenant_tags;
- (CMTag *)revenant_copyAllTags:(CMItemCount *)countOut;
@end
