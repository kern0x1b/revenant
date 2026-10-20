#import <UIKit/UIKit.h>

@class RevenantBackdrop;

@protocol RevenantBackdropClient <NSObject>
- (BOOL)backdropIsWanted:(RevenantBackdrop *)backdrop;
- (CGRect)backdropRegion:(RevenantBackdrop *)backdrop;
- (void)backdrop:(RevenantBackdrop *)backdrop captured:(uint8_t *)pixels width:(size_t)width height:(size_t)height rowBytes:(size_t)rowBytes rect:(CGRect)captured;
@end

@interface RevenantBackdrop : NSObject
- (instancetype)initWithView:(UIView *)view client:(id<RevenantBackdropClient>)client;
@property (nonatomic, assign) CGFloat scale;
- (void)start;
- (void)stop;
- (void)setNeedsRefresh;
- (void)invalidate;
- (void)refresh;
@end
