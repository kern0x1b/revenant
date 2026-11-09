#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "RevenantPDFObjects.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    CGRect media;
    CGRect crop;
    CGRect bleed;
    CGRect trim;
    CGRect art;
    NSInteger rotation;
} RevenantPDFPageBoxes;

@interface RevenantPDFPageEntry : NSObject
@property (nonatomic, readonly) CGPDFPageRef page;
@property (nonatomic, readonly) RevenantPDFPageBoxes boxes;
+ (instancetype)entryWithPage:(CGPDFPageRef)page boxes:(RevenantPDFPageBoxes)boxes;
@end

NSData *_Nullable RevenantPDFAssemble(NSArray<RevenantPDFPageEntry *> *pages, NSDictionary<NSString *, id> *info, NSString *_Nullable owner,
                                      NSString *_Nullable user, uint32_t permissions, void (^_Nullable step)(NSUInteger index, BOOL finished));

@interface RevenantPDFCopier : NSObject
@property (nonatomic, readonly) BOOL failed;
- (instancetype)initWithWriter:(RevenantPDFWriter *)writer NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)registerPage:(CGPDFPageRef)page reference:(RevenantPDFReference *)reference;
- (void)copyPage:(CGPDFPageRef)page
       intoReference:(RevenantPDFReference *)reference
              parent:(RevenantPDFReference *)parent
               boxes:(RevenantPDFPageBoxes)boxes;
@end

NS_ASSUME_NONNULL_END
