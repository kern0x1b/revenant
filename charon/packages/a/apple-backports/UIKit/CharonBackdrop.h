#import <UIKit/UIKit.h>

@class CharonBackdrop;

@protocol CharonBackdropClient <NSObject>
- (BOOL)backdropIsWanted:(CharonBackdrop *)backdrop;
- (CGRect)backdropRegion:(CharonBackdrop *)backdrop;
- (void)backdrop:(CharonBackdrop *)backdrop captured:(uint8_t *)pixels width:(size_t)width height:(size_t)height rowBytes:(size_t)rowBytes rect:(CGRect)captured;
@end

@interface CharonBackdrop : NSObject
- (instancetype)initWithView:(UIView *)view client:(id<CharonBackdropClient>)client;
@property (nonatomic, assign) CGFloat scale;
- (void)start;
- (void)stop;
- (void)setNeedsRefresh;
- (void)invalidate;
- (void)refresh;
@end
